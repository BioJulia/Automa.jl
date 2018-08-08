module Test13

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test13" begin
    abra = re"abra"
    ca = re"(ca)+"
    ca.actions[:enter] = [:ca_enter]
    ca.actions[:exit] = [:ca_exit]
    dabra = re"dabra"
    machine = Automa.compile(re.cat(abra, ca, dabra))
    ctx = Automa.CodeGenContext(generator=:inline, clean=true)
    @eval function validate(data)
        logger = Symbol[]
        $(Automa.generate_init_code(ctx, machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(ctx, machine, :debug))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end
    @test validate(b"a") == ([], :incomplete)
    @test validate(b"abrac") == ([:ca_enter], :incomplete)
    @test validate(b"abraca") == ([:ca_enter], :incomplete)
    @test validate(b"abracad") == ([:ca_enter, :ca_exit], :incomplete)
    @test validate(b"abracadabra") == ([:ca_enter, :ca_exit], :ok)
    @test validate(b"abracacadabra") == ([:ca_enter, :ca_exit], :ok)
    @test validate(b"abrad") == ([], :error)
end

end
