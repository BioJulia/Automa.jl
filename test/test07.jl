module Test07

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test07" begin
    re1 = re"a.*b"
    machine = Automa.compile(re1)
    ctx = Automa.CodeGenContext()
    @eval function ismatch1(data)
        $(Automa.generate_init_code(ctx, machine))
        p_end = p_eof = lastindex(data)
        $(Automa.generate_exec_code(ctx, machine))
        return cs == 0
    end
    @test ismatch1(b"ab")
    @test ismatch1(b"azb")
    @test ismatch1(b"azzzb")
    @test !ismatch1(b"azzz")
    @test !ismatch1(b"zzzb")

    re2 = re"a\.*b"
    machine = Automa.compile(re2)
    ctx = Automa.CodeGenContext()
    @eval function ismatch2(data)
        $(Automa.generate_init_code(ctx, machine))
        p_end = p_eof = lastindex(data)
        $(Automa.generate_exec_code(ctx, machine))
        return cs == 0
    end
    @test ismatch2(b"ab")
    @test ismatch2(b"a.b")
    @test ismatch2(b"a...b")
    @test !ismatch2(b"azzzb")
    @test !ismatch2(b"a...")
    @test !ismatch2(b"...b")

    re3 = re"a\.\*b"
    machine = Automa.compile(re3)
    ctx = Automa.CodeGenContext()
    @eval function ismatch3(data)
        $(Automa.generate_init_code(ctx, machine))
        p_end = p_eof = lastindex(data)
        $(Automa.generate_exec_code(ctx, machine))
        return cs == 0
    end
    @test ismatch3(b"a.*b")
    @test !ismatch3(b"a...b")
end

end
