module Stream

import Automa
import TranscodingStreams: TranscodingStream

"""
State of a machine.
"""
mutable struct MachineState
    cs::Int
end

"""
    @mark

Mark at the current position.

Note: `mark(stream)` doesn't work as expected because the reading position is
not updated while scanning the stream.
"""
macro mark()
    esc(:(buffer.markpos = p))
end

"""
    @markpos()

Get the markerd position.
"""
macro markpos()
    esc(:(buffer.markpos))
end

"""
    @relpos(pos)

Get the relative position of the absolute position `pos`.
"""
macro relpos(pos)
    esc(:(@assert buffer.markpos > 0; $(pos) - buffer.markpos + 1))
end

"""
    @abspos(pos)

Get the absolute position of the relative position `pos`.
"""
macro abspos(pos)
    esc(:(@assert buffer.markpos > 0; $(pos) + buffer.markpos - 1))
end

"""
    generate_reader(funcname::Symbol, machine::Automa.Machine; kwargs...)

Generate a streaming reader from `machine`.

TODO: docs.
"""
function generate_reader(
        funcname::Symbol,
        machine::Automa.Machine;
        stateful::Bool=false,
        arguments::Tuple=(),
        context::Automa.CodeGenContext=Automa.CodeGenContext(),
        actions::Dict{Symbol,Expr}=Dict{Symbol,Expr}(),
        initcode::Expr=:(),
        loopcode::Expr=:(),
        returncode::Expr=:(return cs))
    if returncode.head != :return
        returncode = Expr(:return, returncode)
    end
    functioncode = :(function $(funcname)(stream::$(TranscodingStream)) end)
    if stateful
        push!(functioncode.args[1].args, :(state::$(MachineState)))
    end
    for arg in arguments
        push!(functioncode.args[1].args, arg)
    end
    functioncode.args[2] = quote
        buffer = stream.state.buffer1
        data = buffer.data
        $(Automa.generate_init_code(context, machine))
        $(stateful ? :(cs = state.cs) : nothing)
        $(initcode)

        @label __exec__
        if p_eof ≥ 0 || eof(stream)
            p_eof = buffer.marginpos - 1
        end
        p = buffer.bufferpos
        p_end = buffer.marginpos - 1
        $(Automa.generate_exec_code(context, machine, actions))

        Base.skip(stream, p - buffer.bufferpos)
        $(stateful ? :(state.cs = cs) : nothing)

        $(loopcode)

        if cs ≤ 0 || p > p_eof ≥ 0
            @label __return__
            $(returncode)
        end
        @goto __exec__
    end
    return functioncode
end

end  # module
