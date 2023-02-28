module Test06

using Automa
using Test

@testset "Test06" begin
    re = Automa.RegExp

    foo = re.cat("foo")
    foos = re.rep(re.cat(foo, re" *"))
    onexit!(foo, :foo)
    actions = Dict(:foo => :(push!(ret, state.p:p-1); @escape))

    machine = Automa.compile(foos)

    @eval mutable struct MachineState
        p::Int
        cs::Int
        function MachineState(data)
            $(Automa.generate_init_code(machine))
            return new(p, cs)
        end
    end

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        run! = @eval function (state, data)
            ret = []
            $(Automa.generate_init_code(machine))
            p = state.p
            cs = state.cs
            $(Automa.generate_exec_code(machine, actions))
            state.p = p
            state.cs = cs
            return ret
        end
        data = b"foo foofoo   foo"
        state = MachineState(data)
        @test run!(state, data) == [1:3]
        @test run!(state, data) == [5:7]
        @test run!(state, data) == [9:10]
        @test run!(state, data) == [12:16]
        @test run!(state, data) == []
        @test run!(state, data) == []
    end
end

end
