# Tokenizer
# =========

struct Tokenizer
    machine::Machine
    actions_code::Vector{Tuple{Symbol,Expr}}
end

# For backwards compatibility. This function needlessly specializes
# on the number of tokens.
# TODO: Deprecate this
function compile(tokens::Pair{RegExp.RE,Expr}...; optimize::Bool=true)
    compile(collect(tokens), optimize=optimize)
end

function compile(tokens::AbstractVector{Pair{RegExp.RE,Expr}}; optimize::Bool=true)
    start = NFANode()
    final = NFANode()
    actions = Dict{Symbol,Action}()
    for i in 1:lastindex(tokens)
        # HACK: place token exit actions after any other actions
        action = Action(Symbol(:__token, i), 10000 - i)
        actions[action.name] = action
    end
    actions_code = Tuple{Symbol,Expr}[]
    for (i, (re, code)) in enumerate(tokens)
        re′ = RegExp.shallow_desugar(re)
        push!(get!(() -> Symbol[], re′.actions, :enter), :__token_start)
        name = Symbol(:__token, i)
        push!(get!(() -> Symbol[], re′.actions, :final), name)
        nfa = re2nfa(re′, actions)
        push!(start.edges, (Edge(eps), nfa.start))
        push!(nfa.final.edges, (Edge(eps), final))
        push!(actions_code, (name, code))
    end
    nfa = NFA(start, final)
    dfa = nfa2dfa(remove_dead_nodes(nfa))
    if optimize
        dfa = remove_dead_nodes(reduce_nodes(dfa))
    end
    return Tokenizer(dfa2machine(dfa), actions_code)
end

function generate_init_code(tokenizer::Tokenizer)
    # TODO: deprecate this?
    return generate_init_code(CodeGenContext(), tokenizer)
end

function generate_init_code(ctx::CodeGenContext, tokenizer::Tokenizer)
    quote
        $(ctx.vars.p)::Int = 1
        $(ctx.vars.p_end)::Int = 0
        $(ctx.vars.p_eof)::Int = -1
        $(ctx.vars.ts)::Int = 0
        $(ctx.vars.te)::Int = 0
        $(ctx.vars.cs)::Int = $(tokenizer.machine.start_state)
    end
end

function generate_exec_code(ctx::CodeGenContext, tokenizer::Tokenizer, actions=nothing)
    if actions === nothing
        actions = Dict{Symbol,Expr}()
    elseif actions == :debug
        actions = debug_actions(tokenizer.machine)
    elseif isa(actions, AbstractDict{Symbol,Expr})
        actions = copy(actions)
    else
        throw(ArgumentError("invalid actions argument"))
    end
    actions[:__token_start] = :($(ctx.vars.ts) = $(ctx.vars.p))
    for (i, (name, _)) in enumerate(tokenizer.actions_code)
        actions[name] = :(t = $(i); $(ctx.vars.te) = $(ctx.vars.p))
    end
    return generate_table_code(ctx, tokenizer, actions)
end

function generate_table_code(ctx::CodeGenContext, tokenizer::Tokenizer, actions::AbstractDict{Symbol,Expr})
    action_dispatch_code, set_act_code = generate_action_dispatch_code(ctx, tokenizer.machine, actions)
    trans_table = generate_transition_table(tokenizer.machine)
    getbyte_code = generate_geybyte_code(ctx)
    cs_code = :($(ctx.vars.cs) = $(trans_table)[($(ctx.vars.cs) - 1) << 8 + $(ctx.vars.byte) + 1])
    eof_action_code = generate_eof_action_code(ctx, tokenizer.machine, actions)
    token_exit_code = generate_token_exit_code(tokenizer)
    return quote
        $(ctx.vars.mem) = $(SizedMemory)($(ctx.vars.data))
        # Initialize token and token start to 0 - no token seen yet
        t = 0
        ts = 0
        # In a loop: Get input byte, set action, update current state, execute action
        while p ≤ p_end && cs > 0
            $(getbyte_code)
            $(set_act_code)
            $(cs_code)
            $(action_dispatch_code)
            p += 1
        end
        if p > p_eof ≥ 0
            # If EOF and in accept state, run EOF code and set current state to 0
            # meaning accept state
            if cs ∈ $(tokenizer.machine.final_states)
                $(eof_action_code)
                cs = 0
            # Else, if we're not already in a failed state (cs < 0), then set cs to failed state
            elseif cs > 0
                cs = -cs
            end
        end
        # If in a failed state, reset p (why do we do this?)
        if cs < 0
            p -= 1
        end
        if t > 0 && (cs ≤ 0 || p > p_end ≥ 0)
            $(token_exit_code)
            p = te + 1
            if cs != 0
                cs = $(tokenizer.machine.start_state)
            end
        end
    end
end

function generate_token_exit_code(tokenizer::Tokenizer)
    i = 0
    default = :()
    return foldr(default, reverse(tokenizer.actions_code)) do name_code, els
        _, code = name_code
        i += 1
        Expr(:if, :(t == $(i)), code, els)
    end
end
