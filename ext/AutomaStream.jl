module AutomaStream

using Automa: Automa
using TranscodingStreams: TranscodingStream, NoopStream

function Automa.generate_reader(
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
    # Expands special Automa pseudomacros. When not inside the machine execution,
    # at_eof and cs is meaningless, and when both are set to nothing, @escape
    # will error at parse time
    function rewrite(ex::Expr)
        Automa.rewrite_special_macros(;
            ctx=context,
            ex=ex,
            at_eof=nothing,
            cs=nothing
        )
    end
    vars = context.vars
    functioncode.args[2] = quote
        $(vars.buffer) = stream.state.buffer1
        $(vars.data) = $(vars.buffer).data
        $(Automa.generate_init_code(context, machine))
        $(rewrite(initcode))
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
        $(vars.p) = $(vars.buffer).bufferpos
        $(vars.p_end) = $(vars.buffer).marginpos - 1
        $(Automa.generate_exec_code(context, machine, actions))
        
        # Advance the buffer, hence advancing the stream itself
        $(vars.buffer).bufferpos = $(vars.p)

        $(rewrite(loopcode))

        if $(vars.cs) < 0
            $(rewrite(errorcode))
        end

        # If the machine errored, or we're past the end of the stream, actually return.
        # Else, keep looping.
        if $(vars.cs) == 0 || ($(vars.is_eof) && $(vars.p) > $(vars.p_end))
            @label __return__
            $(rewrite(returncode))
        end
        @goto __exec__
    end
    return functioncode
end

function Automa.generate_io_validator(
    funcname::Symbol,
    regex::Automa.RegExp.RE;
    goto::Bool=false
    )
    ctx = if goto
        Automa.CodeGenContext(generator=:goto)
    else
        Automa.DefaultCodeGenContext
    end
    vars = ctx.vars
    returncode = quote
        return if iszero(cs)
            nothing
        else
            # The column must be cleared cols. If we're EOF, all bytes have
            # already been cleared by the buffer when attempting to get more bytes.
            # If not, we add the bytes still in the buffer to the column
            col = cleared_cols
            col += ($(vars.p) - p_newline) * !$(vars.is_eof)
            # Report position of last byte before EOF if EOF.
            error_byte = if $(vars.p) > $(vars.p_end)
                nothing
            else
                $(vars.byte)
            end
            # If errant byte was a newline, instead of counting it as last
            # byte on a line (which would be inconsistent), count it as first
            # byte on a new line
            line_num += error_byte == UInt8('\n')
            col -= error_byte == UInt8('\n')
            (error_byte, (line_num, col))
        end
    end
    initcode = quote
        # Unmark buffer in case it's been marked before hand
        @unmark()
        line_num = 1
        # Keep track of how many columns since newline that has
        # been cleared from the buffer
        cleared_cols = 0
        # p value of last newline _in the current buffer_.
        p_newline = 0
    end
    loopcode = quote
        # If we're about to clear the buffer (ran out of buffer, did not error),
        # then update cleared_cols, and since the buffer is about to be cleared,
        # remove p_newline
        if $(vars.cs) > 0 && $(vars.p) > $(vars.p_end) && !$(vars.is_eof)
            cleared_cols += $(vars.p) - p_newline - 1
            p_newline = 0
        end
    end
    machine = Automa.compile(Automa.RegExp.set_newline_actions(regex))
    actions = if :newline ∈ Automa.machine_names(machine)
        Dict{Symbol, Expr}(:newline => quote
                line_num += 1
                cleared_cols = 0
                p_newline = $(vars.p)
            end
        )
    else
        Dict{Symbol, Expr}()
    end
    function_code = Automa.generate_reader(
        funcname,
        machine;
        context=ctx,
        initcode=initcode,
        loopcode=loopcode,
        actions=actions,
        returncode=returncode,
        errorcode=:(@goto __return__),
    )
    return quote
        """
            $($(funcname))(io::IO)

        Checks if the data in `io` conforms to the given regex specified at function definition time.
        If the input conforms, return `nothing`.
        Else return `(byte, (line, col))` where `byte` is the first invalid byte,
        and `(line, col)` the 1-indexed position of that byte.
        If the invalid byte is a `\n` byte, `col` is 0.
        If the input errors due to unexpected EOF, `byte` is `nothing`, and the line and column
        given is the last byte in the file.
        """
        $function_code

        $(funcname)(io::$(IO)) = $(funcname)($(NoopStream)(io))
    end 
end

end # module
