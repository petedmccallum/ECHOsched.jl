# function ScheduleExtraction(; verboseOutput::Bool=false)

verboseOutput=true ## TEMP

## MAIN LOOP, THROUGH EACH DATA RECORD
# for n in 1:length(proj.dataIndices)

n=5 ## TEMP

## INIT LOCAL VARS
t = proj.smartMeters[n].tVec
dataSample = proj.smartMeters[n].dat
nDays = Dates.value(proj.smartMeters[n].nDays)

## SET UP VERBOSE OUTPUT IF REQUESTED
if verboseOutput == true
    proj.verbose[n] = DataFrame(
    date=[string(proj.smartMeters[1].tVec[i])[1:10] for i in 1:48:size(proj.smartMeters[1].tVec,1)],
    seed_L = fill!(Array{Float64}(undef,nDays),NaN),
    seed_M = fill!(Array{Float64}(undef,nDays),NaN),
    seed_H = fill!(Array{Float64}(undef,nDays),NaN),
    clusterAssignment = fill!(Array{Array{Int8}}(undef,nDays),fill!(Array{Int8}(undef,48),-99)),
    clusterAssignmentValue = fill!(Array{Array{Float64}}(undef,nDays),fill!(Array{Float64}(undef,48),NaN)))
    # clusterAssignment = fill!(Array{Array{Int8}}(undef,5),Array{Int8}(undef,48))
end

## INIT
nSamplesPlus1 = Int16(Second(24*3600)/proj.smartMeters[1].tRes)+1 ## PLUS ONE TO PICK UP EVENTS THAT TRANSCEND DAYS (OCCURING AT 00:00)

## SET UP DAY RANGE
days = 1:nDays

dataSample = FixJanFirst(t,dataSample) ## LINEARLY INTERPOLATE AT 00:00 1ST JAN IF ZERO VALUE
dataSample = FixMissedKwhReading(dataSample) ## INTERPOLATE FOR MISSED KWH READINGS

## PREPEND FINAL ROW FROM PREVIOUS DAY TO ALLOW FOR EVENTS OCCURING 00:00HRS
dataSample = vcat([dataSample[end,1] dataSample[end,1:end-1]'],dataSample)

## INITILALISE ARRAY
global binaryHeatingResponse
binaryHeatingResponse = fill!(Array{Float64}(undef,nSamplesPlus1,nDays),NaN)

## CREATE REGISTER FOR DAILY controlRegime
global controlRegime
controlRegime = Array{Union{Missing,String}}(missing,nDays)

## SCAN DAILY DATA
for dy in days
    ds = dataSample[:,dy]
    iNan = [i for i in 1:length(ds) if isnan(ds[i])]
    if length(iNan)==0

        ## SET SEEDS (FORCE 1D CLUSTER USING ZERO SECOND DIMENSION)
        dsCnt=[0 ((maximum(ds)-minimum(ds))*0.1+minimum(ds)) maximum(ds);zeros(1,3)]

        ## MAKE SUITABLE ARRAY FOR CLUSTERING (FORCE 1D CLUSTER USING ZERO SECOND DIMENSION)
        ds=[ds';zeros(1,nSamplesPlus1)]

        ## K-MEANS: 3 CLUSTERS FOR HIGH/MED/LOW
        clsr = Clustering.kmeans!(ds,dsCnt)

        ## RECORD CENTERS
        if verboseOutput == true
            clsrCenters = sort(clsr.centers[1,:])
            proj.verbose[n].seed_L[dy] = clsrCenters[1]
            proj.verbose[n].seed_M[dy] = clsrCenters[2]
            proj.verbose[n].seed_H[dy] = clsrCenters[3]
        end

        ## RECORD CLUSTER ASSIGNMENT VALUES
        pos = sortperm(clsr.centers[1,:])
        clsrAssgn = pos[clsr.assignments]
        if verboseOutput == true
            proj.verbose[n].clusterAssignmentValue[dy] = fill!(Array{Float32}(undef,48),NaN)
            proj.verbose[n].clusterAssignmentValue[dy][clsrAssgn[1:end-1].==1].=proj.verbose[n].seed_L[dy]
            proj.verbose[n].clusterAssignmentValue[dy][clsrAssgn[1:end-1].==2].=proj.verbose[n].seed_M[dy]
            proj.verbose[n].clusterAssignmentValue[dy][clsrAssgn[1:end-1].==3].=proj.verbose[n].seed_H[dy]
        end

        # REMOVE GENTLE RAMP AT START-UP
        rampBool = [join(clsrAssgn[i:(i+2)]).=="012" for i in 1:(nSamplesPlus1-2)]
        iRamp = [i for i in 1:length(rampBool) if rampBool[i]] .+ 1
        # TEMPORARY FIX
        [clsrAssgn[i] = 0 for i in iRamp]

        if verboseOutput == true
            proj.verbose[n].clusterAssignment[dy] = clsrAssgn[1:end-1] .-2
        end

        ## MAP HIGH/MED/LOW DATA TO 1/1/0
        clsrAssgn = Int8.((clsrAssgn).>1)

        binaryHeatingResponse[:,dy] = clsrAssgn
        # elseif maximum(ds)>0.2 && dataKrt<8 ## CATEGORISE AS "HtgCont" (CONTINUOUS)
        # controlRegime[dy] = 5
        # controlRegime[dy] = "c"
        # binaryHeatingResponse[:,dy] = ones(nSamplesPlus1,1)
        # else ## IF MAX LOAD IS <0.2kW AND KURTOSIS <8, CATEGORISE AS "HtgIdle"
        # controlRegime[dy] = 2
        # controlRegime[dy] = "i"
        # end
    else ## IF NaNS ARE IDENTIFIED, CATEGORISE AS "1_RejectedData"
        # controlRegime[dy] = 1
        controlRegime[dy] = "v"
    end
end

## BUILD ARRAY OF SCHEDULES FOR EACH DAY
sched = [[i/2 for i in 1:(size(binaryHeatingResponse,1)-1) if abs.(diff(binaryHeatingResponse[:,dy]))[i]==1] for dy in days]
## DETERMINE DAYS WHERE SCHEDULES ARE POPULATED
# println(sched)

global schedContInd, schedIdleInd, schedProgRandInd, schedRandInd
schedContInd = []
schedIdleInd = []
schedRandInd = []
schedProgRandInd = []
for dy in [dy for dy in days if !isequal(controlRegime[dy],"v")]
    if !isempty(sched[dy]) && iseven(length(sched[dy]))
        push!(schedProgRandInd,dy)
    elseif minimum(dataSample[:,dy]).>0.2
        push!(schedContInd,dy)
    elseif maximum(dataSample[:,dy]).<0.2
        push!(schedIdleInd,dy)
    else
        push!(schedRandInd,dy)
    end
end

# schedContInd = [dy for dy in days if isempty(sched[dy]) && maximum(dataSample[:,dy]).>0.2]
# schedIdleInd = [dy for dy in days if isempty(sched[dy]) && maximum(dataSample[:,dy]).<0.2]
# schedProgRandInd = [dy for dy in days if ~isempty(sched[dy])]

# println(schedRandInd)
# println(controlRegime)
for sR in schedRandInd
    controlRegime[sR] = "r"
end
## IF MAX LOAD IS >0.2kW, CATEGORISE AS "HtgCont" REGIME (CONTINUOUS)
for sC in schedContInd
    controlRegime[sC] = "c"
    binaryHeatingResponse[:,sC] = ones(nSamplesPlus1,1)
end
## IF MAX LOAD IS <0.2kW, CATEGORISE AS "HtgIdle" REGIME
for sI in schedIdleInd
    controlRegime[sI] = "i"
    binaryHeatingResponse[:,sI] = zeros(nSamplesPlus1,1)
end



## CONTINUOUS ("c"), IDLE ("i") AND VOID ("v") ARE NOW DEFINED "controlRegime" ⇒ PREPEND "H/L" DEPENDING ON SETPOINT STATUS AT 00:00 (APPLIES TO "p" AND REMAINING "r" REGIMES)
htgInitHigh = [dy for dy in days if binaryHeatingResponse[1,dy].==1]
randomOrProgram = [dy for dy in days if ismissing(controlRegime[dy])]
[sched[dy]=vcat(-1,sched[dy]) for dy in intersect(htgInitHigh,randomOrProgram)]


schedUnique = unique(sched[schedProgRandInd])
# [println("$(dy)\t→\t$(length(sched[dy]))\t→\t$(isempty(sched[dy]))\t→\t$(sched[dy])") for dy in schedProgRandInd]
# println(" ")
# [println(s) for s in schedUnique]

## CYCLE THROUGH DAYS YET TO BE CATEGORISED INTO "controlRegime" (MIXED HIGH/LOW SETPOINTS)
## ASSIGN EACH DAILY SCHEDULE TO A UNIQUE SCHEDULE ID
global schedId
schedId = fill!(Array{Int32}(undef,nDays),0)
# for d in [dy for dy in days if controlRegime[dy]==0]
# println([dy for dy in days if isequal(controlRegime[dy],missing)])
# println(schedId)

# println(controlRegime)
for d in [dy for dy in days if isequal(controlRegime[dy],missing)]
    schedId[d] = Int([sU for sU in 1:length(schedUnique) if sched[d]==schedUnique[sU]][1])
end
# println(schedId)

## ESTABLISH ARRAY OF LOCAL OFFSET FOR PATTERN RECOGNITION (-1WEEK, -1DAY, +1DAY, +1WEEK)
DayOffsets(x,xMax) = [x+i for i in [-7 -1 1 7] if (x+i)>0 && (x+i)<(xMax+1)]
# dayOffsets = [DayOffsets(dy,days[end]) for dy in days]

# for d in [dy for dy in days if controlRegime[dy]==0]
for d in [dy for dy in days if isequal(controlRegime[dy],missing)]
    dayOffsets = DayOffsets(d,days[end])
    # if isempty(findall(dayOffsets.==schedId[d]))
    if !isempty(findall(schedId[dayOffsets].==schedId[d]))
        # println("$(schedId[d]) \t→\t $(schedId[dayOffsets]) \t→\t $(d)")
        # controlRegime[d] = 3
        controlRegime[d] = "p"
    else
        # println("$(schedId[d]) \t→\t $(schedId[dayOffsets]) \t→\t $(d) x")
        # controlRegime[d] = 4
        controlRegime[d] = "r"
    end
end




## IDENTIFY AND REASSIGN PROFILES APPEARING IN HtgRand ("r") REGIME, WHICH ALSO APPEAR IN HtgProg ("p")
schedIdProg = unique(schedId[findall(controlRegime[:].=="p")])
pos = [i for i in 1:length(schedId) if !isempty(findall(schedIdProg.==schedId[i]))]
controlRegime[pos].="p"

## COUNT INSTANCES OF HEATING PROGRAMS
htgPrograms = [length(findall(schedId.==i)) for i in unique(schedId[findall(controlRegime[:].=="p")])]

## CHECK RANDOM DAYS FOR REPEATING BEHAVIOUR
schedIdRand = unique(schedId[findall(controlRegime[:].=="r")])
htgRandoms = [length(findall(schedId.==i)) for i in unique(schedId[findall(controlRegime[:].=="r")]) if !(i.==0)]

## IDENTIFY AND REASSIGN PROFILES THAT OCCUR MORE THAT 5 TIMES FROM "r" TO "p"
# println(schedIdRand[17])
# println(htgRandoms[17])

controlRegimes = [length(findall(controlRegime.==i)) for i in ["c","p","r","i","v"]] ## 'c'→CONTINUOUS,'p'→PROGRAM,'r'→RANDOM,'i'→IDLE,'v'→VOID
proj.summaryData.HtgCont[n] = controlRegimes[1]
proj.summaryData.HtgProg[n] = controlRegimes[2]
proj.summaryData.HtgRand[n] = controlRegimes[3]
proj.summaryData.HtgIdle[n] = controlRegimes[4]
proj.summaryData.HtgVoid[n] = controlRegimes[5]
proj.summaryData.NumProgs[n] = length(htgPrograms)
proj.summaryData.HtgPrograms[n] = "$(join(sort(htgPrograms,rev=true),"|"))"
proj.summaryData.RandomReoccur[n] = "$(join(sort(htgRandoms,rev=true)[1:6],"|"))"

## CREATE BOOL ARRAY FOR HIGH HEATING STATE AT MIDNIGHT
schedProg = schedUnique[schedIdProg]
htgSPHigh =  [schedProg[i][1].==-1 for i in 1:length(schedProg)]
[schedProg[i]=schedProg[i][2:end] for i in 1:length(schedProg) if htgSPHigh[i].==true]

## WRITE HTEAGIN SCEDULE DATAFRAM (GIVING SHAPE("|" DELIM); REF DWELLING; ID WRT THAT DWELLING; H/L BOOL AT MIDNIGHT)
for i in 1:length(schedIdProg)
    push!(proj.htgSchedules,[join(schedProg[i],"|") parse(Int32,split(proj.smartMeters[n].id,"_")[4]) schedIdProg[i] htgSPHigh[i]])
end
dwellingProfiles = DataFrame(ControlRegime=controlRegime, SchedID=schedId)
fullPath = join([proj.dataPath "GasProfileData" "GasProfileDataTest_$(split(proj.smartMeters[n].id,"_")[4]).csv"],"/")
CSV.write(fullPath,dwellingProfiles)

println("okay         →  $(n)")

# catch
#     println("unsuccessful →  $(n)")
# end
# end
# return proj
# end
