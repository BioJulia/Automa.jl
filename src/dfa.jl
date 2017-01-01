# Deterministic Finite Automaton
# ==============================

type DFANode
    next::Dict{Any,Tuple{DFANode,Vector{Symbol}}}
    eof_actions::Vector{Symbol}
    final::Bool
end

type DFA
    start::DFANode
end

function nfa2dfa(nfa::NFA)
    new_dfanode(nodes) = DFANode(Dict(), [], nfa.final ∈ epsilon_closure(nodes))
    start = epsilon_closure(nfa.start)
    dfanodes = Dict([start => new_dfanode(start)])
    unmarked = Set([start])
    while !isempty(unmarked)
        S = pop!(unmarked)
        for l in 0x00:0xff
            T = epsilon_closure(move(S, l))
            if isempty(T)
                continue
            end
            if !haskey(dfanodes, T)
                dfanodes[T] = new_dfanode(T)
                push!(unmarked, T)
            end
            actions = OrdAction[]
            for s in S
                if isempty(s.actions)
                    # no need to check
                    continue
                end
                if !isempty(epsilon_closure(move(epsilon_closure(s), l)))
                    append!(actions, s.actions)
                end
            end
            sort_actions!(actions)
            dfanodes[S].next[l] = (dfanodes[T], [a.name for a in actions])
        end
    end

    # attach EOF actions
    for (S, dfanode) in dfanodes
        actions = OrdAction[]
        for s in S
            if nfa.final ∈ epsilon_closure(s)
                append!(actions, s.actions)
            end
        end
        sort_actions!(actions)
        dfanode.eof_actions = [a.name for a in actions]
    end
    return DFA(dfanodes[start])
end

function sort_actions!(actions::Vector{OrdAction})
    return sort!(actions, by=a -> a.order)
end

function move(nodes::Set{NFANode}, label)
    set = Set{NFANode}()
    for node in nodes
        if haskey(node.next, label)
            union!(set, node.next[label])
        end
    end
    return set
end

function epsilon_closure(node::NFANode)
    closure = Set{NFANode}()
    unmarked = Set([node])
    while !isempty(unmarked)
        s = pop!(unmarked)
        push!(closure, s)
        if haskey(s.next, :eps)
            for t in s.next[:eps]
                if t ∉ closure
                    push!(unmarked, t)
                end
            end
        end
    end
    return closure
end

function epsilon_closure(nodes::Set{NFANode})
    closure = Set{NFANode}()
    for node in nodes
        union!(closure, epsilon_closure(node))
    end
    return closure
end

function reduce_states(dfa::DFA)
    Q = all_states(dfa)
    distinct = distinct_states(Q)
    # reconstruct an optimized DFA
    equivalent(s) = filter(t -> (s, t) ∉ distinct, Q)
    new_dfanode(s) = DFANode(Dict(), [], s.final)
    start = new_dfanode(dfa.start)
    S_start = equivalent(dfa.start)
    dfanodes = Dict([S_start => start])
    unvisited = [(S_start, start)]
    while !isempty(unvisited)
        S, s′ = pop!(unvisited)
        for s in S
            for (l, (t, as)) in s.next
                T = equivalent(t)
                if !haskey(dfanodes, T)
                    t′ = new_dfanode(t)
                    dfanodes[T] = t′
                    push!(unvisited, (T, t′))
                end
                s′.next[l] = (dfanodes[T], as)
            end
            s′.eof_actions = s.eof_actions
        end
    end
    return DFA(start)
end

function all_states(dfa::DFA)
    states = DFANode[]
    traverse(dfa) do s
        push!(states, s)
    end
    return states
end

function distinct_states(Q)
    distinct = Set{Tuple{DFANode,DFANode}}()
    function isdistinct(l, p, q)
        if haskey(p.next, l) && haskey(q.next, l)
            pl = p.next[l]
            ql = q.next[l]
            return (pl[1], ql[1]) ∈ distinct || pl[2] != ql[2]
        else
            return haskey(p.next, l) != haskey(q.next, l)
        end
    end
    for p in Q, q in Q
        if p.final != q.final
            push!(distinct, (p, q))
        end
    end
    #= This is much slower.
    while true
        for p in Q, q in Q
            if (p, q) ∈ distinct
                continue
            end
            for l in 0x00:0xff
                if isdistinct(l, p, q)
                    push!(distinct, (p, q), (q, p))
                    @goto not_converged
                end
            end
            if p.eof_actions != q.eof_actions
                push!(distinct, (p, q), (q, p))
                @goto not_converged
            end
        end
        break
        @label not_converged
    end
    =#
    while true
        converged = true
        for p in Q, q in Q
            if (p, q) ∈ distinct
                continue
            end
            for l in 0x00:0xff
                if isdistinct(l, p, q)
                    push!(distinct, (p, q), (q, p))
                    converged = false
                end
            end
            if p.eof_actions != q.eof_actions
                push!(distinct, (p, q), (q, p))
                converged = false
            end
        end
        if converged
            break
        end
    end
    return distinct
end

function reduce_edges(dfa::DFA)
    new_dfanode(s) = DFANode(Dict(), [], s.final)
    start = new_dfanode(dfa.start)
    dfanodes = Dict(dfa.start => start)
    unvisited = Set([dfa.start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        dfanodes[s].eof_actions = s.eof_actions
        edges = Dict()
        for (l, (t, as)) in s.next
            if !haskey(dfanodes, t)
                dfanodes[t] = new_dfanode(t)
                push!(unvisited, t)
            end
            if !haskey(edges, (t, as))
                edges[(t, as)] = UInt8[]
            end
            push!(edges[(t, as)], l)
        end
        for ((t, as), ls) in edges
            ls′ = compact_labels(ls)
            dfanodes[s].next[ls′] = (dfanodes[t], as)
        end
    end
    return DFA(start)
end

function compact_labels(labels::Vector{UInt8})
    labels = sort(labels)
    labels′ = UnitRange{UInt8}[]
    while !isempty(labels)
        lo = shift!(labels)
        hi = lo
        while !isempty(labels) && first(labels) == hi + 1
            hi = shift!(labels)
        end
        push!(labels′, lo:hi)
    end
    return labels′
end
