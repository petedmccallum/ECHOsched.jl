module ECHOsched

using DataFrames, Dates, CSV, StatsBase, Statistics, Clustering, PlotlyJS # PUBLIC
using Interpolations
using util # DEV

include("structs.jl")
include("gatherData.jl")
# include("extractSchedules.jl")
include("dataFixes.jl")
include("cooling/cooling_segments.jl")
include("cooling/Util.jl")



# Write your package code here.

export cooling_onoff_segmentation

end
