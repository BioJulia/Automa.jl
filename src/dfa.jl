# Deterministic Finite Automaton
# ==============================

# DFATransition
# -------------

immutable DFATransition{T}
    trans::Dict{UInt8,T}
end

function DFATransition()
    return DFATransition(Dict{UInt8,DFANode}())
end

function Base.haskey(trans::DFATransition, label::UInt8)
    return haskey(trans.trans, label)
end

function Base.getindex(trans::DFATransition, label::UInt8)
    return getindex(trans.trans, label)
end

function Base.setindex!(trans::DFATransition, val, label::UInt8)
    setindex!(trans.trans, val, label)
    return trans
end


# DFANode
# -------

immutable DFANode
    trans::DFATransition{DFANode}
    actions::DefaultDict{Any,Set{Action},typeof(gen_empty_actions)}
    final::Bool
    nfanodes::Set{NFANode}  # back reference to NFA nodes (optional)
end

function DFANode(final::Bool=false, S::Set{NFANode}=Set{NFANode}())
    return DFANode(DFATransition(), DefaultDict{Any,Set{Action}}(gen_empty_actions), final, S)
end

function addtrans!(node::DFANode, trans::Pair{UInt8,DFANode}, actions::Set{Action}=Set{Action}())
    label, target = trans
    @assert !haskey(node.trans, label)
    node.trans[label] = target
    union!(node.actions[label], actions)
    return node
end


# DFA
# ---

immutable DFA
    start::DFANode
end

function nfa2dfa(nfa::NFA)
    new_dfanode(S) = DFANode(nfa.final ∈ S, S)
    S = epsilon_closure(Set([nfa.start]))
    start = new_dfanode(S)
    dfanodes = Dict([S => start])
    unvisited = [S]
    while !isempty(unvisited)
        S = pop!(unvisited)
        S_actions = accumulate_actions(S)
        for l in keyrange(S)
            T = epsilon_closure(move(S, l))
            if isempty(T)
                continue
            elseif !haskey(dfanodes, T)
                dfanodes[T] = new_dfanode(T)
                push!(unvisited, T)
            end
            actions = Set{Action}()
            for s in S
                if !haskey(s.trans, l)
                    continue
                end
                T′ = s.trans[l]
                for t in T′
                    union!(actions, s.actions[(l, t)])
                end
                if !isempty(T′)
                    union!(actions, S_actions[s])
                end
            end
            addtrans!(dfanodes[S], l => dfanodes[T], actions)
        end
        if nfa.final ∈ S
            dfanodes[S].actions[:eof] = S_actions[nfa.final]
        end
    end
    return DFA(start)
end

function keyrange(S::Set{NFANode})
    lo = 0xff
    hi = 0x00
    for s in S
        for l in bytekeys(s.trans)
            lo = min(l, lo)
            hi = max(l, hi)
        end
    end
    return lo:hi
end

function move(S::Set{NFANode}, label::UInt8)
    T = Set{NFANode}()
    for s in S
        if haskey(s.trans, label)
            union!(T, s.trans[label])
        end
    end
    return T
end

function epsilon_closure(S::Set{NFANode})
    closure = Set{NFANode}()
    unvisited = copy(S)
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
    Q = Set(traverse(dfa.start))
    distinct = distinct_states(Q)
    # reconstruct an optimized DFA
    equivalent(s) = filter(t -> (s, t) ∉ distinct, Q)
    newnodes = Dict{Set{DFANode},DFANode}()
    new(S) = get!(S -> DFANode(first(S).final), newnodes, S)
    S = equivalent(dfa.start)
    start = new(S)
    unvisited = [S]
    while !isempty(unvisited)
        S = pop!(unvisited)
        @assert !isempty(S)
        s = first(S)
        s′ = new(S)
        for (l, t) in s.trans.trans
            T = equivalent(t)
            if !haskey(newnodes, T)
                push!(unvisited, T)
            end
            addtrans!(s′, l => new(T), s.actions[l])
        end
        s′.actions[:eof] = s.actions[:eof]
    end
    return DFA(start)
end

function distinct_states(Q)
    actions = Dict{Tuple{DFANode,UInt8},Vector{Symbol}}()
    for q in Q, l in keys(q.trans.trans)
        actions[(q, l)] = sorted_unique_action_names(q.actions[l])
    end

    distinct = Set{Tuple{DFANode,DFANode}}()
    function isdistinct(l, p, q)
        phasl = haskey(p.trans, l)
        qhasl = haskey(q.trans, l)
        if phasl && qhasl
            pl = p.trans[l]
            ql = q.trans[l]
            return (pl, ql) ∈ distinct || actions[(p, l)] != actions[(q, l)]
        else
            return phasl != qhasl
        end
    end
    for p in Q, q in Q
        if p.final != q.final
            push!(distinct, (p, q))
        end
    end
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
            if sorted_unique_action_names(p.actions[:eof]) != sorted_unique_action_names(q.actions[:eof])
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

function dfa2nfa(dfa::DFA)
    final = NFANode()
    nfanodes = Dict([dfa.start => NFANode()])
    for s in traverse(dfa.start)
        for (l, t) in s.trans.trans
            if !haskey(nfanodes, t)
                nfanodes[t] = NFANode()
            end
            addtrans!(nfanodes[s], l => nfanodes[t], s.actions[l])
        end
        if s.final
            addtrans!(nfanodes[s], :eps => final, s.actions[:eof])
        end
    end
    start = NFANode()
    addtrans!(start, :eps => nfanodes[dfa.start])
    return NFA(start, final)
end

function revoke_finals(p::Function, dfa::DFA)
    newnodes = Dict{DFANode,DFANode}()
    new(s) = get!(s -> DFANode(s.final && !p(s), s.nfanodes), newnodes, s)
    for s in traverse(dfa.start)
        s′ = new(s)
        for (l, t) in s.trans.trans
            addtrans!(s′, l => new(t), s.actions[l])
        end
        s′.actions[:eof] = s.actions[:eof]
    end
    return DFA(new(dfa.start))
end

function get!(f, col, key)
    return Base.get!(col, key, f(key))
end

function remove_dead_states(dfa::DFA)
    backrefs = make_back_references(dfa)
    alive = Set{DFANode}()
    unvisited = Set([s for s in keys(backrefs) if s.final])
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(alive, s)
        for t in backrefs[s]
            if t ∉ alive
                push!(unvisited, t)
            end
        end
    end

    newnodes = Dict{DFANode,DFANode}()
    new(s) = get!(s -> DFANode(s.final, s.nfanodes), newnodes, s)
    for s in traverse(dfa.start)
        if s ∉ alive
            continue
        end
        s′ = new(s)
        for (l, t) in s.trans.trans
            if t ∈ alive
                addtrans!(s′, l => new(t), s.actions[l])
            end
        end
        s′.actions[:eof] = s.actions[:eof]
    end
    return DFA(new(dfa.start))
end

function make_back_references(dfa::DFA)
    backrefs = Dict(dfa.start => Set{DFANode}())
    for s in traverse(dfa.start)
        for (l, t) in s.trans.trans
            if !haskey(backrefs, t)
                backrefs[t] = Set{DFANode}()
            end
            push!(backrefs[t], s)
        end
    end
    return backrefs
end
