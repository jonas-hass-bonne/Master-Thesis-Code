##############################################################
## This file provides auxiliary functions for general usage ##
######### across the other main parts of the project #########
##############################################################

getDirsAndFiles() = readdir(; join=true, sort=false)    # Convenience function to get full paths 

"""
   rangeshift(r::AbstractRange, s::Integer)

Return a range shifted by a set amount `s`, changing the `start` and `end`
of the range to `start + s` and `end + s` keeping the `step` of the range unchanged
"""
rangeshift(r::AbstractRange, s::Integer) = first(r)+s:step(r):last(r)+s     

######################################################################
### DEFINE A FUNCTION TO CONVENIENTLY EVALUATE CES EXPRESSIONS     ###
### USING THE COMMON TWO INPUTS AND TWO CENTRAL PARAMETERS φ and σ ###
######################################################################

"""
    CES(a, b; phi=0.5, sigma=1)

Computes the CES function defined by:

``CES(a, b, φ, σ) = ((1 - φ) * a^( (σ - 1) / σ ) + φ * b^( (σ - 1) / σ ))^( σ / (σ - 1))``

Using `phi` as the value for ϕ and `sigma` as the value for σ. 
In the special case where `sigma` = 1, instead computes the CD function defined by:

``CD(a, b, φ) = a^(1 - φ) * b^φ``

Note that the inputs `a` and `b` along with `sigma` should all be positive
and that `phi` should be between 0 and 1 in order for the function
to be well-behaved.
"""
function CES(a, b; phi=0.5, sigma=1)
    if a <= 0 || b <= 0 # return close to zero if evaluation is infeasible
        return 1e-9
    end 
    if sigma == 1   # Return limiting CD-function
        return a^(1 - phi)*b^(phi)
    end
    return ((1 - phi) * a^( (sigma - 1) / sigma) + phi * b^( (sigma - 1) / sigma ))^(sigma / (sigma - 1) )
end

#################################################################
### DEFINE A FUNCTION TO CONVENIENTLY EVALUATE SEMI-PERMANENT ###
##### DAMAGE FUNCTION USING CURRENT AND MAXIMUM TEMPERATURE #####
#################################################################

# NOTE: ADD SOME DOCUMENTATION FOR THESE AT SOME POINT

function land_damage(T::Real, Tmax::Real; psi::Real, phi::Real, υ0::Real = 1, υmax::Real = 1.1)
    υ = ifelse(T >= 0 ,
        1 / (1 + psi * (1 - phi) * T^2 + psi * phi * Tmax^2), 
        υmax / (1 + exp(T + log(υmax) + log((1 + psi * phi * Tmax^2 - υ0) / υ0 )))
        )
    return υ
end

function gdp_damage(T::Real; psi1::Real, psi2::Real)
    dam = (psi1 * T + psi2 * T^2) / (1 + psi1 * T + psi2 * T^2)
    
    return dam
end

######################################################################################
### DEFINE FUNCTIONS TO CONVENIENTLY RETRIEVE INFO FROM A MIMI.FIXEDTIMESTEP TYPE  ###
### SPECIFICALLY, TO RETRIEVE THE FIRST AND LAST YEAR AS WELL AS THE TIMESTEP SIZE ###
######################################################################################

"""
    first_year(t::Mimi.FixedTimestep{FIRST, STEP, LAST})

Returns the first year registered in the timestep as an integer
"""
function first_year(ts::Mimi.FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
    return FIRST
end

"""
    last_year(t::Mimi.FixedTimestep{FIRST, STEP, LAST})

Returns the last year registered in the timestep as an integer
"""
function last_year(ts::Mimi.FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
    return LAST
end

"""
    year_delta(t::Mimi.FixedTimestep{FIRST, STEP, LAST})

Returns the number of years between each timestep 
registered in the timestep as an integer
"""
function year_delta(ts::Mimi.FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
    return STEP
end

"""
    timeidx(m::Mimi.AbstractModel, year::Integer)

Return the index in the time dimension for the model `m` corresponding to `year` as an integer
"""
function timeidx(m::Mimi.AbstractModel, year::Integer)
    return m.md.dim_dict[:time][year]
end

######################################################################
### DEFINE FUNCTIONS TO ROBUSTLY UPDATE PARAMETERS IN A MIMI MODEL ###
### USING A COMPONENT WHERE AN INSTANCE OF THE PARAMETER IS USED   ###
### AS AN IDENTIFIER FOR THE PARAMETER, REGARDLESS OF WHETHER THE  ###
### PARAMETER IS SHARED ACROSS THE MODEL OR NOT                    ###
######################################################################

"""
    robust_update_param!(m::Mimi.AbstractModel, component::Symbol, parameter::Symbol, value::Union{<:Real, AbstractArray{<:Real, N} where N})

Update a `parameter` in the Mimi model `m` which is located in `component` to `value`. The shape of `value` must match the shape of `parameter`

The function will automatically identify if `parameter` is a shared model parameter and update the shared model parameter if this is the case using
    
    update_param!(m, shared_parameter, value)

Where ´shared_parameter` is determined internally in the function. If the parameter is not shared, it will be updated using 

    update_param!(m, component, parameter, value)

See [`update_param!`](@Ref) for how Mimi handles parameter updates internally

Returns nothing, as the `parameter` is updated in-place
"""
function robust_update_param!(m::Mimi.AbstractModel, component::Symbol, parameter::Symbol, value::Union{T, AbstractArray{T, N} where N} where T <: Union{Missing, Number})
    # Identify when the parameter is a shared model parameter
    shared_parameter = Mimi.get_model_param_name(m.md, component, parameter)
    if Mimi.is_shared(Mimi.model_param(m.md, shared_parameter))
        update_param!(m, shared_parameter, value)
    else
        update_param!(m, component, parameter, value)
    end
    return nothing
end

"""
    robust_update_param!(m::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, values::Vector{<:Real})

Iteratively update the `parameters` in the Mimi model `m` located in their respective `components` using `values`. 
The length of the `parameters` vector must match the length of the `components` vector

The `values` must be supplied as a vector, which will be reshaped to match the shape of the parameter being updated.
As such, the length of the `values` vector must equal the combined length of the `parameters`

Each parameter update is handed off to the single-parameter update method 

Returns nothing, as the `parameters` are updated in-place
"""
function robust_update_param!(m::Mimi.AbstractModel, components::Vector{Symbol}, names::Vector{Symbol}, values::Vector{<:Real})
    startidx = 1
    for (comp, param) in zip(components, names)
        shape = size(m[comp, param])
        idx = startidx:*(shape...) - 1 + startidx
        reshaped_values = reshape(values[idx], shape)
        robust_update_param!(m, comp, param, reshaped_values)
        startidx = idx[end] + 1
    end
    return nothing
end

"""
    robust_update_param_year!(m::Mimi.AbstractModel, component::Symbol, parameter::Symbol, year::Integer, value::Union{<:Real, AbstractArray{<:Real, N} where N})

Update a `parameter` in the Mimi model `m` which is located in `component` in `year` to `value`. The specified `year` can either be an index value or a key in
the model time dimension `m.md.dim_dict[:time]`

The length of `value` must match the length of `parameter` in `year`

A new matrix of `update_value` for the `parameter` is constructed where the value in `year` is updated to `value` before being passed to

    robust_update_param(m, component, parameter, update_value)

See [`robust_update_param`](@Ref) for how it updates the `parameter`

Returns nothing, as the `parameter` is updated in-place
"""
function robust_update_param_year!(m::Mimi.AbstractModel, component::Symbol, parameter::Symbol, year::Integer, value::Union{<:Real, AbstractArray{<:Real, N} where N})
    if year in keys(m.md.dim_dict[:time].dict)
        year = timeidx(m, year)
    end

    update_value = copy(m[component, parameter])
    selectdim(update_value, 1, year) .= value
    robust_update_param!(m, component, parameter, update_value)
    return nothing
end

"""
    robust_update_param_year!(m::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, year::Integer, value::Vector{<:Real})

Iteratively update the `parameters` in the Mimi model `m`located in their respective `components` in `year`. The specified `year` can either be an
index value or a key in the model time dimension `m.md.dim_dict[:time]`

The `values` must be supplied as a vector, which will be reshaped to match the shape of the parameter being updated.
As such, the length of `values` must equal the combined length of the `parameters`

Each parameter update is handed off to the single-parameter update method

Returns nothing, as the `parameters` are updated in-place
"""
function robust_update_param_year!(m::Mimi.AbstractModel, components::Vector{Symbol}, names::Vector{Symbol}, year::Integer, value::Vector{<:Real})
    startidx = 1
    for (comp, param) in zip(components, names)
        dims = ndims(m[comp, param])
        selector = [i == 1 ? year : Colon() for i in 1:dims]    # Assume first dimension is time
        shape = size(m[comp, param][selector...])
        idx = startidx:*(1, shape...) - 1 + startidx
        reshaped_vals = reshape(value[idx], shape) 
        robust_update_param_year!(m, comp, param, year, reshaped_vals)
        startidx += length(idx)
    end
    return nothing
end

#########################################################
### DEFINE FUNCTIONS TO PERFORM OPTIMIZATION ROUTINES ###
### SUCH AS LEAST SQUARES CURVE FITTING, BOUNDED      ###
### GRADIENT DESCENT AND NEWTON-RHAPSON ROOT FINDING  ###
#########################################################


# NOTE: In the current implementation, it's implicitly assumed that
# the supplied parameters must maintain their initial sign
# This is not necessarily a desired behaviour and perhaps warrants
# a future update to allow for optional specification of explicit bounds
# for the various parameters
"""
    lsq_curve_fit(f::Function, y::Vector{<:Real}, init::Vector{<:Real}; 
    tol::Real=1e-6, maxiter::Integer=Int(1e5), maxnonimprovement::Integer=20,
    max_stepsize::Vector{<:Real}=[1. for _ in eachindex(init)])

Fit a curve to a set of points. It's assumed that the function `f` takes the
supplied points `y` as the first input and the parameters in `init` as the following inputs

Further, it's assumed that `f` returns the criterion value which is used to evaluate the Fit
in such a way that the criterion value is minimized. 

The process is terminated when the relative improvement in the criterion value is smaller
than `tol` or when the criterion hasn't improved for `maxnonimprovement` iterations in a row.

Additionally, an error will be thrown if neither of the two stopping conditions are met
within `maxiter` number of total iterations. 

The `max_stepsize` vector determines the initial maximum stepsize used in the curve fitting
process. The stepsizes can be updated during the fitting process to improve convergence
towards a local minimum.
"""
function lsq_curve_fit(f::Function, y::Array{<:Real}, init::Vector{<:Real}; 
                        tol::Real=1e-6, maxiter::Integer=Int(1e5), maxnonimprovement::Integer=20,
                        max_stepsize::Vector{<:Real}=[1. for _ in eachindex(init)])
    func(x) = f(y, x...)    # Make a local objective function based on supplied y
    fval = func(init)   # Make initial evaluation
    vars = copy(init)    # Copy initial values
    fgrad(x) = ForwardDiff.gradient(func, x)    # Use ForwardDiff to make a gradient function
    gradval = fgrad(vars)    # Compute initial gradient
    threshold = sign.(init) # Identify whether values should be positive or negative based on inital values
    linesearch = sign.(gradval) .* min.(fval ./ abs.(gradval), max_stepsize)   # Compute the linesearch value
    iter = 1
    delta = 1
    bounceback = false
    idx = argmax(abs.(gradval) .* max_stepsize)
    non_improvement = 0

    while delta >= tol # Terminate if relative improvement is small
        newvars = vars .- linesearch
        newfval = func(newvars)
        if newfval < fval   # If improvement is achieved, continue as-is
            delta = (fval - newfval)/fval # Determine relative improvement
            vars = newvars    
            fval = newfval
            gradval = fgrad(vars)
            max_stepsize[idx] *= bounceback ? 2 : 1 # Adjust stepsize if registered
            bounceback = false  # Register that stepsize should not be updated on next improvement
            non_improvement = 0  # Reset non-improvement counter
        else
            non_improvement += 1    # Increment non-improvement counter
            bounceback = true   # Register that stepsize should be adjusted during next improvement
            idx = argmax(abs.(gradval .* max_stepsize)) # Identify steepest gradient element
            max_stepsize[idx] *= 25e-2   # Reduce stepsize for the steepest gradient element in case of non-improvement
        end
        linesearch = sign.(gradval) .* min.(fval ./ abs.(gradval), max_stepsize)   # Compute the linesearch value
        
        iter += 1   # Increment iteration counter
        if iter >= maxiter
            error("Maximum iterations exceeded, terminating algorithm")
        end

        if non_improvement >= maxnonimprovement
            println("Objective not improving after ", maxnonimprovement, " iterations, returning current best guess")
            break
        end
    end

    return vars
end

"""
    NewtonRaphsonRoot(func::Function, var::Real, bounds::Vector{<:Real}; grad::Union{Function, Nothing}=nothing, tol::real=1e-6, maxiter=1000)

Returns the root of `func` using the Newton-Raphson method with `var` as the initial point.

The signature of `func` is assumed to be `func(x::Real)`

If no derivative for the function is supplied, an approximate derivative is computed using [`ForwardDiff.derivative`](@ref)

This method uses finite bounds for the variable to determine the step-size of each iteration. As such, the method is most well-behaved when
the root of the function is in the interior of the bounds and performs poorly when the root is close to the bounds.

The bounds are specified as a vector of length 2, with the lower bound as the first element and the upper bound as the second

The algorithm is terminated when the function value is less than `tol`, or if
the number of iterations exceeds `maxiter`, in which case an exception is thrown.
"""
function NewtonRaphsonRoot(func::Function, var::Real, bounds::Vector{<:Real}; 
                           grad::Union{Function, Nothing}=nothing,
                           tol::Real=1e-6, maxiter=1000)
    ### ERROR HANDLING START ###

    # Check that supplied bounds only contains two values (lower and upper)
    if length(bounds) != 2
        blen = length(bounds)
        throw(ArgumentError("The `bounds` should be specified as a Vector with length 2, the supplied `bounds` have length $blen"))
        
    end

    # Check that supplied bounds follows the specified format
    if bounds[1] >= bounds[2]
        throw(ArgumentError("The `bounds` should be specified with the lower bound as the first element, but the first element is larger or equal to the second element"))
    end

    # Check that initial value is within bounds
    if !(bounds[1] < var < bounds[2])
        throw(DomainError(var, "The initial point `var` should be within the specified bounds, but the initial point is $var while the specified bounds are $bounds"))
    end

    ### ERROR HANDLING END ###

    # Initial function value and gradient
    fval = func(var)
    if grad === nothing # If gradient is unspecified, use approximation
        fgrad(x) = ForwardDiff.derivative(func, x)
    else
        fgrad = grad
    end

    # Check extreme values
    if abs(func(bounds[1])) < tol
        return bounds[1]
    elseif abs(func(bounds[2])) < tol
        return bounds[2]
    end

    delta = abs(fval)
    iter = 1
    
    # While difference exceeds tolerance, improve guess
    while delta >= tol
        gradval = fgrad(var)
        adjustmentrate = (1 - exp(-abs(fval/gradval)))
        var += sign(fval/gradval) < 0 ? (bounds[2] - var) * adjustmentrate : -(var - bounds[1]) * adjustmentrate
        fval = func(var)
        delta = abs(fval)
        
        iter += 1
        if iter >= maxiter
            println("Maximum iterations exceeded, terminating algorithm and returning current best guess")
            println("Current function value is $fval")
            return var
        end
    end
    return var
end

function BoundedGradientDescent(func::Function, var::Vector{<:Real};
                                grad::Union{Function, Nothing}=nothing, stepsize=0.5,
                                tol::Vector{<:Real}=[1e-6 for _ in eachindex(var)], maxiter=1000, 
                                bounds=vcat([[0. 1.] for _ in eachindex(var)]...))
    # Initial step - function valuation and gradient determination
    fval = func(var)
    if grad === nothing # If gradient is unspecified, use ForwardDiff approximation
        fgrad(x) = ForwardDiff.gradient(func, x)
    else 
        fgrad = grad
    end

    # Construct bounding boxes based on bounds and initialize routine
    bbox = bounds
    iter = 1

    while any(bbox[:, 2] .- bbox[:, 1] .>= tol)
        gradval = fgrad(var)
        bbox[gradval .<= 0, 1] = var[gradval .<= 0]
        bbox[gradval .>= 0, 2] = var[gradval .>= 0]
        var .-= stepsize .* (bbox[:, 2] .- bbox[:, 1]) .* sign.(gradval)
        iter += 1
        fval = func(var)

        if iter > maxiter
            error("Maximum iterations exceeded, terminating algorithm")
        end
    end

    return var
end

function BoundedGradientDescent(func::Function, var::Vector{<:Real},
                                ineqcons::Vector{<:Function}, ineqconsid::Vector{<:Any}, varidx::Vector{<:Any}, varflags::Vector{Bool};
                                grad::Union{Function, Nothing}=nothing, lambda::Vector{<:Real}=[1e4 for _ in eachindex(ineqcons)],
                                tol::Vector{<:Real}=[1e-6 for _ in eachindex(var)], maxiter=1000, stepsize=0.5,
                                bounds=vcat([[0. 1.] for _ in eachindex(var)]...))
    # Initial step - function valuation and gradient determination
    conj_func(var) = func(var) + sum([lambda[i] * max(ineqcons[i](var), 0) for i in eachindex(ineqcons)])
    fval = conj_func(var)
    if grad === nothing
        fgrad(x) = ForwardDiff.gradient(conj_func, x)
    else
        fgrad = grad
    end

    # Construct bounding boxes based on bounds
    bbox = bounds
    iter = 1

    # Initialize the routine - consider reworking the exit criteria to take account of mutually bounded variables
    while any(bbox[:, 2] .- bbox[:, 1] .>= tol)
        gradval = fgrad(var)
        if all([ineqcons[i](var) for i in eachindex(ineqcons)] .<= 0)
            # Standard updating scheme - slice up the bounding box
            bbox[gradval .<= 0, 1] = var[gradval .<= 0]
            bbox[gradval .>= 0, 2] = var[gradval .>= 0]
            var .-= stepsize .* (bbox[:, 2] .- bbox[:, 1]) .* sign.(gradval) 

            # For a future revision, this is a method to update in a 2d-grid box for later implementation
            # There seems to be an issue with being able to assign values outside the specified bounds,
            # leading to non-convergence. This may be related to a needed change in the conversion criterion
            # which takes into account 2d values nearing the triangular edge of their box
            # for (idx, flag) in zip(varidx, varflags)
            #     adj = (bbox[idx, 2] .- bbox[idx, 1]) .* sign.(gradval[idx])
            #     if flag # Check if moving in 2d grid
            #         if all(gradval[idx] .<= 0) # Both shares should increase, potential to shoot outside allowed grid
            #             adj = ((1 - sum(bbox[idx, 1])) / length(idx)) .* sign.(gradval[idx])   # (Negative of) Maximum increase for each direction
            #         end
            #     end
            #     var[idx] .-= stepsize .* adj
            # end
        else    # Updating scheme in case an inequality constraint is violated - Don't update bounding boxes and reduce relevant variables
            for i in eachindex(ineqcons)
                violation = ineqcons[i](var) >= 0
                if violation
                    idx = union(varidx[ineqconsid[i]]...)
                    var[idx] .-= (var[idx] .- bbox[idx, 1]) .* stepsize  
                end
            end
        end

        iter += 1
        fval = conj_func(var)

        if iter > maxiter
            error("Maximum iterations exceeded, terminating algorithm")
        end
    end

    return var
end
