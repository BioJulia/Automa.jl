using Documenter
using Automa

makedocs(
    format=:html,
    sitename="Automa.jl",
    modules=[Automa],
    pages=["index.md"])

deploydocs(
    repo="github.com/bicycle1885/Automa.jl.git",
    julia="0.5",
    target="build",
    deps=nothing)
