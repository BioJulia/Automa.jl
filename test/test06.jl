module Test06

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test06" begin
    re = Automa.RegExp

    foo = re.cat("foo")
    foos = re.rep(re.cat(foo, re" *"))
    foo.actions[:exit]  = [:foo]
    actions = Dict(:foo => :(push!(ret, state.p:p-1); @escape))

    machine = Automa.compile(foos)

    @eval mutable struct MachineState
        p::Int
        cs::Int
        function MachineState()
            $(Automa.generate_init_code(Automa.CodeGenContext(), machine))
            return new(p, cs)
        end
    end

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        run! = @eval function (state, data)
            ret = []
            p = state.p
            cs = state.cs
            p_end = p_eof = lastindex(data)
            $(Automa.generate_exec_code(ctx, machine, actions))
            state.p = p
            state.cs = cs
            return ret
        end
        state = MachineState()
        data = b"foo foofoo   foo"
        @test run!(state, data) == [1:3]
        @test run!(state, data) == [5:7]
        @test run!(state, data) == [9:10]
        @test run!(state, data) == [12:16]
        @test run!(state, data) == []
        @test run!(state, data) == []
    end
end

end
