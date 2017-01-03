# Non-deterministic Finite Automaton
# ==================================

immutable Action
    name::Symbol
    order::Int
end

typealias OrdAction Action

function gen_empty_nfanode_set()
    return Set{NFANode}()
end

function gen_empty_actions()
    return Action[]
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
    actions::DefaultDict{Tuple{Any,NFANode},Vector{Action},typeof(gen_empty_actions)}
end

function NFANode()
    trans = NFATransition()
    actions = DefaultDict(Tuple{Any,NFANode},Vector{Action},gen_empty_actions)
    return NFANode(trans, actions)
end

function addtrans!(node::NFANode, trans::Tuple{UInt8,NFANode}, actions::Vector{Action}=Action[])
    label, target = trans
    push!(node.trans[label], target)
    append!(node.actions[trans], actions)
    return node
end

function addtrans!(node::NFANode, trans::Tuple{Symbol,NFANode}, actions::Vector{Action}=Action[])
    label, target = trans
    @assert label == :eps
    push!(node.trans.trans_eps, target)
    append!(node.actions[trans], actions)
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
    enter_actions = OrdAction[]
    exit_actions = OrdAction[]
    if haskey(re.actions, :enter)
        for a in re.actions[:enter]
            push!(enter_actions, OrdAction(a, order))
            order += 1
        end
    end
    if haskey(re.actions, :exit)
        for a in re.actions[:exit]
            push!(exit_actions, OrdAction(a, order))
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
