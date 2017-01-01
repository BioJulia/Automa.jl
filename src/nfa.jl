# Non-deterministic Finite Automaton
# ==================================

immutable OrdAction
    name::Symbol
    order::Int
end

#=
type NFANode
    next::Vector{Pair}
    actions::Vector{OrdAction}
end
=#
type NFANode
    next::Dict{Any,Vector{NFANode}}
    actions::Vector{OrdAction}
end

function Base.push!(node::NFANode, edge::Pair)
    label, dest = edge
    if !haskey(node.next, label)
        node.next[label] = NFANode[]
    end
    push!(node.next[label], dest)
    return node
end

type NFA
    start::NFANode
    final::NFANode
end

# Convert a RE to an NFA using Thompson's construction.
function re2nfa(re::RE)
    nfa, _ = re2nfa_rec(re, 1)
    return nfa
end

function re2nfa_rec(re, order)
    if haskey(re.actions, :enter)
        enter_actions = []
        for a in re.actions[:enter]
            push!(enter_actions, OrdAction(a, order))
            order += 1
        end
    end
    if haskey(re.actions, :exit)
        exit_actions = []
        for a in re.actions[:exit]
            push!(exit_actions, OrdAction(a, order))
            order += 1
        end
    end

    #start = NFANode([], [])
    #final = NFANode([], [])
    start = NFANode(Dict(), [])
    final = NFANode(Dict(), [])
    if re.head == :byte
        #push!(start.next, re.args[1] => final)
        push!(start, re.args[1] => final)
    elseif re.head == :cat
        if isempty(re.args)
            #push!(start.next, :eps => final)
            push!(start, :eps => final)
        else
            lastnfa, order = re2nfa_rec(re.args[1], order)
            start = lastnfa.start
            for arg in re.args[2:end]
                nfa, order = re2nfa_rec(arg, order)
                #push!(lastnfa.final.next, :eps => nfa.start)
                push!(lastnfa.final, :eps => nfa.start)
                lastnfa = nfa
            end
            final = lastnfa.final
        end
    elseif re.head == :alt
        if isempty(re.args)
            error("invalid arity: $(re.head)")
        end
        for arg in re.args
            nfa, order = re2nfa_rec(arg, order)
            #push!(start.next, :eps => nfa.start)
            #push!(nfa.final.next, :eps => final)
            push!(start, :eps => nfa.start)
            push!(nfa.final, :eps => final)
        end
    elseif re.head == :rep
        if length(re.args) != 1
            error("invalid arity: $(re.head)")
        end
        nfa, order = re2nfa_rec(re.args[1], order)
        #push!(start.next, :eps => final)
        #push!(start.next, :eps => nfa.start)
        #push!(nfa.final.next, :eps => final)
        #push!(nfa.final.next, :eps => nfa.start)
        push!(start, :eps => final)
        push!(start, :eps => nfa.start)
        push!(nfa.final, :eps => final)
        push!(nfa.final, :eps => nfa.start)
    #elseif re.head == :eos
    #    push!(start.next, :eos => final)
    else
        error("unsupported operation: $(re.head)")
    end

    if haskey(re.actions, :enter)
        append!(start.actions, enter_actions)
    end
    if haskey(re.actions, :exit)
        append!(final.actions, exit_actions)
    end

    return NFA(start, final), order
end
