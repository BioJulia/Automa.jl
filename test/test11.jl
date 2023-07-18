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
    c = re"[A-Z][a-z]+"
    precond!(c, :le, when=:all)
    onexit!(c, :three)

    machine = compile((a | b | c) * '\n')
    actions = Dict(
        :one => :(push!(logger, :one)),
        :two => :(push!(logger, :two)),
        :three => :(push!(logger, :three)),
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
        # p > n
        @test validate(b"a\n", 0) == ([], :error)
        # p == n
        @test validate(b"a\n", 1) == ([:one], :ok)
        # p == n
        @test validate(b"a1\n", 1) == ([:two], :ok)
        # p == n on enter, but not after first
        @test validate(b"Aa\n", 1) == ([], :error)
        @test validate(b"Aaa\n", 3) == ([:three], :ok)
        @test validate("A\n", 1) == ([], :error)
        @test validate("aa", 2) == ([], :incomplete)
        # matches b
        @test validate(b"aa1\n", 1) == ([:two], :ok)
        # Matches a
        @test validate(b"aa\n", 2) == ([:one], :ok)
        # Matches b
        @test validate(b"aa1\n", 2) == ([:two], :ok)
        # Matches neither
        @test validate(b"1\n", 1) == ([], :error)
    end
end

end
