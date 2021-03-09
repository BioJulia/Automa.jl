function debug_machine(machine::Automa.Machine)
    @assert machine.start_state == 1
    cloned_nodes = [Automa.Node(i) for i in machine.states]
    for node in Automa.traverse(machine.start)
        for (edge, child) in node.edges
            cloned_edge = Automa.Edge(
                edge.labels,
                edge.precond,
                Automa.ActionList(copy(edge.actions.actions))
            )
            isempty(cloned_edge.actions) || @assert -1 < minimum(edge.actions.actions) do action
                action.order
            end
            push!(cloned_edge.actions, Automa.Action(:debug, -1))
            push!(cloned_nodes[node.state].edges, (cloned_edge, cloned_nodes[child.state]))
        end
    end
    Automa.Machine(
        cloned_nodes[1],
        1:length(cloned_nodes),
        1,
        copy(machine.final_states),
        copy(machine.eof_actions)   
    )
end

function create_debug_code(machine::Automa.Machine; ascii::Bool=false,
    ctx::Union{Automa.CodeGenContext, Nothing}=nothing
)
    ctx = ctx === nothing ? Automa.CodeGenContext() : ctx
    logsym = gensym()
    action_dict = Dict(map(collect(Automa.action_names(machine))) do name
        name => quote
            push!(last($logsym)[3], $(QuoteNode(name)))
        end
    end)
    @assert !haskey(action_dict, :debug) "Machine can't contain action :debug"
    action_dict[:debug] = quote
        push!($logsym, ($(ctx.vars.byte), $(ctx.vars.cs), Symbol[])
        )
    end
    debugger = debug_machine(machine)
    quote
        function execute_debug($(ctx.vars.data)::Union{String, Vector{UInt8}})
            $logsym = $(if ascii
                quote Tuple{Char, Int, Vector{Symbol}}[] end
            else
                quote Tuple{UInt8, Int, Vector{Symbol}}[] end
            end)
            $(Automa.generate_init_code(ctx, debugger))
            p_end = p_eof = sizeof($(ctx.vars.data))
            $(Automa.generate_exec_code(ctx, debugger, action_dict))
            ($(ctx.vars.cs), $logsym)
        end
    end
end

