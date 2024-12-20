########################################################
# This file provides functions to set parameter values #
# for the climate module of the GreenDICE model        #
########################################################

# All parameter values are taken from the description of the FaIR 
# climate model provided in Leach et al (2021)

# The description for calibrating g0 and g1 should be updated in a future revision
# to reflect that values for each passed ghg (along columns) are computed

# Also, perhaps methods should be provided for handling single gases and multiple
# gases passed as matrices (single gases would be old methods, multiple gases are current methods)

"""
    climate_calib_g0(a::Dict, τ::Dict, g1::Real)

Compute the g0 iIRF₁₀₀ calibration parameter 
as described in Leach et al (2021) for the FaIR model 

The computation is as follows:

`` exp( - [Σᴺᵢ₌₁ aᵢ * τᵢ * [1 - exp( -100/τᵢ )]]/g₁) ``

See also:

    [`climate_calib_g1`](@ref) for calibration of g1
"""
function climate_calib_g0(a::Dict, τ::Dict, g1::Vector{<:Real})
    avals = collect(values(a)...)
    τvals = collect(values(τ)...)
    g0 = exp.( -vec(sum(avals .* τvals .* (1 .- exp.((-100 ./ τvals))), dims=1)) ./ g1)
    return g0
end

"""
    climate_calib_g1(a::Dict, τ::Dict)

Compute the g1 iIRF₁₀₀ calibration parameter
as described in Leach et al (2021) for the FaIR model

The computation is as follows:

`` Σᴺᵢ₌₁ aᵢ * τᵢ * [1 - (1 + 100/τᵢ) * exp( -100/τᵢ )] ``
"""
function climate_calib_g1(a::Dict, τ::Dict)
    avals = collect(values(a)...)
    τvals = collect(values(τ)...)
    g1 = sum(avals .* τvals .* (1 .- (1 .+ 100 ./ τvals) .* exp.(-100 ./ τvals)), dims=1)
    return vec(g1)
end


"""
    climate_calib_temperature_params(; <keyword arguments>)

Returns a dictionary with response coefficients 
in the three-box temperature model as described in Leach et al (2021)
for the FaIR model

# Arguments
- `TCR::Real=1.79`:                                                     Transient Climate Response
- `RWF::Real=0.552`:                                                    Realized Warming Fraction
- `F2x::Real=3.759`:                                                    Forcing from CO₂ doubling
- `d`::Dict{Symbol, Vector{<:Real}}=Dict([:d => [0.903, 7.92, 355]]):   Thermal response timescales
- `q1`::Real=0.18:                                                      Thermal response coefficient for first thermal box  
"""
function climate_calib_temperature_params(;TCR::Real=1.79, RWF::Real=.552, F2x::Real=3.759,
                                           d = Dict([:d => [0.903, 7.92, 355]]),
                                           q1 = 0.180)
    v = [1 - (x/69.66) * (1 - exp(-69.66/x)) for x in collect(values(d)...)]
    ECS = TCR/RWF
    q3 = (((TCR/F2x) - q1*(v[1] - v[2]) - (ECS/F2x)*v[2])) / (v[3] - v[2])
    q2 = (ECS/F2x) - q1 - q3
    q = Dict([(:climate, :q) => [q1, q2, q3]])
    return q  
end

"""
    climate_calib_init(; year::Integer=2010)

Returns a dictionary with initial values for the different carbon reservoirs
in the specified year. 

This is done by running the FaIR model described in Leach et al (2021) using
historical emissions and concentration data from the RCMIP project.
The data is compiled by Hoesly et al (2018)
"""
function climate_calib_init(years; FAiR::Union{Nothing, Mimi.AbstractModel}=nothing)
    # Check to see if a FAiR Mimi model has been provided, otherwise throw an error
    isnothing(FAiR) ? error("A Mimi model for FAiR must be provided for calibration") : nothing

    
    yearidx = timeidx(FAiR, years[1])

    # Load historical emission and concentration data
    emission_df = getrcmipemissiondata()
    concentration_df = getrcmipconcentrationdata()
    
    # Load emissions from the EDGAR database and combine them in one DataFrame
    dfSum(df) = vec(sum(Matrix(df[:, 2:end]), dims=2))   # Convenience function to sum across sectors in EDGAR DataFrames
    edgar_emission_df = hcat(DataFrame("Year" => getedgarmethaneemissions()[!, 1]), 
                             DataFrame(names(emission_df)[2:end] .=> [dfSum(getedgarco2emissions()), 
                                                                      dfSum(getedgarmethaneemissions()), 
                                                                      dfSum(getedgarnitrousoxideemissions())]))

    # Stitch together the two datasets (incurring a data break in 2015) to obtain a longer emission series
    emission_df = vcat(emission_df, edgar_emission_df[edgar_emission_df.Year .>= 2015, :])

    # Obtain years defined in the FAiR model
    years = keys(FAiR.md.dim_dict[:time])
    emission_selector = emission_df[!, 1] .∈ Ref(years)
    concentration_selector = concentration_df[!, 1] .∈ Ref(years)
    
    # Select only those years where the FAiR model is defined
    emissions = Matrix(emission_df[emission_selector, 2:end])
    concentrations = Matrix(concentration_df[concentration_selector, 2:end])

    # For now, supply a zero-valued exogenous forcings vector
    exogenous_forcing_vec = fill(0., length(years))

    # Set initial parameters of the FAiR model and run it
    update_params!(FAiR, Dict((:climate, :E) => emissions, (:climate, :C₀) => concentrations[1, :], (:climate, :Oₑₓ) => exogenous_forcing_vec))
    run(FAiR)
    out_dict = Dict((:climate, :R0) => FAiR[:climate, :R][yearidx, :, :], 
                    (:climate, :T0) => FAiR[:climate, :T][yearidx], 
                    (:climate, :S0) => FAiR[:climate, :S][yearidx, :],
                    (:climate, :β0) => FAiR[:climate, :β][yearidx, :],
                    (:climate, :C₀) => FAiR[:climate, :C₀][:],
                    (:climate, :Ecum0) => FAiR[:climate, :Ecum][yearidx-1, :])
    
    return out_dict
end


"""
    climate_calib_complete(;<keyword arguments>)

Returns a dictionary with parameter values for the FaIR model
described in Leach et al (2021)

# Arguments
- `a::Vector{<:Real}=[0.2173, 0.224, 0.2824, 0.2763]`:      Share of emissions entering each carbon reservoir
- `τ::Vector{<:Real}=[1e9, 394.4, 36.54, 4.304]`:           Unmodified decay timescales for each carbon reservoir
- `r::Vector{<:Real}=[33.9, 0.0188, 2.67, 0]`:              Coefficients determining state-dependence of decay timescales
- `ϵ₁::Real=4.57`:                                          Weight of logarithmic forcing
- `ϵ₂::Real=0`:                                             Weight of linear forcing
- `ϵ₃::Real=0.086`:                                         Weight of square-root forcing
- `TCR::Real=1.79`:                                         Transient Climate Response
- `RWF::Real=0.552`:                                        Realized Warming Fraction
- `F2x::Real=3.759`:                                        Forcing from CO₂ doubling
- `d::Vector{<:Real}=[0.903, 7.92, 355]`:                   Thermal response timescales
- `q1::Real=0.18`:                                          Thermal response coefficient for first thermal box  
- `E2C::Real=0.46888759388759393`:                          Emissions to concentration conversion factor
- `Oₑₓ::Vector{<:Real}=[0 for t in timeperiods]`:           Series of exogenous forcing
- `R0::Vector{<:Real}=[0, 0, 0, 0]`:                        Initial concentrations in each carbon reservoir
- `β0::Real=0`:                                             Initial state-dependent decay-rate adjustment parameter
- `S0::Vector{<:Real}=[0, 0, 0]`:                           Initial partial temperatures in each thermal box
- `T0::Real=0`:                                             Initial temperature above pre-industrial level
- `FAiR::Union{Nothing, Mimi.AbstractModel}=nothing`:       Mimi representation of the FAiR model for calibration


See also: 

    [`climate_calib_temperature_params`](@ref) for calibration of other thermal response coefficients (called internally)

    [`climate_calib_g0`](@ref) for calibration of g0 (called internally)

    [`climate_calib_g1`](@ref) for calibration of g1 (called internally)

    [`climate_calib_init`](@ref) for calibration of initial carbon concentrations and temperature (called internally)        
"""
function climate_calib_complete(years ;a::Matrix{<:Real} = [.2173 1 1; .224 0 0; .2824 0 0; .2763 0 0],
                                 τ::Matrix{<:Real} = [1e9 8.25 100; 394.4 1 1; 36.54 1 1; 4.304 1 1],
                                 r::Matrix{<:Real} = [33.9 8.25 63.2; 0.0188 0 0; 2.67 -0.3 0; 0 0.00032 0],
                                 ϵ₁::Vector{<:Real} = [4.57, 0, 0], 
                                 ϵ₂::Vector{<:Real} = [0, 0.000163, 0.000663], 
                                 ϵ₃::Vector{<:Real} = [0.086, 0.038, 0.106],
                                 TCR::Real=1.79, RWF::Real=.552, F2x::Real=3.759,
                                 d::Vector{<:Real} = [0.903, 7.92, 355], q1::Real = 0.180, E2C::Vector{<:Real} = [0.46888759388759393, 0.351665695415695, 0.200951825951825],
                                 E2R::Vector{<:Real} = [12/44, 1, 28/44], Oₑₓ::Vector{<:Real} = fill(0., length(years)), 
                                 R0::Matrix{<:Real} = [0. 0. 0.; 0. 0. 0.; 0. 0. 0.; 0. 0. 0.], Ecum0::Vector{<:Real} = [0., 0., 0.],
                                 β0::Vector{<:Real} = [0., 0., 0.], S0::Vector{<:Real} = [0., 0., 0.], T0::Real = 0., FAiR::Union{Nothing, Mimi.AbstractModel}=nothing)
    a = Dict((:climate, :a) => a)
    τ = Dict((:climate, :τ) => τ)
    r = Dict([(:climate, sym) for sym in [:r₀, :rᵤ, :rₜ, :rₐ]] .=> [r[i, :] for i in 1:size(r)[1]])
    ϵ = Dict([(:climate, sym) for sym in [:ϵ₁, :ϵ₂, :ϵ₃]] .=> [ϵ₁, ϵ₂, ϵ₃])
    d = Dict((:climate, :d) => d)
    E2R = Dict((:climate, :E2R) => E2R)
    q = climate_calib_temperature_params(TCR=TCR, RWF=RWF, F2x=F2x, d=d, q1=q1)
    g₁ = climate_calib_g1(a, τ)
    g₀ = climate_calib_g0(a, τ, g₁)
    initial = Dict([(:climate, sym) for sym in [:E2C, :R0, :β0, :S0, :T0, :Ecum0]] .=> [E2C, R0, β0, S0, T0, Ecum0])
    merged = merge(a, τ, r, ϵ, q, d, E2R, Dict((:climate, :g₀) => g₀, (:climate, :g₁) => g₁), initial)
    update_params!(FAiR, merged)
    merged[(:climate, :Oₑₓ)] = Oₑₓ  # Add exogenous forcings after FAiR parameter update
    sim = climate_calib_init(years, FAiR = FAiR) # year should be a variable in the outer function
    for sym in [:R0, :β0, :S0, :T0, :C₀, :Ecum0]
        merged[(:climate, sym)] = sim[(:climate, sym)]
    end
    return merged
end