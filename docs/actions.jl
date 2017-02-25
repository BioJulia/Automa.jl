using Automa
using Automa.RegExp: @re_str
const re = Automa.RegExp

ab = re"ab*"
c = re"c"
pattern = re.cat(ab, c)

ab.actions[:enter] = [:enter_ab]
ab.actions[:exit]  = [:exit_ab]
ab.actions[:all]   = [:all_ab]
ab.actions[:final] = [:final_ab]
c.actions[:enter]  = [:enter_c]
c.actions[:exit]   = [:exit_c]
c.actions[:final]  = [:final_c]

write("actions.dot", Automa.machine2dot(Automa.compile(pattern)))
run(`dot -Tpng -o src/figure/actions.png actions.dot`)
