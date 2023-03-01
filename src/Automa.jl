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

function generate_reader end
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

const RE = Automa.RegExp
using .RegExp: @re_str, opt, rep, rep1, onenter!, onexit!, onall!, onfinal!, precond!

# This list of exports lists the API
export RE,
    @re_str,
    CodeGenContext,
    Tokenizer,
    tokenize,
    compile,

    # user-facing generator functions
    generate_validator_function,
    generate_init_code,
    generate_exec_code,
    generate_code,
    generate_reader,
    generate_io_validator,
    make_tokenizer,

    # cat and alt is not exported in favor of * and |
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
