module Test17

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test17" begin
    re1 = re"[a\-c]"
    re1.actions[:enter] = [:enter]
    re1.actions[:exit] = [:exit]
    machine1 = Automa.compile(re1)
    @test occursin(r"^Automa.Machine\(<.*>\)$", repr(machine1))

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine1)
        exec_code = Automa.generate_exec_code(ctx, machine1, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
            return cs == 0, logger
        end

        @test validate(b"-") == (true, [:enter, :exit])
        @test validate(b"b") == (false, Symbol[])
    end

    re2 = re"[a-c]"
    re2.actions[:enter] = [:enter]
    re2.actions[:exit] = [:exit]
    machine2 = Automa.compile(re2)
    @test occursin(r"^Automa.Machine\(<.*>\)$", repr(machine2))

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine2)
        exec_code = Automa.generate_exec_code(ctx, machine2, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
            return cs == 0, logger
        end

        @test validate(b"-") == (false, [])
        @test validate(b"b") == (true, Symbol[:enter, :exit])
    end
end

end
