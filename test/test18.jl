module Test18

using Automa
using Automa.RegExp: @re_str
using Test

@testset "Test18" begin
    machine = Automa.compile(re"\0\a\b\t\n\v\r\x00\xff\xFF[\\][^\\]")
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
        @test validate(b"abracadabra") == false
        @test validate(b"\0\a\b\t\n\v\r\x00\xff\xFF\\!") == true
        @test validate(b"\0\a\b\t\n\v\r\x00\xff\xFF\\\\") == false
    end
end

end
