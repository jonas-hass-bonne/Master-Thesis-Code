#########################################################
# This file provides functions to set parameter values  #
# for the utility functions in the GreenDICE model      #
#########################################################

# NOTICE: ALL CONTENTS OF THE FILE IS SUBJECT TO CHANGE
# THIS IS SIMPLY FOR INITIAL TESTING PURPOSES

function utility_calib_food(;σ=2, croppricedf=getfaocroppricedata(), livestockpricedf=getfaolivestockpricedata(), 
                            cropconsumptiondf=getfaocropconsumptiondata(), livestockconsumptiondf=getfaolivestockconsumptiondata(),
                            popdf=getpopdata(aggregate=false), countrymap=mapfao2wbcountries())

    # Join datasets together on common keys
    dfcombinedcrop = innerjoin(cropconsumptiondf, croppricedf, on=["Year", "Item"])
    dfcombinedlivestock = innerjoin(livestockconsumptiondf, livestockpricedf, on=["Year", "Item"])

    # Split by country and year and compute weighted consumption and price indices
    gdf = groupby(dfcombinedcrop, ["Year", "Area"])
    dfcombinedcrop = transform(gdf, "Value" => (x -> x ./ sum(x)) => "Share")
    gdf = groupby(dfcombinedlivestock, ["Year", "Area"])
    dfcombinedlivestock = transform(gdf, "Value" => (x -> x ./ sum(x)) => "Share")

    # Define a local aggregator function to compute weighted price and total consumption
    function aggregator(v, p, s)
        wp = sum(p .* s)
        vtot = sum(v)
        return DataFrame([vtot wp], :auto)
    end

    gdf = groupby(dfcombinedcrop, ["Year", "Area"])
    dfcrop = combine(gdf, ["Value", "Price", "Share"] => aggregator => ["Consumption", "Price"])
    gdf = groupby(dfcombinedlivestock, ["Year", "Area"])
    dflivestock = combine(gdf, ["Value", "Price", "Share"] => aggregator => ["Consumption", "Price"])
    dffood = outerjoin(dfcrop, dflivestock, on=["Year", "Area"], renamecols="_Crop" => "_Livestock")

    # For each country, compute their implied share parameter θ
    function compute_theta(cropc, cropp, livestockc, livestockp; sigma=σ)
        return (livestockc.^(1/sigma) .* livestockp) ./ (cropc .^(1/sigma) .* cropp .+ livestockc.^(1/sigma) .* livestockp)
    end
    gdf = groupby(dffood, ["Area"])
    transform!(gdf, names(gdf)[3:end] => compute_theta => "Theta")

    # Then determine the population-weighted mean of theta in each year, and finally take the mean across years
    dffood."Area"= map(x -> countrymap[x], dffood."Area")   # Map the FAO countries to the World Bank countries
    gdf = groupby(popdf, ["Year"])
    transform!(gdf, "Population" => (x -> x./sum(skipmissing(x))) => "Share")
    dfcombined = innerjoin(dffood[:, ["Year", "Area", "Theta"]], popdf[:, ["Year", "Country", "Share"]], on=["Year", "Area" => "Country"])

    gdf = groupby(dfcombined, "Year")
    df_out = combine(gdf, ["Theta", "Share"] => ((t, s) -> sum(t .* s)) => "Theta")

    return mean(df_out."Theta")
end

"""
    utility_calib_complete(years; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function utility_calib_complete(years; σᶜ = 2, φᶜ=0.7, Θᶠ = 1800,
                                 σᵘ=2.381, φᵘ=0.1,
                                 η=1.45,   ρ=0.01,
                                 σᶠ = 2, φᶠ=0.3)
    φᶠ= utility_calib_food(σ=σᶠ)
    C = Dict([(:welfare, sym) for sym in [:σᶜ, :φᶜ, :Θᶠ]] .=> [σᶜ, φᶜ, Θᶠ])
    U = Dict([(:welfare, sym) for sym in [:σᵘ, :φᵘ]] .=> [σᵘ, φᵘ])
    W = Dict([(:welfare, sym) for sym in [:η, :ρ]] .=> [η, ρ])
    F = Dict([(:welfare, sym) for sym in [:σᶠ, :φᶠ]] .=> [σᶠ, φᶠ])
    return merge(C, U, W, F)
end