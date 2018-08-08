module Test12

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test12" begin
    a = re"a*"
    a.actions[:all] = [:a]
    machine = Automa.compile(a)

    ctx = Automa.CodeGenContext()
    @eval function validate(data)
        logger = Symbol[]
        $(Automa.generate_init_code(ctx, machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(ctx, machine, :debug))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end
    @test validate(b"") == ([], :ok)
    @test validate(b"a") == ([:a], :ok)
    @test validate(b"aa") == ([:a, :a], :ok)
    @test validate(b"aaa") == ([:a, :a, :a], :ok)
    @test validate(b"aaab") == ([:a, :a, :a], :error)
end

end
