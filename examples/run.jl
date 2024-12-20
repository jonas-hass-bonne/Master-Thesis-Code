############################################################
## This file imports the model code and runs the baseline ##
#### optimal scenario as well as the policy experiment #####
############################################################

include("../src/main.jl")   # Load the code file defining the module

using .MimiAGLUDICE # Import functions and definitions from the module

# Define the baseline model and determine optimal parameter values
m = constructmodel()
run(m)
optParams = ModelOptim(m, [:welfare, :welfare, :production], [:s, :μ, :ξᶠ])
robust_update_param!(m, [:welfare, :welfare, :production], [:s, :μ, :ξᶠ], [optParams...])
run(m)

# Define the policy experiment
years = m.md.dim_dict[:time]    # Convenience reference to model time dimension
policyVec = vcat([1. for _ in 1:10], [range(1., .45/.56, 16)...], [.45/.56 for _ in 27:length(years)])   # endpoint divided by intial point
policyξˣᶜ = [0.16 for _ in years] .* policyVec
policyξˣˡ = [0.4 for _ in years] .* policyVec
policyMat = [zeros(length(years)) policyξˣᶜ policyξˣˡ zeros(length(years))]

# Determine a new policy model and determine optimal parameter values
pm = deepcopy(m)    # Make a new model for the policy experiment
robust_update_param!(pm, :allocation, :ξˣ, policyMat)   # Implement the policy
run(pm)
poptParams = ModelOptim(pm, [:welfare, :welfare, :production], [:s, :μ, :ξᶠ])
robust_update_param!(pm, [:welfare, :welfare, :production], [:s, :μ, :ξᶠ], [optParams...])
run(pm)