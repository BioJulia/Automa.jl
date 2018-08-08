module Test08

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test08" begin
    re = Automa.RegExp
    int = re"[-+]?[0-9]+"
    prefloat = re"[-+]?([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)"
    float = prefloat | re.cat(prefloat | re"[-+]?[0-9]+", re"[eE][-+]?[0-9]+")
    number = int | float
    spaces = re.rep(re.space())
    numbers = re.cat(re.opt(spaces * number), re.rep(re.space() * spaces * number), spaces)

    number.actions[:enter] = [:mark]
    int.actions[:exit]     = [:int]
    float.actions[:exit]   = [:float]

    machine = Automa.compile(numbers)

    actions = Dict(
        :mark  => :(mark = p),
        :int   => :(push!(tokens, (:int, String(data[mark:p-1])))),
        :float => :(push!(tokens, (:float, String(data[mark:p-1])))),
    )

    ctx = Automa.CodeGenContext()

    @eval function tokenize(data)
        tokens = Tuple{Symbol,String}[]
        mark = 0
        $(Automa.generate_init_code(ctx, machine))
        p_end = p_eof = lastindex(data)
        $(Automa.generate_exec_code(ctx, machine, actions))
        return tokens, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end

    @test tokenize(b"") == ([], :ok)
    @test tokenize(b"  ") == ([], :ok)
    @test tokenize(b"42") == ([(:int, "42")], :ok)
    @test tokenize(b"3.14") == ([(:float, "3.14")], :ok)
    @test tokenize(b"1 -42 55") == ([(:int, "1"), (:int, "-42"), (:int, "55")], :ok)
    @test tokenize(b"12. -22. .1 +10e12") == ([(:float, "12."), (:float, "-22."), (:float, ".1"), (:float, "+10e12")], :ok)
    @test tokenize(b" -3 -1.2e-3  +54 1.E2  ") == ([(:int, "-3"), (:float, "-1.2e-3"), (:int, "+54"), (:float, "1.E2")], :ok)

    @test tokenize(b"e") == ([], :error)
    @test tokenize(b"42,") == ([], :error)
    @test tokenize(b"42 ,") == ([(:int, "42")], :error)

    @test tokenize(b".") == ([], :incomplete)
    @test tokenize(b"1e") == ([], :incomplete)
    @test tokenize(b"1e-") == ([], :incomplete)
end

end
