# Deterministic Finite Automaton
# ==============================

struct DFANode
    edges::Vector{Tuple{Edge,DFANode}}
    final::Bool
    eof_actions::ActionList
    nfanodes::Set{NFANode}
end

function DFANode(final::Bool, eof_actions::ActionList, nodes::Set{NFANode})
    return DFANode(Tuple{Edge,DFANode}[], final, eof_actions, nodes)
end

function DFANode(final::Bool, nodes::Set{NFANode})
    return DFANode(final, ActionList(), nodes)
end

function Base.show(io::IO, node::DFANode)
    print(io, summary(node), "(<", length(node.edges), " edges", '@', objectid(node), ">)")
end

struct DFA
    start::DFANode
end

# Check if the DFA is really deterministic or not.
function validate(dfa::DFA)
    for s in traverse(dfa.start)
        for i in 1:lastindex(s.edges), j in 1:i-1
            ei = s.edges[i][1]
            ej = s.edges[j][1]
            if overlaps(ei, ej)
                error("found non-deterministic edges")
            end
        end
    end
end

function nfa2dfa(nfa::NFA, unambiguous::Bool=true)
    newnodes = Dict{Set{NFANode},DFANode}()
    new(S) = get!(newnodes, S, DFANode(nfa.final ∈ S, S))
    isvisited(S) = haskey(newnodes, S)
    S = epsilon_closure(nfa.start)
    start = new(S)
    unvisited = [S]
    while !isempty(unvisited)
        # TODO: support fail
        S = pop!(unvisited)
        S_actions = accumulate_actions(S)
        s′ = new(S)

        if s′.final
            union!(s′.eof_actions, S_actions[nfa.final])
        end

        # accumulate edges and preconditions
        labels = Vector{ByteSet}()
        preconds = Set{Symbol}()
        for s in S, (e, t) in s.edges
            if !iseps(e)
                push!(labels, e.labels)
                union!(preconds, precondition_names(e.precond))
            end
        end

        # append DFA edges and nodes
        pn = collect(preconds)
        for label in disjoint_split(labels)
            # This enumeration will not finish in reasonable time when there
            # are too many preconditions.
            edges = Dict{Tuple{DFANode,ActionList},Vector{UInt64}}()
            for pv in UInt64(0):UInt64((1 << length(pn)) - 1)
                T = Set{NFANode}()
                actions = ActionList()
                for s in S, (e, t) in s.edges
                    if !isdisjoint(e.labels, label) && satisfies(e, pn, pv)
                        push!(T, t)
                        union!(actions, e.actions)
                        union!(actions, S_actions[s])
                    end
                end
                if !isempty(T)
                    T = epsilon_closure(T)
                    if !isvisited(T)
                        push!(unvisited, T)
                    end
                    push!(get!(edges, (new(T), actions), UInt64[]), pv)
                end
            end
            for ((t′, actions), pvs) in edges
                pn′, pvs′ = remove_redundant_preconds(pn, pvs)
                for pv′ in pvs′
                    push!(s′.edges, (Edge(label, make_precond(pn′, pv′), actions), t′))
                end
            end
        end
    end
    # Each key represents a set of NFANodes that collapses to one DFANode.
    # If any set contain conflicting possible actions, raise an error.
    unambiguous && validate_nfanodes(newnodes, start)
    return remove_dead_nodes(DFA(start))
end

function epsilon_closure(node::NFANode)
    return epsilon_closure(Set([node]))
end

function epsilon_closure(nodes::Set{NFANode})
    closure = Set{NFANode}()
    unvisited = copy(nodes)
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(closure, s)
        for (e, t) in s.edges
            if iseps(e) && t ∉ closure
                push!(unvisited, t)
            end
        end
    end
    return closure
end

"Find the nodes in this set where no other node in the set has an edge to it"
function gettop(S::Set{NFANode})
    top = copy(S)
    for s in S
        for (e, t) in s.edges
            if iseps(e)
                delete!(top, t)
            end
        end
    end
    return top
end

"Find paths from top nodes through epsilon edges, keeping track of actions taken."
function get_epsilon_paths(tops::Set{NFANode})
    paths = Tuple{Union{Nothing, Edge}, NFANode, Vector{Symbol}}[]
    heads = [(node, Symbol[]) for node in tops]
    visited = Set{NFANode}()
    while !isempty(heads)
        node, actions = pop!(heads)
        if iszero(length(node.edges))
            push!(paths, (nothing, node, actions))
        end
        for (edge, child) in node.edges
            if iseps(edge)
                if !in(node, visited)
                    push!(heads, (child, append!(copy(actions), [a.name for a in edge.actions])))
                end
            else
                append!(actions, [a.name for a in edge.actions])
                push!(paths, (edge, node, actions))
            end
        end
        push!(visited, node)
    end
    return paths
end

"Compute the shortest input to reach any given DFANode"
function shortest_input(start::DFANode)::Dict{DFANode, String}
    printable = Automa.ByteSet(0x21:0x78)
    result = Dict(start => "")
    # Breadth first search
    current_generation = Set([start])
    next_generation = Set{DFANode}()
    while !isempty(current_generation)
        for parent in current_generation
            parent_bytes = result[parent]
            for (edge, child) in parent.edges
                haskey(result, child) && continue
                # If possible, grab a printable byte
                printable_edges = intersect(printable, edge.labels)
                byte = first(isempty(printable_edges) ? edge.labels : printable_edges)
                result[child] = String(push!(Vector{UInt8}(parent_bytes), byte))
                push!(next_generation, child)
            end
        end
        (current_generation, next_generation) = (next_generation, current_generation)
        next_generation = Set{DFANode}()
    end
    result
end

function validate_paths(
    paths::Vector{Tuple{Union{Nothing, Edge}, NFANode, Vector{Symbol}}},
    dfanode::DFANode,
    start::DFANode,
    strings_to::Dict{DFANode, String}
)
    # If they have the same actions, there is no ambiguity
    all(actions == paths[1][3] for (e, n, actions) in paths) && return nothing
    for i in 1:length(paths) - 1
        edge1, node1, actions1 = paths[i]
        for j in i+1:length(paths)
            edge2, node2, actions2 = paths[j]
            # If either ends with EOF, they don't have same conditions and we can continue
            # If only one is an EOF, they are distinct
            (edge1 === nothing) ⊻ (edge2 === nothing) && continue
            # If they have same actions, there is no conflict
            actions1 == actions2 && continue
            eof = (edge1 === nothing) & (edge2 === nothing)
            
            if !eof
                # If they are real edges but do not overlap, there is no conflict
                overlaps(edge1, edge2) || continue

                # If the FSM may disambiguate the two edges based on preconditions
                # there is no conflict (or, rather, we can't prove a conflict.
                has_potentially_conflicting_precond(edge1, edge2) && continue
            end

            # Now we know there is an ambiguity, so we just need to create
            # an informative error
            act1 = isempty(actions1) ? "nothing" : string(actions1)
            act2 = isempty(actions2) ? "nothing" : string(actions2)
            input_until_now = repr(strings_to[dfanode])
            final_input = if eof
                "EOF"
            else
                repr(Char(first(intersect(edge1.labels, edge2.labels))))
            end
            error(
                "Ambiguous NFA.\nAfter inputs $input_until_now, observing $final_input " *
                "lead to conflicting action sets $act1 and $act2"
            )
        end
    end
end

function validate_nfanodes(
    newnodes::Dict{Set{NFANode}, DFANode},
    start::DFANode
)
    # Sort all DFA nodes by how short a string can be used to reach it, in order
    # to display the shortest possible conflict if any is found.
    strings_to = shortest_input(start)
    pairs = sort!(collect(newnodes); by=i -> ncodeunits(strings_to[i[2]]))
    for (nfanodes, dfanode) in pairs
        # First get "tops", that's the starting epsilon nodes that cannot be
        # reached by another epsilon node. All paths lead from those
        tops = gettop(nfanodes)
        
        # Quick path: If only one path, there can be no ambiguity
        length(tops) == 1 && all(length(node.edges) == 1 for node in nfanodes) && continue

        # Now we transverse all possible epsilon-paths and keep track of the actions
        # taken along the way
        paths = get_epsilon_paths(tops)

        # If any two paths have different actions, and can be reached with the same
        # byte, the DFA's actions cannot be resolved, and we raise an error
        validate_paths(paths, dfanode, start, strings_to)
    end
end

function disjoint_split(sets::Vector{ByteSet})
    # TODO: maybe too slow when length(sets) is large
    cut(s1, s2) = (intersect(s1, s2), setdiff(s1, s2))
    disjsets = [ByteSet(0x00:0xff)]
    disjsets′ = ByteSet[]
    for x in sets
        for y in disjsets
            y1, y2 = cut(y, x)
            if !all(isdisjoint(z, y1) for z in sets)
                push!(disjsets′, y1)
            end
            if !all(isdisjoint(z, y2) for z in sets)
                push!(disjsets′, y2)
            end
        end
        disjsets, disjsets′ = disjsets′, disjsets
        empty!(disjsets′)
    end
    return disjsets
end

function accumulate_actions(S::Set{NFANode})
    top = gettop(S)
    @assert !isempty(top)
    actions = Dict(s => ActionList() for s in S)
    visited = Set{NFANode}()
    unvisited = top
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(visited, s)
        for (e, t) in s.edges
            if iseps(e)
                @assert !isconditioned(e.precond)
                union!(actions[t], e.actions)
                union!(actions[t], actions[s])
                if t ∉ visited
                    push!(unvisited, t)
                end
            end
        end
    end
    return actions
end

function satisfies(edge::Edge, names::Vector{Symbol}, pv::UInt64)
    for (n, v) in edge.precond
        i = findfirst(isequal(n), names)
        @assert i !== nothing
        @assert 0 < i ≤ 64
        vi = bitat(pv, i)
        if !(v == BOTH || (v == TRUE && vi) || (v == FALSE && !vi))
            return false
        end
    end
    return true
end

function remove_redundant_preconds(names::Vector{Symbol}, pvs::Vector{UInt64})
    mask(n) = ((1 << n) - 1) % UInt64
    newnames = Symbol[]
    pvs = copy(pvs)
    left = length(names)
    for name in names
        sort!(pvs)
        fnd = findfirst(pv -> bitat(pv, left), pvs)
        k = ifelse(fnd === nothing, 0, fnd) # TODO: See if there is a more elegant way of doing this.
        if (k - 1) * 2 == length(pvs)
            redundant = true
            for i in 1:k-1
                m = mask(left - 1)
                if pvs[i] & m != pvs[i+k-1] & m
                    redundant = false
                    break
                end
            end
        else
            redundant = false
        end
        if redundant
            left -= 1
            for i in 1:lastindex(pvs)
                # remove the redundant bit
                pvs[i] = pvs[i] & mask(left)
            end
        else
            push!(newnames, name)
            for i in 1:lastindex(pvs)
                # circular left shift
                pvs[i] = ((pvs[i] << 1) & mask(left)) | bitat(pvs[i], left)
            end
        end
    end
    return newnames, unique(pvs)
end

function make_precond(names::Vector{Symbol}, pv::UInt64)
    precond = Precondition()
    for (i, n) in enumerate(names)
        push!(precond, n => bitat(pv, i) ? TRUE : FALSE)
    end
    return precond
end

function bitat(x::UInt64, i::Integer)
    return ((x >> (i - 1)) & 1) == 1
end

function reduce_nodes(dfa::DFA)
    equivalents = get_equivalent(collect(traverse(dfa.start)))
    newnodes = Dict{Set{DFANode},DFANode}()
    new(S) = get!(newnodes, S) do
        s = first(S)
        return DFANode(s.final, s.eof_actions, foldl((x, s) -> union(x, s.nfanodes), S, init=Set{NFANode}()))
    end
    isvisited(T) = haskey(newnodes, T)
    S = equivalents[dfa.start]
    start = new(S)
    unvisited = [S]
    while !isempty(unvisited)
        S = pop!(unvisited)
        s′ = new(S)
        for (e, t) in first(S).edges
            T = equivalents[t]
            if !isvisited(T)
                push!(unvisited, T)
            end

            # Here, add the old edge to the new DFA. If an equivalent edge already
            # exists, instead add the labels of the old edge to the existing one.
            existing_edge = false
            for (i, (e´, t´)) in enumerate(s′.edges)
                if t´ == new(T) && e´.precond == e.precond && e´.actions == e.actions
                    newlabels = union(e.labels, e´.labels)
                    newedge = Edge(newlabels, e.precond, e.actions)
                    s′.edges[i] = (newedge, t´)
                    existing_edge = true
                    break
                end
            end
            existing_edge || push!(s′.edges, (e, new(T)))
        end
    end
    return DFA(start)
end

function get_groupof(v::Vector{DFANode})
    # These are sets of the outgoing bytes from every node
    labels = Dict(s => foldl((x, y) -> union(x, y[1].labels), s.edges, init=ByteSet()) for s in v)
    
    # First we create groups of nodes that MAY be identical based on quick-to-compute
    # characteristics. This narrows down the number of comparisons needed later.
    # Nodes may be equal if the have the same outgoing bytes, same final node and same
    # EOF actions.
    groupof = Dict{DFANode,Vector{DFANode}}()
    for s1 in v
        unique = true
        for group in values(groupof)
            s2 = first(group)
            if s1.final == s2.final && labels[s1] == labels[s2] && s1.eof_actions == s2.eof_actions
                push!(group, s1)
                groupof[s1] = group
                unique = false
                break
            end
        end
        unique && (groupof[s1] = [s1])
    end
    return groupof
end

function equivalent_pairs(groupof, v)
    # Here, we check each pair in each group. If they share an edge with an overlapping byte,
    # compatible preconditions, but the edge have different actions or leads no a non-equivalent
    # node, they're different. Because a parent's nonequivalence relies on the status of
    # its children, we need to update the parents every time we update a node.
    equivalent_pairs = Set{Tuple{DFANode,DFANode}}()
    for group in values(groupof), s1 in group, s2 in group
        push!(equivalent_pairs, (s1, s2))
    end
    
    # Get a node => vector of parents of node dict
    parentsof = Dict{DFANode,Vector{DFANode}}()
    for s in v, (e,c) in s.edges
        if haskey(parentsof, c)
            push!(parentsof[c], s)
        else
            parentsof[c] = [s]
        end
    end
    unupdated = Set(v)
    while !isempty(unupdated)
        s1 = pop!(unupdated)
        group = groupof[s1]
        for s2 in group
            (s1 == s2 || (s1, s2) ∉ equivalent_pairs) && continue
            for (e1, t1) in s1.edges, (e2, t2) in s2.edges
                if overlaps(e1, e2) && ((t1, t2) ∉ equivalent_pairs || e1.actions != e2.actions)
                    delete!(equivalent_pairs, (s1, s2))
                    haskey(parentsof, s1) && union!(unupdated, parentsof[s1])
                    break
                end
            end
        end
    end
    return equivalent_pairs
end

function split_group(group::Vector{DFANode}, pairs)
    remaining = copy(group)
    result = Vector{DFANode}[]
    nonequivalents = DFANode[]
    while !isempty(remaining)
        s1 = first(remaining)
        equivalents = DFANode[]
        for s2 in remaining
            (s1, s2) ∈ pairs ? push!(equivalents, s2) : push!(nonequivalents, s2)
        end
        push!(result, equivalents)
        (nonequivalents, remaining) = (remaining, nonequivalents)
        empty!(nonequivalents)
    end
    return result
end

"Creates a DFANode => Set{DFANode} dict with equivalent nodes for every node in v"
function get_equivalent(v::Vector{DFANode})
    groupof = get_groupof(v)
    pairs = equivalent_pairs(groupof, v)
    groups = collect(keys(IdDict{Vector{DFANode},Nothing}(v => nothing for v in values(groupof))))
    result = Dict{DFANode,Set{DFANode}}()
    for group in groups
        for subgroup in split_group(group, pairs)
            S = Set(subgroup)
            for node in subgroup
                result[node] = S
            end
        end
    end
    return result
end

function overlaps(e1::Edge, e2::Edge)
    return !(isdisjoint(e1.labels, e2.labels) || conflicts(e1.precond, e2.precond))
end

function revoke_finals(p::Function, dfa::DFA)
    newnodes = Dict{DFANode,DFANode}()
    new(s) = get!(newnodes, s) do
        return DFANode(s.final && !p(s), s.eof_actions, s.nfanodes)
    end
    for s in traverse(dfa.start)
        s′ = new(s)
        for (e, t) in s.edges
            push!(s′.edges, (e, new(t)))
        end
    end
    return DFA(new(dfa.start))
end

function dfa2nfa(dfa::DFA)
    newnodes = Dict{DFANode,NFANode}()
    new(s) = get!(newnodes, s, NFANode())
    final = NFANode()
    for s in traverse(dfa.start)
        s′ = new(s)
        for (e, t) in s.edges
            push!(s′.edges, (e, new(t)))
        end
        if s.final
            push!(s′.edges, (Edge(eps, s.eof_actions), final))
        end
    end
    start = NFANode()
    push!(start.edges, (Edge(eps), new(dfa.start)))
    return NFA(start, final)
end

function remove_dead_nodes(dfa::DFA)
    backrefs = Dict(dfa.start => Set{DFANode}())
    for s in traverse(dfa.start), (_, t) in s.edges
        push!(get!(backrefs, t, Set{DFANode}()), s)
    end

    alive = Set{DFANode}()
    unvisited = [s for s in keys(backrefs) if s.final]
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(alive, s)
        for t in backrefs[s]
            if t ∉ alive
                push!(unvisited, t)
            end
        end
    end
    @assert dfa.start ∈ alive

    newnodes = Dict{DFANode,DFANode}()
    new(s) = get!(newnodes, s, DFANode(s.final, s.eof_actions, s.nfanodes))
    isvisited(s) = haskey(newnodes, s)
    unvisited = [dfa.start]
    while !isempty(unvisited)
        s = pop!(unvisited)
        s′ = new(s)
        for (e, t) in s.edges
            if t ∈ alive
                if !isvisited(t)
                    push!(unvisited, t)
                end
                push!(s′.edges, (e, new(t)))
            end
        end
    end

    return DFA(new(dfa.start))
end
