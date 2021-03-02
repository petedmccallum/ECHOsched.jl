
map_data_to_datafill(data,data_fill,range) = findfirst(data_fill.datetime.==data.datetime[range[1]]):findfirst(data_fill.datetime.==data.datetime[range[end]])

function ranges_from_vec(i)
    sort!(i)
    i_incremental = findall(diff(i).==1)
    i_new_seq = findall(diff(i_incremental).!=1)

    i_start = vcat(i[1],i[i_incremental[i_new_seq.+1]])
    i_stop = vcat(i[i_incremental[i_new_seq].+1],i[end])
    range_arr(start,stop) = start:stop
    ranges = range_arr.(i_start,i_stop)
end

function filltrace(datetime_vec,ranges;colour::String="#0000ff22",yaxis="y",val=1000.)
    range_to_filltrace_t(range) = [maximum([1,range[1]-1]);maximum([1,range[1]-1]);range[end];range[end]]
    range_to_filltrace_y(val,i) = [0,val,val,0]

    i_x = vcat(range_to_filltrace_t.(ranges)...)
    y = vcat(range_to_filltrace_y.(val,1:length(ranges))...)

    trace = scatter(
        x=datetime_vec[i_x][:],
        y=y[:],
        mode="lines",
        line=attr(width=0),
        fill="tozeroy",
        fillcolor=colour,
        yaxis=yaxis,
        showlegend=false,
        hoverinfo="skip",hovertemplate=nothing
    )
end



function lin_interp(data,data_fill,col)
    i_irreg = findall(ismissing.(data_fill[!,col]).==false)
    y = [val for val in data_fill[!,col][i_irreg]]
    interp_linear = LinearInterpolation(i_irreg, y)

    data_fill[!,"$(col)_fill"] = deepcopy(data_fill[!,col])
    i_map = i_irreg[1]:i_irreg[end]
    data_fill[!,"$(col)_fill"][i_map] .= interp_linear(i_map)

    data_fill[!,"$(col)_fill"][data_fill.prolonged_gap] .= missing
    return data_fill
end
