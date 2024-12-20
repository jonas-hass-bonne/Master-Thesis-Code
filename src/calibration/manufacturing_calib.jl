################################################################
# This file provides functions to set parameter values for the #
# production of manufacturing goods in the GreenDICE model     #
################################################################

"""
    manufacturing_calib_TFP(years; α=1/3, gdpdf = getwdidata(), capdf = getwealthaccountsdata(),
                            ilodf = getilodata(), popdf = getpopdata(), tempdf = gethadcruttemperatures(),
                            ψ¹=nothing, ψ²=nothing, ϕ=nothing)

Calibrate the value of TFP for manufacturing 
based on data for labour, capital and production
    Args:
    α (Real)            :   Capital elasticity (default = 1/3)
    gdpdf (DataFrame)   :   DataFrame produced by the getwdidata function
    capdf (DataFrame)   :   DataFrame produced by the getwealthaccountsdata function
    ilodf (DataFrame)   :   DataFrame produced by the getilodata function
    popdf (DataFrame)   :   DataFrame produced by the getpopdata function
    tempdf (DataFrame)  :   DataFrame produced by the gethadcruttemperatures function
    ψ¹ (Real)           :   Damage function first parameter value
    ψ₂ (Real)           :   Damage function second parameter value
    ϕ (Real)            :   Unused damage function parameter (kept for consistency)

    Output:
    tfpdf (DataFrame)   :   DataFrame containing manufacturing TFP for 1995-2018
"""
function manufacturing_calib_TFP(years; α=1/3, gdpdf = getwdidata(), capdf = getwealthaccountsdata(),
                               ilodf = getilodata(), popdf = getpopdata(), tempdf = gethadcruttemperatures(),
                               ψ¹=nothing, ψ²=nothing, ϕ=nothing)
    
    # Combine DataFrames
    labdf = DataFrame("Year" => ilodf."Year", "Labour" => vec(ilodf[:, "Non-agriculture"] ./ sum(Matrix(ilodf[:, ["Agriculture", "Non-agriculture"]]), dims=2)))
    labdf = innerjoin(labdf, popdf, on="Year")
    labdf = combine(groupby(labdf, "Year"), ["Labour", "Population"] => ByRow(*) => "Labour")
    
     # Use temperature data to determine historical damages
    #  maxtemp = [maximum(append!([0.], tempdf.Temperature[begin:t])) for t in 1:nrow(tempdf)]    # Determine maximum temperature each year
    sigmadf = DataFrame("Year" => tempdf.Year, "Sigma" => gdp_damage.(tempdf.Temperature, psi1 = ψ¹, psi2=ψ²))

    # At some point we should also add abatement expenditures, but for now we just ignore this

    df = innerjoin(gdpdf, capdf, labdf, sigmadf, on="Year")

    computeTFP(Y, K, L, sigma; α=α) = Y / ((1 - sigma) * CES(L, K, phi=α))
    TFPdf = combine(groupby(df, "Year"), names(df)[2:end] => ByRow(computeTFP) => "TFP")

    # Perform curve fitting for the estimated TFP series
    timepath_vec = manufacturing_calib_curvefit(TFPdf, 0.05, years)

    return timepath_vec
end

function manufacturing_calib_curvefit(TFPdf, init_decay, years)
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

"""
    manufacturing_calib_complete(years; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function manufacturing_calib_complete(years; α=1/3, damageParamDict=nothing)
    Aᵐ = manufacturing_calib_TFP(years; α=α, damageParamDict["Manufacturing"]...)
    return merge(Dict((:production, :Aᵐ) => Aᵐ), Dict((:production, :α) => α))
end

