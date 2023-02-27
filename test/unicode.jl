module Unicode

using Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Unicode" begin
    passes(machine::Automa.Machine, text) = iszero(first(Automa.execute(machine, text)))

    # No non-ASCII in character sets
    # This is not on principle, we just havne't implemented it yet,
    # and want to make sure we don't produce wrong results.
    @test_throws Exception re.parse("[ø]")

    # Unicode chars work like concatenated
    machine = Automa.compile(re"øæ")
    @test !passes(machine, "æ")
    @test !passes(machine, "ø")
    @test passes(machine, "øæ")
    @test passes(machine, collect(codeunits("øæ")))

    # Byte ranges
    machine = Automa.compile(re"[\x1a-\x29\xaa-\xf0]+")
    @test passes(machine, "\xd0\xe9")
    @test !passes(machine, "")
    @test passes(machine, "\x20\xaa\xf0")
    @test !passes(machine, "\x20\xaa\xf1")
end

end # module