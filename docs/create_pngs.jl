using Automa

DIR = joinpath(dirname(dirname(Base.pathof(Automa))), "docs/src/figure")
ispath(DIR) || mkdir(DIR)

function regex_png(regex, path)
    open("/tmp/re.dot", "w") do io
        println(io, Automa.nfa2dot(Automa.re2nfa(regex)))
    end
    run(pipeline(`dot -Tpng /tmp/re.dot`, stdout=path))
end

function dot_png(dot, path)
    open("/tmp/re.dot", "w") do io
        println(io, dot)
    end
    run(pipeline(`dot -Tpng /tmp/re.dot`, stdout=path))
end    

regex_png(re"a", "$DIR/simple.png")
regex_png(re"(\+|-)?(0|1)*", "$DIR/larger.png")

dot = """
digraph {
  graph [ rankdir = LR ];
  A [ shape = circle ];
 A -> B [ label = "ϵ" ];
  B [ shape = doublecircle ];
}
"""

dot_png(dot, "$DIR/cat.png")

dot = """
digraph {
  graph [ rankdir = LR ];
  A [ shape = circle ];
  B [ shape = circle ];
  1 [ shape = circle ];
  2 [ shape = doublecircle ];
  1 -> A [ label = "ϵ" ];
  1 -> B [ label = "ϵ" ];
  A -> 2 [ label = "ϵ" ];
  B -> 2 [ label = "ϵ" ];
}
"""

dot_png(dot, "$DIR/alt.png")

dot = """
digraph {
  graph [ rankdir = LR ];
  A [ shape = circle ];
  1 [ shape = circle ];
  2 [ shape = doublecircle ];
  1 -> A [ label = "ϵ" ];
  1 -> 2 [ label = "ϵ" ];
  A -> 2 [ label = "ϵ" ];
  A -> A [ label = "ϵ" ];
}
"""

dot_png(dot, "$DIR/kleenestar.png")

open("/tmp/re.dot", "w") do io
    nfa = Automa.re2nfa(re"(\+|-)?(0|1)*")
    dfa = Automa.nfa2dfa(nfa)
    println(io, Automa.dfa2dot(dfa))
end
run(pipeline(`dot -Tpng /tmp/re.dot`, stdout="$DIR/large_dfa.png"))

open("/tmp/re.dot", "w") do io
    machine = compile(re"(\+|-)?(0|1)*")
    println(io, Automa.machine2dot(machine))
end
run(pipeline(`dot -Tpng /tmp/re.dot`, stdout="$DIR/large_machine.png"))
