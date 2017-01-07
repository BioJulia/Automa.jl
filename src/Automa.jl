module Automa

export
    compile,
    generate_init_code,
    generate_exec_code

import DataStructures: DefaultDict, OrderedDict, OrderedSet

const Dict = OrderedDict
const Set = OrderedSet

include("byteset.jl")
include("re.jl")
include("nfa.jl")
include("dfa.jl")
include("dot.jl")
include("machine.jl")
include("codegen.jl")

end # module
