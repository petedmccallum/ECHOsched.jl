
function FindData(fpath::String;query="", ignore="", hideList::Bool=false)

    # ESTABLISH "QUERY" AND "IGNORE" LISTS
    if isa(query, String)
        query = split(query,"&")
    elseif !isa(query, Array)
        println("'query' should be: (1) a string with '&' separating multiple substrings where necessary, (2) an array of strings with containing multiple substrings")
    end
    if isa(ignore, String)
        ignore = split(ignore,"&")
    elseif !isa(ignore, Array)
        println("'ignore' should be: (1) a string with '&' separating multiple substrings where necessary, (2) an array of strings with containing multiple substrings")
    end
    # FIND DIRECTORY CONTENTS
    dir = readdir(fpath);

    # INITIALISE
    dirQry = []

    # IDENTIFY AND LOCATE "QUERY" ARGUEMNTS
    for j in 1:length(query)
        if query[j] != ""
            rslt = [occursin(query[j],dir[i]) for i in 1:length(dir)]
            dirQry = vcat(dirQry,dir[rslt])
        end
    end

    # REMOVE DUPLICATES
    dirQry = unique(dirQry)

    # IDENTIFY AND REMOVE "IGNORE" ARGUEMNTS
    for j in 1:length(ignore)
        if ignore[j] != ""
            rslt = [occursin(ignore[j],dirQry[i]) for i in 1:length(dirQry)]
            dirQry = dirQry[rslt.<true]
        end
    end

    if hideList == false
        println(" ")
        [println("$(i) \t →     $(dirQry[i])") for i in 1:length(dirQry)];
        println(" ")
    end

    return dirQry
end


function LoadData(fname;pth::String="",resolution::Integer=60,from::String="",days::Integer=0,UKDS_1amCorrection::Bool=false)


    ## ESTABLISH PATH TO DATA FROM FIRST TWO ARGUMENTS
    fullPath = joinpath(pth,fname)
    ## ADD ".csv" IF MISSING
    if fullPath[end-3:end] != ".csv"
        fullPath = fullPath*".csv"
    end
    ## INITIAL LOAD OF "raw" ASSUMES HEADERS EXIST (EXCEPTION FOLLOWS)
    raw = CSV.read(fullPath)


    ## CHECK FOR EXCEPTION ⇒ IF NO HEADERS EXIST IN ORIGINAL, RELOAD "raw" WITH "header=0" (TRY/CATCH REQUIRED TO AVOID ERROR)
    header = 1
    try
        firstColName = String(names(raw)[1])
        firstColValue = parse(Float64,firstColName)
        if firstColValue .> 38000 && firstColValue < 44000
            raw = CSV.read(fullPath,header=0)
            header=0
        else
            error("1. Time vector needs to be identified / convert input file to have headers (including time or date in time vector heading)")
        end
    catch
    end


    ## IDENTIFY DATE COLUMN NAME
    if header == 0
        dateTimeCheck = [col for col in names(raw) if occursin("Column1",String(col))]
    else
        ## CHECK IF ORIGINAL FILE INCLUDES TIME VECTOR
        dateTimeCheck = [col for col in names(raw) if occursin("date",lowercase(String(col))) || occursin("time",lowercase(String(col)))]
    end


    ## WHERE PREVIOUSLY CLIPPED DATA INCLUDES EXTRA ROW (MIDNIGHT THE FOLLOWING DAY), REMOVE THIS TO AVOID BLANK DAY AT END OF MATRIX
    # println(raw[dateTimeCheck][1])
    modulusOfT1 = raw[!,dateTimeCheck][!,1][1]%1 ## DETERMINE WHETHER t[1] IS MIDNIGHT OR NOT (WHOLE NUMBER)
    spareRows = (size(raw,1))%(24*60/resolution) ## DETERMINE WHETHER THERE IS AN EXTRA ROW (MIDNIGHT THE FOLLOWING DAY)
    if modulusOfT1==0 && spareRows==1 ## IF BOTH TRUE, REMOVE LAST (SPARE) ROW
        raw = raw[1:end-1,:]
    end


    ## EXTRACT "t" AND "dat" AS ARRAYS
    if !isempty(dateTimeCheck)
        t = raw[!,dateTimeCheck][!,1]
        dataTag = [col for col in names(raw) if col!=dateTimeCheck[1]]
        dat = raw[!,dataTag][!,1]
    else
        error("2. Time vector needs to be identified / convert input file to have headers (including time or date in time vector heading)")
    end



    ## FILL GAPS WITH NANS
    tResSec = minimum(round.(unique(diff(t))*24*60*60))
    ptsPerDay = 24*60*60/tResSec
    # println("Input dat resolution: $(tResSec)sec \t($(ptsPerDay) points per day)")
    padStart = Int(round(t[1]%1*ptsPerDay))
    ind = 1 .+ padStart .+ Int.(round.(1*(t.-t[1])*ptsPerDay)/1)
    padLen = Int(ceil(ind[end]/ptsPerDay)*ptsPerDay)
    dataFillNans = fill!(Array{Float64,1}(undef,padLen),NaN)
    dataFillNans[ind] = dat


    tFill = range(floor(t[1]),stop=(ceil(t[end])),length=padLen+1)
    tFill = tFill[1:end-1]


    ## CONVERT FROM XLS DATE FORMAT TO JULIA (DateTime) FORMAT
    tFill = util.xlsDate.(tFill)


    if from != ""
        ind = 1:length(tFill)
        if isa(from,Date)
            from = DateTime(from)
        elseif isa(from,String)
            from = DateTime(parse(Int64,from[1:4]),parse(Int64,from[6:7]),parse(Int64,from[9:10]))
        end
        pos = ind[from.==tFill]
        tFill = tFill[(pos[1]):end]
        dataFillNans = dataFillNans[(pos[1]):end]

        if days != 0
            ind = 1:length(tFill)
            tTarg = DateTime(Dates.UTM(Dates.value(tFill[1])+(days)*(1000*60*60*24)))
            pos = ind[tFill.==tTarg]
            tFill = tFill[1:(pos[1]-1)]
            dataFillNans = dataFillNans[1:(pos[1]-1)]
        end
    end


    ## RESHAPE DATA TO DAILY ARRAY
    nStep = Int((24*60*60/tResSec))
    nDays = Int(length(dataFillNans)/nStep)
    dataFillNans = reshape(dataFillNans, nStep, nDays)

    ## LINEARLY INTERPOLATE GAP AT 01:00
    if UKDS_1amCorrection == true
        dataFillNans[3,:] = [mean([dataFillNans[2,c],dataFillNans[4,c]]) for c in  1:size(dataFillNans,2)]
    end

    ## EXTRACT SMARTMETER NAME
    n = split(split(fullPath,"/")[end],".")[1]

    ## CREATE STUCT
    smartMeter = SmartMeter(n, dataFillNans, tFill, Second(tResSec), Day(nDays))
    return smartMeter
end



function InitProject(;N,pth::String,query::String)
    ## INIT PROJECT STRUCT
    global proj = Project_SMSPS()
    proj.path = Dict("data"=>pth)
    proj.fullDataList = FindData(proj.path["data"]; query=query,hideList=true)
    proj.dataIndices = vcat([N]...)
    proj.verbose = Array{DataFrame}(undef,length(proj.dataIndices))

    nDwlg = length(N)
    #=
    n = fill!(Array{Int32}(undef,nDwlg),0)
    region = fill!(Array{String}(undef,nDwlg),"tbc")
    numDays = fill!(Array{Int16}(undef,nDwlg),0)
    completeness = fill!(Array{Float64}(undef,nDwlg),0)
    minVal = fill!(Array{Float64}(undef,nDwlg),0)
    maxVal = fill!(Array{Float64}(undef,nDwlg),0)
    spare1 = Array{Union{Missing,Int16}}(missing,nDwlg)
    spare2 = Array{Union{Missing,Int16}}(missing,nDwlg)
    spare3 = Array{Union{Missing,Int16}}(missing,nDwlg)
    spare4 = Array{Union{Missing,Int16}}(missing,nDwlg)
    spare5 = Array{Union{Missing,Int16}}(missing,nDwlg)
    spare6 = Array{Union{Missing,Int16}}(missing,nDwlg)
    spare7 = fill!(Array{String}(undef,nDwlg),"-")
    spare8 = fill!(Array{String}(undef,nDwlg),"-")
    =#

    proj.smartMeters = [LoadData(proj.fullDataList[i],pth=proj.path["data"],UKDS_1amCorrection=true) for i in proj.dataIndices]
    #=
    for i in 1:length(proj.smartMeters)
        # trgFile = proj.fullDataList[i]
        # proj.smartMeters = LoadData((pathData,trgFile))
        n[i] = parse(Int32,split(split(proj.smartMeters[i].id,"_")[end],".")[1])
        region[i] = split(proj.smartMeters[i].id,"_")[3]
        numDays[i] = Int(size(proj.smartMeters[i].dat)[2])
        completeness[i] = 1-sum([1 for j in proj.smartMeters[i].dat if isnan(j)])/(size(proj.smartMeters[i].dat)[1]*size(proj.smartMeters[i].dat)[2])
        minVal[i] = minimum(replace(proj.smartMeters[i].dat, NaN=>Inf))
        maxVal[i] = maximum(replace(proj.smartMeters[i].dat, NaN=>0))
    end

    proj.summaryData = DataFrames.DataFrame(DwellingID=n[:], Region=region,NumDays=numDays[:],
                    Completeness=completeness[:],MinValue=minVal[:],MaxValue=maxVal[:],
                    HtgCont=spare1,HtgProg=spare2,HtgRand=spare3,HtgIdle=spare4,HtgVoid=spare5,
                    NumProgs=spare6, HtgPrograms=spare7, RandomReoccur=spare8)

    proj.htgSchedules = DataFrame(Shape=String[], Dwelling=Int32[], ID=Int16[], HtgSPHigh=Bool[]) ## BLANK DATAFRAME FOR BELOW

    =#
    return proj
end
