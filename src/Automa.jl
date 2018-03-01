__precompile__()

module Automa

import DataStructures: DefaultDict
import Compat: Compat,
    AbstractDict,
    argmax,
    lastindex,
    uninitialized,
    findfirst,
    Nothing,
    popfirst!

if VERSION > v"0.7-"
    using Printf: @sprintf
end

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

end # module
