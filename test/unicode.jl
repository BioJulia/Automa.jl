module Unicode

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Unicode" begin
    # No non-ASCII in character sets
    # This is not on principle, we just havne't implemented it yet,
    # and want to make sure we don't produce wrong results.
    @test_throws Exception re.parse("[ø]")

    # Unicode chars work like concatenated
    machine = Automa.compile(re"øæ")
    @test Automa.execute(machine, "æ")[1] < 0
    @test Automa.execute(machine, "ø")[1] < 0
    @test Automa.execute(machine, "øæ")[1] == 0
    @test Automa.execute(machine, collect(codeunits("øæ")))[1] == 0
end

end # module