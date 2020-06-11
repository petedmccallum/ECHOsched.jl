using ECHOsched
using Test

@testset "ECHOsched.jl" begin
    # Write your tests here.
end


pth="C:/Users/arch/Dropbox/5-Data/DATA/EnergyMeter/UKDS-7591/DwellingDatasets"
query="GasDemand_kWhPer30min"
N=5

@time InitProject(;N=1:100,pth=pth,query=query)
