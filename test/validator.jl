module Validator

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Validator" begin
    machine = let
        Automa.compile(re"a(bc)*|(def)|x+" | re"def" | re"x+")
    end
    eval(Automa.generate_validator_function(:foobar, machine, false))
    eval(Automa.generate_validator_function(:barfoo, machine, true))

    for good_data in [
        "def"
        "abc"
        "abcbcbcbcbc"
        "x"
        "xxxxxx"
    ]
        @test foobar(good_data) === barfoo(good_data) === nothing
    end

    for bad_data in [
        "",
        "abcabc",
        "abcbb",
        "abcbcb",
        "defdef",
        "xabc"
    ]
        @test foobar(bad_data) === barfoo(bad_data) !== nothing
    end
end

end # module