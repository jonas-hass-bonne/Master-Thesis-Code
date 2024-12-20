###############################################################
# This file contains functions to define a list of parameters #
# used in the model                                           #
###############################################################

#######################################
# Load in parameter calibration files #
#######################################

calibration_dir_path = "calibration/"
getDirsAndFiles() = readdir(; join=true, sort=false)    # Convenience function to get full paths 
calibration_dir = cd(getDirsAndFiles, calibration_dir_path)
include.(calibration_dir);


"""
    complete_param_calib(<keyword arguments>)

NOTICE: TEMPORARY

Return a dictionary with Symbol => Value pairs for all
parameters in the model. 

The parameter values can be adjusted by supplying 
appropriate dictionaries as keyword arguments.
The key-value pairs in the passed dictionary will
be unpacked as keyword arguments in the module
referenced by the keyword.

# Available keyword arguments:
- Abatement
- Agriculture
- Climate
- Damages
- Ecosystems
- Emissions
- Initial 
- Manufacturing
- Utility

See also:

|                                        |     |                                                      | 
| :------------------------------------- | :-: | :--------------------------------------------------- |
| [`abatement_calib_complete`](@ref)     |     | For available parameters in the climate module       |
| [`agriculture_calib_complete`](@ref)   |     | For available parameters in the agriculture module   |
| [`climate_calib_complete`](@ref)       |     | For available parameters in the climate module       |
| [`damage_calib_complete`](@ref)        |     | For available parameters in the damages module       |
| [`ecosystems_calib_complete`](@ref)    |     | For available parameters in the ecosystems module    |
| [`emissions_calib_complete`](@ref)     |     | For available parameters in the emission module      |
| [`initial_calib_complete`](@ref)       |     | For available parameters in the initial module       |
| [`manufacturing_calib_complete`](@ref) |     | For available parameters in the manufacturing module |
| [`utility_calib_complete`](@ref)       |     | For available parameters in the utility module       |
"""
function complete_param_calib(years, sectors; kwargs...)

    # Define dictionaries with keyword arguments
    # to pass along to each function
    abatementDict     = haskey(kwargs, :Abatement)     ? kwargs[:Abatement]     : Dict()
    agricultureDict   = haskey(kwargs, :Agriculture)   ? kwargs[:Agriculture]   : Dict()
    climateDict       = haskey(kwargs, :Climate)       ? kwargs[:Climate]       : Dict()
    damagesDict       = haskey(kwargs, :Damages)       ? kwargs[:Damages]       : Dict()
    ecosystemsDict    = haskey(kwargs, :Ecosystems)    ? kwargs[:Ecosystems]    : Dict()
    emissionsDict     = haskey(kwargs, :Emissions)     ? kwargs[:Emissions]     : Dict()
    initialDict       = haskey(kwargs, :Initial)       ? kwargs[:Initial]       : Dict()
    manufacturingDict = haskey(kwargs, :Manufacturing) ? kwargs[:Manufacturing] : Dict()
    utilityDict       = haskey(kwargs, :Utility)       ? kwargs[:Utility]       : Dict()

    # Obtain calibrated parameters for the FaIR model
    climateDict = climate_calib_complete(years; climateDict...)

    # Use temporary function to set emissions parameters
    emissionsDict = emissions_calib_complete(years; emissionsDict...)

    # Use temporary function to set damage parameters
    damagesDict, calibDict = damages_calib_complete(years; sectors=sectors, damagesDict...)

    # Use temporary function to set agricultural parameters
    agricultureDict = agriculture_calib_complete(years; damageParamDict = calibDict, agricultureDict...)

    # Use temporary function to set manufacturing parameters
    manufacturingDict = manufacturing_calib_complete(years ;damageParamDict = calibDict, manufacturingDict...)

    # Use temporary function to set utility parameters
    utilityDict = utility_calib_complete(years; utilityDict...)
    
    # Use temporary function to set abatement parameters
    abatementDict = abatement_calib_complete(years; γ=emissionsDict[(:climate, :γ)], abatementDict...)

    # Use temporary function to set ecosystem parameters
    ecosystemsDict = ecosystems_calib_complete(years; ecosystemsDict...)

    # Use a temporary function to set initial stock values
    initialDict = initial_calib_complete(years; initialDict...)

    # Parameters that should be merged based on values in production dicts
    σˢ = [1., agricultureDict[(:production, :σᶜ)], agricultureDict[(:production, :σˡ)], 1.]
    φˢ = [1., agricultureDict[(:production, :φᶜ)], agricultureDict[(:production, :φˡ)], 1.]
    υ0 = [1., agricultureDict[:υᶜ0], agricultureDict[:υˡ0], ecosystemsDict[:υᵉ0]]
    A  = [manufacturingDict[(:production, :Aᵐ)] agricultureDict[(:production, :Aᶜ)] agricultureDict[(:production, :Aˡ)] ecosystemsDict[(:production, :Aᵉ)]]

    mergeDict = Dict(([(:production, sym) for sym in [:σˢ, :φˢ, :A]] .=> [σˢ, φˢ, A])..., :υ0_shared => υ0)
    
    # Delete unused keys from dictionaries
    delete!.(Ref(agricultureDict), vcat([(:production, sym) for sym in [:σᶜ, :σˡ, :φᶜ, :φˡ, :Aᶜ, :Aˡ]], [:υᶜ0, :υˡ0]));
    delete!.(Ref(ecosystemsDict), [(:production, :Aᵉ), :υᵉ0]);
    delete!(manufacturingDict, (:production, :Aᵐ));

    
    outDict = merge(abatementDict, agricultureDict, climateDict, damagesDict, ecosystemsDict, emissionsDict, initialDict, manufacturingDict, utilityDict, mergeDict)
    
    return merge(abatementDict, agricultureDict, climateDict, damagesDict, ecosystemsDict, emissionsDict, initialDict, manufacturingDict, utilityDict, mergeDict)
end