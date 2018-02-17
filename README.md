# GIFTI

This package includes very basic support for loading GIFTI (`.gii`) files in Julia. Currently only the surface mesh can be extracted, represented as a `HomogeneousMesh` from [GeometryTypes.jl](https://github.com/JuliaGeometry/GeometryTypes.jl).

## Usage

```julia
using GIFTI
mesh = GIFTI.load(open("data.gii"))
```
