using Documenter
using Automa

# run(`julia actions.jl`)
# run(`julia preconditions.jl`)

makedocs(
    sitename = "Automa.jl",
    modules = [Automa],
    pages = [
        "Home" => "index.md",
        "References" => "references.md"
        ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true")
)

deploydocs(
    repo = "github.com/BioJulia/Automa.jl.git",
    target = "build",
    push_preview = true,  
)
