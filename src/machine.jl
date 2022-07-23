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

function action_names(machine::Machine)
    actions = Set{Symbol}()
    for s in traverse(machine.start)
        for (e, t) in s.edges
            union!(actions, a.name for a in e.actions)
        end
    end
    for as in values(machine.eof_actions)
        union!(actions, a.name for a in as)
    end
    return actions
end

function machine_names(machine::Machine)
    actions = action_names(machine)
    for node in traverse(machine.start), (e, _) in node.edges
        union!(actions, e.precond.names)
    end
    return actions
end

function Base.show(io::IO, machine::Machine)
    print(io, summary(machine), "(<states=", machine.states, ",start_state=", machine.start_state, ",final_states=", machine.final_states, ">)")
end

"""
    compile(re::RegExp; optimize, unambiguous) -> Machine

Compile a finite state machine (FSM) from RegExp `re`. If `optimize`, attempt to minimize the number
of states in the FSM. If `unambiguous`, disallow creation of FSM where the actions are not deterministic.

# Examples
```
machine let
    name = re"[A-Z][a-z]+"
    first_last = name * re" " * name
    last_first = name * re", " * name
    Automa.compile(first_last | last_first)
end
```
"""
function compile(re::RegExp.RE; optimize::Bool=true, unambiguous::Bool=false)
    dfa = nfa2dfa(remove_dead_nodes(re2nfa(re)), unambiguous)
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
            break
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

function throw_input_error(
    machine::Machine,
    state::Integer,
    byte::Union{UInt8, Nothing}, # nothing if input is unexpected EOF
    memory, # SizedMemory
    index::Integer
)
    buf = IOBuffer()
    @assert index <= lastindex(memory) + 1
    # Print position in memory
    is_eof = index == lastindex(memory) + 1
    @assert byte isa (is_eof ? Nothing : UInt8)
    slice = max(1,index-100):index - is_eof
    bytes = repr(String([memory[i] for i in slice]))
    write(
        buf,
        "Error during FSM execution at buffer position ",
        string(index),
        ".\nLast ",
        string(length(slice)),
        " bytes were:\n\n"
    )
    write(buf, bytes, "\n\n")

    # Print header
    input = byte isa UInt8 ? repr(first(String([byte]))) : "EOF"
    write(buf, "Observed input: $input at state $state. Outgoing edges:\n")

    # Print edges
    nodes = collect(traverse(machine.start))
    node = nodes[findfirst(n -> n.state == state, nodes)::Int]
    for (edge, _) in node.edges
        print(buf, " * ", replace(edge2str(edge), "\\\\"=>"\\"), '\n')
    end
    if state in machine.final_states
        print(buf, " * ", eof_label(machine.eof_actions[state]), '\n')
    end

    # Print footer
    write(buf, "\nInput is not in any outgoing edge, and machine therefore errored.")

    str = String(take!(buf))
    error(str)
end
