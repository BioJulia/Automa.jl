module Test16

using Automa
using Test

@testset "Test16" begin
    re = re"A+(B+C)*(D|E)+"
    machine = Automa.compile(re)
    ctx = Automa.CodeGenContext(generator=:goto)
    code = 
    validate = @eval function (data)
        $(Automa.generate_init_code(ctx, machine))
        $(Automa.generate_exec_code(ctx, machine))
        return cs == 0
    end
    @test validate(b"ABCD")
    @test validate(b"AABCD")
    @test validate(b"AAABBCD")
    @test validate(b"AAAABCD")
    @test validate(b"AAAABBBBBCD")
    @test validate(b"AAAAAAAAAAAAAABBBBBCBCBBBBBBBBCDE")
    @test validate(b"AAAAAAAAAAAAAABBBBBCBCBBBBBBBBCDEDDDDDDEDEDDDEEEEED")
end

end
