module Test16

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test16" begin
    @test_throws ArgumentError Automa.CodeGenContext(generator=:table,  loopunroll=1)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:inline, loopunroll=1)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:goto,   loopunroll=-1)

    re = re"A+(B+C)*(D|E)+"
    machine = Automa.compile(re)
    for checkbounds in (true, false), loopunroll in 0:4
        ctx = Automa.CodeGenContext(generator=:goto, checkbounds=checkbounds, loopunroll=loopunroll)
        init_code = Automa.generate_init_code(ctx, machine)
        exec_code = Automa.generate_exec_code(ctx, machine)
        validate = @eval function (data)
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
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

end
