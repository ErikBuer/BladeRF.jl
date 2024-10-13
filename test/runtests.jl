using Test

push!(LOAD_PATH, expanduser(".")) # Assumed to be ran from the repl folder.

#include("BladeRF.jl")
using BladeRF

include("doctest.jl")