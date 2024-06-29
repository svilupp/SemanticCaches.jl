using SemanticCaches
using Documenter

DocMeta.setdocmeta!(
    SemanticCaches, :DocTestSetup, :(using SemanticCaches); recursive = true)

makedocs(;
    modules = [SemanticCaches],
    authors = "J S <49557684+svilupp@users.noreply.github.com> and contributors",
    sitename = "SemanticCaches.jl",
    format = Documenter.HTML(;
        canonical = "https://svilupp.github.io/SemanticCaches.jl",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "api_reference.md"
    ]
)

deploydocs(;
    repo = "github.com/svilupp/SemanticCaches.jl",
    devbranch = "main"
)
