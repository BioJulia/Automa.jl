module Test01

using Base.Test
import Automa
import Automa.RegExp: @re_str

@testset "Test01" begin
    re = re""
    re.actions[:enter] = [:enter]
    re.actions[:exit] = [:exit]
    machine = Automa.compile(re)
    @test ismatch(r"^Automa.Machine\(<.*>\)$", repr(machine))

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine)
        exec_code = Automa.generate_exec_code(ctx, machine, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(init_code)
            p_end = p_eof = endof(data)
            $(exec_code)
            return cs == 0, logger
        end
        @test validate(b"") == (true, [:enter, :exit])
        @test validate(b"a") == (false, Symbol[])
    end
end

end
