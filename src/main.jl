module MimiAGLUDICE

using Mimi
using Statistics
using Plots
using ForwardDiff

# Include convenience functions defined in auxiliary.jl
include("auxiliary.jl")    # Auxiliary functions
include("datafetch.jl")    # Data loading functions
include("parameters.jl")   # Calibration functions
include("optim.jl")        # Optimization functions
include("calcscx.jl")      # Social cost calculation functions

########################################
# Load in the components for the model #
########################################

component_dir_path = "components/"    # Path to directory where component files are located
component_dir = cd(getDirsAndFiles, component_dir_path) # Get contents of component directory
leaf_dirs = component_dir[isdir.(component_dir)]    # Identify list of directories for leaf components
composite_files = component_dir[occursin.("composite_", component_dir)]
include.(vcat(readdir.(leaf_dirs; join=true)...));   # Load all files in folders containing leaf modules
include.(composite_files);   # Load all composite component definition files

export constructmodel, ModelOptim, calc_sc_gas, robust_update_param!, robust_update_param_year!

####################
# Set up the model #
####################

# Define indices for the model
const model_years = 2015:2100
const model_sectors = ["Manufacturing", "Agriculture - Plants", "Agriculture - Animals", "Ecosystem Services"]
const model_reservoirs = 1:4
const model_boxes = 1:3
const model_ghgs = ["CO2", "CH4", "N2O"]
const FAiR_years = 1750:2022

function constructmodel(;calibrate::Bool=true)

   m = Model(Number)

   # Define dimensions
   set_dimension!(m, :time, model_years)           # Years
   set_dimension!(m, :sector, model_sectors)       # Sectors
   set_dimension!(m, :reservoir, model_reservoirs) # Carbon reservoirs
   set_dimension!(m, :box, model_boxes)            # Thermal boxes
   set_dimension!(m, :ghg, model_ghgs)             # Greenhouse gases

   # Add composite components to the model
   add_comp!(m, allocation, :allocation)
   add_comp!(m, production, :production)
   add_comp!(m, climate, :climate)
   add_comp!(m, welfare, :welfare)

   # Connect components internally

   # Connect input factors allocated in the allocation component
   # to their respective parameters in the production component
   connect_param!(m, :production, :K, :allocation, :K)
   connect_param!(m, :production, :L, :allocation, :L)
   connect_param!(m, :production, :X, :allocation, :X)

   # Connect manufacturing and food output from production component
   # to their respective parameters in the climate component
   connect_param!(m, :climate, :OUTPUT, :production, :OUTPUT)

   # Also connect them, along with plant-based food production, 
   # to their respective parameters in the welfare component
   connect_param!(m, :welfare, :OUTPUT, :production, :OUTPUT)
   connect_param!(m, :welfare, :Pᶜ, :production, :Pᶜ)

   # Connect temperatures from the climate component
   # to the temperature parameters in the welfare component
   connect_param!(m, :welfare, :T, :climate, :T)
   connect_param!(m, :welfare, :Tmax, :climate, :Tmax)

   # Connect land productivities from the welfare component
   # to their respective parameters in the production component
   connect_param!(m, :production, :υ, :welfare, :υ)

   # Connect capital stocks and land productivities 
   # from the welfare component to their respective parameters 
   # in the allocation component
   connect_param!(m, :allocation, :Ktot, :welfare, :Ktot)

   # connect_param!(m, :production, :υ, :welfare, :υ) # Potential duplicate

   # Finally, create shared parameters and connect them 
   # to their respective relevant components 
   add_shared_param!(m, :Ltot_shared, fill(0., length(model_years)), dims=[:time], data_type=Number)
   connect_param!(m, :allocation, :Ltot, :Ltot_shared)
   connect_param!(m, :welfare, :Ltot, :Ltot_shared)

   add_shared_param!(m, :K0_shared, 0., data_type=Number)
   connect_param!(m, :allocation, :K0, :K0_shared)
   connect_param!(m, :welfare, :K0, :K0_shared)

   add_shared_param!(m, :υ0_shared, fill(0., length(model_sectors)), dims=[:sector], data_type=Number)
   connect_param!(m, :production, :υ0, :υ0_shared)
   connect_param!(m, :welfare, :υ0, :υ0_shared)

   add_shared_param!(m, :μ_shared, fill(0., length(model_years), length(model_sectors), length(model_ghgs)), 
                     dims=[:time, :sector, :ghg], data_type=Number)
   connect_param!(m, :climate, :μ, :μ_shared)
   connect_param!(m, :welfare, :μ, :μ_shared)

   if calibrate
      ######################################################
      # Set up local FAiR instance and calibrate the model #
      ######################################################

      # Set up the FAiR model for calibration of initial climate state
      FAiR = Model(Number)

      # Define dimensions
      set_dimension!(FAiR, :time, FAiR_years)             # Years
      set_dimension!(FAiR, :reservoir, model_reservoirs)  # Carbon reservoirs
      set_dimension!(FAiR, :box, model_boxes)             # Thermal boxes
      set_dimension!(FAiR, :ghg, model_ghgs)              # Greenhouse gases

      add_comp!(FAiR, FAiR_climate, :climate)

      params = complete_param_calib(model_years, model_sectors, Climate=Dict(:FAiR => FAiR))
      update_params!(m, params)
   end

   return m
end

end # module definition end