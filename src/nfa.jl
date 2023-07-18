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

# An NFA contains a start and final nodes, which are not the same, as per
# the textbook definition.
# This NFA is an nfa with epsilon transitions.
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

const ACCEPTED_KEYS = [:enter, :exit, :all, :final]

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
        if re.actions !== nothing
            for k in keys(re.actions)
                @assert k ∈ ACCEPTED_KEYS
            end
        end

        if !isnothing(re.actions) && haskey(re.actions, :enter)
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
            nfa = dfa2nfa(revoke_finals(revoke, nfa2dfa(NFA(start_in, final_in), false)))
            push!(start_in.edges, (Edge(eps), nfa.start))
            final_in = nfa.final
        else
            error("unsupported operation: $(head)")
        end

        if !isnothing(re.actions) && haskey(re.actions, :all)
            as = make_action_list(re, re.actions[:all])
            for s in traverse(start), (e, _) in s.edges
                if !iseps(e)
                    union!(e.actions, as)
                end
            end
        end

        if !isnothing(re.actions) && haskey(re.actions, :final)
            as = make_action_list(re, re.actions[:final])
            for s in traverse(start), (e, t) in s.edges
                if !iseps(e) && final_in ∈ epsilon_closure(t)
                    # Ugly hack: The tokenizer ATM relies on adding actions to the final edge
                    # of tokens. It's fine that they are repeated in that particular case.
                    # Therefore it can't error for token actions.
                    # It should probably be fixed in tokenizer.jl, by emitting the token on the
                    # :exit edge, and changing the codegen for tokenizer to compensate.
                    if any(action -> !startswith(String(action.name), "__token"), as) && any(i -> i === s, traverse(t))
                        error(
                            "Regex has final action(s): [", join([repr(i.name) for i in as], ", "),
                            "], but regex is looping (e.g. `re\"a+\"`), so has no final input."
                        )
                    end
                    union!(e.actions, as)
                end
            end
        end

        if !isnothing(re.actions) && haskey(re.actions, :exit)
            final = NFANode()
            push!(final_in.edges, (Edge(eps, make_action_list(re, re.actions[:exit])), final))
        else
            final = final_in
        end

        # Add preconditions: The enter precondition is only added to the edge leading
        # into this regex's NFA, whereas the all precondition is added to all edges.
        # We do not add it to eps edges, since these are NFA artifacts, and will be
        # removed during compilation to DFA anyway: The salient part is that the non-eps
        # edges have preconditions.
        if re.precond_enter !== nothing
            (name, bool) = re.precond_enter
            for e in traverse_first_noneps(start)
                push!(e.precond, (name => (bool ? TRUE : FALSE)))
            end
        end
        if re.precond_all !== nothing
            (name, bool) = re.precond_all
            for s in traverse(start), (e, _) in s.edges
                if !iseps(e)
                    push!(e.precond, (name => (bool ? TRUE : FALSE)))
                end
            end
        end

        return final
    end

    nfa_start = NFANode()
    nfa_final = rec!(nfa_start, re)
    return remove_dead_nodes(NFA(nfa_start, nfa_final))
end

# Return the set of the first non-epsilon edges reachable from the node
function traverse_first_noneps(node::NFANode)::Set{Edge}
    result = Set{Edge}()
    stack = [node]
    seen = Set(stack)
    while !isempty(stack)
        node = pop!(stack)
        for (edge, child) in node.edges
            if iseps(edge)
                if !in(child, seen)
                    push!(stack, child)
                    push!(seen, child)
                end
            else
                push!(result, edge)
            end
        end
    end
    result
end

# Removes both dead nodes, i.e. nodes from which there is no path to
# the final node, and also unreachable nodes, i.e. nodes that cannot be
# reached from the start node.
function remove_dead_nodes(nfa::NFA)
    # Get a dict Node => Set of nodes that point to Node.
    backrefs = Dict(nfa.start => Set{NFANode}())
    for s in traverse(nfa.start), (_, t) in s.edges
        push!(get!(() -> Set{NFANode}(), backrefs, t), s)
    end

    # Automa could support null regex like `re"A" & re"B"`, but it's trouble,
    # and it's useless for the user, who would probably prefer an error.
    # We throw this error here and not on NFA construction so the user can visualise
    # the NFA and find the error in their regex
    if !haskey(backrefs, nfa.final)
        error(
            "NFA matches the empty set Ø, and therefore consists of only dead nodes. " *
            "Automa currently does not support converting null NFAs to DFAs. " *
            "Double check your regex, or inspect the NFA."
        )
    end

    # Mark nodes as alive, if the final state can be reached from them.
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

    # If this is not true, we threw the big error above.
    @assert nfa.start ∈ alive
    @assert nfa.final ∈ alive

    # Map from old to new node.
    newnodes = Dict{NFANode,NFANode}()
    new(s) = get!(() -> NFANode(), newnodes, s)
    isvisited(s) = haskey(newnodes, s)
    unvisited = [nfa.start]

    # Now make a new NFA that only contain nodes marked alive in the previous step.
    # since we make this new NFA by traversing from the start node, we also skip
    # unreachable nodes
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

    # The following code will remove any nodes that
    # have just a single eps edge with no actions or preconditions.
    # TODO: Never create these nodes in the first place
    function is_useless_eps(node::NFANode)::Bool
        node === new(nfa.start) && return false
        node === new(nfa.final) && return false
        length(node.edges) == 1 || return false
        edge = first(only(node.edges))
        iseps(edge) || return false
        isempty(edge.actions.actions) || return false
        isempty(edge.precond.names) || return false
        return true
    end

    unvisited = [new(nfa.start)]
    visited = Set{NFANode}()
    while !isempty(unvisited)
        node = pop!(unvisited)
        push!(visited, node)
        for (i, (e, child)) in enumerate(node.edges)
            original_child = child
            while is_useless_eps(child)
                child = last(only(child.edges))
            end
            in(child, visited) || push!(unvisited, child)
            if child !== original_child
                node.edges[i] = (e, child)
            end
        end
    end

    return NFA(new(nfa.start), new(nfa.final))
end
