using Documenter
using Automa

# run(`julia actions.jl`)
# run(`julia preconditions.jl`)

makedocs(
    format = :html,
    sitename = "Automa.jl",
    modules = [Automa],
    pages = [
        "Home" => "index.md",
        "References" => "references.md"
    ]
)

deploydocs(
    repo = "github.com/BioJulia/Automa.jl.git",
    julia = "0.6",
    target = "build",
    deps = nothing,
    make = nothing
)
