module Automa

import Compat: @compat, xor
import DataStructures: DefaultDict

include("byteset.jl")
include("re.jl")
include("action.jl")
include("nfa.jl")
include("dfa.jl")
include("dot.jl")
include("machine.jl")
include("codegen.jl")
include("tokenizer.jl")

end # module
