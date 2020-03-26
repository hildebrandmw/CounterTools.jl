using Documenter
using CounterTools

makedocs(
    modules     = [CounterTools],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    sitename    = "CounterTools",
    doctest     = true,
    pages       = Any[
        "Getting Started"   => "index.md",
        "Manual" => Any[
            "monitors.md",
            "records.md",
            "counters.md",
        ],
        "Examples" => Any[
            "core/example.md",
            "uncore/imc.md",
        ],
    ],
)

deploydocs(
    repo        = "github.com/hildebrandmw/CounterTools.jl.git",
    target      = "build",
)

