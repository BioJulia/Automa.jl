using Automa
using Automa.RegExp: @re_str
const re = Automa.RegExp

ab = re"ab*"
ab.when = :cond
c = re"c"
pattern = re.cat(ab, c)

write("preconditions.dot", Automa.machine2dot(Automa.compile(pattern)))
run(`dot -Tpng -o src/figure/preconditions.png preconditions.dot`)
