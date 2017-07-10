using Base.Test
import Automa
import Automa.RegExp: @re_str

@testset "SizedMemory" begin
    # Vector{UInt8}
    mem = Automa.SizedMemory(b"bar")
    @test endof(mem) === length(mem) === 3
    @test mem[1] === UInt8('b')
    @test mem[2] === UInt8('a')
    @test mem[3] === UInt8('r')
    @test_throws BoundsError mem[0]
    @test_throws BoundsError mem[4]

    # String
    mem = Automa.SizedMemory("bar")
    @test endof(mem) === length(mem) === 3
    @test mem[1] === UInt8('b')
    @test mem[2] === UInt8('a')
    @test mem[3] === UInt8('r')
    @test_throws BoundsError mem[0]
    @test_throws BoundsError mem[4]

    # SubString
    mem = Automa.SizedMemory(SubString("xbar", 2, 4))
    @test endof(mem) === length(mem) === 3
    @test mem[1] === UInt8('b')
    @test mem[2] === UInt8('a')
    @test mem[3] === UInt8('r')
    @test_throws BoundsError mem[0]
    @test_throws BoundsError mem[4]
end

@testset "DOT" begin
    re = re"[A-Za-z_][A-Za-z0-9_]*"
    re.actions[:enter] = [:enter]
    re.actions[:exit]  = [:exit]
    nfa = Automa.re2nfa(re)
    @test startswith(Automa.nfa2dot(nfa), "digraph")
    dfa = Automa.nfa2dfa(nfa)
    @test startswith(Automa.dfa2dot(dfa), "digraph")
    machine = Automa.compile(re)
    @test startswith(Automa.machine2dot(machine), "digraph")
    @test ismatch(r"^Automa\.NFANode\(.*\)$", repr(nfa.start))
    @test ismatch(r"^Automa\.DFANode\(.*\)$", repr(dfa.start))
    @test ismatch(r"^Automa\.Node\(.*\)$", repr(machine.start))
end

include("test01.jl")
include("test02.jl")
include("test03.jl")
include("test04.jl")
include("test05.jl")
include("test06.jl")
include("test07.jl")
include("test08.jl")
include("test09.jl")
include("test10.jl")
include("test11.jl")
include("test12.jl")
include("test13.jl")
include("test14.jl")
include("test15.jl")

module Test1
    import Automa
    import Automa.RegExp: @re_str
    using Base.Test

    re = re""

    re.actions[:enter] = [:enter_re]
    re.actions[:exit] = [:exit_re]

    machine = Automa.compile(re)
    @test ismatch(r"^Automa.Machine\(<.*>\)$", repr(machine))

    last, actions = Automa.execute(machine, "")
    @test last == 0
    @test actions == [:enter_re, :exit_re]
    last, actions = Automa.execute(machine, "a")
    @test last < 0
    @test actions == []

    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine, actions=:debug)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end

    @test validate(b"") == (true, [:enter_re, :exit_re])
    @test validate(b"a") == (false, Symbol[])

    # inlined code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate2(b"") == (true, [:enter_re, :exit_re])
    @test validate2(b"a") == (false, Symbol[])

    # goto code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:goto)
    @eval function validate3(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate3(b"") == (true, [:enter_re, :exit_re])
    @test validate3(b"a") == (false, Symbol[])
end

module Test2
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    a = re.rep('a')
    b = re.cat('b', re.rep('b'))
    ab = re.cat(a, b)

    a.actions[:enter] = [:enter_a]
    a.actions[:exit] = [:exit_a]
    a.actions[:final] = [:final_a]
    b.actions[:enter] = [:enter_b]
    b.actions[:exit] = [:exit_b]
    b.actions[:final] = [:final_b]
    ab.actions[:enter] = [:enter_re]
    ab.actions[:exit] = [:exit_re]
    ab.actions[:final] = [:final_re]

    machine = Automa.compile(ab)

    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re]

    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine, actions=:debug)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end

    @test validate(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate(b"a") == (false, [:enter_re,:enter_a,:final_a])
    @test validate(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])

    # inlined code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate2(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate2(b"a") == (false, [:enter_re,:enter_a,:final_a])
    @test validate2(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate2(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])

    # goto code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:goto)
    @eval function validate3(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate3(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate3(b"a") == (false, [:enter_re,:enter_a,:final_a])
    @test validate3(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate3(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])
end

module Test3
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    header = re"[ -~]*"
    newline = re"\r?\n"
    sequence = re.rep(re.cat(re"[A-Za-z]*", newline))
    fasta = re.rep(re.cat('>', header, newline, sequence))

    machine = Automa.compile(fasta)
    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine)

    @eval function validate(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0
    end

    @test validate(b"") == true
    @test validate(b">\naa\n") == true
    @test validate(b">seq1\n") == true
    @test validate(b">seq1\na\n") == true
    @test validate(b">seq1\nac\ngt\n") == true
    @test validate(b">seq1\r\nacgt\r\n") == true
    @test validate(b">seq1\nac\n>seq2\ngt\n") == true
    @test validate(b"a") == false
    @test validate(b">") == false
    @test validate(b">seq1\na") == false
    @test validate(b">seq1\nac\ngt") == false

    exec_code = Automa.generate_exec_code(machine, code=:inline)
    @eval function validate2(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0
    end
    @test validate2(b"") == true
    @test validate2(b">\naa\n") == true
    @test validate2(b">seq1\n") == true
    @test validate2(b">seq1\na\n") == true
    @test validate2(b">seq1\nac\ngt\n") == true
    @test validate2(b">seq1\r\nacgt\r\n") == true
    @test validate2(b">seq1\nac\n>seq2\ngt\n") == true
    @test validate2(b"a") == false
    @test validate2(b">") == false
    @test validate2(b">seq1\na") == false
    @test validate2(b">seq1\nac\ngt") == false

    exec_code = Automa.generate_exec_code(machine, code=:goto)
    @eval function validate3(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0
    end
    @test validate3(b"") == true
    @test validate3(b">\naa\n") == true
    @test validate3(b">seq1\n") == true
    @test validate3(b">seq1\na\n") == true
    @test validate3(b">seq1\nac\ngt\n") == true
    @test validate3(b">seq1\r\nacgt\r\n") == true
    @test validate3(b">seq1\nac\n>seq2\ngt\n") == true
    @test validate3(b"a") == false
    @test validate3(b">") == false
    @test validate3(b">seq1\na") == false
    @test validate3(b">seq1\nac\ngt") == false
end

module Test4
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    beg_a = re.cat('a', re"[ab]*")
    end_b = re.cat(re"[ab]*", 'b')
    beg_a_end_b = re.isec(beg_a, end_b)

    machine = Automa.compile(beg_a_end_b)
    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine)

    @eval function validate(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0
    end

    @test validate(b"") == false
    @test validate(b"a") == false
    @test validate(b"aab") == true
    @test validate(b"ab") == true
    @test validate(b"aba") == false
    @test validate(b"abab") == true
    @test validate(b"abb") == true
    @test validate(b"abbb") == true
    @test validate(b"b") == false
    @test validate(b"bab") == false

    exec_code = Automa.generate_exec_code(machine, code=:inline)
    @eval function validate2(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0
    end
    @test validate2(b"") == false
    @test validate2(b"a") == false
    @test validate2(b"aab") == true
    @test validate2(b"ab") == true
    @test validate2(b"aba") == false
    @test validate2(b"abab") == true
    @test validate2(b"abb") == true
    @test validate2(b"abbb") == true
    @test validate2(b"b") == false
    @test validate2(b"bab") == false

    exec_code = Automa.generate_exec_code(machine, code=:goto)
    @eval function validate3(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0
    end
    @test validate3(b"") == false
    @test validate3(b"a") == false
    @test validate3(b"aab") == true
    @test validate3(b"ab") == true
    @test validate3(b"aba") == false
    @test validate3(b"abab") == true
    @test validate3(b"abb") == true
    @test validate3(b"abbb") == true
    @test validate3(b"b") == false
    @test validate3(b"bab") == false
end

module Test5
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    keyword = re"if|else|end|while"
    ident = re.diff(re"[a-z]+", keyword)
    token = re.alt(keyword, ident)

    keyword.actions[:exit] = [:keyword]
    ident.actions[:exit] = [:ident]

    machine = Automa.compile(token)
    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine, actions=:debug)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end

    @test validate(b"if") == (true, [:keyword])
    @test validate(b"else") == (true, [:keyword])
    @test validate(b"end") == (true, [:keyword])
    @test validate(b"while") == (true, [:keyword])
    @test validate(b"e") == (true, [:ident])
    @test validate(b"eif") == (true, [:ident])
    @test validate(b"i") == (true, [:ident])
    @test validate(b"iff") == (true, [:ident])
    @test validate(b"1if") == (false, [])

    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate2(b"if") == (true, [:keyword])
    @test validate2(b"else") == (true, [:keyword])
    @test validate2(b"end") == (true, [:keyword])
    @test validate2(b"while") == (true, [:keyword])
    @test validate2(b"e") == (true, [:ident])
    @test validate2(b"eif") == (true, [:ident])
    @test validate2(b"i") == (true, [:ident])
    @test validate2(b"iff") == (true, [:ident])
    @test validate2(b"1if") == (false, [])

    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:goto)
    @eval function validate3(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate3(b"if") == (true, [:keyword])
    @test validate3(b"else") == (true, [:keyword])
    @test validate3(b"end") == (true, [:keyword])
    @test validate3(b"while") == (true, [:keyword])
    @test validate3(b"e") == (true, [:ident])
    @test validate3(b"eif") == (true, [:ident])
    @test validate3(b"i") == (true, [:ident])
    @test validate3(b"iff") == (true, [:ident])
    @test validate3(b"1if") == (false, [])
end

module Test6
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    foo = re.cat("foo")
    foos = re.rep(re.cat(foo, re" *"))
    foo.actions[:exit]  = [:foo]
    actions = Dict(:foo => :(push!(ret, state.p:p-1); @escape))
    machine = Automa.compile(foos)

    @eval type MachineState
        p::Int
        cs::Int
        function MachineState()
            $(Automa.generate_init_code(machine))
            return new(p, cs)
        end
    end

    @eval function run!(state, data)
        ret = []
        p = state.p
        cs = state.cs
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine, actions=actions))
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

    @eval function run2!(state, data)
        ret = []
        p = state.p
        cs = state.cs
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine, actions=actions, code=:inline))
        state.p = p
        state.cs = cs
        return ret
    end
    state = MachineState()
    @test run2!(state, data) == [1:3]
    @test run2!(state, data) == [5:7]
    @test run2!(state, data) == [9:10]
    @test run2!(state, data) == [12:16]
    @test run2!(state, data) == []
    @test run2!(state, data) == []

    @eval function run3!(state, data)
        ret = []
        p = state.p
        cs = state.cs
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine, actions=actions, code=:goto))
        state.p = p
        state.cs = cs
        return ret
    end
    state = MachineState()
    @test run3!(state, data) == [1:3]
    @test run3!(state, data) == [5:7]
    @test run3!(state, data) == [9:10]
    @test run3!(state, data) == [12:16]
    @test run3!(state, data) == []
    @test run3!(state, data) == []
end

module Test7
    import Automa
    import Automa.RegExp: @re_str
    using Base.Test

    re1 = re"a.*b"
    machine = Automa.compile(re1)
    @eval function ismatch1(data)
        $(Automa.generate_init_code(machine))
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine))
        return cs == 0
    end
    @test ismatch1(b"ab")
    @test ismatch1(b"azb")
    @test ismatch1(b"azzzb")
    @test !ismatch1(b"azzz")
    @test !ismatch1(b"zzzb")

    re2 = re"a\.*b"
    machine = Automa.compile(re2)
    @eval function ismatch2(data)
        $(Automa.generate_init_code(machine))
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine))
        return cs == 0
    end
    @test ismatch2(b"ab")
    @test ismatch2(b"a.b")
    @test ismatch2(b"a...b")
    @test !ismatch2(b"azzzb")
    @test !ismatch2(b"a...")
    @test !ismatch2(b"...b")

    re3 = re"a\.\*b"
    machine = Automa.compile(re3)
    @eval function ismatch3(data)
        $(Automa.generate_init_code(machine))
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine))
        return cs == 0
    end
    @test ismatch3(b"a.*b")
    @test !ismatch3(b"a...b")
end

module Test8
    import Automa
    import Automa.RegExp: @re_str
    using Base.Test
    const re = Automa.RegExp

    int = re"[-+]?[0-9]+"
    prefloat = re"[-+]?([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)"
    float = prefloat | re.cat(prefloat | re"[-+]?[0-9]+", re"[eE][-+]?[0-9]+")
    number = int | float
    spaces = re.rep(re.space())
    numbers = re.cat(re.opt(spaces * number), re.rep(re.space() * spaces * number), spaces)

    number.actions[:enter] = [:mark]
    int.actions[:exit]     = [:int]
    float.actions[:exit]   = [:float]

    machine = Automa.compile(numbers)

    actions = Dict(
        :mark  => :(mark = p),
        :int   => :(push!(tokens, (:int, data[mark:p-1]))),
        :float => :(push!(tokens, (:float, data[mark:p-1]))),
    )

    @eval function tokenize(data)
        tokens = Tuple{Symbol,String}[]
        mark = 0
        $(Automa.generate_init_code(machine))
        p_end = p_eof = endof(data)
        $(Automa.generate_exec_code(machine, actions=actions))
        return tokens, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end

    @test tokenize(b"") == ([], :ok)
    @test tokenize(b"  ") == ([], :ok)
    @test tokenize(b"42") == ([(:int, "42")], :ok)
    @test tokenize(b"3.14") == ([(:float, "3.14")], :ok)
    @test tokenize(b"1 -42 55") == ([(:int, "1"), (:int, "-42"), (:int, "55")], :ok)
    @test tokenize(b"12. -22. .1 +10e12") == ([(:float, "12."), (:float, "-22."), (:float, ".1"), (:float, "+10e12")], :ok)
    @test tokenize(b" -3 -1.2e-3  +54 1.E2  ") == ([(:int, "-3"), (:float, "-1.2e-3"), (:int, "+54"), (:float, "1.E2")], :ok)

    @test tokenize(b"e") == ([], :error)
    @test tokenize(b"42,") == ([], :error)
    @test tokenize(b"42 ,") == ([(:int, "42")], :error)

    @test tokenize(b".") == ([], :incomplete)
    @test tokenize(b"1e") == ([], :incomplete)
    @test tokenize(b"1e-") == ([], :incomplete)
end

module Test9
    import Automa
    import Automa.RegExp: @re_str
    using Base.Test
    const re = Automa.RegExp

    tokenizer = Automa.compile(
        re"a"      => :(emit(:a, ts:te)),
        re"a*b"    => :(emit(:ab, ts:te)),
    )

    @eval function tokenize(data)
        $(Automa.generate_init_code(tokenizer))
        p_end = p_eof = sizeof(data)
        tokens = Tuple{Symbol,String}[]
        emit(kind, range) = push!(tokens, (kind, data[range]))
        while p ≤ p_eof && cs > 0
            $(Automa.generate_exec_code(tokenizer))
        end
        if cs < 0
            error()
        end
        return tokens
    end

    @test tokenize("") == []
    @test tokenize("a") == [(:a, "a")]
    @test tokenize("b") == [(:ab, "b")]
    @test tokenize("aa") == [(:a, "a"), (:a, "a")]
    @test tokenize("ab") == [(:ab, "ab")]
    @test tokenize("aaa") == [(:a, "a"), (:a, "a"), (:a, "a")]
    @test tokenize("aab") == [(:ab, "aab")]
    @test tokenize("abaabba") == [(:ab, "ab"), (:ab, "aab"), (:ab, "b"), (:a, "a")]
    @test_throws ErrorException tokenize("c")
    @test_throws ErrorException tokenize("ac")
    @test_throws ErrorException tokenize("abc")
    @test_throws ErrorException tokenize("acb")
end

module Test10
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

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

module Test11
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    a = re"[a-z]"
    a.when = :le
    a = re.rep1(a)
    a.actions[:exit] = [:one]
    b = re"[a-z][a-z0-9]*"
    b.actions[:exit] = [:two]

    machine = Automa.compile(re.cat(a | b, '\n'))
    actions = Dict(
        :one => :(push!(logger, :one)),
        :two => :(push!(logger, :two)),
        :le  => :(p ≤ n))

    @test_throws ErrorException Automa.generate_exec_code(machine, actions=actions, code=:table)

    @eval function validate1(data, n)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=actions, code=:inline))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end

    @test validate1(b"a\n", 0) == ([:two], :ok)
    @test validate1(b"a\n", 1) == ([:one, :two], :ok)
    @test validate1(b"a1\n", 1) == ([:two], :ok)
    @test validate1(b"aa\n", 1) == ([:two], :ok)
    @test validate1(b"aa1\n", 1) == ([:two], :ok)
    @test validate1(b"aa\n", 2) == ([:one, :two], :ok)
    @test validate1(b"aa1\n", 2) == ([:two], :ok)
    @test validate1(b"1\n", 1) == ([], :error)

    @eval function validate2(data, n)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=actions, code=:goto))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end

    @test validate2(b"a\n", 0) == ([:two], :ok)
    @test validate2(b"a\n", 1) == ([:one, :two], :ok)
    @test validate2(b"a1\n", 1) == ([:two], :ok)
    @test validate2(b"aa\n", 1) == ([:two], :ok)
    @test validate2(b"aa1\n", 1) == ([:two], :ok)
    @test validate2(b"aa\n", 2) == ([:one, :two], :ok)
    @test validate2(b"aa1\n", 2) == ([:two], :ok)
    @test validate2(b"1\n", 1) == ([], :error)
end

module Test12
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    a = re"a*"
    a.actions[:all] = [:a]
    machine = Automa.compile(a)

    @eval function validate(data)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=:debug))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end

    @test validate(b"") == ([], :ok)
    @test validate(b"a") == ([:a], :ok)
    @test validate(b"aa") == ([:a, :a], :ok)
    @test validate(b"aaa") == ([:a, :a, :a], :ok)
    @test validate(b"aaab") == ([:a, :a, :a], :error)
end

module Test13
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    abra = re"abra"
    ca = re"(ca)+"
    ca.actions[:enter] = [:ca_enter]
    ca.actions[:exit] = [:ca_exit]
    dabra = re"dabra"
    machine = Automa.compile(re.cat(abra, ca, dabra))
    @eval function validate(data)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=:debug, code=:inline, clean=true))
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

module Test14
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    using Base.Test

    a = re"a*"
    machine = Automa.compile(a)
    @eval function validate_table(data)
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, code=:table))
        return p, cs
    end
    @eval function validate_inline(data)
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, code=:inline))
        return p, cs
    end
    @eval function validate_goto(data)
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, code=:goto))
        return p, cs
    end

    @test validate_table(b"")   == validate_inline(b"")   == validate_goto(b"")
    @test validate_table(b"a")  == validate_inline(b"a")  == validate_goto(b"a")
    @test validate_table(b"b")  == validate_inline(b"b")  == validate_goto(b"b")
    @test validate_table(b"ab") == validate_inline(b"ab") == validate_goto(b"ab")
end

module Test15
    import Automa
    import Automa.RegExp: @re_str
    using Base.Test

    a = re"a+"
    a.actions[:enter] = [:enter]
    a.actions[:all]   = [:all]
    a.actions[:final] = [:final]
    a.actions[:exit]  = [:exit]
    b = re"b+"
    b.actions[:enter] = [:enter]
    b.actions[:all]   = [:all]
    b.actions[:final] = [:final]
    b.actions[:exit]  = [:exit]
    ab = Automa.RegExp.cat(a, b)

    machine = Automa.compile(ab)
    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter, :all, :final, :exit, :enter, :all, :final, :exit]

    @eval function validate1(data)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=:debug, code=:table))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end
    @test validate1(b"ab") == ([:enter, :all, :final, :exit, :enter, :all, :final, :exit], :ok)

    @eval function validate2(data)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=:debug, code=:table))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end
    @test validate2(b"ab") == ([:enter, :all, :final, :exit, :enter, :all, :final, :exit], :ok)

    @eval function validate3(data)
        logger = Symbol[]
        $(Automa.generate_init_code(machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(machine, actions=:debug, code=:goto))
        return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
    end
    @test validate3(b"ab") == ([:enter, :all, :final, :exit, :enter, :all, :final, :exit], :ok)
end

module TestFASTA
    include("../example/fasta.jl")
    using Base.Test
    @test records[1].identifier == "NP_003172.1"
    @test records[1].description == "brachyury protein isoform 1 [Homo sapiens]"
    @test records[1].sequence[1:5] == b"MSSPG"
    @test records[1].sequence[end-4:end] == b"SPPSM"
end

module TestFASTQ
    include("../example/fastq.jl")
    using Base.Test
    @test length(records) == 2
    r1 = records[1]
    @test r1.seqlen == 102
    @test String(r1.data[r1.identifier]) == "SRR1238088.23.1"
    @test String(r1.data[r1.description]) == "HWI-ST499:111:D0G94ACXX:1:1101:6631:2166 length=102"
    @test String(r1.data[r1.sequence]) == "AAAGCGTTCTCTTCCGTCAGCCTTCTTCCGCTTCTGTCGTCCTCCGCAACCGTGCCACCTCCCTCACCGTCCGTGCCGCTTCCTCCTACGCCGATGAGCTTC"
    @test String(r1.data[r1.quality]) == "CCCFFFFFHHHHHJIJIJJJJJJJJJJJJJJJJJJJIJJJJIJJJJJJJJJJHHHFFFFFEDDEDDDDDDDDDBDBBDDDDDDDDDDDDDDDDDDDDDDDDC"
    r2 = records[2]
    @test r2.seqlen == 102
    @test String(r2.data[r2.identifier]) == "SRR1238088.24.1"
    @test String(r2.data[r2.description]) == "HWI-ST499:111:D0G94ACXX:1:1101:6860:2182 length=102"
    @test String(r2.data[r2.sequence]) == "GGAGGATACAGCGGCGGCGGCGGCGGTTACTCCTCAAGAGGTGGTGGTGGCGGAAGCTACGGTGGTGGAAGACGTGAGGGAGGAGGAGGATACGGTGGTGGC"
    @test String(r2.data[r2.quality]) == "CCCFFFFFHHHGHJJJJJJFDDDDBDBDBCACDCDCDC8AB>AD5?@7@DDDDBDDDDCDDD3<@0<@ACDBCB<<ABDD9@D<<@8?D?9::?B3?B5?BC"
end

module TestNumbers
    include("../example/numbers.jl")
    using Base.Test
    @test tokens == [(:dec,"1"),(:hex,"0x0123BEEF"),(:oct,"0o754"),(:float,"3.14"),(:float,"-1e4"),(:float,"+6.022045e23")]
    @test status == :ok
    @test startswith(Automa.machine2dot(machine), "digraph")
end

module TestTokenizer
    include("../example/tokenizer.jl")
    using Base.Test
    @test tokens[1:14] == [
        (:identifier,"quicksort"),
        (:lparen,"("),
        (:identifier,"xs"),
        (:rparen,")"),
        (:spaces," "),
        (:equal,"="),
        (:spaces," "),
        (:identifier,"quicksort!"),
        (:lparen,"("),
        (:identifier,"copy"),
        (:lparen,"("),
        (:identifier,"xs"),
        (:rparen,")"),
        (:rparen,")")]
    @test tokens[end-5:end] == [
        (:keyword,"return"),
        (:spaces," "),
        (:identifier,"j"),
        (:newline,"\n"),
        (:keyword,"end"),
        (:newline,"\n")]
end
