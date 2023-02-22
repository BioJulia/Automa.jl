module Automa

using ScanByte: ScanByte, ByteSet

# Encode a byte set into a sequence of non-empty ranges.
function range_encode(set::ScanByte.ByteSet)
    result = UnitRange{UInt8}[]
    it = iterate(set)
    it === nothing && return result
    start, state = it
    lastbyte = byte = start
    it = iterate(set)
    while it !== nothing
        byte, state = it
        if byte > lastbyte + 1
            push!(result, start:lastbyte)
            start = byte
        end
        lastbyte = byte
        it = iterate(set, state)
    end
    push!(result, start:byte)
    return result
end

"""
    generate_reader(funcname::Symbol, machine::Automa.Machine; kwargs...)

**NOTE: This method requires TranscodingStreams to be loaded**

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
function generate_reader end

"""
    generate_io_validator(funcname::Symbol, regex::RE; goto::Bool=false)

**NOTE: This method requires TranscodingStreams to be loaded**

Create code that, when evaluated, defines a function named `funcname`.
This function takes an `IO`, and checks if the data in the input conforms
to the regex, without executing any actions.
If the input conforms, return `nothing`.
Else, return `(byte, (line, col))`, where `byte` is the first invalid byte,
and `(line, col)` the 1-indexed position of that byte.
If the invalid byte is a `\n` byte, `col` is 0 and the line number is incremented.
If the input errors due to unexpected EOF, `byte` is `nothing`, and the line and column
given is the last byte in the file.
If `goto`, the function uses the faster but more complicated `:goto` code.
"""
function generate_io_validator end

include("re.jl")
include("precond.jl")
include("action.jl")
include("edge.jl")
include("nfa.jl")
include("dfa.jl")
include("machine.jl")
include("traverser.jl")
include("dot.jl")
include("memory.jl")
include("codegen.jl")
include("tokenizer.jl")

if !isdefined(Base, :get_extension)
    include("../ext/AutomaStream.jl")
end

using .RegExp: RE, @re_str, opt, rep, rep1, onenter!, onexit!, onall!, onfinal!, precond!

include("workload.jl")

# This list of exports lists the API
export CodeGenContext,
    Variables,
    Tokenizer,
    tokenize,
    compile,

    # user-facing generator functions
    generate_buffer_validator,
    generate_init_code,
    generate_exec_code,
    generate_code,
    generate_reader,
    generate_io_validator,
    make_tokenizer,

    # cat and alt is not exported in favor of * and |
    RE,
    @re_str,
    opt,
    rep,
    rep1,
    onexit!,
    onenter!,
    onall!,
    onfinal!,
    precond!,

    # Debugging functionality
    machine2dot

end # module
