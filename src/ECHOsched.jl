module ECHOsched

using DataFrames, Dates, CSV, StatsBase, Statistics, Clustering # PUBLIC
using util # DEV

include("structs.jl")
include("gatherData.jl")
# include("extractSchedules.jl")
include("dataFixes.jl")
include("cooling/cooling_segmentation.jl")



# Write your package code here.

export cooling_onoff_segmentation

end
