module Automa

using DataStructures: DefaultDict
using Printf: @sprintf

include("sdict.jl")
include("sset.jl")

# TODO: use StableDict and StableSet only where they are required
const Dict = StableDict
const Set = StableSet

include("byteset.jl")
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
