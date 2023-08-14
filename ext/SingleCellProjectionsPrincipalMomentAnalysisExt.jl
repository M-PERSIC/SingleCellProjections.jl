module SingleCellProjectionsPrincipalMomentAnalysisExt

using SingleCellProjections

if isdefined(Base, :get_extension)
	using PrincipalMomentAnalysis: PMA, SimplexGraph, simplices2kernelmatrixroot
else
	using ..PrincipalMomentAnalysis: PMA, SimplexGraph, simplices2kernelmatrixroot
end


function _implicitpma(A, samplekernelroot::AbstractMatrix; kwargs...)
	prod(size(A))==0 && return PMA(zeros(0,0), zeros(0), zeros(0,0), zeros(0,0))
	B = SingleCellProjections.matrixproduct(A, samplekernelroot)
	F = SingleCellProjections.implicitsvd(B; kwargs...)

	U = F.U
	S = F.S
	V = A'U
	V ./= S'
	PMA(U,S,Matrix(V'),Matrix(F.V))
end

"""
	implicitpma(A, G::SimplexGraph; nsv=3, subspacedims=8nsv, niter=2)

Computes the Principal Moment Analysis of the implicitly given matrix `A` (variables × samples) using the sample simplex graph `G`.
"""
implicitpma(A, G::SimplexGraph; kwargs...) = _implicitpma(A, simplices2kernelmatrixroot(G; simplify=false); kwargs...)
implicitpma(A, G::AbstractMatrix{Bool}; kwargs...) = implicitpma(A, SimplexGraph(G); kwargs...)



SingleCellProjections.innersize(F::PMA) = length(F.S)


SingleCellProjections.var_coordinates(F::PMA) = F.U
SingleCellProjections.obs_coordinates(F::PMA) = Diagonal(F.S)*F.Vt

SingleCellProjections.var_coordinates(data::DataMatrix{<:PMA}) = var_coordinates(data.matrix)
SingleCellProjections.obs_coordinates(data::DataMatrix{<:PMA}) = obs_coordinates(data.matrix)


function SingleCellProjections._subsetmatrix(F::PMA, I::Index, J::Index)
	U = F.U[I,:]
	Vt = F.Vt[:,J]
	lmul!(Diagonal(F.S), Vt)
	SingleCellProjections.LowRank(U, Vt)
end


SingleCellProjections._showmatrix(io, matrix::PMA) = print(io, "PMA (", SingleCellProjections.innersize(matrix), " dimensions)")


struct PMAModel <: ProjectionModel
	F::PMA
	var_match::DataFrame
	var::Symbol
	obs::Symbol
end

SingleCellProjections.projection_isequal(m1::PMAModel, m2::PMAModel) = m1.F === m2.F && m1.var_match == m2.var_match
SingleCellProjections.update_model(m::PMAModel; var=m.var, obs=m.obs, kwargs...) = (SVDModel(m.F, m.var_match, var, obs), kwargs)

function PrincipalMomentAnalysis.pma(data::DataMatrix, args...; nsv=3, var=:copy, obs=:copy, kwargs...)
	F = implicitpma(data.matrix, args...; nsv=nsv, kwargs...)
	model = PMAModel(F,select(data.var,data.var_id_cols), var, obs)
	update_matrix(data, F, model; model.var, model.obs)
end

function project_impl(data::DataMatrix, model::PMAModel; verbose=true)
	@assert SingleCellProjections.table_cols_equal(data.var, model.var_match) "PMA projection expects model and data variables to be identical."

	F = model.F
	X = data.matrix

	V = X'F.U # TODO: compute F.U'X instead to get Vt directly
	matrix = SingleCellProjections.LowRank(F.U, V') # V is already scaled with F.S like it should be
	update_matrix(data, matrix, model; model.obs, model.var)
end


function Base.show(io::IO, ::MIME"text/plain", model::PMAModel)
	print(io, "PMAModel(nsv=", SingleCellProjections.innersize(model.F), ')')
end

end
