"""
Streaming Interface of Automa.jl.

NOTE: This module is still experimental. The behavior may change without
deprecations.
"""
module Stream

import Automa
import TranscodingStreams: TranscodingStream

"""
    @mark()

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

Generate a streaming reader function of the name `funcname` from `machine`.

The generated function consumes data from a stream passed as the first argument
and executes the machine with filling the data buffer.

This function returns an expression object of the generated function.  The user
need to evaluate it in a module in which the generated function is needed.

# Keyword Arguments
- `arguments`: Additional arguments `funcname` will take (default: `()`).
    The default signature of the generated function is `(stream::TranscodingStream,)`,
    but it is possible to supply more arguments to the signature with this keyword argument.
- `context`: Automa's codegenerator (default: `Automa.CodeGenContext()`).
- `actions`: A dictionary of action code (default: `Dict{Symbol,Expr}()`).
- `initcode`: Initialization code (default: `:()`).
- `loopcode`: Loop code (default: `:()`).
- `returncode`: Return code (default: `:(return cs)`).

The generated code looks like this:
```julia
function {funcname}(stream::TranscodingStream, {arguments}...)
    buffer = stream.state.buffer1
    data = buffer.data
    {declare variables used by the machine}
    {initcode}
    @label __exec__
    {set up the variables and the data buffer}
    {execute the machine}
    {loopcode}
    if cs ≤ 0 || p > p_eof ≥ 0
        @label __return__
        {returncode}
    end
    @goto __exec__
end
```
"""
function generate_reader(
        funcname::Symbol,
        machine::Automa.Machine;
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
    for arg in arguments
        push!(functioncode.args[1].args, arg)
    end
    functioncode.args[2] = quote
        buffer = stream.state.buffer1
        data = buffer.data
        $(Automa.generate_init_code(context, machine))
        $(initcode)

        @label __exec__
        if p_eof ≥ 0 || eof(stream)
            p_eof = buffer.marginpos - 1
        end
        p = buffer.bufferpos
        p_end = buffer.marginpos - 1
        $(Automa.generate_exec_code(context, machine, actions))
        Base.skip(stream, p - buffer.bufferpos)

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
