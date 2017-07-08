__precompile__()

module Automa

import Compat: @compat, xor, take!
import DataStructures: DefaultDict

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
