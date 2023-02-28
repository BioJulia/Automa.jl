module Test12

using Automa
using Test

@testset "Test12" begin
    a = re"a*"
    onall!(a, :a)
    machine = compile(a)

    @eval function validate(data)
        logger = Symbol[]
        $(generate_code(CodeGenContext(), machine, :debug))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end
    @test validate(b"") == ([], :ok)
    @test validate(b"a") == ([:a], :ok)
    @test validate(b"aa") == ([:a, :a], :ok)
    @test validate(b"aaa") == ([:a, :a, :a], :ok)
    @test validate(b"aaab") == ([:a, :a, :a], :error)
end

end
