module ECHOsched

using DataFrames, Dates, CSV, StatsBase, Statistics, Clustering, PlotlyJS # PUBLIC
using util # DEV

include("structs.jl")
include("gatherData.jl")
# include("extractSchedules.jl")
include("dataFixes.jl")
include("cooling/cooling_segments.jl")



# Write your package code here.

export cooling_onoff_segmentation

end
