"""Determine active cooling segments

Uses temperature and derivatives to determine when cooling is active. A Δt of
10 minutes or better is preferred. This function can be used in conjunction with
`cooling_gap_fill()`.

"""
function cooling_onoff_segmentation(
        time_vec,
        temperature;
        θ_creep_limit_1::Float64=0.,
        θ_creep_limit_2::Float64=0.11,
        return_trace::Bool=false,
        filltrace_const=30)

    # Dataframe for input data
    data = DataFrame(:t=>time_vec,:θ=>temperature)

    # Find temperature derivative
    derivative(y,t) = diff(y)./(Dates.value.(diff(t))/(1000*60))
    dy_dt = derivative(data.θ,data.t)

    # Find every point with a negative derivative (steeper than -0.5°C/minute)
    i_neg_grad = findall(dy_dt.<=-0.05)

    # Find where this downward slope persists over more than 1 timestep
    tmp = findall(diff(i_neg_grad).>1)
    cooling_segment_start = vcat(i_neg_grad[1],i_neg_grad[tmp.+1])


    function find_cooling_off(data,cooling_segment_start,i)
        t = data.t[cooling_segment_start[i]:cooling_segment_start[i+1]]
        y = data.θ[cooling_segment_start[i]:cooling_segment_start[i+1]]
        # Find first consecutive temp rise (indended for <=0.1°C/minute rises)
        i_up = findall(derivative(y,t).>θ_creep_limit_1)
        i_up = isnothing(findfirst(diff(i_up).==1)) ? 1e9 : i_up[findfirst(diff(i_up).==1)]
        # Find first significant temp rise (i.e. >0.1°C/minute rises)
        i_up_sig = findall(derivative(y,t).>θ_creep_limit_2)
        Int(minimum(vcat(length(t),i_up,i_up_sig)))
    end
    cooling_segment_len = find_cooling_off.((data,),(cooling_segment_start,),1:(length(cooling_segment_start)-1))

    # Close last cooling segment at end of timeseries
    cooling_segment_len = vcat(cooling_segment_len,1+nrow(data)-maximum(cooling_segment_start))

    # Set index ranges for cooling segments
    range_arr(start,len) = start.+(0:(len-1))
    cooling_ranges = range_arr.(cooling_segment_start,cooling_segment_len)

    # Join overlapping cooling ranges
    j = sort(unique(vcat(collect.(cooling_ranges)...)))
    k = findall(diff(j).>1)
    range_arr_2(start,stop) = start:stop
    cooling_ranges = range_arr_2.(vcat(j[1],j[k.+1]),vcat(j[k],nrow(data)))

    # Build cooling fill traces (optional)
    if return_trace==true
        range_to_filltrace_t(range) = [range[1];range[1];range[end];range[end]]
        range_to_filltrace_y(val,i) = [0,val,val,0]

        cooling_filltrace = scatter(
            x=data.t[vcat(range_to_filltrace_t.(cooling_ranges)...)][:],
            y=vcat(range_to_filltrace_y.(filltrace_const,1:length(cooling_ranges))...)[:],
            mode="lines",
            line=attr(width=0),
            fill="tozeroy",
            fillcolor="#ff000022"
        )
        return cooling_ranges, cooling_filltrace
    end
    return cooling_ranges
end


function ranges_from_vec(i)
    sort!(i)
    i_incremental = findall(diff(i).==1)
    i_new_seq = findall(diff(i_incremental).!=1)

    i_start = vcat(i[1],i[i_incremental[i_new_seq.+1]])
    i_stop = vcat(i[i_incremental[i_new_seq].+1],i[end])
    range_arr(start,stop) = start:stop
    ranges = range_arr.(i_start,i_stop)
end
