
using ApproxFun, OrdinaryDiffEq, Sundials, BenchmarkTools, DiffEqOperators
using DiffEqDevTools
using LinearAlgebra
using Plots; gr()


# Define the linear and nonlinear terms
function lin_term(N)
    dx = 1/(N + 1)
    du = ones(N-1) # off diagonal
    du2 = -ones(N-1) # off diagonal
    d = (1/2) * ones(N-2)
    d2 = (-1/2) * ones(N-2)
    diag=-2 * ones(N)
    DiffEqArrayOperator(5e-5*(1/dx^3) * diagm(-2 => d2, -1 => du, 1 => du2, 2 => d))
end

function nl_term(N)
    dx = 1/(N + 1)
    du = ones(N - 1) # super diagonal
    dl = -ones(N - 1) # lower diagonal
    D = (0.2/dx) * diagm(-1 => dl, 1 => du)

    tmp = zeros(N)
    function (du,u,p,t)
        @. tmp = u^2
        mul!(du, D, tmp)
    end
end

# Construct the problem
function kdv(N)
    f1 = lin_term(N)
    f2 = nl_term(N)
    dx = 1 / (N + 1)
    xs = (1:N) * dx

    μ0 = 0.3; σ0 = 0.05
    f0 = x -> 0.9*exp(-(x - μ0)^2 / (2 * σ0^2))
    u0 = f0.(xs)
    prob = SplitODEProblem(f1, f2, u0, (0.0, 1.0))
    xs, prob
end;


xs, prob = kdv(200)
sol = solve(prob, Tsit5(); abstol=1e-11, reltol=1e-11, dt=1e-7, adptive=false)
test_sol = TestSolution(sol);

tslices = [0.0 0.25 0.50 0.75 1.00]
ys = hcat((sol(t) for t in tslices)...)
labels = ["t = $t" for t in tslices]
fn=plot(xs, ys, label=labels)


const LS_Dense = LinSolveFactorize(lu)


abstols = 0.1 .^ (5:8) # all fixed dt methods so these don't matter much
reltols = 0.1 .^ (1:4)
multipliers = 0.5 .^ (0:3)
setups = [Dict(:alg => IMEXEuler(linsolve=LS_Dense), :dts => 1e-3 * multipliers),
          Dict(:alg => CNAB2(linsolve=LS_Dense), :dts => 1e-5 * multipliers),
          Dict(:alg => CNLF2(linsolve=LS_Dense), :dts => 1e-4 * multipliers),
          Dict(:alg => SBDF2(linsolve=LS_Dense), :dts => 1e-3 * multipliers)]
labels = ["IMEXEuler" "CNAB2" "CNLF2" "SBDF2"]
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="IMEX methods, dense linsolve, low order")


abstols = 0.1 .^ (5:8) # all fixed dt methods so these don't matter much
reltols = 0.1 .^ (1:4)
multipliers = 0.5 .^ (0:3)
setups = [#Dict(:alg => IMEXEuler(linsolve=LinSolveGMRES()), :dts => 1e-5 * multipliers),
          Dict(:alg => CNAB2(linsolve=LinSolveGMRES()), :dts => 1e-5 * multipliers),
          Dict(:alg => CNLF2(linsolve=LinSolveGMRES()), :dts => 1e-5 * multipliers),
          Dict(:alg => SBDF2(linsolve=LinSolveGMRES()), :dts => 1e-4 * multipliers)]
labels = ["IMEXEuler" "CNAB2" "CNLF2" "SBDF2"]
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="IMEX methods, Krylov linsolve, low order")


abstols = 0.1 .^ (5:8) # all fixed dt methods so these don't matter much
reltols = 0.1 .^ (1:4)
multipliers = 0.5 .^ (0:3)
setups = [Dict(:alg => NorsettEuler(), :dts => 1e-6 * multipliers),
          Dict(:alg => NorsettEuler(krylov=true, m=5), :dts => 1e-3 * multipliers),
          #Dict(:alg => NorsettEuler(krylov=true, m=20), :dts => 1e-3 * multipliers), matrix contains Infs or NaNs
          Dict(:alg => ETDRK2(), :dts => 1e-3 * multipliers),
          Dict(:alg => ETDRK2(krylov=true, m=20), :dts => 1e-2 * multipliers),
          Dict(:alg => ETDRK2(krylov=true, m=20), :dts => 1e-2 * multipliers)]
labels = hcat("NorsettEuler (caching)", "NorsettEuler (m=5)",# "NorsettEuler (m=20)",
              "ETDRK2 (caching)", "ETDRK2 (m=5)"), "ETDRK2 (m=20)")
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="ExpRK methods, low order")


abstols = 0.1 .^ (5:8) # all fixed dt methods so these don't matter much
reltols = 0.1 .^ (1:4)
multipliers = 0.5 .^ (0:3)
setups = [Dict(:alg => CNAB2(linsolve=LS_Dense), :dts => 1e-5 * multipliers),
          Dict(:alg => CNAB2(linsolve=LinSolveGMRES()), :dts => 1e-5 * multipliers),
          Dict(:alg => ETDRK2(), :dts => 1e-3 * multipliers)]
labels = ["CNAB2 (dense linsolve)" "CNAB2 (Krylov linsolve)" "ETDRK2 (m=5)"]
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="Between family, low orders")


abstols = 0.1 .^ (7:13)
reltols = 0.1 .^ (4:10)
setups = [Dict(:alg => KenCarp3(linsolve=LS_Dense)),
          Dict(:alg => KenCarp4(linsolve=LS_Dense)),
          Dict(:alg => KenCarp5(linsolve=LS_Dense)),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=3, linear_solver=:Dense)),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=4, linear_solver=:Dense)),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=5, linear_solver=:Dense))]
labels = hcat("KenCarp3", "KenCarp4", "KenCarp5", "ARKODE3", "ARKODE4", "ARKODE5")
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="IMEX methods, dense linsolve, medium order")


abstols = 0.1 .^ (7:13)
reltols = 0.1 .^ (4:10)
setups = [Dict(:alg => KenCarp3(linsolve=LinSolveGMRES())),
          Dict(:alg => KenCarp4(linsolve=LinSolveGMRES())),
          Dict(:alg => KenCarp5(linsolve=LinSolveGMRES())),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=3, linear_solver=:GMRES)),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=4, linear_solver=:GMRES)),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=5, linear_solver=:GMRES))]
labels = ["KenCarp3" "KenCarp4" "KenCarp5" "ARKODE3" "ARKODE4" "ARKODE5"]
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="IMEX methods, medium order")


abstols = 0.1 .^ (7:11) # all fixed dt methods so these don't matter much
reltols = 0.1 .^ (4:8)
multipliers = 0.5 .^ (0:4)
setups = [Dict(:alg => ETDRK3(), :dts => 1e-2 * multipliers),
          #Dict(:alg => ETDRK3(krylov=true, m=5), :dts => 1e-2 * multipliers),matrix contains Infs or NaNs
          Dict(:alg => ETDRK4(), :dts => 1e-3 * multipliers),
          #Dict(:alg => ETDRK4(krylov=true, m=5), :dts => 1e-2 * multipliers),matrix contains Infs or NaNs
          Dict(:alg => HochOst4(), :dts => 1e-2 * multipliers)]
          #Dict(:alg => HochOst4(krylov=true, m=5), :dts => 1e-2 * multipliers)] matrix contains Infs or NaNs
labels = hcat("ETDRK3 (caching)", "ETDRK4 (caching)",# "ETDRK3 (m=5)", "ETDRK4 (m=5)"
              "HochOst4 (caching)")#, "HochOst4 (m=5)")
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="ExpRK methods, medium order")


abstols = 0.1 .^ (7:11)
reltols = 0.1 .^ (4:8)
multipliers = 0.5 .^ (0:4)
setups = [Dict(:alg => KenCarp5(linsolve=LS_Dense)),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=5, linear_solver=:Dense)),
          Dict(:alg => KenCarp5(linsolve=LinSolveGMRES())),
          Dict(:alg => ARKODE(Sundials.Implicit(), order=5, linear_solver=:GMRES)),
          Dict(:alg => ETDRK3(), :dts => 1e-2 * multipliers),
          Dict(:alg => ETDRK4(), :dts => 1e-3 * multipliers)]
labels = hcat("KenCarp5 (dense linsolve)", "ARKODE (dense linsolve)", "KenCarp5 (Krylov linsolve)",
              "ARKODE (Krylov linsolve)", "ETDRK3 (m=5)", "ETDRK4 (m=5)")
@time wp = WorkPrecisionSet(prob,abstols,reltols,setups;
                            print_names=true, names=labels,
                            numruns=5, error_estimate=:l2,
                            save_everystep=false, appxsol=test_sol, maxiters=Int(1e5));

plot(wp, label=labels, markershape=:auto, title="Between family, medium order")


using DiffEqBenchmarks
DiffEqBenchmarks.bench_footer(WEAVE_ARGS[:folder],WEAVE_ARGS[:file])

