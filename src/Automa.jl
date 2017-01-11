module Automa

export
    compile,
    generate_init_code,
    generate_exec_code

import Compat: @compat
import DataStructures: DefaultDict

include("byteset.jl")
include("re.jl")
include("nfa.jl")
include("dfa.jl")
include("dot.jl")
include("machine.jl")
include("codegen.jl")
include("tokenizer.jl")

end # module
