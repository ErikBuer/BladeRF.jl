push!(LOAD_PATH,"../src/")

using Documenter


# Running `julia --project docs/make.jl` can be very slow locally.
# To speed it up during development, one can use make_local.jl instead.
# The code below checks wether its being called from make_local.jl or not.
const LOCAL = get(ENV, "LOCAL", "false") == "true"

global run_doc_tests = LOCAL

if LOCAL
    include("../src/BladeRF.jl")
    using .BladeRF
else
    using BladeRF
end

ENV["GKSwstype"]="100"

# Disable doctests if `run_doc_tests` is false
DocMeta.setdocmeta!(BladeRF, :DocTestSetup, :(using BladeRF); recursive=true)

makedocs(
    modules = [BladeRF],
    format = Documenter.HTML(),
    sitename = "BladeRF.jl",
    pages = Any[
        "index.md",
        "Examples"  => Any[ 
                        "Examples/receiver.md",
                    ],
    ],
    doctest  = run_doc_tests, # As the doctests require hardware they cant be run on the CI.
)

deploydocs(
    repo = "github.com/ErikBuer/BladeRF.jl.git",
    push_preview = true,
)