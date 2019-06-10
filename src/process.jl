"""
Processing functions submodule. 
"""

using Statistics           # used for Perasons correlation calculation
using LsqFit               # used for curve fitting
using DSP                  # used for convolution
using ImageMorphology      # used for TopHat baseline correction


# User Interface.
# ---------------

export smooth, centroid, baseline_correction


# Mass spectra
"""
    smooth(scan::MScontainer; method::MethodType=SG(5, 9))
Smooth the intensity of the input data and returns a similar structure.
# Examples
```julia-repl
julia> smoothed_data = msJ.smooth(scans)
msJ.MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
```
"""
function smooth(scan::MScontainer; method::MethodType=SG(5, 9, 0))
    if method isa msJ.SG
        return savitzky_golay_filtering(scan, method.order, method.window, method.derivative)
    end  
end

"""
    smooth(scans::Vector{MSscan}; method::MethodType=SG(5, 9, 0))
Smooth the intensity of the input data and returns a similar structure.
# Examples
```julia-repl
julia> scans = load("filename")
julia> smoothed_data = msJ.smooth(scans)
6-element Array{msJ.MSscan,1}:
 msJ.MSscan(1, 0.1384, 5.08195e6 .....
```
"""
function smooth(scans::Vector{MSscan}; method::MethodType=SG(5, 9, 0))
    if method isa msJ.SG
        sm_scans = Vector{MSscan}(undef, 0)
        for el in scans
            push!(sm_scans, savitzky_golay_filtering(el, method.order, method.window, method.derivative))
        end
        return sm_scans
    end  
end



"""
    savitzky_golay_filtering(scan::msJ.MScontainer, order::Int, window::Int, deriv::Int)
Savinsky and Golay filtering of mz and int data within the MSscan(s) container.
"""
function savitzky_golay_filtering(scan::MScontainer, order::Int, window::Int, deriv::Int)
    if window % 2 != 1
        return ErrorException("Window has to be an odd number.")
    elseif window < 1
        return ErrorException("window has to be a positive number.")
    elseif window < order + 2
        return ErrorException("window is too small for the order.")
    end
    order_range = range(1, length=(order+1))
    half_window = Int( (window-1) / 2 )

    b = zeros(window, order+1)

    for i = 0:order
        b[:,i+1] = [x for x = -half_window:half_window].^(i)
    end
    
    m = b * LinearAlgebra.pinv(b' * b)
    coefs = m[:,deriv + 1] * factorial(deriv)
    yfirst = scan.int[1]*ones(half_window)
    ylast = scan.int[end]*ones(half_window)
    pad = vcat(yfirst, scan.int, ylast)
    y = conv(coefs[end:-1:1], pad)[2 * half_window + 1 : end - 2 * half_window]
    
    basePeakIntensity = ceil(maximum(y))
    basePeakIndex = num2pnt(y, basePeakIntensity)
    basePeakMz = scan.mz[basePeakIndex]
    
    if scan isa MSscan
        return MSscan(scan.num, scan.rt, scan.tic, scan.mz, y, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy)
    elseif scan isa MSscans

        return MSscans(scan.num, scan.rt, scan.tic, scan.mz, y, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy, scan.s)
    end
end
 

"""
    centroid(scan::MScontainer; method::MethodType=TBPD(:gauss, 1000., 0.2) )
Peak picking algorithm taking a MSscan or MSscans object as input and returning an object of the same type containing the detected peaks. Default method is Threshold Base Peak Detection (TBPD), with a default gaussian peak profile with resolving power of 1000 and 0.2% base peak intensity threshold. Other peak shapes include `:lorentz` for the Cauchy-Lorentz shape and `:voigt` for the pseudo-Voigt profile.
# Examples
```julia-repl
julia> reduced_data = centroid(scans)
MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
```
"""
function centroid(scan::MScontainer; method::MethodType=TBPD(:gauss, 1000., 0.2) )
    if method isa TBPD
        ∆mz = 500.0 / method.resolution       # according to ∆mz / mz  = R, we take the value @ m/z 500
        if method.shape == :gauss
            return tbpd(scan, gauss, ∆mz, convert(Float64,method.threshold))
        elseif method.shape == :lorentz
            return tbpd(scan, lorentz, ∆mz, convert(Float64,method.threshold))
        elseif method.shape == :voigt
            return tbpd(scan, voigt, ∆mz, convert(Float64,method.threshold))
        else
            ErrorException("Unsupported peak profile. Use :gauss, :lorentz or :voigt.")
        end

#    elseif method isa SNRA()
#        return snra(scan, method.threshold)
#    elseif method isa CWT()
#        return cwt(scan, method.threshold)
#    else
#        ErrorException("Unsupported method.")
    end
    
end

"""
    centroid(scans::Vector{MSscan}; method::MethodType=TBPD(:gauss, 1000., 0.2) )
Peak picking algorithm taking an array of MSscan as input and returning an object of the same type containing the detected peaks. Default method is Threshold Base Peak Detection (TBPD), with a default gaussian peak profile with resolving power of 1000 and 0.2% base peak intensity threshold. Other peak shapes include `:lorentz` for the Cauchy-Lorentz shape and `:voigt` for the pseudo-Voigt profile.
# Examples
```julia-repl
julia> reduced_data = centroid(scans)
6-element Array{msJ.MSscan,1}:
MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
```
"""
function centroid(scans::Vector{MSscan}; method::MethodType=TBPD(:gauss, 4500., 0.2) )
    if method isa TBPD
        cent_scans = Vector{MSscan}(undef,0)
        for el in scans
            ∆mz = 500.0 / method.resolution       # according to ∆mz / mz  = R, we take the value @ m/z 500
            if method.shape == :gauss
                push!(cent_scans, tbpd(el, gauss, ∆mz, convert(Float64,method.threshold)))
            elseif method.shape == :lorentz
                push!(cent_scans, tbpd(el, lorentz, ∆mz, convert(Float64,method.threshold)))
            elseif method.shape == :voigt
                push!(cent_scans, tbpd(el, voigt, ∆mz, convert(Float64,method.threshold)))
            else
                ErrorException("Unsupported peak profile. Use :gauss, :lorentz or :voigt.")
            end
        end
        return cent_scans
#    elseif method isa SNRA()
#        return snra(scan, method.threshold)
#    elseif method isa CWT()
#        return cwt(scan, method.threshold)
#    else
#        ErrorException("Unsupported method.")
    end
    
end

    
"""
    gauss(x::Float64, p::Vector{Float64})
Gaussian shape function used by the TBPD method
"""
function gauss(x::Float64, p::Vector{Float64})
    # Gaussian shape function
    # width            = p[1]
    # x0               = p[2]
    # height           = p[3]
    # background level = p[4]
    # model(x, p) = p[4] + p[3] * exp(- ( (x-p[2])/p[1] )^2)
    return  p[4] + p[3] * exp(- ( (x-p[2])/p[1] )^2)
end

"""
    lorentz(x::Float64, p::Vector{Float64})
Cauchy-Lorentz shape function used by the TBPD method
"""
function lorentz(x::Float64, p::Vector{Float64})
    # Lorentzian shape function
    # width            = p[1]
    # x0               = p[2]
    # height           = p[3]
    # background level = p[4]
    # model(x, p) = p[4] + (p[3] / ( p[1] * (x-p[2])^2) )
    return p[4] + p[3]*π*p[1]/(π*p[1] + ( (x - p[2]) / p[1])^2)
end

"""
    voigt(x::Float64, p::Vector{Float64})
Pseudo-Voigt profile function used by the TBPD method
"""
function voigt(x::Float64, p::Vector{Float64})
    # pseudo-voigt profile
    gammaG = p[1] / (2.0 * sqrt(log(2.0)))
    gammaL = p[1] / 2.0
    Gamma = (gammaG^5 + 2.69269 * gammaG^4 * gammaL + 2.42843 * gammaG^3 * gammaL^2 + 4.47163 * gammaG^2 * gammaL^3 + 0.07842 * gammaG * gammaL^4 + gammaL^5)^(1/5)
    eta = 1.36603 *(gammaL / Gamma) - 0.47719 * (gammaL / Gamma)^2 + 0.11116 * (gammaL / Gamma)^3

    L(x,Gam,x0) = (Gam / π) / ((x-x0)^2 + Gam^2)
    G(x,Gam,x0) = exp( -( (x-x0)^2) / (2.0 * Gam^2) ) / Gam * sqrt(2π)
   return  p[4] + p[3]  * ( eta * L(x,Gamma,p[2]) + (1 - eta) * G(x,Gamma,p[2]) ) 
end


"""
    tbpd(scan::msJ.MScontainer, shape::Symbol,  R::Real, thres::Real)
Template based beak detection algorithm
"""
#function tbpd(scan::MScontainer, shape::Symbol,  R::Real, thres::Real)   #template based peak detection
function tbpd(scan::MScontainer, model::Function,  ∆mz::Real, thres::Real)   #template based peak detection
    box = num2pnt(scan.mz, scan.mz[1]+0.4) - 1        # taking a box of 0.5 width m/z
    correlation = zeros(length(scan.mz))
    maxi = maximum(scan.int)
    val = 0.0
    for i = 1:1:length(scan.mz)-box
        level = scan.int[i]
        if level >=  maxi * thres / 100. 
            bkg = 0.0
            p0 = [∆mz, scan.mz[i], level, bkg]
            ydata = [model(el, p0) for el in scan.mz[i:i+box]]
            val = Statistics.cor(scan.int[i:i+box], ydata)
        else
            val = 0.0
        end
        if val >= 0.62
            correlation[i] = val
        else
            correlation[i] = 0.0
        end
    end

    peaks_mz = Vector{Float64}(undef,0)
    peaks_int = Vector{Float64}(undef,0)
    peaks_s = Vector{Float64}(undef,0)

    diff_prev = 0.0
    diff      = 0.0 

    # rough numerical differentiation of correlation vector to find its maximum
    for i =2:length(correlation)-2
        diff = (-correlation[i-1] +correlation[i+1]) / 2.0 
        if diff < 0.0
            if diff_prev > 0.0
                max_value = maximum( scan.int[i-3:i+3] )
                max_index = num2pnt(scan.int, max_value)
                push!(peaks_mz, scan.mz[max_index])
                push!(peaks_int, scan.int[max_index])
                if scan isa MSscans
                    push!(peaks_s, scan.s[max_index])
                end
            end
        end       
        diff_prev = diff
    end

    basePeakIntensity = maximum(peaks_int)
    basePeakMz = peaks_mz[ num2pnt(peaks_int, basePeakIntensity) ]
    
    if scan isa MSscans
        return MSscans(scan.num, scan.rt, sum(peaks_int), peaks_mz, peaks_int, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy, peaks_s)
    elseif scan isa MSscan
        return MSscan(scan.num, scan.rt, sum(peaks_int), peaks_mz, peaks_int, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy)
    end
end

"""
function snra(scan::MScontainer)                                        # Signal to Noise Ration Analysis
    error("SNR not implemented")
end

function cwt(scan::MScontainer)                                         # Continuous Wavelet Transform 
    error("Wavelets not implemented")
end
"""

"""
    baseline_correction(scan::MScontainer; method::MethodType=IPSA(51, 100) )
Baseline correction taking a MSscan or MSscans object as input and returning an object of the same type as the input with the mass spectra corrected for their base line. Defaults method is IPSA(51, 100), where 51 is the width of Savinsky-Golay window and 100 is the maximum iteration. Other methods are available with `method = msJ.LOESS(3)`. See msJ.TopHat and msJ.LOESS `MethodType`.
# Examples
```julia-repl
julia> reduced_data = baseline_correction(scan)
MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
julia> reduced_data = baseline_correction(scans, method = msJ.LOESS(1))
MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
```
"""
function baseline_correction(scan::MScontainer; method::MethodType=IPSA(51, 100) )
    if method isa TopHat
        return tophat_filter(scan, method.region)
    elseif method isa LOESS
        return loess(scan, method.iter)
    elseif method isa IPSA
        return ipsa(scan, method.width, method.maxiter)
    end
end



"""
    baseline_correction(scan::Vector{MSscan}; method::MethodType=IPSA(51, 100) )
Baseline correction taking a vector of MSscan as input and returning an object of the same type as the input with the mass spectra corrected for their base line. Defaults method is IPSA(51, 100), where 51 is the width of Savinsky-Golay window and 100 is the maximum iteration. Other methods are available with `method = msJ.LOESS(3)`. See msJ.TopHat and msJ.LOESS `MethodType`.
# Examples
```julia-repl
julia> reduced_data = baseline_correction(scan)
MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
julia> reduced_data = baseline_correction(scans, method = msJ.LOESS(1))
6-element Array{msJ.MSscan,1}:
MSscans(1, 0.1384, 5.08195e6, [140.083, 140.167, 140.25, 140.333, 140.417, 140.5, 140.583, 140.667, 140.75, 140.833  …  1999.25, 1999.33, 1999.42, ....
```
"""
function baseline_correction(scans::Vector{MSscan}; method::MethodType=IPSA(51, 100) )
    if method isa TopHat
        return tophat_filter(scans, method.region)
    elseif method isa LOESS
        return loess(scans, method.iter)
    elseif method isa IPSA
        return ipsa(scans, method.width, method.maxiter)
    end
end



"""
    tophat(scan::MScontainer, region::Int)
Method taking a MScontainer object as input and returning an object of the same type with the mass spectra without their base line, using the TopHat filtering algorithm.
"""
function tophat_filter(scan::MScontainer, region::Int )
    TIC = sum( tophat(scan.int, region) )
    basePeakIntensity = maximum(tophat(scan.int, region))
    basePeakMz = scan.mz[num2pnt(scan.int,basePeakIntensity)]
    if scan isa MSscans
        return MSscans(scan.num, scan.rt, TIC, scan.mz, tophat(scan.int, region), scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy, peaks_s)
    elseif scan isa MSscan
        return MSscan(scan.num, scan.rt, TIC, scan.mz, tophat(scan.int, region), scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy)
    end
    return 
end


"""
    tophat(scans::Vector{MSscan}, region::Int )
Method taking an array of MSscan as input and returning an object of the same type with mass spectra without their base line, using the TopHat method.
"""
function tophat_filter(scans::Vector{MSscan}, region::Int )
    bl_scans = Vector{MSscan}(undef,0)
    for scan in scans
        TIC = sum(tophat(scan.int, region))
        basePeakIntensity = maximum(tophat(scan.int, region))
        basePeakMz = scan.mz[num2pnt(scan.int,basePeakIntensity)]
        push!(bl_scans,  MSscan(scan.num, scan.rt, TIC, scan.mz, tophat(scan.int, region), scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy))
    end
    return bl_scans
end


"""
    loess(scan::MScontainer, iter::Int )
Method  taking a MSscan or MSscans object as input and returning an object of the same type with the mass spectra without their base line, using the LOESS (Locally Weighted Error Sum of Squares regression).
"""
function loess(scans::Vector{MSscan}, iter::Int )
    bl_scans = Vector{MSscan}(undef,0)
    for scan in scans
        push!(bl_scans, loess(scan, iter))
    end
    return bl_scans
end


"""
    loess(scan::MScontainer, iter::Int )
Method  taking a MSscan or MSscans object as input and returning an object of the same type with the mass spectra without their base line, using the LOESS (Locally Weighted Error Sum of Squares regression).
"""
function loess(scan::MScontainer, iter::Int )
    n = length(scan.mz) 
    r = Int(ceil( n / 2 ))
    h = [sort(abs.(scan.mz .- scan.mz[i]))[r] for i=1:n ]
    w = clamp.(abs.( ( scan.mz .- transpose(scan.mz)) ./ h), 0.0, 1.0)
    w = (1 .- w.^3).^3
    baseline = zeros(n)
    res = zeros(n)
    delta = ones(n)
    for j=1:iter 
        for i=1:n
            weight = delta .* w[:,i]
            b = [sum(weight .* scan.int), sum(weight .* (scan.int .* scan.mz))]
            A = [sum(weight), sum(weight .* scan.mz), 
                 sum(weight .* scan.mz), sum(weight .* scan.mz.^2) ]
            A = reshape(A, 2, 2)
            beta = LinearAlgebra.pinv(A) * b
            baseline[i] = beta[1] + beta[2] * scan.mz[i]
        end
        res = scan.int - baseline
        s = Statistics.median(abs.(res))
        delta = clamp.(res ./ (6.0 .* s), -1, 1)
        delta = (1 .- delta.^2).^2
    end 
    TIC = sum(res)
    basePeakIntensity = maximum(res)
    basePeakMz = scan.mz[num2pnt(scan.int,basePeakIntensity)]
    if scan isa MSscans
        return MSscans(scan.num, scan.rt, TIC, scan.mz, res, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy, peaks_s)
    elseif scan isa MSscan
        return MSscan(scan.num, scan.rt, TIC, scan.mz, res, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy)
    end
end


"""
    ipsa(scan::MScontainer, width::Real, maxiter::Int)
Method  taking a MSscan or MSscans object as input and returning an object of the same type with the mass spectra without their base line, using the iterative polynomial smoothing algorithm (IPSA) baseline correction.
"""
function ipsa(scan::MScontainer, width::Real, maxiter::Int)
    if iseven(width) 
        width -= 1
    end
    #step 1
    eps = 1e-07
    input = zeros( length(scan.int) )
    res = zeros( length(scan.int) )
    #step 2
    bkg = SG(scan.int, 0, width,0)
    bkg_old = zeros(length(scan.int))
    res = scan.int - bkg
    # step 3
    eratio_old = 0.0
    # step 4
    counter = 1
    while true

        for i = 1:length(input)
            if scan.int[i] < bkg[i]
                input[i] = scan.int[i]
            else
                input[i] = bkg[i]
            end
        end
        bkg = SG(input, 0, width,0)
        res = scan.int - bkg ;
        eratio = norm(bkg - bkg_old) / norm(bkg)

        if (abs(eratio - eratio_old)) < eps
            break
        elseif counter > maxiter
            break
        end
        counter += 1
        eratio_old = eratio
        bkg_old = bkg
    end
    
    basePeakIntensity = ceil(maximum(res))
    basePeakIndex = num2pnt(res, basePeakIntensity)
    basePeakMz = scan.mz[basePeakIndex]

    if scan isa MSscan
        return MSscan(scan.num, scan.rt, scan.tic, scan.mz, res, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy)
    elseif scan isa MSscans

        return MSscans(scan.num, scan.rt, scan.tic, scan.mz, res, scan.level, basePeakMz, basePeakIntensity, scan.precursor, scan.polarity, scan.activationMethod, scan.collisionEnergy, scan.s)
    end

end


"""
    ipsa(scan::MScontainer, width::Real, maxiter::Int)
Method  taking a MSscan or MSscans object as input and returning an object of the same type with the mass spectra without their base line, using the iterative polynomial smoothing algorithm (IPSA) baseline correction.
"""
function ipsa(scans::Vector{MSscan}, width::Real, maxiter::Int)
    if iseven(width) 
        width -= 1
    end
    bl_scans = Vector{MSscan}(undef,0)
    for scan in scans
        push!(bl_scans, ipsa(scan, width, maxiter))
    end
    return bl_scans
end
