module Test17

using Automa
import Automa.RegExp: @re_str
using Test

@testset "Test17" begin
    re1 = re"[a\-c]"
    onenter!(re1, :enter)
    onexit!(re1, :exit)
    machine1 = Automa.compile(re1)
    @test occursin(r"^Automa.Machine\(<.*>\)$", repr(machine1))

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        code = Automa.generate_code(ctx, machine1, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(code)
            return cs == 0, logger
        end

        @test validate(b"-") == (true, [:enter, :exit])
        @test validate(b"b") == (false, Symbol[])
    end

    re2 = re"[a-c]"
    onenter!(re2, :enter)
    onexit!(re2, :exit)
    machine2 = Automa.compile(re2)
    @test occursin(r"^Automa.Machine\(<.*>\)$", repr(machine2))

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        code = Automa.generate_code(ctx, machine2, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(code)
            return cs == 0, logger
        end

        @test validate(b"-") == (false, [])
        @test validate(b"b") == (true, Symbol[:enter, :exit])
    end
end

end
