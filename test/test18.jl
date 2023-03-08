module Test18

using Automa
using Automa.RegExp: @re_str
using Test

@testset "Test18" begin
    regex = re"\0\a\b\t\n\v\r\x00\xff\xFF[\\][^\\]"
    for goto in (false, true)
        @eval $(Automa.generate_buffer_validator(:validate, regex; goto=goto, docstring=false))

        # Bad input types
        @test_throws Exception validate(18)
        @test_throws Exception validate('a')
        @test_throws Exception validate(0x01:0x02)

        @test validate(b"\0\a\b\t\n\v\r\x00\xff\xFF\\!") === nothing
        bad_input = b"\0\a\b\t\n\v\r\x00\xff\xFF\\\\\\"
        @test validate(bad_input) == lastindex(bad_input)
        bad_input = b"\0\a\b\t\n\v\r\x00\xff\xFF\\"
        @test validate(bad_input) == 0
    end
end

end
