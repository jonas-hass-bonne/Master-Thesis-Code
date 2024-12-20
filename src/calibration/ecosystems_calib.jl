#########################################################
# This file provides functions to set parameter values  #
# for the damage functions in the GreenDICE model       #
#########################################################

# NOTICE: ALL CONTENTS OF THE FILE IS SUBJECT TO CHANGE
# THIS IS SIMPLY FOR INITIAL TESTING PURPOSES

"""
    ecosystems_calib_complete(; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function ecosystems_calib_complete(years; Aᵉ = [50 for _ in years], αᵉ = 0.5, υᵉ0 = 1)
    exo = Dict(([(:production, sym) for sym in [:Aᵉ, :αᵉ]]  .=> [Aᵉ, αᵉ])..., :υᵉ0 => υᵉ0)
    return exo
end