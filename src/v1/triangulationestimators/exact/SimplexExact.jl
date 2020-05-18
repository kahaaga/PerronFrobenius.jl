export SimplexExact
import Simplices.Delaunay.delaunay_static

"""
    SimplexExact

A transfer operator estimator using a triangulation partition and exact 
simplex intersections [^Diego2019]. 

*Note: due to the exact simplex intersections, this estimator is slow.*

[^Diego2019]: Diego, David, Kristian Agasøster Haaga, and Bjarte Hannisdal. "Transfer entropy computation using the Perron-Frobenius operator." Physical Review E 99.4 (2019): 042212.
"""
struct SimplexExact <: TransferOperator
    bc::String
    
    function SimplexExact(bc::String = "circular")
        isboundarycondition(bc, "triangulation")  || error("Boundary condition '$bc' not valid.")
        new(bc)
    end
end
Base.show(io::IO, se::SimplexExact) = print(io, "SimplexExact{$(se.bc)}")


""" Generate a TransferOperatorGenerator for an exact simplex estimator."""
function transferoperatorgenerator(pts, method::SimplexExact)
    # modified points, where the image of each point is guaranteed to lie within the convex hull of the previous points
    invariant_pts = invariantize(pts)
    
    # triangulation of the invariant points
    triang = delaunay_static(invariant_pts[1:end-1])
    init = (invariant_pts = invariant_pts,
            triang = triang)
    
    TransferOperatorGenerator(method, pts, init)
end

function (tog::TransferOperatorGenerator{<:SimplexExact})(tol = 1e-8)
    invariant_pts, triang = getfield.(Ref(tog.init), (:invariant_pts, :triang))
    
    D = length(invariant_pts[1])
    N = length(triang)
    ϵ = tol / N
    
    # Pre-allocate simplex and its image
    image_simplex = MutableSimplex(zeros(Float64, D, D+1))
    simplex = MutableSimplex(zeros(Float64, D, D+1))
    M = zeros(Float64, N, N)
    
    for j in 1:N
        # Fill the image simplex
        for k = 1:(D + 1)
            image_simplex[k] .= 0.0
            image_simplex[k] = invariant_pts[triang[j][k] + 1]
        end
        
        imvol = abs(orientation(image_simplex))

        for i = 1:N
            #@show j, i
            # Fill which we're testing if arrives in the image simplex,
            # and if it does, how much of it overlaps with the image
            # simplex.
            for k = 1:(D + 1)
                simplex[k] .= 0.0
                simplex[k] = invariant_pts[triang[i][k]]
            end

            # Only compute the entry of the transfer matrix
            # if simplices are of sufficient size.
            vol = abs(orientation(simplex))

            if vol * imvol > 0 && (vol/imvol) > ϵ
                M[j, i] = simplexintersection(simplex, image_simplex) / imvol
            end
        end
    end
    
    M
end