# BladeRF.jl

Julia wrappers for [BladeRF](https://github.com/Nuand/bladeRF) library.

The package is currently not a registered package.
Add it using ht following command.

```Julia
] add git@github.com:ErikBuer/BladeRF.jl.git
```

Support to the bladeRF Julia is also found in the [AbstractSDRs.jl](https://github.com/JuliaTelecom/AbstractSDRs.jl) package.

## Testing the code

The tests must be run with a BladeRF connected.

From project root, run the following bash command.

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Building docs locally

To speed up docs generation locally, there is a separate make_local.jl file.
Trun this file from project root.