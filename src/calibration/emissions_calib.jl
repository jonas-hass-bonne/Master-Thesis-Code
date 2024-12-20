#########################################################
# This file provides functions to set parameter values  #
# for the emission functions in the GreenDICE model     #
#########################################################

# NOTICE: ALL CONTENTS OF THE FILE IS SUBJECT TO CHANGE
# THIS IS SIMPLY FOR INITIAL TESTING PURPOSES

# Things to note for future revisions:
#   Currently, individual calibration routines take no input, but it should probably be considered if this is ideal
#   and, if not, what type of input would make sense for the functions. An initial year and number of timeperiods
#   may well be some relevant input, allowing for more flexibility

#   Additionally, the exact calibration is sensitive to the choice of initial parameters (as always), and while
#   there are routines for selecting sensible starting values for initial intensities and growth rates, the initial
#   decay rate is arbitrarily chosen through trial-and-error, so it should be considered whether this should be
#   a parameter which is passed to the function.

#   Along this vein, there is also scope for selecting some initial step-sizes for the trust-region minimizer
#   so perhaps this should also be a parameter passed along in the functions

"""
    emissions_calib_crops()

Returns a dictionary with calibrated timepaths for emission intensities
in the crop-based agricultural sector
"""
function emissions_calib_crops(years)
    # Load in data needed for the calibration routine
    df_prod = getfaocropproductiondata()    # Output of crop-based agriculture
    df_methane = getedgarmethaneemissions()[:, [1,3]]   # Methane emissions of crops
    df_co2  = getedgarco2emissions()[:, [1,3]]  # CO2 emissions of crops
    df_n2o  = getedgarnitrousoxideemissions()[:, [1,3]] # Nitrous oxide emissions of crops

    # Transform the various DataFrames to only include data needed for calibration
    # Production transformation - Setting output to Feed, Food and Tourist consumption output
    select!(df_prod, "Year", "Feed - Gigacalories", "Tourist consumption - Gigacalories", "Food - Gigacalories")
    df_prod = select(transform(df_prod, [2:ncol(df_prod)...] => (+) => :Gigacalories), :Year, :Gigacalories)
    df_prod.Gigacalories .*= 1e-9   # Change units to Exacalories and relabel accordingly
    rename!(df_prod, (:Gigacalories => :Exacalories))

    # Relabel column names in the emission datasets
    [rename!(df, [:Year, name]) for (df, name) in zip([df_co2, df_methane, df_n2o], [:CO2, :CH4, :N2O])]; 

    # Combine emission and production data into a single DataFrame
    df_combined = innerjoin(df_prod, df_co2, df_methane, df_n2o, on = :Year)
    
    # Perform curve-fitting operation using the combined DataFrame
    timepath_mat = emissions_calib_curvefit(df_combined, 0.035, years)
    
    # Return the predicted timepaths for emission intensities as a matrix
    return timepath_mat
end

"""
    emissions_calib_livestock()

Returns a dictionary with calibrated timepaths for emission intensities
in the livestock-based agricultural sector
"""
function emissions_calib_livestock(years)
    # Load in data needed for the calibration routine
    df_prod = getfaolivestockproductiondata()   # Output of livestock-based agriculture
    df_methane = getedgarmethaneemissions()[:, [1,2]]   # Methane emissions of livestock
    df_co2  = getedgarco2emissions()[:, [1,2]]  # CO2 emissions of livestock
    df_n2o  = getedgarnitrousoxideemissions()[:, [1,2]] # Nitrous oxide emissions of livestock

    # Transform the various DataFrames to only include data needed for calibration
    # Production transformation - Setting output to Tourist consumption and Food output
    df_prod = df_prod[:, ["Year", "Tourist consumption - Gigacalories", "Food - Gigacalories"]]
    df_prod = transform(df_prod, [2:ncol(df_prod)...] => (+) => :Gigacalories)[:, [:Year, :Gigacalories]]
    df_prod.Gigacalories .*= 1e-9
    rename!(df_prod, (:Gigacalories => :Exacalories))

    # Relabel column names in the emission datasets
    [rename!(df, [:Year, name]) for (df, name) in zip([df_co2, df_methane, df_n2o], [:CO2, :CH4, :N2O])];     

    # Combine emission and production data into a single DataFrame
    df_combined = innerjoin(df_prod, df_co2, df_methane, df_n2o, on = :Year)
    
    # Perform curve-fitting operation using the combined DataFrame
    timepath_mat = emissions_calib_curvefit(df_combined, 0.035, years)
    
    # Return the predicted timepaths for emission intensities as a matrix
    return timepath_mat
end

function emissions_calib_manufacturing(years)
    # Load in data needed for the calibration
    df_prod = getwdidata()  # Output of manufacturing sector
    df_methane = getedgarmethaneemissions()[:, [1,4]]   # Methane emissions of livestock
    df_co2  = getedgarco2emissions()[:, [1,4]]  # CO2 emissions of livestock
    df_n2o  = getedgarnitrousoxideemissions()[:, [1,4]] # Nitrous oxide emissions of livestock

    # Relabel column names in the emission datasets
    [rename!(df, [:Year, name]) for (df, name) in zip([df_co2, df_methane, df_n2o], [:CO2, :CH4, :N2O])];

    # Combine emission and production data into a single DataFrame
    df_combined = innerjoin(df_prod, df_co2, df_methane, df_n2o, on = :Year)

    # Perform curve-fitting operation using the combined DataFrame
    timepath_mat = emissions_calib_curvefit(df_combined, 0.02, years)

    return timepath_mat
end

function emissions_calib_curvefit(df_combined, init_decay, years)
    intensity_transform(y, c, m, n) = [c ./ y m ./ y n ./ y]
    df_intensities = transform(df_combined, names(df_combined)[names(df_combined) .!= "Year"] => intensity_transform => [:gammaCO2, :gammaCH4, :gammaN2O])[:, [:Year, :gammaCO2, :gammaCH4, :gammaN2O]]
    
    # Calculate growth rates in intensities
    df_growth = (df_intensities[2:end, 2:end] .- df_intensities[1:end-1, 2:end]) ./ ((df_intensities[1:end-1, 2:end] .== 0) .* 1 .+ df_intensities[1:end-1, 2:end])
    df_growth.Year = df_intensities.Year[2:end]
    select!(df_growth, :Year, :gammaCO2, :gammaCH4, :gammaN2O)  # Reorder the columns so year column is first

    # Perform simple OLS estimation of the curve parameters (initial values and decay rate)
    curve(γ₀, g₀, δ, t_periods) = γ₀ .* cumprod([1 + g₀/((1 + δ)^i) for i in 0:t_periods-1])

    function obj_func(γ, γ₀, g₀, δ)
        γ_tilde = curve(γ₀, g₀, δ, length(γ))
        res = γ .- γ_tilde
        return sum(res.^2)
    end

    beta_mat = Matrix(undef, 3, 3)
    init_mat = hcat([[df_intensities[1,i], mean(df_growth[:, i]), init_decay] for i in 2:4]...)
    
    for (i, γ) in enumerate(eachcol(df_intensities[:, 2:end]))
        beta_mat[:, i] = lsq_curve_fit(obj_func, γ, init_mat[:, i], max_stepsize=[1., 1e-2, 1e-2])
    end

    # Determine initial values for the projection

    g₀_vec = vec(beta_mat[2,:] ./ ((1 .+ beta_mat[3,:]).^(years[1] - df_combined."Year"[1])))
    γ₀_vec = vec(Matrix(df_intensities[df_intensities.Year .== years[1], 2:end]))

    return hcat([curve(γ₀_vec[i], g₀_vec[i], beta_mat[3, i], length(years)) for i in eachindex(beta_mat[3,:])]...)
end

"""
    emissions_calib_complete(; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function emissions_calib_complete(years; γᵐ=[0.55, 0., 0.], gᵞᵐ=[-0.05, 0., 0.], δᵐ=[-0.004, 0., 0.], 
                                   γᶜ=[0., 0.01*1e-9, 0.6*1e-9],  gᵞᶜ=[0., -0.001, -0.03], δᶜ=[0., -0.001, -0.002],
                                   γˡ=[0., 0.75*1e-9, 0.02*1e-9], gᵞˡ=[0., -0.02, -0.01], δˡ=[0., -0.001, -0.001])
    γᵐ = emissions_calib_manufacturing(years)
    γᶜ = emissions_calib_crops(years)
    γˡ = emissions_calib_livestock(years)
    γ = Array{Float64}(undef, length(years), 4, 3) # Initialize an array to store the emissions parameters
    # Assign the emission parameters in their respective locations in the array
    for (i, gamma) in zip(eachindex(γ[1,:,1]), [γᵐ, γᶜ, γˡ, (fill(0., length(years), 3))])
        γ[:, i, :] = gamma
    end
    return Dict((:climate, :γ) => γ)
end