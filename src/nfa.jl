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
function re2nfa(re::RE)
    nfa, _ = re2nfa_rec(re, 1)
    return nfa
end

function re2nfa_rec(re::RE, order::Int)
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

    start = NFANode()
    final = NFANode()
    =>(x, y) = (x, y)
    if re.head == :byte
        addtrans!(start, re.args[1] => final)
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
        if isempty(re.args)
            error("invalid arity: $(re.head)")
        end
        for arg in re.args
            nfa, order = re2nfa_rec(arg, order)
            addtrans!(start, :eps => nfa.start)
            addtrans!(nfa.final, :eps => final)
        end
    elseif re.head == :rep
        if length(re.args) != 1
            error("invalid arity: $(re.head)")
        end
        nfa, order = re2nfa_rec(re.args[1], order)
        addtrans!(start, :eps => final)
        addtrans!(start, :eps => nfa.start)
        addtrans!(nfa.final, :eps => final)
        addtrans!(nfa.final, :eps => nfa.start)
    elseif re.head == :diff
        if length(re.args) != 2
            error("invalid arity: $(re.head)")
        end
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
