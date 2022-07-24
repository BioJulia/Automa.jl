module Test18

using Automa
using Automa.RegExp: @re_str
using Test

@testset "Test18" begin
    machine = Automa.compile(re"\0\a\b\t\n\v\r\x00\xff\xFF[\\][^\\]")
    for generator in (:table, :goto), checkbounds in (true, false), clean in (true, false)
        (generator == :goto && checkbounds) && continue
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        code = Automa.generate_code(ctx, machine)
        validate = @eval function (data)
            $(code)
        end
        @test_throws Exception validate(b"abracadabra")
        @test validate(b"\0\a\b\t\n\v\r\x00\xff\xFF\\!") === nothing
        @test validate(b"\0\a\b\t\n\v\r\x00\xff\xFF\\\\") === nothing
    end
end

end
