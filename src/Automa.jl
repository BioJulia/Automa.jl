module Automa

export
    @re_str,
    compile,
    generate_init_code,
    generate_exec_code

import DataStructures: DefaultDict

include("re.jl")
include("nfa.jl")
include("dfa.jl")
include("dot.jl")
include("machine.jl")
include("codegen.jl")

import .RegExp: @re_str  # re-export

end # module
