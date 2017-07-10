using Documenter
using Automa

# run(`julia actions.jl`)
# run(`julia preconditions.jl`)

makedocs(
    format=:html,
    sitename="Automa.jl",
    modules=[Automa],
    pages=["index.md", "references.md"])

deploydocs(
    repo="github.com/BioJulia/Automa.jl.git",
    julia="0.5",
    target="build",
    deps=nothing,
    make=nothing)
