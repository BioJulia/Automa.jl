using Automa
using Automa.RegExp
const re = Automa.RegExp

int      = re"[-+]?[0-9]+"
hex      = re"0x[0-9A-Fa-f]+"
oct      = re"0o[0-7]+"
prefloat = re"[-+]?([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)"
float    = prefloat | re.cat(prefloat | re"[-+]?[0-9]+", re"[eE][-+]?[0-9]+")
number   = int | hex | oct | float
numbers  = re.cat(re.opt(number), re.rep(re" +" * number), re" *")

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
    :int   => :(emit(:int)),
    :hex   => :(emit(:hex)),
    :oct   => :(emit(:oct)),
    :float => :(emit(:float)),
)

@eval function tokenize(data::String)
    tokens = Tuple{Symbol,String}[]
    mark = 0
    $(generate_init_code(machine))
    p_end = p_eof = endof(data)
    emit(kind) = push!(tokens, (kind, data[mark:p-1]))
    $(generate_exec_code(machine, actions=actions))
    return tokens, cs ∈ $(machine.final_states) ? :ok : cs < 0 ? :error : :incomplete
end

tokens, status = tokenize("1 0x0123BEEF 0o754 3.14 -1e4 +6.022045e23")
