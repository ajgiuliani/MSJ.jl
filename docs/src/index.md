Home
====

`msJ.jl` is a package for loading, processing and plotting mass spectrometry data. It provides a range of functionalities such as:
* Getting information on the file
* Reading a file
* Averaging mass spectra based on various criteria that may be combined
* Getting chromatogram
* Processing the data


The [tutorial page](tutorial.md) shows examples how to use this package and provides a general guide to it. The [manual page](manual.md) explains the structure of the package and the [reference page](reference.md) gives a full documentation for each type and function.


## Installation
---------------
There are two ways of installing the package.
```julia
julia> using Pkg ;
julia> Pkg.add(PackageSpec(url="https://github.com/ajgiuliani/msJ.jl"))
```

or

```julia
julia> ]
(v1.1) pkg>  add https://github.com/ajgiuliani/msJ.jl
```


## Supported file format
-----------
  - mzXML