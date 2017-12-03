import Automa
import Automa.RegExp: @re_str
using BenchmarkTools

srand(1234)
data = String(vcat([push!(rand(b"ACGTacgt", 59), UInt8('\n')) for _ in 1:1000]...))


# Case 1
# ------

println(raw"([A-Za-z]*\r?\n)*")
println("PCRE:                 ", @benchmark ismatch($(r"^(:?[A-Za-z]*\r?\n)*$"), data))

machine = Automa.compile(re"([A-Za-z]*\r?\n)*")
context = Automa.CodeGenContext(generator=:goto, checkbounds=false)
@eval function match(data)
    $(Automa.generate_init_code(context, machine))
    p_end = p_eof = endof(data)
    $(Automa.generate_exec_code(context, machine))
    return cs == 0
end
println("Automa.jl:            ", @benchmark match(data))

context = Automa.CodeGenContext(generator=:goto, checkbounds=false, loopunroll=10)
@eval function match(data)
    $(Automa.generate_init_code(context, machine))
    p_end = p_eof = endof(data)
    $(Automa.generate_exec_code(context, machine))
    return cs == 0
end
println("Automa.jl (unrolled): ", @benchmark match(data))


# Case 2
# ------

println()
println(raw"([ACGTacgt]*\r?\n)*")
println("PCRE:                 ", @benchmark ismatch($(r"^(:?[ACGTacgt]*\r?\n)*$"), data))

machine = Automa.compile(re"([ACGTacgt]*\r?\n)*")
context = Automa.CodeGenContext(generator=:goto, checkbounds=false)
@eval function match(data)
    $(Automa.generate_init_code(context, machine))
    p_end = p_eof = endof(data)
    $(Automa.generate_exec_code(context, machine))
    return cs == 0
end
println("Automa.jl:            ", @benchmark match(data))

context = Automa.CodeGenContext(generator=:goto, checkbounds=false, loopunroll=10)
@eval function match(data)
    $(Automa.generate_init_code(context, machine))
    p_end = p_eof = endof(data)
    $(Automa.generate_exec_code(context, machine))
    return cs == 0
end
println("Automa.jl (unrolled): ", @benchmark match(data))
