using Documenter
using BladeRF

# Run doctests for BladeRF.jl

DocMeta.setdocmeta!(BladeRF, :DocTestSetup, :(using BladeRF); recursive=true)
Documenter.doctest(BladeRF)