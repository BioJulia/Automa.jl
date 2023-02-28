module Test11

using Automa
using Test

@testset "Test11" begin
    a = re"[a-z]+"
    precond!(a, :le)
    a = rep1(a)
    onexit!(a, :one)
    b = re"[a-z]+[0-9]+"
    onexit!(b, :two)

    machine = compile((a | b) * '\n')
    actions = Dict(
        :one => :(push!(logger, :one)),
        :two => :(push!(logger, :two)),
        :le  => :(p ≤ n))

    ctx = CodeGenContext(generator=:table)
    @test_throws ErrorException Automa.generate_exec_code(ctx, machine, actions)

    for clean in (true, false)
        ctx = CodeGenContext(generator=:goto, clean=clean)
        validate = @eval function (data, n)
            logger = Symbol[]
            $(Automa.generate_init_code(ctx, machine))
            $(Automa.generate_exec_code(ctx, machine, actions))
            return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
        end
        @test validate(b"a\n", 0) == ([], :error)
        @test validate(b"a\n", 1) == ([:one], :ok)
        @test validate(b"a1\n", 1) == ([:two], :ok)
        @test validate(b"aa\n", 1) == ([], :error)
        @test validate(b"aa1\n", 1) == ([:two], :ok)
        @test validate(b"aa\n", 2) == ([:one], :ok)
        @test validate(b"aa1\n", 2) == ([:two], :ok)
        @test validate(b"1\n", 1) == ([], :error)
    end
end

end
