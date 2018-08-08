module Test10

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test10" begin
    machine = Automa.compile(re.primitive(0x61))
    @test Automa.execute(machine, "a")[1] == 0
    @test Automa.execute(machine, "b")[1] < 0

    machine = Automa.compile(re.primitive(0x61:0x62))
    @test Automa.execute(machine, "a")[1] == 0
    @test Automa.execute(machine, "b")[1] == 0
    @test Automa.execute(machine, "c")[1] < 0

    machine = Automa.compile(re.primitive('a'))
    @test Automa.execute(machine, "a")[1] == 0
    @test Automa.execute(machine, "b")[1] < 0

    machine = Automa.compile(re.primitive('樹'))
    @test Automa.execute(machine, "樹")[1] == 0
    @test Automa.execute(machine, "儒")[1] < 0

    machine = Automa.compile(re.primitive("ジュリア"))
    @test Automa.execute(machine, "ジュリア")[1] == 0
    @test Automa.execute(machine, "パイソン")[1] < 0

    machine = Automa.compile(re.primitive([0x61, 0x62, 0x72]))
    @test Automa.execute(machine, "abr")[1] == 0
    @test Automa.execute(machine, "acr")[1] < 0

    machine = Automa.compile(re"[^A-Z]")
    @test Automa.execute(machine, "1")[1] == 0
    @test Automa.execute(machine, "A")[1] < 0
    @test Automa.execute(machine, "a")[1] == 0

    machine = Automa.compile(re"[A-Z]+" & re"FOO?")
    @test Automa.execute(machine, "FO")[1] == 0
    @test Automa.execute(machine, "FOO")[1] == 0
    @test Automa.execute(machine, "foo")[1] < 0

    machine = Automa.compile(re"[A-Z]+" \ re"foo")
    @test Automa.execute(machine, "FOO")[1] == 0
    @test Automa.execute(machine, "foo")[1] < 0

    machine = Automa.compile(!re"foo")
    @test Automa.execute(machine, "bar")[1] == 0
    @test Automa.execute(machine, "foo")[1] < 0
end

end
