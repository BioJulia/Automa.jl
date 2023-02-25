"""
Streaming Interface of Automa.jl.

NOTE: This module is still experimental. The behavior may change without
deprecations.
"""
module Stream

import Automa
import TranscodingStreams: TranscodingStream, NoopStream

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
- `errorcode`: Executed if `cs < 0` after `loopcode` (default error message)

See the source code of this function to see how the generated code looks like
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

"""
    generate_io_validator(funcname::Symbol, regex::RE; goto::Bool=false, report_col::Bool=true)

Create code that, when evaluated, defines a function named `funcname`.
This function takes an `IO`, and checks if the data in the input conforms
to the regex, without executing any actions.
If the input conforms, return `nothing`.
If `report_col` is set, return `(byte, (line, col))`, else return `(byte, line)`,
where `byte` is the first invalid byte, and `(line, col)` the 1-indexed position of that byte.
If the invalid byte is a `\n` byte, `col` is 0 and the line number is incremented.
If the input errors due to unexpected EOF, `byte` is `nothing`, and the line and column
given is the last byte in the file.
If `report_col` is set, the validator may buffer one line of the input.
If the input has very long lines that should not be buffered, set it to `false`.
If `goto`, the function uses the faster but more complicated `:goto` code.
"""
function generate_io_validator(
    funcname::Symbol,
    regex::RegExp.RE;
    goto::Bool=false,
    report_col::Bool=true
    )
    ctx = if goto
        Automa.CodeGenContext(generator=:goto)
    else
        Automa.DefaultCodeGenContext
    end
    vars = ctx.vars
    returncode = if report_col
        quote
            return if iszero(cs)
                nothing
            else
                col = $(vars.p) - $(vars.buffer).markpos
                # Report position of last byte before EOF
                error_byte = if $(vars.p) > $(vars.p_end)
                    col -= 1
                    nothing
                else
                    col -= $(vars.byte) == UInt8('\n')
                    $(vars.byte)
                end
                (error_byte, (line_num, col))
            end
        end
    else
        quote
            return if iszero(cs)
                nothing
            else
                error_byte = if $(vars.p) > $(vars.p_end)
                    nothing
                else
                    $(vars.byte)
                end
                (error_byte, line_num)
            end
        end
    end
    machine = compile(RegExp.set_newline_actions(regex))
    actions = if :newline ∈ machine_names(machine)
        Dict{Symbol, Expr}(:newline => quote
                line_num += 1
                $(report_col ? :(@mark()) : :())
            end
        )
    else
        Dict{Symbol, Expr}()
    end
    machine_names(machine)
    function_code = generate_reader(
        funcname,
        machine;
        context=ctx,
        initcode=:(line_num = 1; @unmark()),
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

end  # module
