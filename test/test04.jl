module Test04

if VERSION >= v"0.7-"
    using Test
else
    using Base.Test
end
import Automa
import Automa.RegExp: @re_str
import Compat: lastindex

@testset "Test04" begin
    re = Automa.RegExp
    beg_a = re.cat('a', re"[ab]*")
    end_b = re.cat(re"[ab]*", 'b')
    beg_a_end_b = re.isec(beg_a, end_b)

    machine = Automa.compile(beg_a_end_b)

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine)
        exec_code = Automa.generate_exec_code(ctx, machine)
        validate = @eval function (data)
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
            return cs == 0
        end
        @test validate(b"") == false
        @test validate(b"a") == false
        @test validate(b"aab") == true
        @test validate(b"ab") == true
        @test validate(b"aba") == false
        @test validate(b"abab") == true
        @test validate(b"abb") == true
        @test validate(b"abbb") == true
        @test validate(b"b") == false
        @test validate(b"bab") == false
    end
end

end
