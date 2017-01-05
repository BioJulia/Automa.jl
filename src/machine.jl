# Machine
# =======

type Machine
    states::UnitRange{Int}
    start_state::Int
    final_states::Set{Int}
    transitions::Dict{Int,Dict{Any,Tuple{Int,Vector{Symbol}}}}
    eof_actions::Dict{Int,Vector{Symbol}}
    actions::Dict{Symbol,Expr}
end

function compile(re::RE; actions=nothing, optimize=2)
    dfa = nfa2dfa(remove_dead_states(re2nfa(re)))
    if optimize == 0
        # do nothing
    elseif optimize == 1
        dfa = reduce_states(dfa)
    elseif optimize == 2
        dfa = reduce_edges(reduce_states(dfa))
    else
        throw(ArgumentError("optimization level must be in {0, 1, 2}"))
    end
    if actions == nothing
        actions = Dict{Symbol,Expr}()
    elseif actions == :debug
        actions = debug_actions(dfa)
    elseif isa(actions, Dict{Symbol,Expr})
        # ok
    else
        throw(ArgumentError("invalid actions argument"))
    end
    return dfa2machine(dfa, actions)
end

function dfa2machine(dfa::DFA, actions::Dict{Symbol,Expr})
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
    return Machine(1:serial, serials[start], final_states, transitions, eof_actions, actions)
end

function debug_actions(dfa::DFA)
    actions = Set{Symbol}()
    traverse(dfa) do s
        for (_, (_, as)) in s.next
            union!(actions, sorted_action_names(as))
        end
        union!(actions, sorted_action_names(s.eof_actions))
    end
    function log_expr(name)
        return :(push!(logger, $(QuoteNode(name))))
    end
    return Dict(name => log_expr(name) for name in actions)
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
