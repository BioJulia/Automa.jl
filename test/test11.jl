module Test11

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test11" begin
    a = re"[a-z]"
    a.when = :le
    a = re.rep1(a)
    a.actions[:exit] = [:one]
    b = re"[a-z][a-z0-9]*"
    b.actions[:exit] = [:two]

    machine = Automa.compile(re.cat(a | b, '\n'))
    actions = Dict(
        :one => :(push!(logger, :one)),
        :two => :(push!(logger, :two)),
        :le  => :(p ≤ n))

    ctx = Automa.CodeGenContext(generator=:table)
    @test_throws ErrorException Automa.generate_exec_code(ctx, machine, actions)

    for generator in (:inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        validate = @eval function (data, n)
            logger = Symbol[]
            $(Automa.generate_init_code(ctx, machine))
            p_end = p_eof = sizeof(data)
            $(Automa.generate_exec_code(ctx, machine, actions))
            return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
        end
        @test validate(b"a\n", 0) == ([:two], :ok)
        @test validate(b"a\n", 1) == ([:one, :two], :ok)
        @test validate(b"a1\n", 1) == ([:two], :ok)
        @test validate(b"aa\n", 1) == ([:two], :ok)
        @test validate(b"aa1\n", 1) == ([:two], :ok)
        @test validate(b"aa\n", 2) == ([:one, :two], :ok)
        @test validate(b"aa1\n", 2) == ([:two], :ok)
        @test validate(b"1\n", 1) == ([], :error)
    end
end

end
