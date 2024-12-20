#########################################################
# This file provides functions to set parameter values  #
# for the damage functions in the GreenDICE model       #
#########################################################

# NOTICE: ALL CONTENTS OF THE FILE IS SUBJECT TO CHANGE
# THIS IS SIMPLY FOR INITIAL TESTING PURPOSES

function damages_calib_land(;share=0.0793, total=0.02166875)
    υ = 1 - share * total
    ψ = (1-υ) / (υ * 2.5^2)
    
    return ψ
end

function damages_calib_manufacturing(;ψ₁=0, ψ₂=0.003467, share=0.5942)
    ψ₁ *= share
    ψ₂ *= share
    
    return (ψ₁, ψ₂)
end

# NOTE: Baseline shares are from Table 3 in the meta-analysis by Tol (2024) (average column, divided by total summed impacts)

"""
    damages_calib_complete(; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function damages_calib_complete(years; ψᵐ¹=0, ψᵐ²=0.003467,
                                 cropshare=0.0793, ϕᶜ=0.2,
                                 livestockshare=0.0424, ϕˡ=0.2,
                                 ecosystemshare = 0.2841, ϕᵉ=0.5, sectors=model_sectors)
    base25dam = ψᵐ¹ * 2.5 + ψᵐ² * 2.5^2 # Baseline damages at 2.5 degrees (Nordhaus calibration)
    ψᶜ = damages_calib_land(share=cropshare, total=base25dam)
    ψˡ = damages_calib_land(share=livestockshare, total=base25dam)
    ψᵉ = damages_calib_land(share=ecosystemshare, total=base25dam)
    (ψᵐ¹, ψᵐ²) = damages_calib_manufacturing(ψ₁=ψᵐ¹, ψ₂=ψᵐ², share=1 - cropshare - livestockshare - ecosystemshare)
    damagesDict = Dict([(:welfare, sym) for sym in [:ψ¹, :ψ², :ϕ]] .=> [[ψᵐ¹, 0., 0., 0.], [ψᵐ², ψᶜ, ψˡ, ψᵉ], [0., ϕᶜ, ϕˡ, ϕᵉ]])
    calibDict = Dict(sectors .=> [Dict([sym for sym in [:ψ¹, :ψ², :ϕ]] .=> [damagesDict[(:welfare, sym)][i] for sym in [:ψ¹, :ψ², :ϕ]]) for i in eachindex(sectors)])
    return damagesDict, calibDict
end