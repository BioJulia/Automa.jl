# Machine
# =======

type Machine
    states::UnitRange{Int}
    start_state::Int
    final_states::Set{Int}
    transitions::Dict{Int,Dict{UInt8,Tuple{Int,Vector{Symbol}}}}
    eof_actions::Dict{Int,Vector{Symbol}}
    dfa::DFA
end

function compile(re::RegExp.RE; optimize::Bool=true)
    dfa = nfa2dfa(remove_dead_states(re2nfa(re)))
    if optimize
        dfa = remove_dead_states(reduce_states(dfa))
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
            eof_actions[serials[s]] = sorted_unique_action_names(s.eof_actions)
        end
        for (l, (t, as)) in s.next
            if !haskey(serials, t)
                serials[t] = (serial += 1)
                push!(unvisited, t)
            end
            if !haskey(transitions, serials[s])
                transitions[serials[s]] = Dict()
            end
            transitions[serials[s]][l] = (serials[t], sorted_unique_action_names(as))
        end
    end
    return Machine(1:serial, serials[start], final_states, transitions, eof_actions, dfa)
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
