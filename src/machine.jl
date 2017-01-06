# Machine
# =======

type Machine
    states::UnitRange{Int}
    start_state::Int
    final_states::Set{Int}
    transitions::Dict{Int,Dict{Any,Tuple{Int,Vector{Symbol}}}}
    eof_actions::Dict{Int,Vector{Symbol}}
end

function compile(re::RegExp.RE; optimize::Integer=2)
    if optimize ∉ (0, 1, 2)
        throw(ArgumentError("optimization level must be in {0, 1, 2}"))
    end
    dfa = nfa2dfa(remove_dead_states(re2nfa(re)))
    if optimize == 1
        dfa = remove_dead_states(reduce_states(dfa))
    elseif optimize == 2
        dfa = reduce_edges(remove_dead_states(reduce_states(dfa)))
    end
    return dfa2machine(dfa)
end

function dfa2machine(dfa::DFA)
    start = dfa.start
    serial = 0
    serials = Dict(start => (serial += 1))
    final_states = Set([0])  # zero indicates the EOF state
    transitions = Dict()
    eof_actions = Dict()
    unvisited = Set([start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        if s.final
            push!(final_states, serials[s])
            eof_actions[serials[s]] = sorted_action_names(s.eof_actions)
        end
        for (l, (t, as)) in s.next
            if !haskey(serials, t)
                serials[t] = (serial += 1)
                push!(unvisited, t)
            end
            if !haskey(transitions, serials[s])
                transitions[serials[s]] = Dict()
            end
            transitions[serials[s]][l] = (serials[t], sorted_action_names(as))
        end
    end
    return Machine(1:serial, serials[start], final_states, transitions, eof_actions)
end

function traverse(f::Function, dfa::DFA)
    visited = Set{DFANode}()
    unvisited = Set([dfa.start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(visited, s)
        f(s)
        for (_, (t, _)) in s.next
            if t ∉ visited
                push!(unvisited, t)
            end
        end
    end
end
