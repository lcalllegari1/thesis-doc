#import "/theme/headings.typ": *
#import "/theme/utils.typ": *

#chapter([Discussion], label: <chap:discussion>)

This chapter combines the progression of Chapters 4 and 5 with the results of the evaluation in @chap:evaluation to answer the research questions, delimit the conclusions, and identify the resulting architectural choices.

#section([Research Findings], label: <sec:research-findings>)

The answers to the research questions require direct cost rankings within matched coverage and structural privacy. Comparisons across those boundaries instead measure what is saved or paid by changing a guarantee or disclosure surface.

#subsection([Monolithic Design and Behavior], label: <sub:discussion-monolithic-scalability>)

A credible baseline must remove avoidable circuit costs before any difference is attributed to decomposition. Chapter 4 compares four permutation mechanisms, rejects the quadratic pairwise check, and selects sorting as the canonical exact mechanism (@sub:permutation-selection). The refined construction then replaces the cost matrix's quadratic proof-system public surface with one Merkle root (@sec:optimized-circuit).

After refinement, the complete relation remains one proving task. Its circuit and prover requirements grow with $n$, with backend padding making the progression stepped (@sub:monolithic-circuit-growth, @sub:monolithic-prover-scaling). Maximum Barretenberg-reported proving memory rises from $2.39$ GiB at $n=1000$ to $12.95$ GiB when $n=4000$, the largest successful monolithic checkpoint. The $n=5000$ attempt exceeds the host's memory budget. Proof size remains $14\,656$ bytes and the verifier still receives the two-value interface $(root,T)$. The result is a comparison-ready baseline within the fixed stack: its verifier interface remains succinct, but one prover still absorbs growing whole-route work and memory.

#subsection([Advantages of Decomposition], label: <sub:discussion-composite-memory>)

Against this baseline, decomposition divides the route-level work among smaller tasks and adds recombination. The combined segment work remains close to the whole-route computation, so its possible advantages lie in reducing the largest task, extending the range feasible on fixed hardware, and exposing work that can be scheduled independently.

The external constructions exhibit two recombination regimes. Sort glue retains the global sort over all $n$ nodes and becomes the limiting task: when $n=4000$, both sort variants remain near $8.8$ GiB for every measured $K$, below the $12.95$-GiB monolithic baseline but fixed by the same glue floor. Product glue combines compact fingerprints and chain summaries and remains smaller than a segment, allowing the complete peak to fall to approximately $1.6$ GiB at $K=8$ (@fig:component-memory-n4000). This lower profile depends on the computational product-coverage mechanism and is not an unconditional improvement over exact sorting (@sub:plain-product-challenge).

Recursion creates a third regime: increasing $K$ shrinks the inner tasks but enlarges the outer circuit through additional constrained proof verifications. The lowest measured recursive peak at $n=4000$ therefore occurs at $K=4$, before the outer stage becomes dominant. Every composite construction also completes at $n=5000$, beyond the successful monolithic range, although the sort variants already approach the host budget. Segmentation is consequently a resource-allocation parameter rather than a quantity to maximize.

Scheduling introduces a separate trade-off. On one host, every composite schedule at the shared $n=4000$ checkpoint is at least as long as the monolithic one. External segment and glue tasks can run independently, whereas recursion retains a dependent outer stage. The distributed estimates exploit this distinction by adding comparable workers and are not hardware-normalized speedups. The capacity requirement falls when the largest composite task stays below the monolithic proving task.

#subsection([Recombination and Structural Privacy], label: <sub:discussion-structural-tradeoffs>)

Segmentation removes the global view that lets one circuit enforce the complete claim. Recombination must restore agreement on the matrix root and threshold, continuity across segment boundaries and cycle closure, aggregation of the partial costs and the threshold check, and coverage of every node (@sub:recombination-contract). The constructions share this contract but differ in how they represent its evidence, what crosses the segment boundary, and who checks it.

The plain constructions publish the summaries required for external recombination: node sets or testable fingerprints, together with endpoints and partial costs. Commitments hide the summary contents behind blinded digests while retaining $K+1$ external proofs and reconciliation; committed product also retains the public whole-route challenge $X$. Recursive product instead supplies the inner proofs and their interfaces as private outer-circuit witness data, leaving the final verifier with one proof over $(root,T)$ and no public per-segment values.

These interfaces place the corresponding costs differently. Commitments add hiding and opening work while leaving proof checks and public-input reconciliation to the final verifier. Recursion absorbs those checks into a dependent outer proving stage whose constrained verification cost grows with $K$. Plain-to-committed comparisons measure the price of hiding within one coverage family, while external-to-recursive product measures the cost of removing the public segment interface. Sort-to-product comparisons also change the coverage representation and soundness properties. The recombination interface determines the attainable structural privacy and whether the final verifier, glue prover, or recursive outer prover enforces the contract.

#figure(
  placement: top,
  block(width: 100%, breakable: false)[
    #set text(size: 8.5pt)
    #set par(justify: false)
    #table(
      columns: (1.02fr, 1.55fr, 1.08fr, 1.48fr, 1.52fr),
      stroke: none,
      align: (left, left, left, left, left),
      inset: (x: 3pt, y: 4.5pt),

      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Construction]],
        text(font: "Libertinus Sans")[#smallcaps[Coverage and disclosure]],
        text(font: "Libertinus Sans")[#smallcaps[Memory limiter]],
        text(font: "Libertinus Sans")[#smallcaps[Prover schedule]],
        text(font: "Libertinus Sans")[#smallcaps[Final verifier]],
      ),
      table.hline(stroke: 0.6pt),

      [monolithic sort], [exact; no partition surface], [whole-route circuit], [one task], [one proof; two inputs],
      table.hline(stroke: 0.3pt),
      [plain sort], [exact; public node sets, endpoints, and costs], [glue], [independent segments and glue], [$K+1$ proofs; reconciliation; payload grows with $n$],
      [committed sort], [exact; blinded segment digests], [glue], [independent tasks with hiding overhead], [$K+1$ proofs; digest reconciliation],
      table.hline(stroke: 0.3pt),
      [plain product], [computational; testable summaries], [segment], [independent segments and compact glue], [$K+1$ proofs; payload grows with $K$],
      [committed product], [computational; blinded digests and public $X$], [segment], [independent tasks and compact committed glue], [$K+1$ proofs; digest reconciliation],
      table.hline(stroke: 0.3pt),
      [recursive product], [computational; no final per-segment values], [segment/outer crossover], [parallel inner stage; dependent outer stage], [one proof; two inputs],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Architectural profiles of the evaluated constructions.])[
    Architectural synthesis of the structural properties in Chapter 5 and the measurements in Chapter 6. Memory limiters describe the observed large-instance regime rather than universal asymptotes. Costs are directly comparable only under matched coverage and structural privacy.
  ],
) <table:discussion-architectural-profiles>

Together, the profiles in @table:discussion-architectural-profiles answer the leading question from @sec:research-questions. The monolithic architecture keeps the global relation in one growing proving task and gives the verifier one proof over a compact interface. Composite architectures create smaller, independently schedulable tasks, while recombination restores the conditions that no segment can prove alone. Whether this change is useful depends on the recombination task, coverage guarantee, disclosure boundary, available workers, and final-verifier capacity.

#section([Beyond TSP Proofs], label: <sec:beyond-route-proofs>)

TSP exposes the semantic cut behind this study. Arc authentication and internal cost accumulation can be checked within a segment, while global coverage, continuity between segments, cycle closure, and the threshold depend on the complete route.

The same approach may apply when a relation admits a natural witness partition and each local proof can establish a meaningful claim from its part. Recombination must then enforce the conditions that cross the partition through explicit boundary evidence. Depending on the application, those conditions may be an aggregate bound, uniqueness across a collection, continuity between steps, or agreement on shared state. A relation-aware design therefore asks where to cut the relation, what each piece can prove, which global properties the cut removes, what evidence must cross the boundary, and where the complete claim should be restored.

#section([Limitations], label: <sec:limitations>)

The measurements characterize one TSP relation, one canonical satisfying instance for each $n$, and one consumer host and proving stack (@sub:experimental-setup). Circuit shape, gate count, proof topology, and dominant backend allocations depend principally on the structural parameters, but unconstrained witness generation can remain input-sensitive. Absolute times, memory requirements, padded-domain transitions, and capacity boundaries may change with the instance family, hardware, compiler, backend, or software release. The metric definitions and preprocessing and setup exclusions follow @sub:measurement-protocol; verifier timing also excludes application-specific reconciliation (@sec:verifier-load).

The evaluation covers selected values of $n$, $K in {2,4,8}$, and equal-length segments. The refined monolithic baseline is comparison-ready, but it could include further improvements, and the five composite constructions are selected points rather than an exhaustive frontier. The study therefore identifies neither a universally optimal $K$ nor a universally best proof architecture; unequal partitions, other coverage mechanisms, or other recombination strategies may shift the balance.

No networked cluster was deployed. Distributed completion times compose uncontended component runs and exclude communication, coordination, contention, failures, retries, and aggregate resource use. The model assumes workers controlled by one logical prover and does not address malicious workers or confidentiality of the witness material assigned to them.

The targeted cheating tests in @sec:correctness-testing are implementation sanity checks, not a formal security proof, external audit, or verification of the complete compiler and backend toolchain. The security claims remain conditional on UltraHonk, Fiat--Shamir, Poseidon2, product-based coverage, commitment binding and hiding, and authenticated verification keys. The implementation also lacks explicit domain separation among its Poseidon2 uses (@sub:commitment-layer).

#section([Future Work], label: <sec:future-work>)

The central technical target is recombination. An exact-coverage representation that avoids the global sort could reduce the glue floor without adding the probabilistic error of product coverage. Folding, aggregation, or specialized recursive verification may also reduce the cost of absorbing local proofs or the number of checks exposed to the final verifier (@sec:related-recursion-pcd). A related design could occupy the gap between external commitments and full recursion, hiding segment structure and reducing the final proof set without reproducing the complete outer-circuit cost.

The relation-aware method of @sec:beyond-route-proofs should be tested on another globally constrained relation, starting from a credible monolithic baseline and an explicit recombination contract. Repeating the comparison under another compiler, proof system, hardware configuration, or instance distribution would help distinguish effects of semantic decomposition from behavior specific to Noir, UltraHonk, and the benchmark host.

Deployment-aware decomposition should choose the segment count and sizes from worker memory, worker count, acceptable completion time, verifier load, and structural-privacy requirements, rather than fixing equal-length segments and $K in {2,4,8}$. Unequal or adaptive partitions should then be evaluated on a networked deployment that measures communication, coordination, contention, failures, and aggregate resource use omitted from the schedules in @sec:end-to-end-prover-time.

Before deployment, the construction requires stronger assurance. The implementation should separate its Poseidon2 domains explicitly, formalize the security of the complete composition, extend adversarial testing, and undergo external review. It would also need authenticated verification keys and build artifacts, together with an explicit worker-trust and witness-confidentiality model.


#section([Conclusions], label: <sec:conclusions>)

For the TSP relation studied here, decomposition moves global coverage, continuity, cycle closure, and total-cost enforcement into recombination. Segment proofs establish authenticated local arcs and partial costs, but not the complete claim. Glue or recursion must restore that claim without recreating the whole-route bottleneck.

Recombination also sets the guarantee and disclosure boundary. Sort glue preserves exact coverage but retains a global sort. Product fingerprints yield the lower measured memory profile at the price of a negligible probabilistic soundness error. Plain external constructions expose segment summaries; commitments hide their contents but retain $K+1$ proofs, a visible partition topology, and final-verifier reconciliation. Recursion keeps the inner proofs and interfaces private from the final verifier, which receives one proof over $(root,T)$, but adds a dependent outer proving stage.

With one sufficiently capable prover, the refined monolithic construction remains the simplest choice: it preserves exact coverage, hides the route and cost, and produces one proof. A memory-constrained prover can run a composite construction sequentially at a lower peak and longer completion time; multiple workers can schedule external tasks concurrently. Among the evaluated composites, exact coverage selects sort, whereas product offers the lower measured memory profile when its probabilistic guarantee is acceptable. For external recombination, commitments hide segment summaries but retain the proof collection. Recursion fits deployments that require one final proof and can support the dependent outer stage, especially when verification is constrained or widely replicated.

The value of decomposition depends on whether recombination restores the global claim within the deployment's memory, scheduling, verification, and disclosure constraints.
