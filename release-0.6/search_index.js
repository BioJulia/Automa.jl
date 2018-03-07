var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Automa.jl-1",
    "page": "Home",
    "title": "Automa.jl",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#Overview-1",
    "page": "Home",
    "title": "Overview",
    "category": "section",
    "text": "Automa.jl is a package for generating finite-state machines (FSMs) and tokenizers in Julia.The following code is an example of tokenizing various kinds of numeric literals in Julia.import Automa\nimport Automa.RegExp: @re_str\nconst re = Automa.RegExp\n\n# Describe patterns in regular expression.\noct      = re\"0o[0-7]+\"\ndec      = re\"[-+]?[0-9]+\"\nhex      = re\"0x[0-9A-Fa-f]+\"\nprefloat = re\"[-+]?([0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+)\"\nfloat    = prefloat | re.cat(prefloat | re\"[-+]?[0-9]+\", re\"[eE][-+]?[0-9]+\")\nnumber   = oct | dec | hex | float\nnumbers  = re.cat(re.opt(number), re.rep(re\" +\" * number), re\" *\")\n\n# Register action names to regular expressions.\nnumber.actions[:enter] = [:mark]\noct.actions[:exit]     = [:oct]\ndec.actions[:exit]     = [:dec]\nhex.actions[:exit]     = [:hex]\nfloat.actions[:exit]   = [:float]\n\n# Compile a finite-state machine.\nmachine = Automa.compile(numbers)\n\n# This generates a SVG file to visualize the state machine.\n# write(\"numbers.dot\", Automa.machine2dot(machine))\n# run(`dot -Tpng -o numbers.png numbers.dot`)\n\n# Bind an action code for each action name.\nactions = Dict(\n    :mark  => :(mark = p),\n    :oct   => :(emit(:oct)),\n    :dec   => :(emit(:dec)),\n    :hex   => :(emit(:hex)),\n    :float => :(emit(:float)),\n)\n\n# Generate a tokenizing function from the machine.\ncontext = Automa.CodeGenContext()\n@eval function tokenize(data::String)\n    tokens = Tuple{Symbol,String}[]\n    mark = 0\n    $(Automa.generate_init_code(context, machine))\n    p_end = p_eof = lastindex(data)\n    emit(kind) = push!(tokens, (kind, data[mark:p-1]))\n    $(Automa.generate_exec_code(context, machine, actions))\n    return tokens, cs == 0 ? :ok : cs < 0 ? :error : :incomplete\nend\n\ntokens, status = tokenize(\"1 0x0123BEEF 0o754 3.14 -1e4 +6.022045e23\")Finally, space-separated numbers are tokenized as follows:julia> tokens\n6-element Array{Tuple{Symbol,String},1}:\n (:dec,\"1\")\n (:hex,\"0x0123BEEF\")\n (:oct,\"0o754\")\n (:float,\"3.14\")\n (:float,\"1e-4\")\n (:float,\"+6.022045e23\")\n\njulia> status\n:ok\n(Image: )Automa.jl is composed of three elements: regular expressions, compilers, and code generators. Regular expressions are used to specify patterns that you want to match and bind actions to. A regular expression can be built using APIs provided from the Automa.RegExp module. The regular expression with actions is then fed to a compiler function that creates a finite state machine and optimizes it to minimize the number of states. Finally, the machine object is used to generate Julia code that can be spliced into functions.Machines are byte-oriented in a sense that input data fed into a machine is a sequence of bytes. The generated code of a machine reads input data byte by byte and updates a current state variable based on transition rules defined by regular expressions. If one or more actions are associated to a state transition they will be executed before reading a next byte. If no transition rule is found for a byte of a specific state the machine sets the current state to an error value, stops executing, and breaks from a loop."
},

{
    "location": "index.html#Regular-expressions-1",
    "page": "Home",
    "title": "Regular expressions",
    "category": "section",
    "text": "Regular expressions in Automa.jl is somewhat more restricted than usual regular expressions in Julia. Some features like lookahead or backreference are not provided. In Automa.jl, re\"...\" is used instead of r\"...\" because these are different regular expressions. However, the syntax of Automa.jl\'s regular expressions is a subset of Julia\'s ones and hence it would be already familiar. Some examples are shown below:decimal    = re\"[-+]?[0-9]+\"\nkeyword    = re\"if|else|while|end\"\nidentifier = re\"[A-Za-z_][0-9A-Za-z_]*\"An important feature of regular expressions is composition of (sub-) regular expressions. One or more regular expressions can be composed using following functions:Function Alias Meaning\ncat(re...) * concatenation\nalt(re1, re2...) | alternation\nrep(re)  zero or more repetition\nrep1(re)  one or more repetition\nopt(re)  zero or one repetition\nisec(re1, re2) & intersection\ndiff(re1, re2) \\ difference (subtraction)\nneg(re) ! negationActions can be bind to regular expressions. Currently, there are four kinds of actions: enter, exit, :all and final. Enter actions will be executed when it enters the regular expression. In contrast, exit actions will be executed when it exits from the regular expression. All actions will be executed in all transitions and final actions will be executed every time when it reaches a final (or accept) state. The following code and figure demonstrate transitions and actions between states.using Automa\nusing Automa.RegExp: @re_str\nconst re = Automa.RegExp\n\nab = re\"ab*\"\nc = re\"c\"\npattern = re.cat(ab, c)\n\nab.actions[:enter] = [:enter_ab]\nab.actions[:exit]  = [:exit_ab]\nab.actions[:all]   = [:all_ab]\nab.actions[:final] = [:final_ab]\nc.actions[:enter]  = [:enter_c]\nc.actions[:exit]   = [:exit_c]\nc.actions[:final]  = [:final_c]\n\nwrite(\"actions.dot\", Automa.machine2dot(Automa.compile(pattern)))\nrun(`dot -Tpng -o src/figure/actions.png actions.dot`)(Image: )Transitions can be conditioned by actions that return a boolean value. Assigning a name to the when field of a regular expression can bind an action to all transitions within the regular expression as the following example shows.using Automa\nusing Automa.RegExp: @re_str\nconst re = Automa.RegExp\n\nab = re\"ab*\"\nab.when = :cond\nc = re\"c\"\npattern = re.cat(ab, c)\n\nwrite(\"preconditions.dot\", Automa.machine2dot(Automa.compile(pattern)))\nrun(`dot -Tpng -o src/figure/preconditions.png preconditions.dot`)(Image: )"
},

{
    "location": "index.html#Compilers-1",
    "page": "Home",
    "title": "Compilers",
    "category": "section",
    "text": "After finished defining a regular expression with optional actions you can compile it into a finite-state machine using the compile function. The Machine type is defined as follows:type Machine\n    start::Node\n    states::UnitRange{Int}\n    start_state::Int\n    final_states::Set{Int}\n    eof_actions::Dict{Int,Set{Action}}\nendFor the purpose of debugging, Automa.jl offers the execute function, which emulates the machine execution and returns the last state with the action log. Let\'s execute a machine of re\"a*b\" with actions used in the previous example.julia> machine = Automa.compile(ab)\nAutoma.Machine(<states=1:3,start_state=1,final_states=Set([0,2])>)\n\njulia> Automa.execute(machine, \"b\")\n(2,Symbol[:enter_a,:exit_a,:enter_b,:final_b,:exit_b])\n\njulia> Automa.execute(machine, \"ab\")\n(2,Symbol[:enter_a,:final_a,:exit_a,:enter_b,:final_b,:exit_b])\n\njulia> Automa.execute(machine, \"aab\")\n(2,Symbol[:enter_a,:final_a,:final_a,:exit_a,:enter_b,:final_b,:exit_b])\nThe Tokenizer type is also a useful tool built on top of Machine:type Tokenizer\n    machine::Machine\n    actions_code::Vector{Tuple{Symbol,Expr}}\nendA tokenizer can be created using the compile function as well but the argument types are different. When defining a tokenizer, compile takes a list of pattern and action pairs as follows:tokenizer = Automa.compile(\n    re\"if|else|while|end\"      => :(emit(:keyword)),\n    re\"[A-Za-z_][0-9A-Za-z_]*\" => :(emit(:identifier)),\n    re\"[0-9]+\"                 => :(emit(:decimal)),\n    re\"=\"                      => :(emit(:assign)),\n    re\"(\"                      => :(emit(:lparen)),\n    re\")\"                      => :(emit(:rparen)),\n    re\"[-+*/]\"                 => :(emit(:operator)),\n    re\"[\\n\\t ]+\"               => :(),\n)The order of arguments is used to resolve ambiguity of pattern matching. A tokenizer tries to find the longest token that is available from the current reading position. When multiple patterns match a substring of the same length, higher priority token placed at a former position in the arguments list will be selected. For example, \"else\" matches both :keyword and :identifier but the :keyword action will be run because it is placed before :identifier in the arguments list.Once a pattern is determined, the start and end positions of the token substring can be accessed via ts and te local variables in the action code. Other special variables (i.e. p, p_end, p_eof and cs) will be explained in the following section. See example/tokenizer.jl for a complete example."
},

{
    "location": "index.html#Code-generators-1",
    "page": "Home",
    "title": "Code generators",
    "category": "section",
    "text": "Once a machine or a tokenizer is created it\'s ready to generate Julia code using metaprogramming techniques.  Here is an example to count the number of words in a string:import Automa\nimport Automa.RegExp: @re_str\nconst re = Automa.RegExp\n\nword = re\"[A-Za-z]+\"\nwords = re.cat(re.opt(word), re.rep(re\" +\" * word), re\" *\")\n\nword.actions[:exit] = [:word]\n\nmachine = Automa.compile(words)\n\nactions = Dict(:word => :(count += 1))\n\n# Generate a function using @eval.\ncontext = Automa.CodeGenContext()\n@eval function count_words(data)\n    # initialize a result variable\n    count = 0\n\n    # generate code to initialize variables used by FSM\n    $(Automa.generate_init_code(context, machine))\n\n    # set end and EOF positions of data buffer\n    p_end = p_eof = lastindex(data)\n\n    # generate code to execute FSM\n    $(Automa.generate_exec_code(context, machine, actions))\n\n    # check if FSM properly finished\n    if cs != 0\n        error(\"failed to count words\")\n    end\n\n    return count\nendThis will work as we expect:julia> count_words(\"\")\n0\n\njulia> count_words(\"The\")\n1\n\njulia> count_words(\"The quick\")\n2\n\njulia> count_words(\"The quick brown\")\n3\n\njulia> count_words(\"The quick brown fox\")\n4\n\njulia> count_words(\"A!\")\nERROR: failed to count words\n in count_words(::String) at ./REPL[10]:16\nThere are two code-generating functions: generate_init_code and generate_exec_code. Both of them take a CodeGenContext object as the first argument and a Machine object as the second. The generate_init_code generates variable declatarions used by the finite state machine (FSM). julia> Automa.generate_init_code(context, machine)\nquote  # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 67:\n    p::Int = 1 # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 68:\n    p_end::Int = 0 # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 69:\n    p_eof::Int = -1 # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 70:\n    cs::Int = 1\nend\nThe input byte sequence is stored in the data variable, which, in this case, is passed as an argument. The data object must support Automa.pointerstart and Automa.pointerend methods. These point to the start and end memory positions, respectively. There are default implementations for these methods, which depend on Base.pointer and Base.sizeof methods. So, if data is a Vector{UInt8} or a String object, there is no need to implement them. But if you want to use your own type, you need to support them.The variable p points at the next byte position in data. p_end points at the end position of data available in data. p_eof is similar to p_end but it points at the actual end of the input sequence. In the example above, p_end and p_eof are soon set to sizeof(data) because these two values can be determined immediately.  p_eof would be undefined when data is too long to store in memory. In such a case, p_eof is set to a negative integer at the beginning and later set to a suitable position when the end of an input sequence is seen. The cs variable stores the current state of a machine.The generate_exec_code generates code that emulates the FSM execution by updating cs (current state) while reading bytes from data. You don\'t need to care about the details of generated code because it is often too complicated to read for human. In short, the generated code tries to read as many bytes as possible from data and stops when it reaches p_end or when it fails transition.julia> Automa.generate_exec_code(context, machine, actions)\nquote  # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 116:\n    ##659 = (Automa.SizedMemory)(data) # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 117:\n    while p ≤ p_end && cs > 0 # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 118:\n        ##660 = (getindex)(##659, p) # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 119:\n        @inbounds ##661 = ([0 0; 0 0; … ; 0 0; 0 0])[(cs - 1) << 8 + ##660 + 1] # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 120:\n        @inbounds cs = ([-1 -2; -1 -2; … ; -1 -2; -1 -2])[(cs - 1) << 8 + ##660 + 1] # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 121:\n        if ##661 == 1\n            count += 1\n        else\n            ()\n        end # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 122:\n        p += 1\n    end # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 124:\n    if p > p_eof ≥ 0 && cs ∈ Set([2, 1]) # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 125:\n        if cs == 2\n            count += 1\n        else\n            if cs == 1\n            else\n                ()\n            end\n        end # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 126:\n        cs = 0\n    else  # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 127:\n        if cs < 0 # /Users/kenta/.julia/v0.6/Automa/src/codegen.jl, line 128:\n            p -= 1\n        end\n    end\nend\nAfter finished execution, the value stored in cs indicates whether the execution successfully finished or not. cs == 0 means the FSM read all data and finished successfully. cs < 0 means it failed somewhere. cs > 0 means it is still in the middle of execution and needs more input data if any. The following snippet is a pseudocode of the machine execution:# start main loop\nwhile p ≤ p_end && cs > 0\n    l = {{ read a byte of `data` at position `p` }}\n    if {{ transferable from `cs` with `l` }}\n        cs = {{ next state of `cs` with `l` }}\n        {{ execute actions if any }}\n    else\n        cs = -cs\n    end\n    p += 1  # increment the position variable\nend\n\nif p_eof ≥ 0 && p > p_eof && cs ∈ machine.final_states\n    {{ execute EOF actions if any }}\n    cs = 0\nelseif cs < 0\n    p -= 1  # point at the last read byte\nendAutoma.jl has three kinds of code generators. The first and default one uses two lookup tables to pick up the next state and the actions for the current state and input. The second one expands these lookup tables into a series of if-else branches. The third one is based on @goto jumps. These three code generators are named as :table, :inline, and :goto, respectively. To sepcify a code generator, you can pass the code=:table|:inline|:goto argument to Automa.generate_exec_code. The generated code size and its runtime speed highly depends on the machine and actions. However, as a rule of thumb, the code size and the runtime speed follow this order (i.e. :table will generates the smallest but the slowest code while :goto will the largest but the fastest). Also, specifying check=false turns off bounds checking while executing and often improves the runtime performance slightly."
},

{
    "location": "references.html#",
    "page": "References",
    "title": "References",
    "category": "page",
    "text": ""
},

{
    "location": "references.html#References-1",
    "page": "References",
    "title": "References",
    "category": "section",
    "text": ""
},

{
    "location": "references.html#Automa.SizedMemory",
    "page": "References",
    "title": "Automa.SizedMemory",
    "category": "type",
    "text": "SizedMemory(data)\n\nCreate a SizedMemory object from data.\n\ndata must implement Automa.pointerstart and Automa.pointerend methods. These are used to get the range of the contiguous data memory of data.  These have default methods which uses Base.pointer and Base.sizeof methods.  For example, String and Vector{UInt8} support these Base methods.\n\nNote that it is user\'s responsibility to keep the data object alive during SizedMemory\'s lifetime because it does not have a reference to the object.\n\n\n\n"
},

{
    "location": "references.html#Automa.pointerend",
    "page": "References",
    "title": "Automa.pointerend",
    "category": "function",
    "text": "pointerend(data)::Ptr{UInt8}\n\nReturn the end position of data.\n\nThe default implementation is Automa.pointerstart(data) + sizeof(data) - 1.\n\n\n\n"
},

{
    "location": "references.html#Automa.pointerstart",
    "page": "References",
    "title": "Automa.pointerstart",
    "category": "function",
    "text": "pointerstart(data)::Ptr{UInt8}\n\nReturn the start position of data.\n\nThe default implementation is convert(Ptr{UInt8}, pointer(data)).\n\n\n\n"
},

{
    "location": "references.html#Data-1",
    "page": "References",
    "title": "Data",
    "category": "section",
    "text": "Automa.SizedMemory\nAutoma.pointerend\nAutoma.pointerstart"
},

{
    "location": "references.html#Automa.Variables",
    "page": "References",
    "title": "Automa.Variables",
    "category": "type",
    "text": "Variable names used in generated code.\n\nThe following variable names may be used in the code.\n\np::Int: current position of data\np_end::Int: end position of data\np_eof::Int: end position of file stream\nts::Int: start position of token (tokenizer only)\nte::Int: end position of token (tokenizer only)\ncs::Int: current state\ndata::Any: input data\nmem::SizedMemory: input data memory\nbyte::UInt8: current data byte\n\n\n\n"
},

{
    "location": "references.html#Automa.CodeGenContext",
    "page": "References",
    "title": "Automa.CodeGenContext",
    "category": "type",
    "text": "CodeGenContext(;\n    vars=Variables(:p, :p_end, :p_eof, :ts, :te, :cs, :data, gensym(), gensym()),\n    generator=:table,\n    checkbounds=true,\n    loopunroll=0,\n    getbyte=Base.getindex,\n    clean=false\n)\n\nCreate a code generation context.\n\nArguments\n\nvars: variable names used in generated code\ngenerator: code generator (:table, :inline or :goto)\ncheckbounds: flag of bounds check\nloopunroll: loop unroll factor (≥ 0)\ngetbyte: function of byte access (i.e. getbyte(data, p))\nclean: flag of code cleansing\n\n\n\n"
},

{
    "location": "references.html#Automa.generate_init_code",
    "page": "References",
    "title": "Automa.generate_init_code",
    "category": "function",
    "text": "generate_init_code(context::CodeGenContext, machine::Machine)::Expr\n\nGenerate variable initialization code.\n\n\n\n"
},

{
    "location": "references.html#Automa.generate_exec_code",
    "page": "References",
    "title": "Automa.generate_exec_code",
    "category": "function",
    "text": "generate_exec_code(ctx::CodeGenContext, machine::Machine, actions=nothing)::Expr\n\nGenerate machine execution code with actions.\n\n\n\n"
},

{
    "location": "references.html#Code-generator-1",
    "page": "References",
    "title": "Code generator",
    "category": "section",
    "text": "Automa.Variables\nAutoma.CodeGenContext\nAutoma.generate_init_code\nAutoma.generate_exec_code"
},

]}
