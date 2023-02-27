module Test01

using Automa
import Automa.RegExp: @re_str
using Test

@testset "Test01" begin
    re = re""
    onenter!(re, :enter)
    onexit!(re, :exit)
    machine = Automa.compile(re)
    @test occursin(r"^Automa.Machine\(<.*>\)$", repr(machine))

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        code = Automa.generate_code(ctx, machine, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(code)
            return cs == 0, logger
        end
        @test validate(b"") == (true, [:enter, :exit])
        @test validate(b"a") == (false, Symbol[])
    end
end

end
