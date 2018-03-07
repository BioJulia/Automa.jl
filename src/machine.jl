# Machine
# =======

struct Node
    state::Int
    edges::Vector{Tuple{Edge,Node}}
end

function Node(state::Int)
    return Node(state, Tuple{Edge,Node}[])
end

function Base.show(io::IO, node::Node)
    print(io, summary(node), "(<state=$(node.state),#edges=$(length(node.edges))>)")
end

function findedge(s::Node, b::UInt8)
    for (e, t) in s.edges
        if b ∈ e.labels
            return (e, t)
        end
    end
    error("$(b) ∈ label not found")
end

struct Machine
    start::Node
    states::UnitRange{Int}
    start_state::Int
    final_states::Set{Int}
    eof_actions::Dict{Int,ActionList}
end

function Base.show(io::IO, machine::Machine)
    print(io, summary(machine), "(<states=", machine.states, ",start_state=", machine.start_state, ",final_states=", machine.final_states, ">)")
end

function compile(re::RegExp.RE; optimize::Bool=true)
    dfa = nfa2dfa(remove_dead_nodes(re2nfa(re)))
    if optimize
        dfa = remove_dead_nodes(reduce_nodes(dfa))
    end
    validate(dfa)
    return dfa2machine(dfa)
end

function dfa2machine(dfa::DFA)
    newnodes = Dict{DFANode,Node}()
    new(s) = get!(() -> Node(length(newnodes) + 1), newnodes, s)
    final_states = Set{Int}()
    eof_actions = Dict{Int,ActionList}()
    for s in traverse(dfa.start)
        s′ = new(s)
        if s.final
            push!(final_states, s′.state)
            eof_actions[s′.state] = s.eof_actions
        end
        for (e, t) in s.edges
            push!(s′.edges, (e, new(t)))
        end
    end
    start = new(dfa.start)
    @assert start.state == 1
    return Machine(start, 1:length(newnodes), 1, final_states, eof_actions)
end

function execute(machine::Machine, data::Vector{UInt8})
    s = machine.start
    cs = s.state
    actions = Symbol[]
    for d in data
        try
            e, s = findedge(s, d)
            cs = s.state
            append!(actions, action_names(e.actions))
        catch ex
            if !isa(ex, ErrorException)
                rethrow()
            end
            cs = -cs
        end
    end
    if cs ∈ machine.final_states && haskey(machine.eof_actions, s.state)
        append!(actions, action_names(machine.eof_actions[s.state]))
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
    return execute(machine, convert(Vector{UInt8}, codeunits(data)))
end
