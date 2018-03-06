# Non-deterministic Finite Automaton
# ==================================

struct NFANode
    edges::Vector{Tuple{Edge,NFANode}}
end

function NFANode()
    return NFANode(Tuple{Edge,NFANode}[])
end

function Base.show(io::IO, node::NFANode)
    print(io, summary(node), "(<", length(node.edges), " edges", '@', objectid(node), ">)")
end

struct NFA
    start::NFANode
    final::NFANode

    function NFA(start::NFANode, final::NFANode)
        @assert start !== final
        return new(start, final)
    end
end

# epsilon transition
const eps = ByteSet()

function iseps(e::Edge)
    return isempty(e.labels)
end

function re2nfa(re::RegExp.RE, predefined_actions::Dict{Symbol,Action}=Dict{Symbol,Action}())
    actions = Dict{Tuple{RegExp.RE,Symbol},Action}()
    action_order = 1

    function make_action_list(re, names)
        list = ActionList()
        for name in names
            if haskey(predefined_actions, name)  # pick up a predefined action
                action = predefined_actions[name]
            elseif haskey(actions, (re, name))
                action = actions[(re, name)]
            else
                action = Action(name, action_order)
                actions[(re, name)] = action
                action_order += 1
            end
            push!(list, action)
        end
        return list
    end

    # Thompson's construction.
    function rec!(start, re)
        if haskey(re.actions, :enter)
            start_in = NFANode()
            push!(start.edges, (Edge(eps, make_action_list(re, re.actions[:enter])), start_in))
        else
            start_in = start
        end

        re′ = RegExp.shallow_desugar(re)
        head = re′.head
        args = re′.args

        if head == :set
            @assert length(args) == 1
            final_in = NFANode()
            push!(start_in.edges, (Edge(args[1]), final_in))
        elseif head == :cat
            f = start_in
            for arg in args
                f = rec!(f, arg)
            end
            if f == start_in
                final_in = NFANode()
                push!(start_in.edges, (Edge(eps), final_in))
            else
                final_in = f
            end
        elseif head == :alt
            @assert length(args) > 0
            final_in = NFANode()
            for arg in args
                s = NFANode()
                f = rec!(s, arg)
                push!(start_in.edges, (Edge(eps), s))
                push!(       f.edges, (Edge(eps), final_in))
            end
        elseif head == :rep
            @assert length(args) == 1
            s = NFANode()
            f = rec!(s, args[1])
            final_in = NFANode()
            push!(start_in.edges, (Edge(eps), s))
            push!(start_in.edges, (Edge(eps), final_in))
            push!(       f.edges, (Edge(eps), s))
            push!(       f.edges, (Edge(eps), final_in))
        elseif head == :isec || head == :diff
            @assert length(args) == 2
            final_in = NFANode()
            s1 = NFANode()
            f1 = rec!(s1, args[1])
            push!(start_in.edges, (Edge(eps), s1))
            push!(      f1.edges, (Edge(eps), final_in))
            s2 = NFANode()
            f2 = rec!(s2, args[2])
            push!(start_in.edges, (Edge(eps), s2))
            push!(      f2.edges, (Edge(eps), final_in))
            if head == :isec
                revoke = s -> f1 ∉ s.nfanodes || f2 ∉ s.nfanodes
            else  # re.head == :diff
                revoke = s -> f2 ∈ s.nfanodes
            end
            nfa = dfa2nfa(revoke_finals(revoke, nfa2dfa(NFA(start_in, final_in))))
            push!(start_in.edges, (Edge(eps), nfa.start))
            final_in = nfa.final
        else
            error("unsupported operation: $(head)")
        end

        if haskey(re.actions, :all)
            as = make_action_list(re, re.actions[:all])
            for s in traverse(start), (e, _) in s.edges
                if !iseps(e)
                    union!(e.actions, as)
                end
            end
        end

        if haskey(re.actions, :final)
            as = make_action_list(re, re.actions[:final])
            for s in traverse(start), (e, t) in s.edges
                if !iseps(e) && final_in ∈ epsilon_closure(t)
                    union!(e.actions, as)
                end
            end
        end

        if haskey(re.actions, :exit)
            final = NFANode()
            push!(final_in.edges, (Edge(eps, make_action_list(re, re.actions[:exit])), final))
        else
            final = final_in
        end

        if re.when != nothing
            name = re.when
            for s in traverse(start), (e, _) in s.edges
                if !iseps(e)
                    push!(e.precond, (name => TRUE))
                end
            end
        end

        return final
    end

    nfa_start = NFANode()
    nfa_final = rec!(nfa_start, re)
    return NFA(nfa_start, nfa_final)
end

function remove_dead_nodes(nfa::NFA)
    backrefs = Dict(nfa.start => Set{NFANode}())
    for s in traverse(nfa.start), (_, t) in s.edges
        push!(get!(() -> Set{NFANode}(), backrefs, t), s)
    end

    alive = Set{NFANode}()
    unvisited = [nfa.final]
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

    newnodes = Dict{NFANode,NFANode}()
    new(s) = get!(() -> NFANode(), newnodes, s)
    isvisited(s) = haskey(newnodes, s)
    unvisited = [nfa.start]
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

    return NFA(new(nfa.start), new(nfa.final))
end
