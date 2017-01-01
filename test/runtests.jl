module Test1
    using Automa
    using Base.Test

    re = re""

    re.actions[:enter] = [:enter_re]
    re.actions[:exit] = [:exit_re]

    machine = compile(re, actions=:debug)
    init_code = generate_init(machine)
    exec_code = generate_exec(machine)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs ∈ $(machine.accept_states), logger
    end

    @test validate(b"") == (true, [:enter_re, :exit_re])
    @test validate(b"a") == (false, Symbol[])

    # inlined code
    exec_code = generate_exec(machine, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs ∈ $(machine.accept_states), logger
    end
    @test validate2(b"") == (true, [:enter_re, :exit_re])
    @test validate2(b"a") == (false, Symbol[])
end

module Test2
    using Automa
    using Base.Test

    a = rep(re"a")
    b = cat(re"b", rep(re"b"))
    re = cat(a, b)

    a.actions[:enter] = [:enter_a]
    a.actions[:exit] = [:exit_a]
    b.actions[:enter] = [:enter_b]
    b.actions[:exit] = [:exit_b]
    re.actions[:enter] = [:enter_re]
    re.actions[:exit] = [:exit_re]

    machine = compile(re, actions=:debug)
    init_code = generate_init(machine)
    exec_code = generate_exec(machine)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs ∈ $(machine.accept_states), logger
    end

    @test validate(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:exit_re,:exit_b])
    @test validate(b"a") == (false, [:enter_re,:enter_a])
    @test validate(b"ab") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:exit_re,:exit_b])
    @test validate(b"abb") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:exit_re,:exit_b])

    # inlined code
    exec_code = generate_exec(machine, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs ∈ $(machine.accept_states), logger
    end
    @test validate2(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:exit_re,:exit_b])
    @test validate2(b"a") == (false, [:enter_re,:enter_a])
    @test validate2(b"ab") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:exit_re,:exit_b])
    @test validate2(b"abb") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:exit_re,:exit_b])
end

module Test3
    using Automa
    using Base.Test

    header = re"[ -~]*"
    newline = re"\r?\n"
    sequence = rep(cat(re"[A-Za-z]*", newline))
    fasta = rep(cat(re">", header, newline, sequence))

    machine = compile(fasta)
    init_code = generate_init(machine)
    exec_code = generate_exec(machine)

    @eval function validate(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs ∈ $(machine.accept_states)
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

    exec_code = generate_exec(machine, code=:inline)
    @eval function validate2(data)
        $(init_code)
        p_end = p_eof = endof(data)
        $(exec_code)
        return cs ∈ $(machine.accept_states)
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
end
