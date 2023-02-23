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

function create_debug_function(machine::Automa.Machine; ascii::Bool=false,
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
        function debug_compile($(ctx.vars.data)::Union{String, Vector{UInt8}})
            $logsym = $(if ascii
                quote Tuple{Char, Int, Vector{Symbol}}[] end
            else
                quote Tuple{UInt8, Int, Vector{Symbol}}[] end
            end)
            $(Automa.generate_init_code(ctx, debugger))
            p_end = sizeof($(ctx.vars.data))
            is_eof = true
            $(Automa.generate_exec_code(ctx, debugger, action_dict))
            ($(ctx.vars.cs), $logsym)
        end
    end
end

function debug_execute(re::Automa.RegExp.RE, data::Vector{UInt8}; ascii=false)
    machine = Automa.compile(re, optimize=false)
    s = machine.start
    cs = s.state
    result = Tuple{Union{Nothing, ascii ? Char : UInt8}, Int, Vector{Symbol}}[]
    for d in data
        try
            e, s = Automa.findedge(s, d)
            cs = s.state
            push!(result, (d, cs, Automa.action_names(e.actions)))
        catch ex
            if !isa(ex, ErrorException)
                rethrow()
            end
            cs = -cs
            break
        end
    end
    if cs ∈ machine.final_states && haskey(machine.eof_actions, s.state)
        push!(result, (nothing, 0, Automa.action_names(machine.eof_actions[s.state])))
    end
    if cs > 0
        if cs ∈ machine.final_states
            cs = 0
        else
            cs = -cs
        end
    end
    return cs, result
end

function debug_execute(re::Automa.RegExp.RE, data::String; ascii=false)
    debug_execute(re, collect(codeunits(data)); ascii=ascii)
end