using Automa
using Automa.RegExp
const re = Automa.RegExp

a = re"a*"
b = re"b"

a.actions[:enter] = [:enter_a]
a.actions[:exit]  = [:exit_a]
a.actions[:final] = [:final_a]
b.actions[:enter] = [:enter_b]
b.actions[:exit]  = [:exit_b]
b.actions[:final] = [:final_b]

write("actions.dot", Automa.dfa2dot(compile(a * b).dfa))
run(`dot -Tpng -o figure/actions.png actions.dot`)
