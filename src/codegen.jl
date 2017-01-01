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

function generate_exec(machine::Machine)
    trans_table = generate_transition_table(machine)
    action_code = generate_action_code(machine)
    eof_action_code = generate_eof_action_code(machine)
    @assert size(trans_table, 1) == 256
    return quote
        while p ≤ p_end
            l = data[p]
            ns = $(trans_table)[(cs - 1) << 8 + l + 1]
            $(action_code)
            if ns < 0
                # set the last state by flipping the sign
                cs = -cs
                @goto escape
            end
            cs = ns
            p += 1
        end
        if p > p_eof ≥ 0
            $(eof_action_code)
        end
        @label escape
    end
end

function generate_transition_table(machine::Machine)
    trans_table = Matrix{Int}(256, length(machine.states))
    fill!(trans_table, -1)
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

function generate_action_code(machine::Machine)
    codes = []
    for (s, trans) in machine.transitions
        codes_in = []
        for (l, (_, as)) in trans
            action = Expr(:block, [machine.actions[a] for a in as]...)
            push!(codes_in, Expr(:if, label_condition(l), action))
        end
        push!(codes, Expr(:if, :(cs == $(s)), Expr(:block, codes_in...)))
    end
    return Expr(:block, codes...)
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

function generate_eof_action_code(machine::Machine)
    codes = []
    for (s, as) in machine.eof_actions
        codes_in = [machine.actions[a] for a in as]
        push!(codes, Expr(:if, :(cs == $(s)), Expr(:block, codes_in...)))
    end
    return Expr(:block, codes...)
end
