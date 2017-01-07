# Automa

[![Build Status](https://travis-ci.org/bicycle1885/Automa.jl.svg?branch=master)](https://travis-ci.org/bicycle1885/Automa.jl)

[![Coverage Status](https://coveralls.io/repos/bicycle1885/Automa.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/bicycle1885/Automa.jl?branch=master)

[![codecov.io](http://codecov.io/github/bicycle1885/Automa.jl/coverage.svg?branch=master)](http://codecov.io/github/bicycle1885/Automa.jl?branch=master)

A Julia package for text validation and parsing based on state machine compiler.

This is a number literal tokenizer using Automa.jl:
```julia
using Automa
using Automa.RegExp
const re = Automa.RegExp

int      = re"[-+]?[0-9]+"
hex      = re"0x[0-9A-Fa-f]+"
oct      = re"0o[0-7]+"
prefloat = re"[-+]?([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)"
float    = prefloat | re.cat(prefloat | re"[-+]?[0-9]+", re"[eE][-+]?[0-9]+")
number   = int | hex | oct | float
spaces   = re.rep(re.space())
numbers  = re.cat(re.opt(spaces * number), re.rep(re.space() * spaces * number), spaces)

number.actions[:enter] = [:mark]
int.actions[:exit]     = [:int]
hex.actions[:exit]     = [:hex]
oct.actions[:exit]     = [:oct]
float.actions[:exit]   = [:float]

machine = compile(numbers)

#= This generates a SVG file to visualize the state machine.
write("numbers.dot", Automa.dfa2dot(machine.dfa))
run(`dot -Tsvg -o numbers.svg numbers.dot`)
=#

actions = Dict(
    :mark  => :(mark = p),
    :int   => :(push!(tokens, (:int, data[mark:p-1]))),
    :hex   => :(push!(tokens, (:hex, data[mark:p-1]))),
    :oct   => :(push!(tokens, (:oct, data[mark:p-1]))),
    :float => :(push!(tokens, (:float, data[mark:p-1]))),
)

@eval function tokenize(data::String)
    tokens = Tuple{Symbol,String}[]
    mark = 0
    $(generate_init_code(machine))
    p_end = p_eof = endof(data)
    $(generate_exec_code(machine, actions=actions))
    return tokens, cs ∈ $(machine.final_states) ? :ok : cs < 0 ? :error : :incomplete
end

tokens, status = tokenize("1 0x0123BEEF 0o754 3.14 -1e4 +6.022045e23")
```

The compiled deterministic finite automaton (DFA) looks like this:
![DFA](/numbers.png)
