# Deterministic Finite Automaton
# ==============================

type DFANode
    next::Dict{Any,Tuple{DFANode,Set{Action}}}
    eof_actions::Set{Action}
    final::Bool
    nfanodes::Set{NFANode}  # back reference to NFA nodes (optional)
end

type DFA
    start::DFANode
end

function nfa2dfa(nfa::NFA)
    new_dfanode(S) = DFANode(Dict(), Set{Action}(), nfa.final ∈ S, S)
    S = epsilon_closure(Set([nfa.start]))
    start = new_dfanode(S)
    dfanodes = Dict([S => start])
    unvisited = Set([S])
    while !isempty(unvisited)
        S = pop!(unvisited)
        S_actions = accumulate_actions(S)
        for l in 0x00:0xff
            T = epsilon_closure(move(S, l))
            if isempty(T)
                continue
            elseif !haskey(dfanodes, T)
                dfanodes[T] = new_dfanode(T)
                push!(unvisited, T)
            end
            actions = Set{Action}()
            for s in S
                T′ = s.trans[l]
                for t in T′
                    union!(actions, s.actions[(l, t)])
                end
                if !isempty(T′)
                    union!(actions, S_actions[s])
                end
            end
            dfanodes[S].next[l] = (dfanodes[T], actions)
        end
        if nfa.final ∈ S
            dfanodes[S].eof_actions = S_actions[nfa.final]
        end
    end
    return DFA(start)
end

function move(S::Set{NFANode}, label::UInt8)
    T = Set{NFANode}()
    for s in S
        union!(T, s.trans[label])
    end
    return T
end

function epsilon_closure(S::Set{NFANode})
    closure = Set{NFANode}()
    unvisited = Set(copy(S))
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(closure, s)
        for t in s.trans[:eps]
            if t ∉ closure
                push!(unvisited, t)
            end
        end
    end
    return closure
end

function accumulate_actions(S::Set{NFANode})
    top = copy(S)
    for s in S
        setdiff!(top, s.trans[:eps])
    end
    @assert !isempty(top)
    actions = Dict(s => Set{Action}() for s in S)
    visited = Set{NFANode}()
    unvisited = top
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(visited, s)
        for t in s.trans[:eps]
            union!(actions[t], union(actions[s], s.actions[(:eps, t)]))
            if t ∉ visited
                push!(unvisited, t)
            end
        end
    end
    return actions
end

function reduce_states(dfa::DFA)
    Q = all_states(dfa)
    distinct = distinct_states(Q)
    # reconstruct an optimized DFA
    equivalent(s) = filter(t -> (s, t) ∉ distinct, Q)
    new_dfanode(s) = DFANode(Dict(), Set{Action}(), s.final, Set{NFANode}())
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
        phasl = haskey(p.next, l)
        qhasl = haskey(q.next, l)
        if phasl && qhasl
            pl = p.next[l]
            ql = q.next[l]
            return (pl[1], ql[1]) ∈ distinct || pl[2] != ql[2]
        else
            return phasl != qhasl
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
                    break
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
    new_dfanode(s) = DFANode(Dict(), Set{Action}(), s.final, Set{NFANode}())
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
            ls′ = RegExp.compact_labels(ls)
            dfanodes[s].next[ls′] = (dfanodes[t], as)
        end
    end
    return DFA(start)
end

function dfa2nfa(dfa::DFA)
    =>(x, y) = (x, y)
    final = NFANode()
    nfanodes = Dict([dfa.start => NFANode()])
    unvisited = Set([dfa.start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        for (l, (t, as)) in s.next
            @assert isa(l, UInt8)
            if !haskey(nfanodes, t)
                nfanodes[t] = NFANode()
                push!(unvisited, t)
            end
            addtrans!(nfanodes[s], l => nfanodes[t], as)
        end
        if s.final
            addtrans!(nfanodes[s], :eps => final, s.eof_actions)
        end
    end
    start = NFANode()
    addtrans!(start, :eps => nfanodes[dfa.start])
    return NFA(start, final)
end

function revoke_finals!(p::Function, dfa::DFA)
    visited = Set{DFANode}()
    unvisited = Set([dfa.start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(visited, s)
        if p(s)
            s.final = false
        end
        for (_, (t, _)) in s.next
            if t ∉ visited
                push!(unvisited, t)
            end
        end
    end
    return dfa
end
