function FixJanFirst(t,data)
    for yr in Dates.year(t[1]):Dates.year(t[end])
        try
            Jan1st = findin(t.==Date(yr,1,1),true)[1]
            adjacentValues = data[[-1 1]+Jan1st]
            if maximum(adjacentValues)>0 && data[Jan1st]==0
                data[Jan1st] = mean(adjacentValues)
            end
        catch
        end
    end
    return data
end


function FixMissedKwhReading(dataSample)
    ## ASSIGN GLOBAL SCOPE TO RETURN RESULT
    global dataVector
    ## MAKE VECTOR OUT OF DATA TO CAPTURE MISSED VALUES CLOSE TO 00:00
    dataVector = dataSample[:]
    ## IDENTIFY WHERE TO PERFORM MISSED VALUE TEST (STARTING POINT FOR TEST IS A ZERO VALUE)
    indZero = findall(dataVector.==0)
    indZero = indZero[findall(indZero.>=2)]
    indZero = indZero[findall(indZero.<=(length(dataVector)-2))]
    ## LOOP THROUGH ALL ZERO VALUES TO PERFORM TEST AT EACH LOCATION
    for iZ in indZero
        ## ASSIGN GLOBAL SCOPE TO RETURN RESULT
        global dataVector
        ## PERFORN TEST: CHECK TO SEE IF THE FOLLOWING DATAPOINT (n+1) IS LARGER THAT ⨯1.5 THE PRECEDING POINT (n-1) OR SUBSEQUENT POINT (n+2)
        if dataVector[iZ+1]>1.5*(maximum([dataVector[iZ-1] dataVector[iZ+2]]))
            dataVector[iZ] = Statistics.mean([dataVector[iZ-1] dataVector[iZ+2]])
            dataVector[iZ+1] = Statistics.mean([dataVector[iZ-1] dataVector[iZ+2]])
        end
    end
    dataSample = reshape(dataVector,size(dataSample,1),size(dataSample,2))
    return dataSample
end
