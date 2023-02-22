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
    esc(:(__buffer.markpos = p))
end

"""
    @markpos()

Get the markerd position.
"""
macro markpos()
    esc(:(__buffer.markpos))
end

"""
    @relpos(pos)

Get the relative position of the absolute position `pos`.
"""
macro relpos(pos)
    esc(:(@assert __buffer.markpos > 0; $(pos) - __buffer.markpos + 1))
end

"""
    @abspos(pos)

Get the absolute position of the relative position `pos`.
"""
macro abspos(pos)
    esc(:(@assert __buffer.markpos > 0; $(pos) + __buffer.markpos - 1))
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
    __buffer = stream.state.buffer1
    \$(vars.data) = buffer.data
    {declare variables used by the machine}
    {initcode}
    @label __exec__
    {fill the buffer if more data is available}
    {update p, is_eof and p_end to match buffer}
    {execute the machine}
    {flush used data from the buffer}
    {loopcode}
    if cs ≤ 0 || (is_eof && p > p_end)
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
        arguments=(),
        context::Automa.CodeGenContext=Automa.DefaultCodeGenContext,
        actions::Dict{Symbol,Expr}=Dict{Symbol,Expr}(),
        initcode::Expr=:(),
        loopcode::Expr=:(),
        returncode::Expr=:(return $(context.vars.cs)),
        errorcode::Expr=Automa.generate_input_error_code(context, machine)
)
    # Add a `return` to the return expression if the user forgot it
    if returncode.head != :return
        returncode = Expr(:return, returncode)
    end
    # Create the function signature
    functioncode = :(function $(funcname)(stream::$(TranscodingStream)) end)
    for arg in arguments
        push!(functioncode.args[1].args, arg)
    end
    vars = context.vars
    functioncode.args[2] = quote
        __buffer = stream.state.buffer1
        $(vars.data) = __buffer.data
        $(Automa.generate_init_code(context, machine))
        $(initcode)
        # Overwrite is_eof for Stream, since we don't know the real EOF
        # until after we've actually seen the stream eof
        $(vars.is_eof) = false

        # Code between __exec__ and the bottom is repeated in a loop,
        # in order to continuously read data, filling in new data to the buffer
        # once it runs out.
        # When the buffer is filled, data in the buffer may shift, which necessitates
        # us updating `p` and `p_end`.
        # Hence, they need to be redefined here.
        @label __exec__
        # The eof call here is what refills the buffer, if the buffer is used up,
        # eof will try refilling the buffer before returning true
        $(vars.is_eof) = eof(stream)
        $(vars.p) = __buffer.bufferpos
        $(vars.p_end) = __buffer.marginpos - 1
        $(Automa.generate_exec_code(context, machine, actions))

        # This function flushes any unused data from the buffer, if it is not marked.
        # this way Automa can keep reading data in a smaller buffer
        $(vars.p) > __buffer.bufferpos && Base.skip(stream, $(vars.p) - __buffer.bufferpos)

        $(loopcode)

        if $(vars.cs) < 0
            $(errorcode)
        end

        # If the machine errored, or we're past the end of the stream, actually return.
        # Else, keep looping.
        if $(vars.cs) == 0 || ($(vars.is_eof) && $(vars.p) > $(vars.p_end))
            @label __return__
            $(returncode)
        end
        @goto __exec__
    end
    return functioncode
end

end  # module
