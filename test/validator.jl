module Validator

using Automa
using TranscodingStreams: NoopStream
using Test

@testset "Validator" begin
    regex = re"a(bc)*|(def)|x+" | re"def" | re"x+"
    eval(Automa.generate_validator_function(:foobar, regex, false))
    eval(Automa.generate_validator_function(:barfoo, regex, true))

    eval(Automa.generate_io_validator(:io_bar, regex; goto=false))
    eval(Automa.generate_io_validator(:io_foo, regex; goto=true))

    for good_data in [
        "def"
        "abc"
        "abcbcbcbcbc"
        "x"
        "xxxxxx"
    ]
        @test foobar(good_data) ===
            barfoo(good_data) ===
            io_foo(IOBuffer(good_data)) ===
            io_bar(IOBuffer(good_data)) ===
            io_bar(NoopStream(IOBuffer(good_data))) ===
            nothing
    end

    for bad_data in [
        "",
        "abcabc",
        "abcbb",
        "abcbcb",
        "defdef",
        "xabc"
    ]
        @test foobar(bad_data) ===
            barfoo(bad_data) !==
            nothing

        @test io_foo(IOBuffer(bad_data)) ==
            io_bar(IOBuffer(bad_data)) ==
            io_bar(NoopStream(IOBuffer(bad_data))) !=
            nothing
    end
end

@testset "Multiline validator" begin
    regex = re"(>[a-z]+\n)+"
    eval(Automa.generate_io_validator(:io_bar_2, regex; goto=false))
    eval(Automa.generate_io_validator(:io_foo_2, regex; goto=true))

    let data = ">abc"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (nothing, (1, 4))
    end

    let data = ">abc:a"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (UInt8(':'), (1, 5))
    end

    let data = ">"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (nothing, (1, 1))
    end

    let data = ""
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (nothing, (1, 0))
    end

    let data = ">abc\n>def\n>ghi\n>j!"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (UInt8('!'), (4, 3))
    end

    let data = ">abc\n;"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (UInt8(';'), (2, 1))
    end 
end

@testset "Report column or not" begin
    regex = re"[a-z]+"
    eval(Automa.generate_io_validator(:io_foo_3, regex; goto=false, report_col=true))
    eval(Automa.generate_io_validator(:io_bar_3, regex; goto=false, report_col=false))

    let data = "abc;"
        @test io_foo_3(IOBuffer(data)) == (UInt8(';'), (1, 4))
        @test io_bar_3(IOBuffer(data)) == (UInt8(';'), 1)
    end

    # Test that, if `report_col` is not set, very long lines are not
    # buffered (because the mark is not set).
    let data = repeat("abcd", 100_000) * ';'
        io = NoopStream(IOBuffer(data))
        @test length(io.state.buffer1.data) < 100_000
    end
end

end # module