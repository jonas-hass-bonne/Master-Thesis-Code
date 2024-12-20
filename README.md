# Master-Thesis-Code
Code for the master thesis "Flipping the Capital Eclipse: The Role of Land use in Climate Change Policy"

## Running the simulation
In order to run the model simulation, a working copy of Julia must be installed, which can be obtained by [following this link](https://julialang.org/downloads).

Additionally, the following Julia packages must be installed:
- Mimi
- Statistics
- ForwardDiff
- CSV
- DataFrames
- XLSX

These packages can be installed from the Julia REPL using the following command:

    using Pkg
    Pkg.add(["Mimi", "Statistics", "ForwardDiff", "CSV", "DataFrames", "XLSX"])

The simulation can then be performed by including the run.jl file in the REPL using `include("path/to/examples/run.jl")`.

This file will setup and run the baseline optimal allocation as well as the policy experiment of reducing agricultural land area.

The outcomes of the baseline model is stored in the variable `m`, while the outcomes of the policy is stored in the variable `pm`

These can be accessed as normal Mimi model objects to retrieve values for any desired variables. You can refer to the [Mimi documentation](https://mimiframework.ord) for how to interact with and extract results from Mimi models.