# Code Generator
# ==============

# Variables:
#   * `p::Int`: position of current data
#   * `p_end::Int`: end position of data
#   * `p_eof::Int`: end position of file stream
#   * `cs::Int`: current state

function generate_init_code(machine::Machine)
    return quote
        p::Int = 1
        p_end::Int = 0
        p_eof::Int = -1
        cs::Int = $(machine.start_state)
    end
end

function generate_exec_code(machine::Machine; actions=nothing, code::Symbol=:table, check::Bool=true, clean::Bool=false)
    if actions == nothing
        actions = Dict{Symbol,Expr}()
    elseif actions == :debug
        actions = debug_actions(machine)
    elseif isa(actions, Associative{Symbol,Expr})
        actions = convert(Dict, actions)
    else
        throw(ArgumentError("invalid actions argument"))
    end

    if code == :table
        code = generate_table_code(machine, actions, check)
    elseif code == :inline
        code = generate_inline_code(machine, actions, check)
    elseif code == :goto
        code = generate_goto_code(machine, actions, check)
    else
        throw(ArgumentError("invalid code: $(code)"))
    end

    if clean
        return cleanup(code)
    else
        return code
    end
end

function generate_table_code(machine::Machine, actions::Dict{Symbol,Expr}, check::Bool)
    action_dispatch_code, action_table = generate_action_dispatch_code(machine, actions)
    trans_table = generate_transition_table(machine)
    getbyte_code = generate_geybyte_code(check)
    act_code = :(@inbounds act = $(action_table)[(cs - 1) << 8 + l + 1])
    cs_code = :(@inbounds cs = $(trans_table)[(cs - 1) << 8 + l + 1])
    eof_action_code = generate_eof_action_code(machine, actions)
    @assert size(action_table, 1) == size(trans_table, 1) == 256
    return quote
        while p ≤ p_end && cs > 0
            $(getbyte_code)
            $(act_code)
            $(cs_code)
            $(action_dispatch_code)
            p += 1
        end
        if p > p_eof ≥ 0 && cs ∈ $(machine.final_states)
            $(eof_action_code)
            cs = 0
        elseif cs < 0
            p -= 1
        end
    end
end

function generate_transition_table(machine::Machine)
    trans_table = Matrix{Int}(256, length(machine.states))
    for j in 1:size(trans_table, 2)
        trans_table[:,j] = -j
    end
    for s in traverse(machine.start), (e, t) in s.edges, l in e.labels
        trans_table[l+1,s.state] = t.state
    end
    return trans_table
end

function generate_action_dispatch_code(machine::Machine, actions::Dict{Symbol,Expr})
    action_table = Matrix{Int}(256, length(machine.states))
    fill!(action_table, 0)
    action_ids = Dict{Vector{Symbol},Int}()
    for s in traverse(machine.start)
        for (e, t) in s.edges
            if isempty(e.actions)
                continue
            end
            names = sorted_unique_action_names(e.actions)
            id = get!(action_ids, names, length(action_ids) + 1)
            for l in e.labels
                action_table[l+1,s.state] = id
            end
        end
    end
    default = :()
    action_dispatch_code = foldr(default, action_ids) do names_id, els
        names, id = names_id
        action_code = rewrite_special_macros(generate_action_code(names, actions), false)
        return Expr(:if, :(act == $(id)), action_code, els)
    end
    return action_dispatch_code, action_table
end

function generate_inline_code(machine::Machine, actions::Dict{Symbol,Expr}, check::Bool)
    trans_code = generate_transition_code(machine, actions)
    eof_action_code = generate_eof_action_code(machine, actions)
    getbyte_code = generate_geybyte_code(check)
    return quote
        while p ≤ p_end && cs > 0
            $(getbyte_code)
            $(trans_code)
            p += 1
        end
        if p > p_eof ≥ 0 && cs ∈ $(machine.final_states)
            $(eof_action_code)
            cs = 0
        elseif cs < 0
            p -= 1
        end
    end
end

function generate_transition_code(machine::Machine, actions::Dict{Symbol,Expr})
    default = :(cs = -cs)
    return foldr(default, traverse(machine.start)) do s, els
        then = foldr(default, s.edges) do edge, els′
            e, t = edge
            action_code = rewrite_special_macros(generate_action_code(e.actions, actions), false)
            then′ = :(cs = $(t.state); $(action_code))
            return Expr(:if, generate_condition_code(e, actions), then′, els′)
        end
        return Expr(:if, state_condition(s.state), then, els)
    end
end

function compact_transition{T}(trans::Dict{UInt8,T})
    revtrans = Dict{T,Vector{UInt8}}()
    for (l, val) in trans
        if !haskey(revtrans, val)
            revtrans[val] = UInt8[]
        end
        push!(revtrans[val], l)
    end
    return [(ByteSet(ls), val) for (val, ls) in revtrans]
end

function generate_goto_code(machine::Machine, actions::Dict{Symbol,Expr}, check::Bool)
    actions_in = Dict{Node,Set{Vector{Symbol}}}()
    for s in traverse(machine.start), (e, t) in s.edges
        push!(get!(actions_in, t, Set{Vector{Symbol}}()), sorted_unique_action_names(e.actions))
    end
    action_label = Dict{Node,Dict{Vector{Symbol},Symbol}}()
    for s in traverse(machine.start)
        action_label[s] = Dict()
        if haskey(actions_in, s)
            for (i, names) in enumerate(actions_in[s])
                action_label[s][names] = Symbol("state_", s.state, "_action_", i)
            end
        end
    end

    blocks = Expr[]
    for s in traverse(machine.start)
        block = Expr(:block)
        for (names, label) in action_label[s]
            if isempty(names)
                continue
            end
            append_code!(block, quote
                @label $(label)
                $(rewrite_special_macros(generate_action_code(names, actions), false, s.state))
                @goto $(Symbol("state_", s.state))
            end)
        end
        append_code!(block, quote
            @label $(Symbol("state_", s.state))
            p += 1
            if p > p_end
                cs = $(s.state)
                @goto exit
            end
        end)
        default = :(cs = $(-s.state); @goto exit)
        dispatch_code = foldr(default, s.edges) do edge, els
            e, t = edge
            if isempty(e.actions)
                then = :(@goto $(Symbol("state_", t.state)))
            else
                then = :(@goto $(action_label[t][sorted_unique_action_names(e.actions)]))
            end
            return Expr(:if, generate_condition_code(e, actions), then, els)
        end
        append_code!(block, quote
            @label $(Symbol("state_case_", s.state))
            $(generate_geybyte_code(check))
            $(dispatch_code)
        end)
        push!(blocks, block)
    end

    enter_code = foldr(:(@goto exit), machine.states) do s, els
        return Expr(:if, :(cs == $(s)), :(@goto $(Symbol("state_case_", s))), els)
    end

    eof_action_code = rewrite_special_macros(generate_eof_action_code(machine, actions), true)

    return quote
        if p > p_end
            @goto exit
        end
        $(enter_code)
        $(Expr(:block, blocks...))
        @label exit
        if p > p_eof ≥ 0 && cs ∈ $(machine.final_states)
            $(eof_action_code)
            cs = 0
        elseif cs < 0
            p -= 1
        end
    end
end

function append_code!(block::Expr, code::Expr)
    @assert block.head == :block
    @assert code.head == :block
    append!(block.args, code.args)
    return block
end

function generate_eof_action_code(machine::Machine, actions::Dict{Symbol,Expr})
    return foldr(:(), machine.eof_actions) do s_as, els
        s, as = s_as
        names = sorted_unique_action_names(as)
        action_code = rewrite_special_macros(generate_action_code(names, actions), true)
        Expr(:if, state_condition(s), action_code, els)
    end
end

function generate_action_code(set::Set{Action}, actions::Dict{Symbol,Expr})
    return generate_action_code(sorted_unique_action_names(set), actions)
end

function generate_action_code(names::Vector{Symbol}, actions::Dict{Symbol,Expr})
    return Expr(:block, (actions[n] for n in names)...)
end

function generate_geybyte_code(docheck::Bool)
    block = Expr(:block)
    if docheck
        append_code!(block, quote
            if !$(check)(data, p)
                throw(BoundsError(data, p))
            end
        end)
    end
    append_code!(block, quote
        l = $(getbyte)(data, p)
    end)
    return block
end

function state_condition(s::Int)
    return :(cs == $(s))
end

function generate_condition_code(edge::Edge, actions::Dict{Symbol,Expr})
    labelcode = foldr((range, cond) -> Expr(:||, :(l in $(range)), cond), :(false), range_encode(edge.labels))
    precondcode = foldr((p, cond) -> Expr(:&&, p.value ? actions[p.name] : :(!$(actions[p.name])), cond), :(true), edge.preconds)
    return :($(labelcode) && $(precondcode))
end

# Used by the :table and :inline code generators.
function rewrite_special_macros(ex::Expr, eof::Bool)
    args = []
    for arg in ex.args
        if arg == :(@escape)
            if !eof
                push!(args, quote
                    p += 1
                    break
                end)
            end
        elseif isa(arg, Expr)
            push!(args, rewrite_special_macros(arg, eof))
        else
            push!(args, arg)
        end
    end
    return Expr(ex.head, args...)
end

# Used by the :goto code generator.
function rewrite_special_macros(ex::Expr, eof::Bool, cs::Int)
    args = []
    for arg in ex.args
        if arg == :(@escape)
            if !eof
                push!(args, quote
                    cs = $(cs)
                    p += 1
                    @goto exit
                end)
            end
        elseif isa(arg, Expr)
            push!(args, rewrite_special_macros(arg, eof, cs))
        else
            push!(args, arg)
        end
    end
    return Expr(ex.head, args...)
end

function cleanup(ex::Expr)
    args = []
    for arg in ex.args
        if isa(arg, Expr)
            if arg.head == :line
                # pass
            elseif ex.head == :block && arg.head == :block
                append!(args, cleanup(arg).args)
            else
                push!(args, cleanup(arg))
            end
        else
            push!(args, arg)
        end
    end
    return Expr(ex.head, args...)
end

function debug_actions(machine::Machine)
    actions = Set{Symbol}()
    for s in traverse(machine.start)
        for (e, t) in s.edges
            union!(actions, a.name for a in e.actions)
        end
    end
    for as in values(machine.eof_actions)
        union!(actions, a.name for a in as)
    end
    function log_expr(name)
        return :(push!(logger, $(QuoteNode(name))))
    end
    return Dict(name => log_expr(name) for name in actions)
end

# Generic foldr.
function foldr(op::Function, x0, xs)
    function rec(xs, s)
        if done(xs, s)
            return x0
        else
            x, s = next(xs, s)
            return op(x, rec(xs, s))
        end
    end
    return rec(xs, start(xs))
end


# Accessors
# ---------

@inline function check(data::String, p::Integer)
    return 1 ≤ p ≤ sizeof(data)
end

@inline function getbyte(data::String, p::Integer)
    return unsafe_load(pointer(data), p)
end

@inline function check(data::AbstractVector{UInt8}, p::Integer)
    return 1 ≤ p ≤ endof(data)
end

@inline function getbyte(data::AbstractVector{UInt8}, p::Integer)
    @inbounds return data[p]
end
