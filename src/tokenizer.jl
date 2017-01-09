# Tokenizer
# =========

type Tokenizer
    machine::Machine
    actions_code::Vector{Tuple{Symbol,Expr}}
end

function compile(tokens::Pair{RegExp.RE,Expr}...; optimize::Bool=true)
    start = NFANode()
    final = NFANode()
    actions = Dict{Symbol,Action}()
    for i in 1:endof(tokens)
        # HACK: place token exit actions after any other actions
        action = Action(Symbol(:__token, i), 10000 - i)
        actions[action.name] = action
    end
    actions_code = Tuple{Symbol,Expr}[]
    for (i, (re, code)) in enumerate(tokens)
        re′ = RegExp.expand(RegExp.desugar(re))
        name = Symbol(:__token, i)
        if !haskey(re′.actions, :final)
            re′.actions[:final] = Symbol[]
        end
        push!(re′.actions[:final], name)
        nfa = re2nfa_rec(re′, actions)
        addtrans!(start, (:eps, nfa.start))
        addtrans!(nfa.final, (:eps, final))
        push!(actions_code, (name, code))
    end
    nfa = NFA(start, final)
    dfa = reduce_states(nfa2dfa(nfa))
    machine = dfa2machine(dfa)
    return Tokenizer(machine, actions_code)
end

function generate_init_code(tokenizer::Tokenizer)
    quote
        p::Int = 1
        p_end::Int = 0
        p_eof::Int = -1
        cs::Int = $(tokenizer.machine.start_state)
        ts::Int = 0
        te::Int = 0
    end
end

function generate_exec_code(tokenizer::Tokenizer; actions=nothing)
    if actions == nothing
        actions = Dict{Symbol,Expr}()
    elseif actions == :debug
        actions = debug_actions(tokenizer.machine)
    elseif isa(actions, Associative{Symbol,Expr})
        actions = copy(actions)
    else
        throw(ArgumentError("invalid actions argument"))
    end
    for (i, (name, _)) in enumerate(tokenizer.actions_code)
        actions[name] = :(t = $(i); te = p)
    end
    return generate_table_code(tokenizer, actions, true)
end

function generate_table_code(tokenizer::Tokenizer, actions::Associative{Symbol,Expr}, docheck::Bool)
    trans_table = generate_transition_table(tokenizer.machine)
    action_code = generate_table_action_code(tokenizer.machine, actions)
    eof_action_code = generate_eof_action_code(tokenizer.machine, actions)
    check_code = generate_check_code(docheck)
    getbyte_code = generate_geybyte_code()
    token_exit_code = generate_token_exit_code(tokenizer)
    ns_code = :(ns = $(trans_table)[(cs - 1) << 8 + l + 1])
    @assert size(trans_table, 1) == 256
    return quote
        t = 0
        ts = p
        while p ≤ p_end && cs > 0
            $(check_code)
            $(getbyte_code)
            $(ns_code)
            $(action_code)
            cs = ns
            p += 1
        end
        if p > p_eof ≥ 0 && cs ∈ $(tokenizer.machine.final_states)
            let ns = 0
                $(eof_action_code)
                cs = ns
            end
        end
        if cs ≤ 0 || p > p_eof
            $(token_exit_code)
            p = te + 1
            cs = $(tokenizer.machine.start_state)
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
