
// This program was created by the Equelle compiler from SINTEF.

#include "equelle/EquelleRuntimeCPU.hpp"

void ensureRequirements(const equelle::EquelleRuntimeCPU& er);

int main(int argc, char** argv)
{
    // Get user parameters.
    Opm::ParameterGroup param(argc, argv, false);

    using namespace equelle;
    // Create the Equelle runtime.
    EquelleRuntimeCPU er(param);

    ensureRequirements(er);

    // ============= Generated code starts here ================

    const Scalar k = er.inputScalarWithDefault("k", double(0.3));
    const CollOfScalar u_initial = er.inputCollectionOfScalar("u_initial", er.allCells());
    const CollOfFace dirichlet_boundary = er.inputDomainSubsetOf("dirichlet_boundary", er.boundaryFaces());
    const CollOfScalar dirichlet_val = er.inputCollectionOfScalar("dirichlet_val", dirichlet_boundary);
    const CollOfScalar vol = er.norm(er.allCells());
    const CollOfFace interior_faces = er.interiorFaces();
    const CollOfCell first = er.firstCell(interior_faces);
    const CollOfCell second = er.secondCell(interior_faces);
    const CollOfScalar itrans = (k * (er.norm(interior_faces) / er.norm((er.centroid(first) - er.centroid(second)))));
    const CollOfFace bf = er.boundaryFaces();
    const CollOfCell bf_cells = er.trinaryIf(er.isEmpty(er.firstCell(bf)), er.secondCell(bf), er.firstCell(bf));
    const CollOfScalar bf_sign = er.trinaryIf(er.isEmpty(er.firstCell(bf)), er.operatorExtend(-double(1), bf), er.operatorExtend(double(1), bf));
    const CollOfScalar btrans = (k * (er.norm(bf) / er.norm((er.centroid(bf) - er.centroid(bf_cells)))));
    const CollOfScalar dir_sign = er.operatorOn(bf_sign, er.boundaryFaces(), dirichlet_boundary);
    std::function<CollOfScalar(const CollOfScalar&)> computeInteriorFlux = [&](const CollOfScalar& u) -> CollOfScalar {
        return (-itrans * er.gradient(u));
    };
    std::function<CollOfScalar(const CollOfScalar&)> computeBoundaryFlux = [&](const CollOfScalar& u) -> CollOfScalar {
        const CollOfScalar u_dirbdycells = er.operatorOn(u, er.allCells(), er.operatorOn(bf_cells, er.boundaryFaces(), dirichlet_boundary));
        const CollOfScalar dir_fluxes = ((er.operatorOn(btrans, er.boundaryFaces(), dirichlet_boundary) * dir_sign) * (u_dirbdycells - dirichlet_val));
        return er.operatorExtend(dir_fluxes, dirichlet_boundary, er.boundaryFaces());
    };
    std::function<CollOfScalar(const CollOfScalar&, const CollOfScalar&, const Scalar&)> computeResidual = [&](const CollOfScalar& u, const CollOfScalar& u0, const Scalar& dt) -> CollOfScalar {
        const CollOfScalar ifluxes = computeInteriorFlux(u);
        const CollOfScalar bfluxes = computeBoundaryFlux(u);
        const CollOfScalar fluxes = (er.operatorExtend(ifluxes, er.interiorFaces(), er.allFaces()) + er.operatorExtend(bfluxes, er.boundaryFaces(), er.allFaces()));
        const CollOfScalar residual = ((u - u0) + ((dt / vol) * er.divergence(fluxes)));
        return residual;
    };
    const SeqOfScalar timesteps = er.inputSequenceOfScalar("timesteps");
    CollOfScalar u0;
    u0 = u_initial;
    for (const Scalar& dt : timesteps) {
        std::function<CollOfScalar(const CollOfScalar&)> computeResidualLocal = [&](const CollOfScalar& u) -> CollOfScalar {
            return computeResidual(u, u0, dt);
        };
        const CollOfScalar u_guess = u0;
        const CollOfScalar u = er.newtonSolve(computeResidualLocal, u_guess);
        er.output("u", u);
        er.output("maximum of u", er.maxReduce(u));
        u0 = u;
    }

    // ============= Generated code ends here ================

    return 0;
}

void ensureRequirements(const equelle::EquelleRuntimeCPU& er)
{
    (void)er;
}
