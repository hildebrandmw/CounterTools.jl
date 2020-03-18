using Documenter
using CounterTools

makedocs(
    modules     = [CounterTools],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    sitename    = "CounterTools",
    doctest     = false,
    pages       = Any[
        "Getting Started"   => "index.md",
        "Core Monitoring"   => "core.md",
        "Uncore Monitoring" => Any[
            "iMC" => "imc.md",
        ],
    ],
)

deploydocs(
    repo        = "github.com/hildebrandmw/CounterTools.jl.git",
    target      = "build",
)

