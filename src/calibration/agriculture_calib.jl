######################################################################
# This file provides functions to calibrate parameter values for the #
# production of agricultural goods in the GreenDICE model            #
######################################################################


"""
    agriculture_calib_crop_TFP(;α=.3, σ=.6, φ=.5, proddf = getfaocropproductiondata(), ludf = getfaolanddata(),
                                    capdf = getagcapdata(), ilodf = getilodata(), popdf = getpopdata(), tempdf = gethadcruttemperatures(), 
                                    ψ¹=nothing, ψ²=nothing, ϕ=nothing)

Compute and return a Vector with yearly TFP values for the 
plant-based agricultural sector in the GreenDICE model based on given
DataFrames with output data, land use, capital, and labour data along with 
the provided functional parameters α, σ and φ
"""
function agriculture_calib_crop_TFP(years; α=1/3, σ=1.2, φ=.5, proddf = getfaocropproductiondata(), ludf = getfaolanddata(),
                                    capdf = getagcapdata(), ilodf = getilodata(), popdf = getpopdata(), tempdf = gethadcruttemperatures(), 
                                    ψ¹=nothing, ψ²=nothing, ϕ=nothing)
    # Strip the relevant data from datasets
    
    # Production transformation - Setting output to Feed, Food and Tourist consumption output
    select!(proddf, "Year", "Feed - Gigacalories", "Tourist consumption - Gigacalories", "Food - Gigacalories")
    gdf = groupby(proddf, "Year")  # Group values by year
    proddf = combine(gdf, names(proddf)[2:end] => (+) => :Gigacalories)  # Compute totals for each year
    proddf.Gigacalories .*= 1e-9   # Change units to Exacalories and relabel accordingly
    rename!(proddf, "Gigacalories" => "Exacalories")

    # Land use transformation - Selecting land for plant-based agricultural activities
    select!(ludf, "Year", "Plant-based agriculture")
    
    # Population transformation - Use ILO data to determine share of workers in agriculture
    # Because ILO data is pretty shoddy for many countries, the components rarely if ever adds up to the total
    cropshare = (ilodf.Agriculture ./ (ilodf.Agriculture .+ ilodf."Non-agriculture") ) ./ 2   # Assume half of agricultural workers are engaged here
    popdf = popdf[popdf.Year .∈ Ref(ilodf.Year), :] # Select years for which labor share data exists
    popdf.Population .*= cropshare

    # Use temperature data to determine historical damages
    maxtemp = [maximum(append!([0.], tempdf.Temperature[begin:t])) for t in 1:nrow(tempdf)]    # Determine maximum temperature each year
    upsilondf = DataFrame("Year" => tempdf.Year, "Upsilon" => land_damage.(tempdf.Temperature, maxtemp, psi=ψ², phi=ϕ, υ0 = 1., υmax = 1.1))

    # Join all dataframes together in years where all data is present
    df = innerjoin(proddf, popdf, capdf, upsilondf, ludf, on="Year")
    rename!(df, "Plant-based agriculture" => "Land - Gigahectares", "Total" => "Capital - Trillions", "Population" => "Labour - Billions")
    
    # Perform TFP calibration routine
    function computeTFP(Fp, L, K, υ, X; α=α, σ=σ, φ=φ)
        LK = CES(L, K, phi=α)
        υX = υ*X
        denom = CES(LK, υX, phi=φ, sigma=σ)
        TFP = Fp/denom
    end
    gdf = groupby(df, "Year")
    TFPdf = combine(gdf, names(df)[2:end] => ByRow(computeTFP) => "TFP")
    
    # Perform curve fitting for the estimated TFP series
    timepath_vec = agriculture_calib_curvefit(TFPdf, 0.03, years)

    return timepath_vec
end

"""
    agriculture_calib_livestock_TFP(;α=.3, σ=.6, φ=.5, αₐ=.5, proddf = getfaolivestockproductiondata(), ludf = getfaolanddata(),
                                        capdf = getagcapdata(), ilodf = getilodata(), popdf = getpopdata(), tempdf = gethadcruttemperatures(), 
                                        feeddf = getfaocropproductiondata(), ψ¹=nothing, ψ²=nothing, ϕ=nothing)

Compute and return a Vector with yearly TFP values for the 
animal-based agricultural sector in the GreenDICE model based on given
DataFrames with output data, land use, capital, labour and feed data along with 
the provided functional parameters α, σ and φ
"""
function agriculture_calib_livestock_TFP(years; α=1/3, σ=1.2, φ=.8, αₐ=.5, proddf = getfaolivestockproductiondata(), ludf = getfaolanddata(),
                                        capdf = getagcapdata(), ilodf = getilodata(), popdf = getpopdata(), tempdf = gethadcruttemperatures(), 
                                        feeddf = getfaocropproductiondata(), ψ¹=nothing, ψ²=nothing, ϕ=nothing)
    # Strip the relevant data from datasets

    # Feed transformation - Isolate the feed supply variable
    select!(feeddf, "Year", "Feed - Gigacalories")
    feeddf."Feed - Gigacalories" .*= 1e-9   # Change units to Exacalories
    rename!(feeddf, "Feed - Gigacalories" => "Feed - Exacalories")  # Relabel accordingly
    
    # Production transformation - Setting output to Feed, Food and Tourist consumption output
    select!(proddf, "Year", "Tourist consumption - Gigacalories", "Food - Gigacalories")
    gdf = groupby(proddf, "Year")  # Group values by year
    proddf = combine(gdf, names(proddf)[2:end] => (+) => :Gigacalories)  # Compute totals for each year
    proddf.Gigacalories .*= 1e-9   # Change units to Exacalories and relabel accordingly
    rename!(proddf, "Gigacalories" => "Exacalories")

    # Land use transformation - Selecting land for plant-based agricultural activities
    select!(ludf, "Year", "Animal-based agriculture")
    
    # Population transformation - Use ILO data to determine share of workers in agriculture
    # Because ILO data is pretty shoddy for many countries, the components rarely if ever adds up to the total
    cropshare = (ilodf.Agriculture ./ (ilodf.Agriculture .+ ilodf."Non-agriculture") ) ./ 2   # Assume half of agricultural workers are engaged here
    popdf = popdf[popdf.Year .∈ Ref(ilodf.Year), :] # Select years for which labor share data exists
    popdf.Population .*= cropshare

    # Use temperature data to determine historical damages
    maxtemp = [maximum(append!([0.], tempdf.Temperature[begin:t])) for t in 1:nrow(tempdf)]    # Determine maximum temperature each year
    upsilondf = DataFrame("Year" => tempdf.Year, "Upsilon" => land_damage.(tempdf.Temperature, maxtemp, psi=ψ², phi=ϕ, υ0 = 1., υmax = 1.1))

    # Join all dataframes together in years where all data is present
    df = innerjoin(proddf, popdf, capdf, upsilondf, ludf, feeddf, on="Year")
    rename!(df, "Animal-based agriculture" => "Land - Gigahectares", "Total" => "Capital - Trillions", "Population" => "Labour - Billions")
    
    # Perform TFP calibration routine
    function computeTFP(Fa, L, K, υ, X, F; α=α, σ=σ, φ=φ, αₐ=αₐ)
        LK = CES(L, K, phi=α)
        υXF = (υ*X)^(αₐ) * F^(1 - αₐ)
        denom = CES(LK, υXF, phi=φ, sigma=σ)
        TFP = Fa/denom
    end
    gdf = groupby(df, "Year")
    TFPdf = combine(gdf, names(df)[2:end] => ByRow(computeTFP) => "TFP")
    
    # Perform curve fitting for the estimated TFP series
    timepath_vec = agriculture_calib_curvefit(TFPdf, 0.05, years)

    return timepath_vec
end

function agriculture_calib_curvefit(TFPdf, init_decay, years)
    # Calculate growth rates for TFP
    TFPgrowthdf = DataFrame("Year" => TFPdf."Year"[2:end], "Growth" => (TFPdf."TFP"[2:end] .- TFPdf."TFP"[1:end-1]) ./ TFPdf."TFP"[1:end-1])

    # Perform simple OLS estimation of the curve parameters (initial values and decay rate)
    curve(TFP₀, g₀, δ, t_periods) = TFP₀ .* cumprod([1 + g₀/((1 + δ)^i) for i in 0:t_periods-1])

    function obj_func(TFP, TFP₀, g₀, δ)
        TFP_tilde = curve(TFP₀, g₀, δ, length(TFP))
        res = TFP .- TFP_tilde
        return sum(res.^2)
    end

    init_vec = [TFPdf."TFP"[1], mean(TFPgrowthdf."Growth"), init_decay]
    beta_vec = lsq_curve_fit(obj_func, TFPdf."TFP", init_vec, max_stepsize=[1., 1e-2, 1e-2])

    # Determine initial values for the projection
    TFP₀ = TFPdf[TFPdf."Year" .== years[1], "TFP"][1]
    g₀ = beta_vec[2] / ((1 + beta_vec[3])^(years[1] - TFPdf."Year"[1]))

    return curve(TFP₀, g₀, beta_vec[3], length(years))
end

# Currently, there is no inheritance for choice of datasets, but this may be revised in a future update

"""
    agriculture_calib_complete(;<keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function agriculture_calib_complete(years; α=1/3, σᶜ=1.2, φᶜ=0.5, 
                                     σˡ=1.2, φˡ=0.8, αₐ=0.5, 
                                     υᶜ0=1, υˡ0=1, damageParamDict=nothing)
    # Unabashedly assume 60 5-year timeperiods
    Aᶜ = agriculture_calib_crop_TFP(years; α=α, σ=σᶜ, φ=φᶜ, damageParamDict["Agriculture - Plants"]...)
    Aˡ = agriculture_calib_livestock_TFP(years; α=α, σ=σˡ, φ=φˡ, αₐ=αₐ, damageParamDict["Agriculture - Animals"]...)
    pars = Dict(([(:production, sym) for sym in [:αˡ, :σᶜ, :σˡ, :φᶜ, :φˡ]] .=> [αₐ, σᶜ, σˡ, φᶜ, φˡ])..., 
                :υᶜ0 => υᶜ0, :υˡ0 => υˡ0)
    return merge(Dict((:production, :Aᶜ)=> Aᶜ, (:production, :Aˡ) => Aˡ), pars) 
end