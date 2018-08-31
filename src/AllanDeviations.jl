module AllanDeviations

#
# Exports/
#
export AllanTauDescriptor, AllTaus, QuarterOctave, HalfOctave, Octave, HalfDecade, Decade

export allandev
export mallandev
export hadamarddev
export timedev
export totaldev
export mtie
#
# /Exports
#



#
# Types/
#
abstract type AllanTauDescriptor end
struct AllTaus <: AllanTauDescriptor end
struct QuarterOctave <: AllanTauDescriptor end
struct HalfOctave <: AllanTauDescriptor end
struct Octave <: AllanTauDescriptor end
struct HalfDecade <: AllanTauDescriptor end
struct Decade <: AllanTauDescriptor end
#
# /Types
#



#
# Helper Functions/
#
function frequencytophase(data::Array{T, 1}, rate::AbstractFloat) where T
	dt = 1 / rate
	n = length(data) + 1
	dataPrime = zeros(T, n)
	walkingSum = zero(T)
	@inbounds for i in 2:n #spare the first element so that the phase begins with zero
		walkingSum += data[i - 1]
		dataPrime[i] = walkingSum * dt
	end
	dataPrime
end

#tau-descriptor to m
function taudescription_to_m(::Type{AllTaus}, rate::AbstractFloat, n::Int)
	1:(n - 2)
end
function taudescription_to_m(::Type{Decade}, rate::AbstractFloat, n::Int)
	10 .^(0:Int(floor(log10(n))))
end
function taudescription_to_m(::Type{HalfDecade}, rate::AbstractFloat, n::Int)
	5 .^(0:Int(floor(log(5.0, n))))
end
function taudescription_to_m(::Type{Octave}, rate::AbstractFloat, n::Int)
	2 .^(0:Int(floor(log2(n))))
end
function taudescription_to_m(::Type{HalfOctave}, rate::AbstractFloat, n::Int)
	unique(Int.(floor.(
		1.5 .^(0:Int(floor(log(1.5, n))))
		)))
end
function taudescription_to_m(::Type{QuarterOctave}, rate::AbstractFloat, n::Int)
	unique(Int.(floor.(
		1.25 .^(0:Int(floor(log(1.25, n))))
		)))
end
#tau with custom log base value to m
function taudescription_to_m(taus::AbstractFloat, rate::AbstractFloat, n::Int)
	if taus <= 1.0
		error("Custom `taus`-log scale must be greater than 1.0")
	end
	unique(Int.(floor.(
		taus .^(0:Int(floor(log(taus, n))))
		)))
end
#tau with custom array to m
function taudescription_to_m(taus::Array{Float64}, rate::AbstractFloat, n::Int)
	m = unique(Int.(floor.(rate .* taus)))
	m[m .>= 1]
end
#
# /Helper Functions
#



#
# Exported functions/
#



"""
allandev(data, rate; [frequency=false], [overlapping=true], [taus=Octave])
Calculates the allan deviation

#parameters:
* `<data>`:			The data array to calculate the deviation from either as as phases or frequencies.
* `<rate>`:			The rate of the data given.
* `[frequency]`:		True if `data` contains frequency data otherwise (default) phase data is assumed.
* `[overlapping]`:	True (default) to calculate overlapping deviation, false otherwise.
* `[taus]`:			Taus to calculate the deviation at. This can either be an AllanTauDescriptor type `AllTaus, Decadade, HalfDecade, Octave (default), HalfOctave, QuarterOctave`, an array of taus to calculate at or a number to build a custom log-scale on.

#returns: named tupple (tau, deviation, error, count)
* `tau`:		Taus which where used.
* `deviation`:	Deviations calculated.
* `error`:		Respective errors.
* `count`:		Number of contributing terms for each deviation.
"""
function allandev(
		data::Array{T, 1},
		rate::AbstractFloat;
		frequency::Bool = false,
		overlapping::Bool = true,
		taus::Union{Type{U}, AbstractFloat, Array{Float64}} = 2.0) where {T, U <: AllanTauDescriptor}

	#frequency to phase calculation
	if frequency
		data = frequencytophase(data, rate)
	end

	n = length(data)
	if n < 3
		error("Length for `data` in allandev must be at least 3 or greater")
	end

	#tau calculations
	m = taudescription_to_m(taus, rate, n)

	dev = zeros(T, length(m)) #allandeviation
	deverr = zeros(T, length(m)) #allandeviation error
	devcount = zeros(Int, length(m)) #sum term count

	mStride = 1 #overlapping - can be overwritten in loop for consecutive
	@inbounds for (index, τ) in enumerate(m)

		if !overlapping #overwrite stride for consecutive operation
			mStride = τ
		end
		
		#allan deviation: http://www.leapsecond.com/tools/adev_lib.c
		sum = zero(T)
		i = 1
		terms = 0
		while (i + 2 * τ) <= n
			v = data[i] - 2 * data[i + τ] + data[i + 2 * τ]
			sum += v * v
			i += mStride
			terms += 1
		end
		if terms <= 1 #break the tau loop if no contribution with term-count > 1 is done
			break
		end

		dev[index] = sqrt(sum / (2 * terms)) / τ * rate
		deverr[index] = dev[index] / sqrt(terms)
		devcount[index] = terms
	end

	selector = devcount .> 1 #select only entries, where 2 or more terms contributed to the deviation
	(tau = m[selector] ./ rate, deviation = dev[selector], error = deverr[selector], count = devcount[selector])
end




"""
mallandev(data, rate; [frequency=false], [overlapping=true], [taus=Octave])
Calculates the modified allan deviation

#parameters:
* `<data>`:			The data array to calculate the deviation from either as as phases or frequencies.
* `<rate>`:			The rate of the data given.
* `[frequency]`:		True if `data` contains frequency data otherwise (default) phase data is assumed.
* `[overlapping]`:	True (default) to calculate overlapping deviation, false otherwise.
* `[taus]`:			Taus to calculate the deviation at. This can either be an AllanTauDescriptor type `AllTaus, Decadade, HalfDecade, Octave (default), HalfOctave, QuarterOctave`, an array of taus to calculate at or a number to build a custom log-scale on.

#returns: named tupple (tau, deviation, error, count)
* `tau`:		Taus which where used.
* `deviation`:	Deviations calculated.
* `error`:		Respective errors.
* `count`:		Number of contributing terms for each deviation.
"""
function mallandev(
		data::Array{T, 1},
		rate::AbstractFloat;
		frequency::Bool = false,
		overlapping::Bool = true,
		taus::Union{Type{U}, AbstractFloat, Array{Float64}} = 2.0) where {T, U <: AllanTauDescriptor}

	#frequency to phase calculation
	if frequency
		data = frequencytophase(data, rate)
	end

	n = length(data)
	if n < 4
		error("Length for `data` in mallandev must be at least 4 or greater")
	end

	#tau calculations
	m = taudescription_to_m(taus, rate, n)

	dev = zeros(T, length(m)) #allandeviation
	deverr = zeros(T, length(m)) #allandeviation error
	devcount = zeros(Int, length(m)) #sum term count

	mStride = 1 #overlapping - can be overwritten in loop for consecutive
	@inbounds for (index, τ) in enumerate(m)

		if !overlapping #overwrite stride for consecutive operation
			mStride = τ
		end

		#allan deviation: http://www.leapsecond.com/tools/adev_lib.c
		sum = zero(T)
		v = zero(T)
		i = 1
		while (i + 2 * τ) <= n && i <= τ
			v += data[i] - 2 * data[i + τ] + data[i + 2 * τ]
			i += mStride
		end
		sum += v * v
		terms = 1
		i = 1
		while (i + 3 * τ) <= n
			v += data[i + 3 * τ] - 3 * data[i + 2 * τ] + 3 * data[i + τ] - data[i]
			sum += v * v
			i += mStride
			terms += 1
		end

		if terms <= 1 #break the tau loop if no contribution with term-count > 1 is done
			break
		end

		dev[index] = sqrt(sum / (2 * terms)) / (τ * τ) * rate
		deverr[index] = dev[index] / sqrt(terms)
		devcount[index] = terms
	end

	selector = devcount .> 1 #select only entries, where 2 or more terms contributed to the deviation
	(tau = m[selector] ./ rate, deviation = dev[selector], error = deverr[selector], count = devcount[selector])
end




"""
hadamarddev(data, rate; [frequency=false], [overlapping=true], [taus=Octave])
Calculates the hadamard deviation

#parameters:
* `<data>`:			The data array to calculate the deviation from either as as phases or frequencies.
* `<rate>`:			The rate of the data given.
* `[frequency]`:		True if `data` contains frequency data otherwise (default) phase data is assumed.
* `[overlapping]`:	True (default) to calculate overlapping deviation, false otherwise.
* `[taus]`:			Taus to calculate the deviation at. This can either be an AllanTauDescriptor type `AllTaus, Decadade, HalfDecade, Octave (default), HalfOctave, QuarterOctave`, an array of taus to calculate at or a number to build a custom log-scale on.

#returns: named tupple (tau, deviation, error, count)
* `tau`:		Taus which where used.
* `deviation`:	Deviations calculated.
* `error`:		Respective errors.
* `count`:		Number of contributing terms for each deviation.
"""
function hadamarddev(
		data::Array{T, 1},
		rate::AbstractFloat;
		frequency::Bool = false,
		overlapping::Bool = true,
		taus::Union{Type{U}, AbstractFloat, Array{Float64}} = 2.0) where {T, U <: AllanTauDescriptor}

	#frequency to phase calculation
	if frequency
		data = frequencytophase(data, rate)
	end

	n = length(data)
	if n < 5
		error("Length for `data` in hadamarddev must be at least 5 or greater")
	end

	#tau calculations
	m = taudescription_to_m(taus, rate, n)

	dev = zeros(T, length(m)) #hadamarddeviation
	deverr = zeros(T, length(m)) #hadamarddeviation error
	devcount = zeros(Int, length(m)) #sum term count

	mStride = 1 #overlapping - can be overwritten in loop for consecutive
	@inbounds for (index, τ) in enumerate(m)

		if !overlapping #overwrite stride for consecutive operation
			mStride = τ
		end

		#hadamard deviation: http://www.leapsecond.com/tools/adev_lib.c
		sum = zero(T)
		i = 1
		terms = 0
		while (i + 3 * τ) <= n
			v = data[i + 3 * τ] - 3 * data[i + 2 * τ] + 3 * data[i + τ] - data[i]
			sum += v * v
			i += mStride
			terms += 1
		end
		if terms <= 1 #break the tau loop if no contribution with term-count > 1 is done
			break
		end

		dev[index] = sqrt(sum / (6 * terms)) / τ * rate
		deverr[index] = dev[index] / sqrt(terms)
		devcount[index] = terms
	end

	selector = devcount .> 1 #select only entries, where 2 or more terms contributed to the deviation
	(tau = m[selector] ./ rate, deviation = dev[selector], error = deverr[selector], count = devcount[selector])
end




"""
timedev(data, rate; [frequency=false], [overlapping=true], [taus=Octave])
Calculates the time deviation

#parameters:
* `<data>`:			The data array to calculate the deviation from either as as phases or frequencies.
* `<rate>`:			The rate of the data given.
* `[frequency]`:		True if `data` contains frequency data otherwise (default) phase data is assumed.
* `[overlapping]`:	True (default) to calculate overlapping deviation, false otherwise.
* `[taus]`:			Taus to calculate the deviation at. This can either be an AllanTauDescriptor type `AllTaus, Decadade, HalfDecade, Octave (default), HalfOctave, QuarterOctave`, an array of taus to calculate at or a number to build a custom log-scale on.

#returns: named tupple (tau, deviation, error, count)
* `tau`:		Taus which where used.
* `deviation`:	Deviations calculated.
* `error`:		Respective errors.
* `count`:		Number of contributing terms for each deviation.
"""
function timedev(
		data::Array{T, 1},
		rate::AbstractFloat;
		frequency::Bool = false,
		overlapping::Bool = true,
		taus::Union{Type{U}, AbstractFloat, Array{Float64}} = 2.0) where {T, U <: AllanTauDescriptor}

	n = length(data)
	if n < 4
		error("Length for `data` in timedev must be at least 4 or greater")
		#we check this here, so that we can output the right function name in case of the error
	end

	(mdtaus, mddeviation, mderror, mdcount) = mallandev(data, rate, frequency = frequency, overlapping = overlapping, taus = taus)
	mdm = mdtaus ./ sqrt(3)

	(tau = mdtaus, deviation = mdm .* mddeviation, error = mdm .* mderror, count = mdcount)
end



"""
totaldev(data, rate; [frequency=false], [overlapping=true], [taus=Octave])
Calculates the total deviation

#parameters:
* `<data>`:			The data array to calculate the deviation from either as as phases or frequencies.
* `<rate>`:			The rate of the data given.
* `[frequency]`:		True if `data` contains frequency data otherwise (default) phase data is assumed.
* `[overlapping]`:	True (default) to calculate overlapping deviation, false otherwise.
* `[taus]`:			Taus to calculate the deviation at. This can either be an AllanTauDescriptor type `AllTaus, Decadade, HalfDecade, Octave (default), HalfOctave, QuarterOctave`, an array of taus to calculate at or a number to build a custom log-scale on.

#returns: named tupple (tau, deviation, error, count)
* `tau`:		Taus which where used.
* `deviation`:	Deviations calculated.
* `error`:		Respective errors.
* `count`:		Number of contributing terms for each deviation.
"""
function totaldev(
		data::Array{T, 1},
		rate::AbstractFloat;
		frequency::Bool = false,
		overlapping::Bool = true,
		taus::Union{Type{U}, AbstractFloat, Array{Float64}} = 2.0) where {T, U <: AllanTauDescriptor}

	#frequency to phase calculation
	if frequency
		data = frequencytophase(data, rate)
	end

	n = length(data)
	if n < 3
		error("Length for `data` in totaldev must be at least 3 or greater")
	end

	if !overlapping #warn for consecutive execution
		@warn "It is highly unusual to use the total deviation in the non overlapping form. Do not use this for definite interpretation or publication."
	end

	#tau calculations
	m = taudescription_to_m(taus, rate, n)

	#array reflection
	dataPrime = zeros(Float64, 3 * n - 4)
	datStart = 2 * data[1]
	datEnd = 2 * data[n]
	nm2 = n - 2
	@inbounds for i = 1:nm2
		dataPrime[i          ] = datStart - data[n - i]	#left reflection
		dataPrime[i + nm2    ] = data[i]				#original data from 1 to (n - 2)
		dataPrime[i + nm2 + n] = datEnd - data[n - i]	#right reflection
	end
	dataPrime[2 * nm2 + 1] = data[n - 1]				#original data (n - 1)
	dataPrime[2 * nm2 + 2] = data[n]					#original data (n)

	dev = zeros(T, length(m)) #totaldev
	deverr = zeros(T, length(m)) #totaldev error
	devcount = zeros(Int, length(m)) #sum term count

	mStride = 1 #overlapping - can be overwritten in loop for consecutive
	@inbounds for (index, τ) in enumerate(m)

		if n - τ < 1
			break
		end

		if !overlapping #overwrite stride for consecutive operation
			mStride = τ
		end

		#hadamard deviation: http://www.leapsecond.com/tools/adev_lib.c
		sum = zero(T)
		i = n
		terms = 0
		while (i <= nm2 + n - 1)
			v = dataPrime[i - τ] - 2 * dataPrime[i] + dataPrime[i + τ]
			sum += v * v
			i += mStride
			terms += 1
		end
		if terms <= 1 #break the tau loop if no contribution with term-count > 1 is done
			break
		end

		dev[index] = sqrt(sum / (2 * terms)) / τ * rate
		deverr[index] = dev[index] / sqrt(terms)
		devcount[index] = terms
	end

	selector = devcount .> 1 #select only entries, where 2 or more terms contributed to the deviation
	(tau = m[selector] ./ rate, deviation = dev[selector], error = deverr[selector], count = devcount[selector])
end



"""
mtie(data, rate; [frequency=false], [overlapping=true], [taus=Octave])
Calculates the maximal time interval error

# parameters:
* `<data>`:			The data array to calculate the deviation from either as as phases or frequencies.
* `<rate>`:			The rate of the data given.
* `[frequency]`:	True if `data` contains frequency data otherwise (default) phase data is assumed.
* `[overlapping]`:	True (default) to calculate overlapping deviation, false otherwise.
* `[taus]`:			Taus to calculate the deviation at. This can either be an AllanTauDescriptor type `AllTaus, Decadade, HalfDecade, Octave (default), HalfOctave, QuarterOctave`, an array of taus to calculate at or a number to build a custom log-scale on.

# returns: named tupple (tau, deviation, error, count)
* `tau`:		Taus which where used.
* `deviation`:	Deviations calculated.
* `error`:		Respective errors.
* `count`:		Number of contributing terms for each deviation.
"""
function mtie(
		data::Array{T, 1},
		rate::AbstractFloat;
		frequency::Bool = false,
		overlapping::Bool = true,
		taus::Union{Type{U}, AbstractFloat, Array{Float64}} = 2.0) where {T, U <: AllanTauDescriptor}

	#frequency to phase calculation
	if frequency
		data = frequencytophase(data, rate)
	end

	n = length(data)
	if n < 2
		error("Length for `data` in mtie must be at least 2 or greater")
	end

	if !overlapping #warn for consecutive execution
		@warn "It is highly unusual to use the mtie in the non overlapping form. Do not use this for definite interpretation or publication."
	end

	#tau calculations
	m = taudescription_to_m(taus, rate, n)

	dev = zeros(T, length(m)) #mtie
	deverr = zeros(T, length(m)) #mtie error
	devcount = zeros(Int, length(m)) #sum term count

	mStride = 1 #overlapping - can be overwritten in loop for consecutive
	@inbounds for (index, τ) in enumerate(m)

		if !overlapping #overwrite stride for consecutive operation
			mStride = τ
		end

		#mtie: https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication1065.pdf
		terms = n - τ
		if terms < 2
			break
		end

		submin = data[1]
		submax = data[1]
		for j = 1:(1 + τ)
			if data[j] < submin
				submin = data[j]
			elseif data[j] > submax
				submax = data[j]
			end
		end
		delta = submax - submin
		maximumv = delta
		for i = (1 + mStride):(mStride):(n - τ)

			#max pipe
			if data[i - mStride] == submax #rolling max-pipe is obsolete
				submax = data[i]
				for j = i:(i + τ)
					if data[j] > submax
						submax = data[j]
					end
				end
				delta = submax - submin
			elseif data[i + τ] > submax #if new element is bigger than the old one
				submax = data[i + τ]
				delta = submax - submin
			end

			#min pipe
			if data[i - mStride] == submin #rolling min-pipe is obsolete
				submin = data[i]
				for j = i:(i + τ)
					if data[j] < submin
						submin = data[j]
					end
				end
				delta = submax - submin
			elseif data[i + τ] < submin #if new element is smaller than the old one
				submin = data[i + τ]
				delta = submax - submin
			end

			#comparer
			if delta > maximumv
				maximumv = delta
			end

		end

		dev[index] = maximumv
		deverr[index] = dev[index] / sqrt(terms)
		devcount[index] = terms
	end

	selector = devcount .> 1 #select only entries, where 2 or more terms contributed to the deviation
	(tau = m[selector] ./ rate, deviation = dev[selector], error = deverr[selector], count = devcount[selector])
end



#
# /Exported functions
#



end # AllanDeviations
