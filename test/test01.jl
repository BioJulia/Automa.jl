module Test01

if VERSION >= v"0.7-"
    using Test
else
    using Base.Test
end
import Automa
import Automa.RegExp: @re_str
import Compat: lastindex, contains

@testset "Test01" begin
    re = re""
    re.actions[:enter] = [:enter]
    re.actions[:exit] = [:exit]
    machine = Automa.compile(re)
    @test contains(repr(machine), r"^Automa.Machine\(<.*>\)$")

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine)
        exec_code = Automa.generate_exec_code(ctx, machine, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
            return cs == 0, logger
        end
        @test validate(b"") == (true, [:enter, :exit])
        @test validate(b"a") == (false, Symbol[])
    end
end

end
