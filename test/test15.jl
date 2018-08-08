module Test15

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test15" begin
    a = re"a+"
    a.actions[:enter] = [:enter]
    a.actions[:all]   = [:all]
    a.actions[:final] = [:final]
    a.actions[:exit]  = [:exit]
    b = re"b+"
    b.actions[:enter] = [:enter]
    b.actions[:all]   = [:all]
    b.actions[:final] = [:final]
    b.actions[:exit]  = [:exit]
    ab = Automa.RegExp.cat(a, b)

    machine = Automa.compile(ab)
    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter, :all, :final, :exit, :enter, :all, :final, :exit]

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        validate = @eval function (data)
            logger = Symbol[]
            $(Automa.generate_init_code(ctx, machine))
            p_end = p_eof = sizeof(data)
            $(Automa.generate_exec_code(ctx, machine, :debug))
            return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
        end
        @test validate(b"ab") == ([:enter, :all, :final, :exit, :enter, :all, :final, :exit], :ok)
    end
end

end
