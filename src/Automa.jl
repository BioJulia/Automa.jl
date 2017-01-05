module Automa

export
    @re_str,
    compile,
    generate_init,
    generate_exec

import DataStructures: DefaultDict

include("re.jl")
include("nfa.jl")
include("dfa.jl")
include("dot.jl")
include("machine.jl")
include("codegen.jl")

import .RegExp: @re_str  # re-export

end # module
