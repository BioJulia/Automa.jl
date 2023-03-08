 using SnoopPrecompile: @precompile_all_calls

@precompile_all_calls begin
let
    goto_ctx = CodeGenContext(generator=:goto)
    table_ctx = CodeGenContext(generator=:table)
        
    # Create a buffer validator
    regex = let
        name = onexit!(onenter!(re"[^\t\r\n]+", :mark), :name)
        field = onexit!(onenter!(re"[^\t\r\n]+", :mark), :field)
        nameline = name * rep('\t' * name)
        record = onexit!(field * rep('\t' * field), :record)
        nameline * re"\r?\n" * record * rep(re"\r?\n" * record) * rep(re"\r?\n")
    end
    generate_buffer_validator(:foo, regex; goto=true)
    generate_buffer_validator(:foo, regex; goto=false)

    # Create an ordinary parser
    machine = compile(regex)
    actions = Dict(
        :mark => :(pos = p),
        :name => :(push!(headers, String(data[pos:p-1]))),
        :field => quote
            n_fields += 1
            push!(fields, String(data[pos:p-1]))
        end,
        :record => quote
            n_fields == length(headers) || error("Malformed TSV")
            n_fields = 0
        end
    )

    generate_code(goto_ctx, machine, actions)
    generate_code(table_ctx, machine, actions)

    # Create a tokenizer
    tokens = [
        re"[A-Za-z_][0-9A-Za-z_!]*!",
        re"\(",
        re"\)",
        re",",
        re"abc",
        re"\"",
        re"[\t\f ]+",
    ];
    make_tokenizer(tokens; goto=true)
    make_tokenizer(tokens; goto=false)
end
end
