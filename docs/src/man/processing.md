# Processing
## Smooth
The [`smooth`](@ref) function is public and applies on `MSscan`or `MSscans` objects, with an optional `method` argument set to `MSj.SG(5, 9, 0)`.  Smoothing is performed on the `int` field using the [Savinsky and Golay](https://en.wikipedia.org/wiki/Savitzky%E2%80%93Golay_filter). The first argument is the order (5 by default), the second is the number of points (default 9)  and the last, is the derivative level (0).
The function returns an `MScontainer` type identical to the input. 
	
## Base line correction
Base line correction is performed using the [`baseline_correction`](@ref) function. This function as two methods and operates either on [`MScontainer`](@ref) or on Array of [`MSscan`](@ref) such as obtained after [importing data](Importing data).
```julia
baseline_correction(scans)
baseline_correction(scans, method = MSj.IPSA(51, 100))
```
The `method` argument allows choosing the algorithm. 

#### Top Hat
This filter is based Top Hat transform used in image processing ([wikipedia](https://en.wikipedia.org/wiki/Top-hat_transform), [Sauve et al. (2004)](https://pdfs.semanticscholar.org/c04c/afc9b2670edd1ea38f0f724cadbe2ec321e9.pdf). The region onto which the operation is performed is set using the `region`field of the [`MSj.TopHat`](@ref). This filter removes every structure from the input which are smaller in size than the structuring element. Usually a region of 100 points is enough.This filter is fast and works quite well on large and complex backgrounds.

#### Iterative polynomial smoothing algorithm (IPSA)
The default algorithm is the IPSA for iterative polynomial smoothing algorithm ([Wang et al. (2017)](https://doi.org/10.1177/0003702816670915). This iterative algorithm use a zero ordre Savinsly and Golay smoothing to estimate a background. Then a new input, constructed by taking the minimum of either the original spectrum or the background, is smooth again. The process is repeated until the maximum iteration is reached or when the background does not change much. The termination criteria has been changed from the original paper.

##### Locally weighted error sum of squares regression (LOESS)
The LOESS family of algorithm is based on non-parametric linear [local regression](https://en.wikipedia.org/wiki/Local_regression) where the regression is weighted to reduced the influence of more distant data. We use here the iterative robust estimation procedure where the weights are updated with a bisquare function of the median of the residuals.
This algorithm takes the number of iteration to be performed. Usually 3 iteration is enough. This algorithm is slow and is not recommended. The implementation will be improved in future versions.



## Peak picking
Pick-picking is performed using the public [`centroid`](@ref) function. It operates on `MSscan`or `MSscans`type of data and return a similar type. It takes a method argument, set by default to the Signal to Noise Analysis method: `MSj.SNRA`.
```julia
centroid(scan)
```
#### Signal to Noise Ratio Analysis (SNRA)
Signal to noise ratio analysis is a very general approach, which relies on the definition of noise. Here, we use TopHat filter to define the noise. Then the signal to noise ratio is calculated. Peaks are found by searching for a local maximum for which the signal to noise ratio is above the threshold. By defaults the `MSj.SNRA` uses a threshold = 1.0 and a structuring element of 100 points.
```julia
centroid(scan, method = MSj.SNRA(1., 100)
```

#### Threshold base peak detection algorithm (TBPD)
The TBPD method identifies features based on their similarity (as described by the Pearson correlation coefficient) with a [template peak](https://doi.org/10.1007/978-1-60761-987-1_22). By default the `MSj.TBPD` method type uses a Gaussian function, with 1000 mass resolving power and a threshold level set to 0.2% as :
```julia
centroid(scan, method = MSj.TBPD(:gauss, 1000, 0.2)
```
Two other shape functions are available:
- `:loretz` which uses a Cauchy-Lorentz function and
- `:voigt` which implements a pseudo-voigt profile ([Ida et al., J. Appl. Cryst. (2000)](https://doi.org/10.1107%2Fs0021889800010219), [Wikipedia](https://en.wikipedia.org/wiki/Voigt_profile#Pseudo-Voigt_approximation))

The `:lorentz` profile fits better Fourrier Transform mass spectra. The `:voigt` shape is the result of the convolution of gaussi and Cauchy-Lorentz shape.

```julia
centroid(scan, method = MSj.TBPD(:lorentz, 1000., 0.1)
centroid(scan, method = MSj.TBPD(:voight,  1000., 0.1)
```
	
