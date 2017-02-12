# Non-deterministic Finite Automaton
# ==================================

immutable Action
    name::Symbol
    order::Int
end

function sorted_actions(actions::Set{Action})
    return sort!(collect(actions), by=a->a.order)
end

function sorted_unique_action_names(actions::Set{Action})
    names = Symbol[]
    for a in sorted_actions(actions)
        if a.name ∉ names
            push!(names, a.name)
        end
    end
    return names
end

function gen_empty_nfanode_set()
    return Set{NFANode}()
end

function gen_empty_actions()
    return Set{Action}()
end

type NFATransition{T}
    trans::DefaultDict{UInt8,Set{T},typeof(gen_empty_nfanode_set)}
    trans_eps::Set{T}
end

function NFATransition()
    trans = DefaultDict{UInt8,Set{NFANode}}(gen_empty_nfanode_set)
    trans_eps = Set{NFANode}()
    return NFATransition(trans, trans_eps)
end

function bytekeys(trans::NFATransition)
    return keys(trans.trans)
end

function Base.haskey(trans::NFATransition, label::UInt8)
    return haskey(trans.trans, label)
end

function Base.getindex(trans::NFATransition, label::UInt8)
    return trans.trans[label]
end

function Base.getindex(trans::NFATransition, label::Symbol)
    @assert label == :eps
    return trans.trans_eps
end

type NFANode
    trans::NFATransition{NFANode}
    actions::DefaultDict{Tuple{Any,NFANode},Set{Action},typeof(gen_empty_actions)}
end

function NFANode()
    trans = NFATransition()
    actions = DefaultDict{Tuple{Any,NFANode},Set{Action}}(gen_empty_actions)
    return NFANode(trans, actions)
end

immutable NFATraverser
    start::NFANode
end

function traverse(node::NFANode)
    return NFATraverser(node)
end

function Base.start(traverser::NFATraverser)
    visited = Set{NFANode}()
    unvisited = [traverser.start]
    return visited, unvisited
end

function Base.done(traverser::NFATraverser, state)
    _, unvisited = state
    return isempty(unvisited)
end

function Base.next(traverser::NFATraverser, state)
    visited, unvisited = state
    s = pop!(unvisited)
    push!(visited, s)
    for (_, T) in s.trans.trans
        for t in T
            if t ∉ visited
                push!(unvisited, t)
            end
        end
    end
    for t in s.trans[:eps]
        if t ∉ visited
            push!(unvisited, t)
        end
    end
    return s, (visited, unvisited)
end

function addtrans!(node::NFANode, trans::Pair{UInt8,NFANode}, actions::Set{Action}=Set{Action}())
    label, target = trans
    push!(node.trans[label], target)
    union!(node.actions[(label, target)], actions)
    return node
end

function addtrans!(node::NFANode, trans::Pair{Symbol,NFANode}, actions::Set{Action}=Set{Action}())
    label, target = trans
    @assert label == :eps
    push!(node.trans.trans_eps, target)
    union!(node.actions[(label, target)], actions)
    return node
end

function addactions!(node::NFANode, trans::Tuple{UInt8,NFANode}, actions::Set{Action})
    union!(node.actions[trans], actions)
    return node
end

# Canonical NFA type.
type NFA
    start::NFANode
    final::NFANode
end

# Convert a RE to an NFA using Thompson's construction.
function re2nfa(re::RegExp.RE)
    re′ = RegExp.expand(RegExp.desugar(re))
    return re2nfa_rec(re′, Dict{Symbol,Action}())
end

function re2nfa_rec(re::RegExp.RE, actions::Dict{Symbol,Action})
    enter_actions = Set{Action}()
    if haskey(re.actions, :enter)
        for name in re.actions[:enter]
            if !haskey(actions, name)
                actions[name] = Action(name, length(actions))
            end
            push!(enter_actions, actions[name])
        end
    end

    function check_arity(p)
        if !p(length(re.args))
            error("invalid arity: $(re.head)")
        end
    end

    start = NFANode()
    final = NFANode()
    if re.head == :set
        check_arity(n -> n == 1)
        for b in re.args[1]
            addtrans!(start, b => final)
        end
    elseif re.head == :bytes
        if isempty(re.args)
            addtrans!(start, :eps => final)
        else
            node = start
            for b::UInt8 in re.args
                next = NFANode()
                addtrans!(node, b => next)
                node = next
            end
            final = node
        end
    elseif re.head == :cat
        lastnfa = NFA(start, final)
        addtrans!(start, :eps => final)
        for arg in re.args
            nfa = re2nfa_rec(arg, actions)
            addtrans!(lastnfa.final, :eps => nfa.start)
            lastnfa = nfa
        end
        final = lastnfa.final
    elseif re.head == :alt
        check_arity(n -> n > 0)
        for arg in re.args
            nfa = re2nfa_rec(arg, actions)
            addtrans!(start, :eps => nfa.start)
            addtrans!(nfa.final, :eps => final)
        end
    elseif re.head == :rep
        check_arity(n -> n == 1)
        nfa = re2nfa_rec(re.args[1], actions)
        addtrans!(start, :eps => final)
        addtrans!(start, :eps => nfa.start)
        addtrans!(nfa.final, :eps => final)
        addtrans!(nfa.final, :eps => nfa.start)
    elseif re.head == :isec
        check_arity(n -> n == 2)
        nfa1 = re2nfa_rec(re.args[1], actions)
        nfa2 = re2nfa_rec(re.args[2], actions)
        addtrans!(start, :eps => nfa1.start)
        addtrans!(start, :eps => nfa2.start)
        addtrans!(nfa1.final, :eps => final)
        addtrans!(nfa2.final, :eps => final)
        dfa = nfa2dfa(NFA(start, final))
        revoke_finals!(s -> !(nfa1.final ∈ s.nfanodes && nfa2.final ∈ s.nfanodes), dfa)
        nfa = dfa2nfa(dfa)
        start = nfa.start
        final = nfa.final
    elseif re.head == :diff
        check_arity(n -> n == 2)
        nfa1 = re2nfa_rec(re.args[1], actions)
        nfa2 = re2nfa_rec(re.args[2], actions)
        addtrans!(start, :eps => nfa1.start)
        addtrans!(start, :eps => nfa2.start)
        addtrans!(nfa1.final, :eps => final)
        addtrans!(nfa2.final, :eps => final)
        dfa = nfa2dfa(NFA(start, final))
        revoke_finals!(s -> nfa2.final ∈ s.nfanodes, dfa)
        nfa = dfa2nfa(dfa)
        start = nfa.start
        final = nfa.final
    else
        error("unsupported operation: $(re.head)")
    end

    if haskey(re.actions, :enter)
        newstart = NFANode()
        addtrans!(newstart, :eps => start, enter_actions)
        start = newstart
    end

    if haskey(re.actions, :exit)
        exit_actions = Set{Action}()
        for name in re.actions[:exit]
            if !haskey(actions, name)
                actions[name] = Action(name, length(actions))
            end
            push!(exit_actions, actions[name])
        end
        newfinal = NFANode()
        addtrans!(final, :eps => newfinal, exit_actions)
        final = newfinal
    end

    if haskey(re.actions, :final)
        finals = NFANode[]
        for s in traverse(start)
            if final ∈ epsilon_closure(Set([s]))
                push!(finals, s)
            end
        end
        final_actions = Set{Action}()
        for name in re.actions[:final]
            if !haskey(actions, name)
                actions[name] = Action(name, length(actions))
            end
            push!(final_actions, actions[name])
        end
        for s in traverse(start)
            for (l, T) in s.trans.trans
                for t in T
                    if t ∈ finals
                        addactions!(s, (l, t), final_actions)
                    end
                end
            end
        end
    end

    return NFA(start, final)
end

function remove_dead_states(nfa::NFA)
    backrefs = make_back_references(nfa)
    alive = Set{NFANode}()
    unvisited = Set([nfa.final])
    while !isempty(unvisited)
        s = pop!(unvisited)
        push!(alive, s)
        for t in backrefs[s]
            if t ∉ alive
                push!(unvisited, t)
            end
        end
    end
    @assert nfa.start ∈ alive
    @assert nfa.final ∈ alive

    newnodes = Dict{NFANode,NFANode}(nfa.start => NFANode())
    unvisited = Set([nfa.start])
    function copy_trans(s, t, l)
        if !haskey(newnodes, t)
            newnodes[t] = NFANode()
            push!(unvisited, t)
        end
        addtrans!(newnodes[s], l => newnodes[t], s.actions[(l, t)])
    end
    while !isempty(unvisited)
        s = pop!(unvisited)
        for (l, T) in s.trans.trans
            for t in T
                if t ∈ alive
                    copy_trans(s, t, l)
                end
            end
        end
        for t in s.trans.trans_eps
            if t ∈ alive
                copy_trans(s, t, :eps)
            end
        end
    end
    return NFA(newnodes[nfa.start], newnodes[nfa.final])
end

function make_back_references(nfa::NFA)
    backrefs = Dict(nfa.start => Set{NFANode}())
    function add_backref(t, s)
        if !haskey(backrefs, t)
            backrefs[t] = Set{NFANode}()
        end
        push!(backrefs[t], s)
    end
    for s in traverse(nfa.start)
        for l in keys(s.trans.trans)
            T = s.trans[l]
            for t in T
                add_backref(t, s)
            end
        end
        for t in s.trans.trans_eps
            add_backref(t, s)
        end
    end
    return backrefs
end
