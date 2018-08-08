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
    is_non_deterministic(e1, e2) = !(isdisjoint(e1.labels, e2.labels) || conflicts(e1.precond, e2.precond))
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

function nfa2dfa(nfa::NFA)
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
    return DFA(start)
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

function disjoint_split(sets::Vector{ByteSet})
    # TODO: maybe too slow when length(sets) is large
    cut(s1, s2) = (intersect(s1, s2), setdiff(s1, s2))
    m = typemax(UInt64)
    disjsets = [ByteSet(m, m, m, m)]
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
    top = copy(S)
    for s in S
        for (e, t) in s.edges
            if iseps(e)
                delete!(top, t)
            end
        end
    end
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
        k = ifelse(fnd == nothing, 0, fnd) # TODO: See if there is a more elegant way of doing this.
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
    Q = Set(traverse(dfa.start))
    distinct = distinct_nodes(Q)
    newnodes = Dict{Set{DFANode},DFANode}()
    new(S) = get!(newnodes, S) do
        s = first(S)
        return DFANode(s.final, s.eof_actions, foldl((x, s) -> union(x, s.nfanodes), S, init=Set{NFANode}()))
    end
    equivalent(s) = filter(t -> (s, t) ∉ distinct, Q)
    isvisited(T) = haskey(newnodes, T)
    S = equivalent(dfa.start)
    start = new(S)
    unvisited = [S]
    while !isempty(unvisited)
        S = pop!(unvisited)
        s′ = new(S)
        for (e, t) in first(S).edges
            T = equivalent(t)
            if !isvisited(T)
                push!(unvisited, T)
            end
            push!(s′.edges, (e, new(T)))
        end
    end
    return DFA(start)
end

function distinct_nodes(S::Set{DFANode})
    labels = Dict(s => foldl((x, y) -> union(x, y[1].labels), s.edges, init=ByteSet()) for s in S)
    distinct = Set{Tuple{DFANode,DFANode}}()

    for s1 in S, s2 in S
        if s1.final != s2.final || labels[s1] != labels[s2] || s1.eof_actions != s2.eof_actions
            push!(distinct, (s1, s2))
        end
    end

    converged = false
    while !converged
        converged = true
        for s1 in S, s2 in S
            if s1 == s2 || (s1, s2) ∈ distinct
                continue
            end
            @assert labels[s1] == labels[s2] && s1.eof_actions == s2.eof_actions
            for (e1, t1) in s1.edges, (e2, t2) in s2.edges
                if overlaps(e1, e2) && ((t1, t2) ∈ distinct || e1.actions != e2.actions)
                    push!(distinct, (s1, s2), (s2, s1))
                    converged = false
                    break
                end
            end
        end
    end

    return distinct
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
