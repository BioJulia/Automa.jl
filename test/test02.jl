module Test02

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test02" begin
    re = Automa.RegExp

    a = re.rep('a')
    b = re.cat('b', re.rep('b'))
    ab = re.cat(a, b)

    a.actions[:enter] = [:enter_a]
    a.actions[:exit] = [:exit_a]
    a.actions[:final] = [:final_a]
    b.actions[:enter] = [:enter_b]
    b.actions[:exit] = [:exit_b]
    b.actions[:final] = [:final_b]
    ab.actions[:enter] = [:enter_re]
    ab.actions[:exit] = [:exit_re]
    ab.actions[:final] = [:final_re]

    machine = Automa.compile(ab)

    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re]

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
        @test validate(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
        @test validate(b"a") == (false, [:enter_re,:enter_a,:final_a])
        @test validate(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
        @test validate(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])
    end
end

end
