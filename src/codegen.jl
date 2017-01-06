# Code Generator
# ==============

# Variables:
#   * `p::Int`: position of current data
#   * `p_end::Int`: end position of data
#   * `p_eof::Int`: end position of file stream
#   * `cs::Int`: current state
#   * `ns::Int`: next state

function generate_init_code(machine::Machine)
    return quote
        p::Int = 1
        p_end::Int = 0
        p_eof::Int = -1
        cs::Int = $(machine.start_state)
    end
end

function generate_exec_code(machine::Machine; actions=nothing, code::Symbol=:table, inbounds::Bool=true)
    if actions == nothing
        actions = Dict{Symbol,Expr}()
    elseif actions == :debug
        actions = debug_actions(machine)
    elseif isa(actions, Associative{Symbol,Expr})
        # ok
    else
        throw(ArgumentError("invalid actions argument"))
    end
    if code == :table
        return generate_table_code(machine, actions, inbounds)
    elseif code == :inline
        return generate_inline_code(machine, actions, inbounds)
    else
        throw(ArgumentError("invalid code: $(code)"))
    end
end

function generate_table_code(machine::Machine, actions::Associative{Symbol,Expr}, inbounds::Bool)
    trans_table = generate_transition_table(machine)
    action_code = generate_table_action_code(machine, actions)
    eof_action_code = generate_eof_action_code(machine, actions)
    l_code = :(l = data[p])
    ns_code = :(ns = $(trans_table)[(cs - 1) << 8 + l + 1])
    if inbounds
        l_code = make_inbounds(l_code)
        ns_code = make_inbounds(ns_code)
    end
    @assert size(trans_table, 1) == 256
    return quote
        while p ≤ p_end && cs > 0
            $(l_code)
            $(ns_code)
            $(action_code)
            cs = ns
            p += 1
        end
        if p > p_eof ≥ 0 && cs ∈ $(machine.final_states)
            let ns = 0
                $(eof_action_code)
                cs = ns
            end
        end
    end
end

function generate_transition_table(machine::Machine)
    trans_table = Matrix{Int}(256, length(machine.states))
    for j in 1:size(trans_table, 2)
        trans_table[:,j] = -j
    end
    for (s, trans) in machine.transitions
        for (l, (t, _)) in trans
            trans_table[l+1,s] = t
        end
    end
    return trans_table
end

function generate_table_action_code(machine::Machine, actions::Associative{Symbol,Expr})
    default = :()
    return foldr(default, collect(machine.transitions)) do s_trans, els
        s, trans = s_trans
        then = foldr(default, compact_transition(trans)) do branch, els′
            l, (t, as) = branch
            action_code = rewrite_special_macros(generate_action_code(as, actions), false)
            Expr(:if, label_condition(l), action_code, els′)
        end
        Expr(:if, state_condition(s), then, els)
    end
end

function generate_inline_code(machine::Machine, actions::Associative{Symbol,Expr}, inbounds::Bool)
    trans_code = generate_transition_code(machine, actions)
    eof_action_code = generate_eof_action_code(machine, actions)
    l_code = :(l = data[p])
    if inbounds
        l_code = make_inbounds(l_code)
    end
    return quote
        while p ≤ p_end && cs > 0
            $(l_code)
            $(trans_code)
            cs = ns
            p += 1
        end
        if p > p_eof ≥ 0 && cs ∈ $(machine.final_states)
            let ns = 0
                $(eof_action_code)
                cs = ns
            end
        end
    end
end

function generate_transition_code(machine::Machine, actions::Associative{Symbol,Expr})
    default = :(ns = -cs)
    return foldr(default, collect(machine.transitions)) do s_trans, els
        s, trans = s_trans
        then = foldr(default, compact_transition(trans)) do branch, els′
            l, (t, as) = branch
            action_code = rewrite_special_macros(generate_action_code(as, actions), false)
            Expr(:if, label_condition(l), :(ns = $(t); $(action_code)), els′)
        end
        Expr(:if, state_condition(s), then, els)
    end
end

function compact_transition(trans::Dict{UInt8,Tuple{Int,Vector{Symbol}}})
    revtrans = Dict{Tuple{Int,Vector{Symbol}},Vector{UInt8}}()
    for (l, t_as) in trans
        if !haskey(revtrans, t_as)
            revtrans[t_as] = UInt8[]
        end
        push!(revtrans[t_as], l)
    end
    return [(ByteSet(ls), t_as) for (t_as, ls) in revtrans]
end

function generate_eof_action_code(machine::Machine, actions::Associative{Symbol,Expr})
    return foldr(:(), collect(machine.eof_actions)) do s_as, els
        s, as = s_as
        action_code = rewrite_special_macros(generate_action_code(as, actions), true)
        Expr(:if, state_condition(s), action_code, els)
    end
end

function generate_action_code(names::Vector{Symbol}, actions::Associative{Symbol,Expr})
    return Expr(:block, (actions[n] for n in names)...)
end

function make_inbounds(ex::Expr)
    return :(@inbounds $(ex))
end

function state_condition(s::Int)
    return :(cs == $(s))
end

function label_condition(set::ByteSet)
    label = compact_labels(set)
    return foldr((range, cond) -> Expr(:||, :(l in $(range)), cond), :(false), label)
end

function compact_labels(set::ByteSet)
    labels = collect(set)
    labels′ = UnitRange{UInt8}[]
    while !isempty(labels)
        lo = shift!(labels)
        hi = lo
        while !isempty(labels) && first(labels) == hi + 1
            hi = shift!(labels)
        end
        push!(labels′, lo:hi)
    end
    return labels′
end

function rewrite_special_macros(ex::Expr, eof_action::Bool)
    args = []
    for arg in ex.args
        if arg == :(@escape)
            if eof_action
                # pass
            else
                push!(args, quote
                    cs = ns
                    p += 1
                    break
                end)
            end
        elseif isa(arg, Expr)
            push!(args, rewrite_special_macros(arg, eof_action))
        else
            push!(args, arg)
        end
    end
    return Expr(ex.head, args...)
end

function debug_actions(machine::Machine)
    actions = Set{Symbol}()
    for trans in values(machine.transitions)
        for (_, as) in values(trans)
            union!(actions, as)
        end
    end
    for as in values(machine.eof_actions)
        union!(actions, as)
    end
    function log_expr(name)
        return :(push!(logger, $(QuoteNode(name))))
    end
    return Dict(name => log_expr(name) for name in actions)
end
