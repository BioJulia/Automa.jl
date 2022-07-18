module Automa

using Printf: @sprintf
import ScanByte: ScanByte, ByteSet

include("sdict.jl")
include("sset.jl")

# TODO: use StableDict and StableSet only where they are required
const Dict = StableDict
const Set = StableSet

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
include("Stream.jl")

end # module
