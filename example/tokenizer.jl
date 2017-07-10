import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp

keyword = re"break|const|continue|else|elseif|end|for|function|if|return|type|using|while"
identifier = re"[A-Za-z_][0-9A-Za-z_!]*"
operator = re"-|\+|\*|/|%|&|\||^|!|~|>|<|<<|>>|>=|<=|=>|==|==="
macrocall = re"@" * re"[A-Za-z_][0-9A-Za-z_!]*"
comment = re"#[^\r\n]*"
char = re.cat('\'', re"[ -&(-~]" | re.cat('\\', re"[ -~]"), '\'')
string = re.cat('"', re.rep(re"[ !#-~]" | re.cat("\\\"")), '"')
triplestring = re.cat("\"\"\"", (re"[ -~]*" \ re"\"\"\""), "\"\"\"")
newline = re"\r?\n"

const minijulia = Automa.compile(
    re","          => :(emit(:comma)),
    re":"          => :(emit(:colon)),
    re";"          => :(emit(:semicolon)),
    re"\."         => :(emit(:dot)),
    re"\?"         => :(emit(:question)),
    re"="          => :(emit(:equal)),
    re"\("         => :(emit(:lparen)),
    re"\)"         => :(emit(:rparen)),
    re"\["         => :(emit(:lbracket)),
    re"]"          => :(emit(:rbracket)),
    re"{"          => :(emit(:lbrace)),
    re"}"          => :(emit(:rbrace)),
    re"$"          => :(emit(:dollar)),
    re"&&"         => :(emit(:and)),
    re"\|\|"       => :(emit(:or)),
    re"::"         => :(emit(:typeannot)),
    keyword        => :(emit(:keyword)),
    identifier     => :(emit(:identifier)),
    operator       => :(emit(:operator)),
    macrocall      => :(emit(:macrocall)),
    re"[0-9]+"     => :(emit(:integer)),
    comment        => :(emit(:comment)),
    char           => :(emit(:char)),
    string         => :(emit(:string)),
    triplestring   => :(emit(:triplestring)),
    newline        => :(emit(:newline)),
    re"[\t ]+"     => :(emit(:spaces)),
)

#=
write("minijulia.dot", Automa.machine2dot(minijulia.machine))
run(`dot -Tsvg -o minijulia.svg minijulia.dot`)
=#

context = Automa.CodeGenContext()
@eval function tokenize(data)
    $(Automa.generate_init_code(context, minijulia))
    p_end = p_eof = sizeof(data)
    tokens = Tuple{Symbol,String}[]
    emit(kind) = push!(tokens, (kind, data[ts:te]))
    while p ≤ p_eof && cs > 0
        $(Automa.generate_exec_code(context, minijulia))
    end
    if cs < 0
        error("failed to tokenize")
    end
    return tokens
end

tokens = tokenize("""
quicksort(xs) = quicksort!(copy(xs))
quicksort!(xs) = quicksort!(xs, 1, length(xs))

function quicksort!(xs, lo, hi)
    if lo < hi
        p = partition(xs, lo, hi)
        quicksort!(xs, lo, p - 1)
        quicksort!(xs, p + 1, hi)
    end
    return xs
end

function partition(xs, lo, hi)
    pivot = div(lo + hi, 2)
    pvalue = xs[pivot]
    xs[pivot], xs[hi] = xs[hi], xs[pivot]
    j = lo
    @inbounds for i in lo:hi-1
        if xs[i] <= pvalue
            xs[i], xs[j] = xs[j], xs[i]
            j += 1
        end
    end
    xs[j], xs[hi] = xs[hi], xs[j]
    return j
end
""")
