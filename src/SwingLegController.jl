include("StanceController.jl")
include("Gait.jl")
include("Types.jl")

function raibert_tdlocations(swingparams::SwingParams, stanceparams::StanceParams, gaitparams::GaitParams, mvref::MovementReference)
	#=
	36 allocations

	Use the raibert heuristic to find the touchdown locations for all legs as if they were all in swing
	=#

	# Contruct the 'skis' defined by p and R
	p2 = swingparams.alpha * gaitparams.stanceticks * gaitparams.dt * mvref.vxyref
	p = SVector(p2[1], p2[2], 0.0)
	Θ = swingparams.beta * gaitparams.stanceticks * gaitparams.dt * mvref.wzref
	R = RotZ(Θ)
	tdlocations = R * SMatrix(stanceparams.defaultstance) .+ p
	return tdlocations
end

function raibert_tdlocation(legindex::Integer, swingparams::SwingParams, stanceparams::StanceParams, gaitparams::GaitParams, mvref::MovementReference)
	#=
	36 allocations due to raiberttdlocations

	Use the raibert heuristic to find the touchdown location for a specific leg in swing.
	=#
	out::SVector{3, Float64} = raibert_tdlocations(swingparams, stanceparams, gaitparams, mvref)[:, legindex]
	return out
end

function swingheight(swingprop::Number, swingparams::SwingParams)
	swingphase = swingprop
	timevec = SVector{5}(swingphase^4, swingphase^3, swingphase^2, swingphase, 1)
	sheight = timevec' * swingparams.zcoeffs # vertical offset relative to the stance default
	return sheight
end

function swingfootlocations(swingprop::Number, footlocations::SMatrix{3, 4, Float64}, swingparams::SwingParams, stanceparams::StanceParams, gaitparams::GaitParams, mvref::MovementReference)
	#=
	Return the incremental position update for the legs as if they were all in swing
	
	swingprop: Proportion of swing phase completed.
	footlocations: Current foot locations
	=#

	@assert swingprop >= 0 && swingprop <= 1.0

	# That sheight is the height where the stance feet should be at the *given time*, 
	# while tdlocations is the location that the feet should be at at the *end* of the swing period.
	sheight = swingheight(swingprop, swingparams)
	tdlocations = raibert_tdlocations(swingparams, stanceparams, gaitparams, mvref)
	timeleft = gaitparams.dt * gaitparams.swingticks * (1 - swingprop)
	v = (tdlocations - footlocations) / timeleft .* SVector{3}(1, 1, 0)
	Δfootlocations = v * gaitparams.dt
	sheight_matrix = SMatrix{3, 4, Float64}(0, 0, sheight + mvref.zref,
											0, 0, sheight + mvref.zref,
											0, 0, sheight + mvref.zref,
											0, 0, sheight + mvref.zref)
	incrementedlocations = sheight_matrix + Δfootlocations
	return incrementedlocations
end

function swingfootlocation(swingprop::Number, footlocation::SVector{3, Float64}, legindex::Integer, swingparams::SwingParams, stanceparams::StanceParams, gaitparams::GaitParams, mvref::MovementReference)
	#=
	Does 36 allocations due to raibert_tdlocation

	Return the new location for a specific foot in swing.
	
	swingprop: Proportion of swing phase completed.
	footlocations: Current foot locations
	=#

	@assert swingprop >= 0 && swingprop <= 1.0

	# That sheight is the height where the stance feet should be at the *given time*, 
	# while tdlocations is the location that the feet should be at at the *end* of the swing period.
	sheight = swingheight(swingprop, swingparams)
	tdlocation = raibert_tdlocation(legindex, swingparams, stanceparams, gaitparams, mvref)
	timeleft = gaitparams.dt * gaitparams.swingticks * (1.0 - swingprop)
	v = (tdlocation - footlocation) / timeleft .* SVector{3}(1, 1, 0)
	Δfootlocation = v * gaitparams.dt
	zvector = SVector{3, Float64}(0, 0, sheight + mvref.zref)
	incrementedlocation::SVector{3, Float64} = footlocation .* SVector{3}(1, 1, 0) + zvector + Δfootlocation
	return incrementedlocation
end