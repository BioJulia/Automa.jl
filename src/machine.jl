# Machine
# =======

immutable Machine
    states::UnitRange{Int}
    start_state::Int
    final_states::Set{Int}
    transitions::Dict{Int,Dict{UInt8,Tuple{Int,Vector{Precondition},Vector{Symbol}}}}
    eof_actions::Dict{Int,Vector{Symbol}}
    dfa::DFA
end

function Base.show(io::IO, machine::Machine)
    print(io, summary(machine), "(<states=", machine.states, ",start_state=", machine.start_state, ",final_states=", machine.final_states, ">)")
end

function compile(re::RegExp.RE; optimize::Bool=true)
    dfa = nfa2dfa(remove_dead_nodes(re2nfa(re)))
    if optimize
        dfa = remove_dead_nodes(reduce_nodes(dfa))
    end
    return dfa2machine(dfa)
end

function dfa2machine(dfa::DFA)
    serials = Dict(s => i for (i, s) in enumerate(traverse(dfa.start)))
    final_states = Set(serials[s] for s in traverse(dfa.start) if s.final)
    #transitions = Dict(
    #    serials[s] => Dict(
    #        l => (serials[t], collect(e.preconds), sorted_unique_action_names(e.actions))
    #        for (e, t) in s.edges for l in e.labels)
    #    for s in traverse(dfa.start))
    transitions = Dict()
    for s in traverse(dfa.start)
        if !haskey(transitions, serials[s])
            transitions[serials[s]] = Dict()
        end
        for (e, t) in s.edges
            for l in e.labels
                transitions[serials[s]][l] = (serials[t], collect(e.preconds), sorted_unique_action_names(e.actions))
            end
        end
    end
    eof_actions = Dict(serials[s] => sorted_unique_action_names(s.eof_actions) for s in traverse(dfa.start) if s.final)
    return Machine(1:length(serials), serials[dfa.start], final_states, transitions, eof_actions, dfa)
end

function execute(machine::Machine, data::Vector{UInt8})
    cs = machine.start_state
    actions = Symbol[]
    for d in data
        if haskey(machine.transitions[cs], d)
            cs, _, as = machine.transitions[cs][d]
            append!(actions, as)
        else
            cs = -cs
        end
        if cs < 0
            break
        end
    end
    if haskey(machine.eof_actions, cs)
        append!(actions, machine.eof_actions[cs])
    end
    if cs > 0
        if cs ∈ machine.final_states
            cs = 0
        else
            cs = -cs
        end
    end
    return cs, actions
end

function execute(machine::Machine, data::String)
    return execute(machine, convert(Vector{UInt8}, data))
end
