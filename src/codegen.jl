# Code Generator
# ==============

# Variables:
#   * `p::Int`: position of current data
#   * `p_end::Int`: end position of data
#   * `p_eof::Int`: end position of file stream
#   * `cs::Int`: current state
#   * `ns::Int`: next state

function generate_init(machine::Machine)
    return quote
        p::Int = 1
        p_end::Int = 0
        p_eof::Int = -1
        cs::Int = $(machine.start_state)
    end
end

function generate_exec(machine::Machine; code::Symbol=:table, inbounds::Bool=true)
    if code == :table
        return generate_table_code(machine, inbounds)
    elseif code == :inline
        return generate_inline_code(machine, inbounds)
    else
        throw(ArgumentError("invalid code: $(code)"))
    end
end

function generate_table_code(machine::Machine, inbounds::Bool)
    trans_table = generate_transition_table(machine)
    action_code = generate_table_action_code(machine)
    eof_action_code = generate_eof_action_code(machine)
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
            if isa(l, UInt8) || isa(l, UnitRange{UInt8})
                trans_table[l+1,s] = t
            elseif isa(l, Vector{UnitRange{UInt8}})
                for ll in l
                    trans_table[ll+1,s] = t
                end
            else
                @assert false
            end
        end
    end
    return trans_table
end

function generate_table_action_code(machine::Machine)
    default = :()
    return foldr(default, collect(machine.transitions)) do s_trans, els
        s, trans = s_trans
        then = foldr(default, collect(trans)) do branch, els′
            l, (t, actions) = branch
            action_code = rewrite_special_macros(generate_action_code(machine, actions), false)
            Expr(:if, label_condition(l), action_code, els′)
        end
        Expr(:if, state_condition(s), then, els)
    end
end

function generate_inline_code(machine::Machine, inbounds::Bool)
    trans_code = generate_transition_code(machine)
    eof_action_code = generate_eof_action_code(machine)
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

function generate_transition_code(machine::Machine)
    default = :(ns = -cs)
    return foldr(default, collect(machine.transitions)) do s_trans, els
        s, trans = s_trans
        then = foldr(default, collect(trans)) do branch, els′
            l, (t, actions) = branch
            action_code = rewrite_special_macros(generate_action_code(machine, actions), false)
            Expr(:if, label_condition(l), :(ns = $(t); $(action_code)), els′)
        end
        Expr(:if, state_condition(s), then, els)
    end
end

function generate_eof_action_code(machine::Machine)
    return foldr(:(), collect(machine.eof_actions)) do s_actions, els
        s, actions = s_actions
        action_code = rewrite_special_macros(generate_action_code(machine, actions), true)
        Expr(:if, state_condition(s), action_code, els)
    end
end

function generate_action_code(machine::Machine, actions::Vector{Symbol})
    return Expr(:block, (machine.actions[a] for a in actions)...)
end

function make_inbounds(ex::Expr)
    return :(@inbounds $(ex))
end

function state_condition(s::Int)
    return :(cs == $(s))
end

function label_condition(label)
    if isa(label, UInt8)
        return :(l == $(label))
    elseif isa(label, UnitRange{UInt8})
        return :(l in $(label))
    elseif isa(label, Vector{UnitRange{UInt8}})
        return foldr((range, cond) -> Expr(:||, :(l in $(range)), cond), :(false), label)
    else
        error("invalid label type: $(typeof(label))")
    end
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
