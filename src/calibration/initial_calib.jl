#########################################################
# This file provides functions to set parameter values  #
# for the damage functions in the GreenDICE model       #
#########################################################

# NOTICE: ALL CONTENTS OF THE FILE IS SUBJECT TO CHANGE
# THIS IS SIMPLY FOR INITIAL TESTING PURPOSES

"""
    initial_calib_complete(; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function initial_calib_complete(years;s=[0.25 for _ in years], L=vcat(getpopdata(), getpopprojections()), X = 8.62339,    # X currently excluding non-modelled land
                                 μᵐ=hcat([[μ for _ in years] for μ in [0., 0., 0.]]...), 
                                 μᶜ=hcat([[μ for _ in years] for μ in [0., 0., 0.]]...), 
                                 μˡ=hcat([[μ for _ in years] for μ in [0., 0., 0.]]...), 
                                 δ = 0.1, ξᵏᵐ=[0.95 for _ in years], ξᵏᶜ=[0.025 for _ in years], # Depreciation rate taken from Barrage and Nordhaus (2023)
                                 ξˡᵐ=[0.68 for _ in years], ξˡᶜ=[0.1735 for _ in years], 
                                 ξˣᶜ=[0.16 for _ in years], ξˣˡ=[0.40 for _ in years], 
                                 ξᶠ = [0.8 for _ in years], K0 = (getwealthaccountsdata()[:,2] .+ getagcapdata()[1:end-2, 2])[18])

    # Allocation parameters
    ξˡᵐ = 1 .- 2 .* ξˡᶜ
    ξˡ  = [ξˡᵐ ξˡᶜ fill(0., length(years)) fill(0., length(years))]
    ξᵏ  = [ξᵏᵐ ξᵏᶜ fill(0., length(years)) fill(0., length(years))]
    ξˣ  = [fill(0., length(years)) ξˣᶜ ξˣˡ fill(0., length(years))]

    # Welfare parameters
    μ = Array{Float64}(undef, length(years), 4, 3) # Initialize array to hold all the abatement parameters 
    # Allocate the abatement parameters to their respective positions in the array
    for (i, mu) in zip(1:size(μ)[2], [μᵐ, μᶜ, μˡ, fill(0., length(years), 3)])
        μ[:, i, :] = mu
    end 
    choice = Dict((:welfare, :s) => s , :μ_shared => μ, 
                  ([(:allocation, sym) for sym in [:ξᵏ, :ξˡ, :ξˣ]] .=> [ξᵏ, ξˡ, ξˣ])..., 
                  (:production, :ξᶠ) => ξᶠ)

    # Shared parameters
    L = L."Population"[L."Year" .>= years[1]]
    if length(L) < length(years)
        L = vcat(L, [L[end]*mean(L[end-9:end]./L[end-10:end-1])^n for n in 1:length(years) - length(L)])
    end
    
    exo = Dict(:Ltot_shared => L, :K0_shared => K0, (:welfare, :δ) => δ, (:allocation, :Xtot) => X, (:climate, :Etot_scc) => zeros(length(years), 3), (:welfare, :m_scc) => zeros(length(years)))
    return merge(exo, choice)
end

