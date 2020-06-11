
struct SmartMeter
    id::String
    dat::Array{Float64,2}
    tVec::Array{DateTime,1}
end

mutable struct Project_SMSPS
    path::Dict
    fullDataList::Array{String,1}
    dataIndices
    smartMeters::Array{SmartMeter,1}
    summaryData::DataFrame
    htgSchedules::DataFrame
    verbose::Array{DataFrame,1}
    Project_SMSPS() = new()
end
