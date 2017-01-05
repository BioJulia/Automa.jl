# Non-deterministic Finite Automaton
# ==================================

immutable Action
    name::Symbol
    order::Int
end

function sorted_actions(actions::Set{Action})
    return sort!(collect(actions), by=a->a.order)
end

function sorted_action_names(actions::Set{Action})
    return [a.name for a in sorted_actions(actions)]
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
    trans = DefaultDict(UInt8,Set{NFANode},gen_empty_nfanode_set)
    trans_eps = Set{NFANode}()
    return NFATransition(trans, trans_eps)
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
    actions = DefaultDict(Tuple{Any,NFANode},Set{Action},gen_empty_actions)
    return NFANode(trans, actions)
end

function addtrans!(node::NFANode, trans::Tuple{UInt8,NFANode}, actions::Set{Action}=Set{Action}())
    label, target = trans
    push!(node.trans[label], target)
    union!(node.actions[trans], actions)
    return node
end

function addtrans!(node::NFANode, trans::Tuple{Symbol,NFANode}, actions::Set{Action}=Set{Action}())
    label, target = trans
    @assert label == :eps
    push!(node.trans.trans_eps, target)
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
    nfa, _ = re2nfa_rec(RegExp.desugar(re), 1)
    return nfa
end

function re2nfa_rec(re::RegExp.RE, order::Int)
    enter_actions = Set{Action}()
    exit_actions = Set{Action}()
    if haskey(re.actions, :enter)
        for a in re.actions[:enter]
            push!(enter_actions, Action(a, order))
            order += 1
        end
    end
    if haskey(re.actions, :exit)
        for a in re.actions[:exit]
            push!(exit_actions, Action(a, order))
            order += 1
        end
    end

    function check_arity(p)
        if !p(length(re.args))
            error("invalid arity: $(re.head)")
        end
    end

    start = NFANode()
    final = NFANode()
    =>(x, y) = (x, y)
    if re.head == :byte
        check_arity(n -> n == 1)
        addtrans!(start, re.args[1] => final)
    elseif re.head == :range
        check_arity(n -> n == 1)
        for b in re.args[1]
            addtrans!(start, b => final)
        end
    elseif re.head == :cat
        lastnfa = NFA(start, final)
        addtrans!(start, :eps => final)
        for arg in re.args
            nfa, order = re2nfa_rec(arg, order)
            addtrans!(lastnfa.final, :eps => nfa.start)
            lastnfa = nfa
        end
        final = lastnfa.final
    elseif re.head == :alt
        check_arity(n -> n > 0)
        for arg in re.args
            nfa, order = re2nfa_rec(arg, order)
            addtrans!(start, :eps => nfa.start)
            addtrans!(nfa.final, :eps => final)
        end
    elseif re.head == :rep
        check_arity(n -> n == 1)
        nfa, order = re2nfa_rec(re.args[1], order)
        addtrans!(start, :eps => final)
        addtrans!(start, :eps => nfa.start)
        addtrans!(nfa.final, :eps => final)
        addtrans!(nfa.final, :eps => nfa.start)
    elseif re.head == :isec
        check_arity(n -> n == 2)
        nfa1, order = re2nfa_rec(re.args[1], order)
        nfa2, order = re2nfa_rec(re.args[2], order)
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
        nfa1, order = re2nfa_rec(re.args[1], order)
        nfa2, order = re2nfa_rec(re.args[2], order)
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

    if !isempty(enter_actions)
        newstart = NFANode()
        addtrans!(newstart, :eps => start, enter_actions)
        start = newstart
    end
    if !isempty(exit_actions)
        newfinal = NFANode()
        addtrans!(final, :eps => newfinal, exit_actions)
        final = newfinal
    end

    return NFA(start, final), order
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
        addtrans!(newnodes[s], (l, newnodes[t]), s.actions[(l, t)])
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
    unvisited = Set([nfa.start])
    function add_backref(t, s)
        if !haskey(backrefs, t)
            backrefs[t] = Set{NFANode}()
            push!(unvisited, t)
        end
        push!(backrefs[t], s)
    end
    while !isempty(unvisited)
        s = pop!(unvisited)
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
