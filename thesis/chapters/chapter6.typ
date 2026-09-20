#import "/theme/headings.typ": *
#import "/theme/utils.typ": *



#chapter([Evaluation], label: <chap:evaluation>)

Chapters 4 and 5 developed the refined monolithic baseline and five composite architectures. This chapter evaluates them under one proving stack, measuring aggregate constrained work, peak prover memory, completion time under sequential and distributed schedules, and final-verifier load. Because the constructions differ in both coverage and public-interface disclosure, costs are ranked directly only where the coverage mechanism and structural-privacy level are held fixed.

#section([Methodology], label: <sec:evaluation-methodology>)

The evaluation compares the architectures under one fixed proving stack and matched inputs. At each route length, every construction receives the same graph and route, while its segment, recombination, and recursive stages are measured as separate proving tasks. The later sections compose these measurements according to the dependencies of each architecture.

#subsection([Experimental Setup], label: <sub:experimental-setup>)

All measurements were collected on one consumer laptop, with Barretenberg using its default native parallelism. The resulting times and capacity limits characterize this host and toolchain, under which every construction is measured. @table:evaluation-environment records the fixed configuration.

Noir compiles each circuit to ACIR, which Barretenberg lowers to UltraHonk under the pinned releases in the table @noir2026 @barretenberg2026. For each $n$, seed 42 determines one complete symmetric Euclidean graph and one valid Hamiltonian cycle of cost $w$.

#figure(
  table(
    columns: (1.2fr, 3.65fr),
    stroke: none,
    align: (left, left),
    inset: (x: 8pt, y: 6pt),
    row-gutter: (0pt, 5pt),

    table.hline(stroke: 1pt),
    table.header(
      text(font: "Libertinus Sans")[#smallcaps[Component]],
      text(font: "Libertinus Sans")[#smallcaps[Configuration]],
    ),
    table.hline(stroke: 0.6pt),
    [Processor], [11th Gen Intel Core i7-1165G7; 4 cores, 8 threads; 2.80 GHz nominal, 4.70 GHz maximum],
    [Memory], [16 GiB installed, approximately 15 GiB visible to the operating system; 4 GiB swap],
    [Storage], [512 GB Intel NVMe solid-state drive],
    [Operating \ system], [Ubuntu 24.04 LTS, x86-64],
    [Circuit \ compiler], [Noir and Nargo 1.0.0-beta.20, \ commit #inline[b4236c1957d0c26c]],
    [Proving \ backend], [Barretenberg 5.0.0-nightly.20260324; UltraHonk],
    [Recursive \ library], [#inline[bb_proof_verification], tag 5.0.0-nightly.20260518],
    [Auxiliary \ tools], [Python 3.12 for orchestration; \ Rust for proof-compatible off-circuit data construction],
    table.hline(stroke: 1pt),
  ),
  caption: outline-caption(short: [Evaluation hardware and software.])[
    Hardware and software configuration used for the evaluation.
  ],
) <table:evaluation-environment>

The public threshold is $T = ceil(1.1 w).$ This gives every benchmark a known feasible witness. At fixed $n$, all constructions and runs reuse the same graph, route, matrix commitment, and authentication data. The comparison therefore controls instance choice to study architectural behavior; it does not estimate performance over a distribution of graphs.

The evaluation varies the route length $n$ and, for composite proofs, the number of equal-length segments $K$. The segment length and Merkle authentication depth follow as

$ M = n / K, quad d = ceil(log_2(n^2)), $

where $M$ is the number of nodes per segment and $d$ is the authentication-path depth over the $n^2$ matrix entries. The composite grid uses $K in {2,4,8}$. Its route lengths up to 1000 are $n in {48,96,128,256,512,768,1000}$; the larger checkpoints are $n in {1504,2000,2504,3000,4000,5000}$.

Every selected route length is divisible by eight; 1504 and 2504 are used in place of 1500 and 2500. Monolithic measurements span $n=8$ to $n=4000$, with denser sampling at smaller sizes. Monolithic cells have three runs through $n=1000$ and two at the larger checkpoints; each external cell has three runs and each recursive cell has two. Measurements that exceed the host's capacity are reported as unavailable rather than extrapolated.

#subsection([Measurement Protocol], label: <sub:measurement-protocol>)

Each circuit is compiled and its verification key generated once per parameterization. The pipeline then generates the witness, produces the proof, and verifies it. Segment, glue, inner, and outer invocations remain separate in the raw data so that later sections can compose them according to each architecture. Compilation and key generation are setup costs rather than recurring online prover time.

The recorded metrics cover the compiler, backend, and verifier interfaces. ACIR opcodes measure the compiler-level circuit, while UltraHonk gates measure its backend expansion. Public-input slots and proof bytes describe the verifier-facing artifacts. A monotonic high-resolution timer records compilation, witness generation, proving, and verification wall-clock intervals, including the tools' normal internal parallelism. Memory is the largest checkpoint printed by Barretenberg during one proving invocation, reported as _maximum Barretenberg-reported proving memory_ rather than operating-system resident-set size.

Gate counts, opcode counts, public-input counts, and proof sizes are deterministic for a fixed parameterization and toolchain. Wall-clock measurements can contain system noise, so their central curve uses the smallest observation among the repeated successful runs and retains the full observed minimum--maximum interval where the plot permits it. This lower envelope estimates the least-contended execution observed on the benchmark host, not expected user time.

Memory uses the median of the run-level maximum checkpoints, with the observed range retained even where it collapses onto the central curve. Complete architectural quantities are derived within each matched run before the corresponding timing or memory summary is selected, so no result combines components taken from different runs.

The measured boundary excludes graph and route generation, Merkle construction, authentication-path extraction, input serialization, verification-key derivation, and deployment orchestration. Distributed completion times compose isolated component measurements according to the architectural dependencies; no networked cluster is measured, and communication and coordination remain outside the model.

#section([Correctness Testing], label: <sec:correctness-testing>)

Before measuring performance, each implementation was exercised on a valid reference instance and targeted negative cases derived from Chapters 4 and 5. Each case changes one value or required relationship while keeping the remaining inputs consistent, so rejection isolates the relevant boundary: circuit constraints, external reconciliation, or recursive verification. In external composition, individually valid segment and glue proofs can still form an inconsistent package and are rejected only during reconciliation. These development-time checks exercise the evaluated code; no formal validation procedure or maintained test suite was used.

Every valid reference was accepted, and each manipulation in @table:correctness-tests was rejected at the intended boundary. These results provide useful sanity checks that the implemented constraints and composition interfaces match their specifications. Cryptographic soundness is not formally derived from them; it still relies on the soundness of UltraHonk, the collision resistance of Poseidon2, commitment binding, and the analytical error bound for product coverage.

#page[
  #layout(size => align(center + horizon)[
    #rotate(-90deg, origin: center, reflow: true)[
      #box(width: size.height)[
        #set text(size: 9.5pt)
        #set par(justify: false)

        #figure(
          block(width: 100%, breakable: false)[
      #table(
        columns: (1.25fr, 1.9fr, 1.65fr, 1.25fr),
        stroke: none,
        align: (left, left, left, left),
        inset: (x: 5pt, y: 5pt),

        table.hline(stroke: 1pt),
        table.header(
          text(font: "Libertinus Sans")[#smallcaps[Protected property]],
          text(font: "Libertinus Sans")[#smallcaps[Targeted manipulation]],
          text(font: "Libertinus Sans")[#smallcaps[What acceptance would permit]],
          text(font: "Libertinus Sans")[#smallcaps[Rejection boundary]],
        ),
        table.hline(stroke: 0.6pt),

        [Route validity],
        [Repeat one node and omit another, or supply an out-of-range identifier],
        [A non-Hamiltonian route],
        [Range and permutation/coverage constraints],

        [Authenticated costs],
        [Alter an edge cost, path direction, sibling value, or root],
        [A cost not drawn from the committed matrix],
        [Merkle index and root checks],

        [Cost aggregation and threshold],
        [Change a partial cost, or set $T$ below the authenticated total],
        [An underreported cost or an infeasible route],
        [Local summation and global threshold constraints],

        [Global coverage],
        [Place a node in two segments and omit another],
        [Locally valid segments that are not a global permutation],
        [Glue or outer sort/product check],

        [Boundary consistency],
        [Alter an endpoint, boundary cost, or boundary authentication path],
        [Segments that do not connect into the authenticated cycle],
        [Recombination topology and Merkle checks],

        [Product and chain binding],
        [Alter $P_i$, a chain anchor, or the common challenge while retaining the other values],
        [A summary not derived from the certified ordered segments],
        [Product, chain, and challenge constraints],

        [External proof binding],
        [Combine valid segment proofs for one route with a valid recombination proof for another],
        [Separately valid proofs that certify inconsistent statements],
        [Post-verification reconciliation],

        [Commitment binding],
        [Alter a hidden summary or opening while retaining its digest, or disagree on the two digest copies],
        [Segment and glue proofs using different concealed values],
        [Commitment recomputation and digest equality],

        [Recursive binding],
        [Alter an inner proof or summary, or substitute an inner relation bound to a different key],
        [An uncertified summary or a proof of the wrong relation],
        [In-circuit proof verification and canonical outer key],

        table.hline(stroke: 1pt),
      )
          ],
          caption: outline-caption(short: [Targeted adversarial correctness tests.])[
            Targeted adversarial manipulations and the enforcement boundary exercised by each. Valid reference cases were accepted, while every listed manipulation was rejected at the indicated boundary.
          ],
        ) <table:correctness-tests>
      ]
    ]
  ])
]

#section([Monolithic Baseline], label: <sec:monolithic-baseline>)

Chapter 4 developed _monolithic-merkle-sort_ as the refined monolithic baseline, addressing the design part of the first research question. We now measure how its circuit and prover requirements grow with $n$ under the environment and reporting conventions of @sec:evaluation-methodology.

#subsection([Circuit Growth], label: <sub:monolithic-circuit-growth>)

The complete route remains in one circuit: coverage sorts $n$ node identifiers, while cost binding authenticates $n$ selected arcs through paths of depth $ceil(log_2(n^2))$. @fig:monolithic-circuit-growth reports the resulting compiler and backend circuit sizes.

#figure(
  image("/assets/figures/acir_and_gates_monolithic.pdf"),
  caption: outline-caption(short: [Monolithic circuit-size scaling.])[
    Compiler-level ACIR opcodes and backend UltraHonk gates for the refined monolithic circuit as the route length $n$ increases. Both are deterministic counts for the fixed toolchain and are shown on logarithmic axes.
  ],
) <fig:monolithic-circuit-growth>

Both representations grow with $n$, with backend lowering placing the gate curve above the opcode curve. At $n=4000$, the circuit reaches approximately $8.30$ million UltraHonk gates. This behavior follows the construction in @sec:optimized-circuit: the Merkle root removes the quadratic public-input surface, but sorting and authenticating the route still grow with $n$.

#subsection([Prover Resources and Host Boundary], label: <sub:monolithic-prover-scaling>)

The practical boundary depends on maximum reported proving memory, witness-generation time, and proving time, shown together in @fig:monolithic-prover-cost.

#figure(
  image("/assets/figures/mem_wit_prove_time.pdf", width: 92%),
  caption: outline-caption(short: [Monolithic prover-cost scaling.])[
    Maximum Barretenberg-reported proving memory, witness-generation time, and proving time for the refined monolithic circuit, on logarithmic axes. For each $n$, the memory curve is the median of the per-run peaks, while the timing curves use the smallest successful observation. Bands span the observed minimum--maximum ranges, following @sub:measurement-protocol.
  ],
) <fig:monolithic-prover-cost>

All three resources increase over the measured range. At $n=4000$, the circuit uses $12.95$ GiB of maximum reported proving memory, takes $33.45$ seconds to generate the witness, and takes $114.38$ seconds to prove.

Proof size and verification do not constrain the measured range: UltraHonk proofs remain $14\,656$ bytes, and the Merkle root fixes the public interface at $(root,T)$, keeping verification at the millisecond scale already observed in @fig:flat-refined-behavior.

The endpoint $n=4000$ is the largest successful monolithic checkpoint, and its reported memory already approaches the approximately $15$ GiB visible to the host. The failed $n=5000$ attempt places the fixed-host boundary between those checkpoints without locating its exact value. Different hardware, backend behavior, or circuit components could move it; under the evaluated stack, the complete route remains one proving task whose resource requirement grows with $n$.

#section([Composite Gate Accounting], label: <sec:aggregate-gate-work>)

The first quantitative test for RQ2 is whether smaller segments reduce the constrained work needed for the complete claim or redistribute it among more proving tasks. Aggregate gate accounting includes the route-dependent work retained by the segments and the stitching tax added by recombination (@sub:stitching-directions).

For an externally recombined construction, the aggregate gate count is

$ G_"external" (n,K) = K dot G_"segment" (n,K) + G_"glue" (n,K). $

For recursion, it is

$ G_"recursive" (n,K) = K dot G#h(1pt)_"inner" (n,K) + G_"outer" (n,K). $

At fixed $(n,K)$, the segments share one compiled circuit shape, and each is proved with a different witness. All $K$ invocations therefore contribute to the total. Recursion likewise includes the inner proofs and the dependent outer proof that verifies and recombines them.

#subsection([Aggregate Gate Work], label: <sub:aggregate-gate-overhead>)

For a construction $A$, define

$ R_A (n,K) = (G_A (n,K)) / (G_"monolithic-sort" (n)). $

The denominator is the refined monolithic Merkle-sort circuit from @sec:monolithic-baseline at the same $n$. The product panels also include _monolithic Merkle-product_, a mechanism-matched control. It retains the committed-matrix cost binding and threshold check of the refined monolithic circuit, but replaces exact sorting with the route-bound product check of @sub:plain-product-coverage and @sub:plain-product-challenge. The complete route remains in one circuit with public interface $(root,T)$, so the control separates coverage-mechanism cost from decomposition. @fig:aggregate-gate-overhead groups measurements by coverage, while the discussion follows Chapter 5's plain, committed, and recursive progression.

#figure(
  placement: top,
  image("/assets/figures/gate_ratio_stacked.pdf"),
  caption: outline-caption(short: [Aggregate gate overhead of composite constructions.])[
    Aggregate UltraHonk gates for the five composite constructions relative to monolithic Merkle-sort at the same $n$. Each external total is given by $K dot G_"segment" + G_"glue"$, and each recursive total is $K dot G_"inner" + G_"outer"$. The external panels use the same linear vertical scale, while the recursive panel is logarithmic. The faint dashed curve in both product panels is the mechanism-matched monolithic Merkle-product control; it ends at $n=3000$, its largest successful measurement. Lines join measured checkpoints. Sizes without a corresponding monolithic-sort denominator are omitted.
  ],
) <fig:aggregate-gate-overhead>

Both plain constructions amortize their composition overhead. Plain-sort ranges from 1.132×--1.454× at $n=48$ and narrows to 1.014×--1.016× at $n=4000$. Its absolute overhead grows, but becomes a smaller fraction of the shared route authentication and cost work. Larger $K$ repeats fixed segment constraints and adds boundary summaries, separating the curves most clearly at small $n$. At $n=3000$, plain-product reaches 1.032×--1.035× against a 1.030× monolithic-product control. The control accounts for most of its distance from the canonical sort baseline, leaving external recombination as the smaller component.

For the committed constructions, hiding cost follows summary width. At $n=4000$, committed-sort remains at 1.074×--1.076×, above the 1.014×--1.016× plain-sort range, because both circuits fold node-dependent openings. Committed-product stays within 1.032×--1.035×, essentially the plain-product range, because it commits to one fixed-size summary per segment. The product variants therefore have nearly equal gate counts despite their different disclosure surfaces (@sub:plain-tradeoffs, @sub:committed-disclosure).

Recursion changes the topology by constraining $K$ proof verifications inside the outer circuit (@sub:recursive-verification). Aggregate cost ranges from 28.88×--116.03× at $n=48$ and falls to 1.209×--1.765× at $n=4000$. The product control isolates the mechanism, while the sort denominator locates recursion against the canonical thesis baseline.


The common denominator places every construction on one accounting scale. Plain, committed, and recursive composition offer different disclosure surfaces, while sort and product offer different coverage guarantees. Direct cost rankings therefore require matched structural privacy and coverage; cross-group comparisons quantify what is paid for a changed interface or mechanism.


@table:aggregate-gate-ratios records the exact representative values from the sweep under the common sort denominator.

#figure(
  block(width: 100%, breakable: false)[
    #set text(size: 9.5pt)
    #set par(justify: false)
    #table(
              columns: (1.45fr, 0.36fr, 0.78fr, 0.78fr, 0.78fr, 0.78fr, 0.78fr),
              stroke: none,
              align: (left, center, center, center, center, center, center),
              inset: (x: 3pt, y: 4pt),

              table.hline(stroke: 1pt),
              table.header(
                text(font: "Libertinus Sans")[#smallcaps[Construction]],
                text(font: "Libertinus Sans")[$K$],
                text(font: "Libertinus Sans")[$n=48$],
                text(font: "Libertinus Sans")[$n=512$],
                text(font: "Libertinus Sans")[$n=1504$],
                text(font: "Libertinus Sans")[$n=3000$],
                text(font: "Libertinus Sans")[$n=4000$],
              ),
              table.hline(stroke: 0.6pt),

              [monolithic product], [--], [1.057], [1.039], [1.032], [1.030], [--],
              table.hline(stroke: 0.3pt),
              [plain sort], [2], [1.132], [1.024], [1.016], [1.014], [1.014],
              [plain sort], [4], [1.239], [1.031], [1.018], [1.015], [1.014],
              [plain sort], [8], [1.454], [1.046], [1.022], [1.017], [1.016],
              table.hline(stroke: 0.3pt),
              [committed sort], [2], [1.250], [1.104], [1.082], [1.074], [1.074],
              [committed sort], [4], [1.362], [1.112], [1.084], [1.075], [1.074],
              [committed sort], [8], [1.587], [1.127], [1.088], [1.077], [1.076],
              table.hline(stroke: 0.3pt),
              [plain product], [2], [1.171], [1.049], [1.036], [1.032], [1.032],
              [plain product], [4], [1.282], [1.056], [1.038], [1.033], [1.033],
              [plain product], [8], [1.503], [1.071], [1.042], [1.035], [1.034],
              table.hline(stroke: 0.3pt),
              [committed product], [2], [1.200], [1.051], [1.037], [1.033], [1.032],
              [committed product], [4], [1.341], [1.060], [1.039], [1.034], [1.033],
              [committed product], [8], [1.621], [1.079], [1.045], [1.036], [1.035],
              table.hline(stroke: 0.3pt),
              [recursive product], [2], [28.88], [2.881], [1.549], [1.268], [1.209],
              [recursive product], [4], [57.93], [4.803], [2.086], [1.515], [1.394],
              [recursive product], [8], [116.03], [8.645], [3.161], [2.010], [1.765],
              table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Aggregate gate ratios to monolithic Merkle-sort.])[
    Selected aggregate gate ratios relative to monolithic Merkle-sort at the same $n$. The monolithic-product row supplies the mechanism-matched control under this normalization. Its $n=4000$ entry is unavailable.
  ],
) <table:aggregate-gate-ratios>

#subsection([Distribution Across Proving Tasks], label: <sub:component-gate-distribution>)

We use $n=3000$, the largest checkpoint containing all five composite constructions, every value of $K$, and both monolithic controls. Monolithic product was attempted at $n=4000$, but the circuit crossed the next padded proving-domain boundary and exceeded the host's available memory.

@fig:component-gate-distribution splits each aggregate total into $K$ segment invocations and one recombination stage. Horizontal rules separate the segment block into individual proving units, while the hatched cap and its annotation report the recombiner and its share

$ G_"recombiner" / (K dot G_"segment" + G_"recombiner"). $

#figure(
  placement: top,
  image("/assets/figures/gate_breakdown_n3000.pdf"),
  caption: outline-caption(short: [Component gate distribution at $n=3000$.])[
    Distribution of aggregate UltraHonk gates at $n=3000$. Each bar contains $K$ segment-circuit invocations and one recombination circuit. The unhatched block is the aggregate segment work and is divided into $K$ equal slabs, each corresponding to one segment circuit; the hatched cap is the glue or recursive outer circuit. Percentages report the recombiner's share of the complete bar. Solid horizontal lines show monolithic Merkle-sort, while dashed lines in the product panels show monolithic Merkle-product. The external panels share a vertical scale; the recursive panel uses an enlarged scale.
  ],
) <fig:component-gate-distribution>

Across all five constructions, the combined segment block changes little with $K$ while one segment becomes smaller. The constructions follow the same pattern: segmentation divides the dominant route work into smaller proving units, and the aggregate total retains that work.

The conservation is approximate and not exact because increasing $K$ transfers boundary arcs to recombination, repeats fixed segment constraints, and changes the local coverage checks. The stacked scale compresses the external recombination caps, so @fig:recombiner-gate-cost shows the same glue and outer components on a shared logarithmic axis.

#figure(
  placement: top,
  image("/assets/figures/recombiner_cost_n3000.pdf", width: 92%),
  caption: outline-caption(short: [Recombiner gate costs at $n=3000$.])[
    Glue and outer UltraHonk gates at $n=3000$ on a shared logarithmic scale; annotations are in millions. The horizontal line is monolithic Merkle-sort. External proof checks and public-input reconciliation are excluded.
  ],
) <fig:recombiner-gate-cost>

Within the plain group, sort glue processes the same $n$ node values for every $K$, while product glue combines $K$ compact fingerprints with the $n$-factor target product. Both process more boundaries and summaries as $K$ grows, but the product recombiner remains much smaller because it avoids the global sort.


The committed group isolates the cost of hiding those interfaces. Committed-sort glue rises from the $0.062$--$0.075$ million plain-sort range to $0.279$--$0.291$ million gates because it re-folds node-dependent openings before global coverage. Committed-product stays at $0.014$--$0.029$ million, close to the $0.013$--$0.026$ million plain-product range, because each opening has fixed size. Hiding cost therefore follows summary width.


Each additional segment adds a constrained proof verification to the recursive outer circuit. It grows from $1.481$ million gates at $K=2$ to $3.019$ million at $K=4$ and $6.094$ million at $K=8$, raising its aggregate share from $18.8%$ to $48.7%$. At $K=8$, the outer circuit alone approaches either monolithic control, before accounting for the eight inner proofs. These gates move verification and recombination behind one final proof.

#figure(
  placement: top,
  block(width: 100%, breakable: false)[
    #set text(size: 9.5pt)
    #set par(justify: false)
    #table(
              columns: (1.4fr, 0.2fr, 0.7fr, 1fr, 1fr, 0.82fr, 1.3fr),
              stroke: none,
              align: (left, center, center, center, center, center, center),
              inset: (x: 3pt, y: 3pt),

              table.hline(stroke: 1pt),
              table.header(
                text(font: "Libertinus Sans")[#smallcaps[Construction]],
                text(font: "Libertinus Sans")[$K$],
                text(font: "Libertinus Sans")[#smallcaps[Segment]],
                text(font: "Libertinus Sans")[$K$ #smallcaps[Segments]],
                text(font: "Libertinus Sans")[#smallcaps[Recombination]],
                text(font: "Libertinus Sans")[#smallcaps[Aggregate]],
                text(font: "Libertinus Sans")[#smallcaps[Recombiner share]],
              ),
              table.hline(stroke: 0.6pt),

              [plain sort], [2], [3.124], [6.248], [0.062], [6.311], [1.0%],
              [plain sort], [4], [1.562], [6.250], [0.067], [6.316], [1.1%],
              [plain sort], [8], [0.782], [6.253], [0.075], [6.328], [1.2%],
              table.hline(stroke: 0.3pt),
              [committed sort], [2], [3.203], [6.407], [0.279], [6.685], [4.2%],
              [committed sort], [4], [1.602], [6.408], [0.283], [6.691], [4.2%],
              [committed sort], [8], [0.801], [6.412], [0.291], [6.703], [4.3%],
              table.hline(stroke: 0.3pt),
              [plain product], [2], [3.206], [6.413], [0.013], [6.426], [0.2%],
              [plain product], [4], [1.604], [6.414], [0.017], [6.432], [0.3%],
              [plain product], [8], [0.802], [6.418], [0.026], [6.443], [0.4%],
              table.hline(stroke: 0.3pt),
              [committed product], [2], [3.207], [6.413], [0.014], [6.427], [0.2%],
              [committed product], [4], [1.604], [6.416], [0.019], [6.435], [0.3%],
              [committed product], [8], [0.803], [6.421], [0.029], [6.450], [0.4%],
              table.hline(stroke: 0.3pt),
              [recursive product], [2], [3.206], [6.413], [1.481], [7.894], [18.8%],
              [recursive product], [4], [1.604], [6.414], [3.019], [9.433], [32.0%],
              [recursive product], [8], [0.802], [6.418], [6.094], [12.512], [48.7%],
              table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Component and aggregate gates at $n=3000$.])[
    Component and aggregate UltraHonk gates at $n=3000$, in millions. Monolithic controls are $6.225$ million gates for sort and $6.409$ million for product; shares use unrounded counts.
  ],
) <table:component-gate-distribution>

At fixed $n$, increasing $K$ shrinks one segment while the combined segment gate count remains almost unchanged. Whether this lowers the capacity requirement depends on the glue or outer task and on backend padding; the next section measures the complete peak directly.

#section([Peak Prover Memory], label: <sec:peak-prover-memory>)

The preceding section counted every proof invocation. Peak memory instead asks whether decomposition reduces the capacity required by any one proving task, one possible advantage under RQ2. A composite architecture improves on the monolithic baseline only if its recombination task also remains below it.

For an externally recombined construction, the complete peak is

$ P_"external" (n,K) = max[(max_(0 <= i < K) P_i^"seg"), P_"glue"]. $

For recursion, it is

$ P_"recursive" (n,K) = max[(max_(0 <= i < K) P_i^"inner"), P_"outer"]. $

Within each matched run, the largest segment or inner invocation is compared with the glue or outer invocation, and the median is taken only after this architectural peak is derived. Under the measured sequential schedule, only one benchmark task is active at a time, so their allocations are not added. Under distribution, the same equations describe the largest capacity required from one worker, not aggregate memory across concurrent workers.

#subsection([End-to-End Memory Scaling], label: <sub:end-to-end-memory-scaling>)

@fig:composite-memory-scaling reports the complete peak across the evaluation grid. Each composite point already contains the maximum over its segment and recombination tasks.

#figure(
  placement: top,
  image("/assets/figures/memory_smallmultiples_linear.pdf"),
  caption: outline-caption(short: [End-to-end proving-memory scaling.])[
    Median end-to-end maximum Barretenberg-reported proving memory for the five composite constructions. Within each matched run, the complete peak is the maximum over the $K$ segment invocations and the glue or outer invocation. All panels use the same linear axes. The solid reference is monolithic Merkle-sort; product-based panels also show monolithic Merkle-product as a faint dashed control. Open markers identify the last measured reference points. Lines join measured checkpoints and are not extrapolated.
  ],
) <fig:composite-memory-scaling>

The sort constructions converge as $n$ grows. At $n=4000$, plain-sort and committed-sort both require approximately $8.8$ GiB for every measured $K$: shorter segments no longer reduce the complete peak. Their overlap does not make the commitment layer free; @sub:component-gate-distribution records its additional constrained work. The similar peaks show instead that both constructions encounter the same memory floor.

The product curves remain separated by $K$. At $n=4000$, their peaks fall from approximately $6.0$ GiB at $K=2$ to $3.2$ GiB at $K=4$ and $1.6$ GiB when $K=8$, so the limiting task continues to shrink with the segment. The reduction is stepped rather than proportional because backend allocations do not vary continuously with circuit size. At $n=3000$, the largest checkpoint shared with the monolithic-product control, monolithic product itself uses less memory than monolithic sort; the composite curves nevertheless remain below this control, isolating an additional reduction from decomposition.

Recursion exposes the opposing effect. Increasing $K$ shrinks each inner task but gives the outer circuit more proofs to verify. At $n=4000$, $K=4$ has the lowest measured recursive peak, below both $K=2$ and $K=8$.

#subsection([Component Bottlenecks], label: <sub:component-memory-bottlenecks>)

We fix $n=4000$, the largest checkpoint shared by the canonical monolithic baseline and every composite configuration, and separate the largest segment or inner invocation from recombination. The monolithic-product control remains visible in @fig:composite-memory-scaling through its last successful measurement and is not extrapolated to this checkpoint.

#figure(
  placement: top,
  image("/assets/figures/memory_dumbbell_n4000.pdf"),
  caption: outline-caption(short: [Component proving-memory profiles at $n=4000$.])[
    Component proving-memory profiles at $n=4000$, the largest checkpoint shared by the canonical monolithic baseline and every composite configuration. Open markers report the median run-level largest-segment memory, while filled markers report median glue or outer memory. Complete peaks are medians of the run-level maxima; at this checkpoint, each coincides with the rightmost component median. Connecting lines associate the two stages and do not represent additive memory or uncertainty. The vertical line marks the median $12.95$-GiB monolithic Merkle-sort peak, displayed as $13.0$ GiB. The logarithmic axis keeps the small product recombination stages visible.
  ],
) <fig:component-memory-n4000>

Sort is glue-bound. From $K=2$ to $K=8$, plain-sort segment memory falls from $5.96$ to $1.38$ GiB and committed-sort from $5.98$ to $1.71$ GiB, while their glue circuits remain near $8.8$ GiB. Both recombiners retain the global $n$-node coverage operation, with committed-sort also opening the hidden summaries. That work does not shrink with $M$, so the glue fixes the complete peak; the monolithic baseline requires roughly $1.47×$ as much memory.

Product is segment-bound. Its glue remains between approximately $0.04$ and $0.06$ GiB, while segment memory falls from approximately $6.0$ to $1.6$ GiB. Compact fingerprints and chain summaries keep recombination below the segment task throughout the measured range. Plain-product and committed-product are nearly identical on this metric despite their different constrained work and public surfaces (@sub:component-gate-distribution, @sub:committed-disclosure).

Recursion crosses between these regimes. At $K=2$, the $6.05$-GiB inner task exceeds the $2.08$-GiB outer stage. At $K=4$, the inner task falls to $3.20$ GiB while the outer rises to $4.03$ GiB; at $K=8$, the corresponding values are $1.66$ and $7.89$ GiB. The measured peak is therefore inner-bound at $K=2$ and outer-bound at $K=4$ and $K=8$.

These memory regimes are compatible with the gate distribution in @sec:aggregate-gate-work. Recombiner share uses an aggregate denominator containing all $K$ segments, whereas peak memory compares recombination with the largest single segment. A small share of total gates can therefore determine the capacity requirement. Memory also changes at padded proving-domain boundaries rather than continuously with gate count, explaining the similar plain and committed peaks despite their different constraint counts.

@table:component-memory-n4000 preserves the exact component and architectural values under the common monolithic-sort baseline.

#figure(
  placement: none,
  block(width: 100%, breakable: false)[
    #set text(size: 9pt)
    #set par(justify: false)
    #table(
      columns: (1.2fr, 0.3fr, 0.82fr, 0.95fr, 0.9fr, 1.2fr),
      stroke: none,
      align: (left, center, center, center, center, center),
      inset: (x: 3pt, y: 4pt),

      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Construction]],
        text(font: "Libertinus Sans")[$K$],
        text(font: "Libertinus Sans")[#smallcaps[Largest segment]],
        text(font: "Libertinus Sans")[#smallcaps[Glue/outer]],
        text(font: "Libertinus Sans")[#smallcaps[Peak]],
        text(font: "Libertinus Sans")[#smallcaps[Baseline / peak]],
      ),
      table.hline(stroke: 0.6pt),

      [plain sort], [2], [5.957], [8.775], [8.775], [1.48×],
      [plain sort], [4], [2.735], [8.775], [8.775], [1.48×],
      [plain sort], [8], [1.384], [8.777], [8.777], [1.48×],
      table.hline(stroke: 0.3pt),
      [committed sort], [2], [5.984], [8.789], [8.789], [1.47×],
      [committed sort], [4], [3.174], [8.790], [8.790], [1.47×],
      [committed sort], [8], [1.708], [8.791], [8.791], [1.47×],
      table.hline(stroke: 0.3pt),
      [plain product], [2], [6.022], [0.043], [6.022], [2.15×],
      [plain product], [4], [3.199], [0.052], [3.199], [4.05×],
      [plain product], [8], [1.644], [0.059], [1.644], [7.88×],
      table.hline(stroke: 0.3pt),
      [committed product], [2], [6.023], [0.043], [6.023], [2.15×],
      [committed product], [4], [3.199], [0.054], [3.199], [4.05×],
      [committed product], [8], [1.613], [0.062], [1.613], [8.03×],
      table.hline(stroke: 0.3pt),
      [recursive product], [2], [6.050], [2.077], [6.050], [2.14×],
      [recursive product], [4], [3.203], [4.029], [4.029], [3.21×],
      [recursive product], [8], [1.663], [7.893], [7.893], [1.64×],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Component and peak proving memory at $n=4000$.])[
    Component and complete maximum Barretenberg-reported proving memory at $n=4000$, in GiB. Segment and recombination values are medians across matched runs. Peak is the median of the run-level maxima; for every row, it coincides with the larger displayed component median. Baseline / peak is $12.95$ GiB divided by that peak.
  ],
) <table:component-memory-n4000>

Every composite configuration also succeeds at $n=5000$, beyond the successfully measured monolithic range. The sort constructions have converged near $12.5$--$12.6$ GiB, product with $K=8$ remains near $1.9$ GiB, and recursive product with $K=4$ remains near $4.1$ GiB. This extends the successfully evaluated range on the fixed host without establishing $n=5000$ as a new ceiling; the sort constructions are already close to the host budget, while product and selected recursive configurations retain more headroom.

#section([End-to-End Prover Time], label: <sec:end-to-end-prover-time>)

Prover time accounts for every task required to complete the proof. For an invocation $j$, its online prover time is

$ t_j = t#h(1pt)_j^"witness" med + med t#h(1pt)_j^"proof", $

where the two terms are the measured witness-generation and proof-generation intervals. Compilation, verification-key derivation, instance preparation, and verification remain outside this online prover metric under @sub:measurement-protocol. We compare the same component measurements under sequential execution and full distribution.

#subsection([Sequential and Distributed Scaling], label: <sub:prover-time-scaling>)

On one host, proving tasks execute one at a time, although each invocation retains Barretenberg's internal parallelism. The complete schedule is

$ T_"seq" = sum_j t_j, $

where $j$ ranges over every segment or inner invocation and the required glue or outer invocation.

#figure(
  placement: top,
  image("/assets/figures/prover_time_sequential_shared.pdf"),
  caption: outline-caption(short: [Sequential prover-time scaling.])[
    Sequential online prover time for the five composite constructions. Every point sums witness and proof generation over all $K$ segment or inner invocations and the glue or outer invocation within a matched run. Curves show the lower-envelope complete time and bands span the observed run-level minimum--maximum range. Both axes are logarithmic and are shared with @fig:distributed-prover-time. The solid reference is monolithic Merkle-sort; product-based panels also show monolithic Merkle-product as a faint dashed control. Open markers identify the last measured reference points. Lines join measured checkpoints and are not extrapolated.
  ],
) <fig:sequential-prover-time>

@fig:sequential-prover-time shows that every construction becomes slower as $n$ grows, and increasing $K$ does not systematically reduce the sequential total. Shorter segments may reduce segment proving time, but there are more segments and recombination adds work; local crossings among the $K$ curves reflect backend padding and timing variation rather than distinct regimes.

At $n=4000$, monolithic sort takes $147.8$ seconds and the composite schedules span approximately $149$--$246$ seconds. At $n=5000$, every composite completes sequentially in approximately $174$--$261$ seconds, while monolithic Merkle-sort exceeds the host memory budget during proof generation. Decomposition therefore extends the successfully evaluated range at the cost of serializing multiple proving tasks.

Sequential execution leaves the independence of the proof tasks unused. External segment and glue proofs depend only on instance data and can run concurrently, so completion waits for the slower task:

$ T#h(1pt)_"dist"^"external" = max[(max_(0 <= i < K) t_i^"segment"), t^"glue"]. $

Recursion parallelizes the inner proofs but retains a dependent outer task:

$ T#h(1pt)_"dist"^"recursive" = max_(0 <= i < K) t_i^"inner" + t^"outer". $

These estimates compose isolated measurements rather than observing a deployed cluster. Full external distribution assumes up to $K+1$ workers comparable to the benchmark host; recursion assumes $K$ inner workers followed by one outer worker.

#figure(
  placement: top,
  image("/assets/figures/prover_time_parallel_shared.pdf"),
  caption: outline-caption(short: [Distributed prover-time scaling.])[
    Fully distributed online prover-time estimates composed from the uncontended component runs. External completion is the maximum of the longest segment task and the independent glue task; recursive completion is the longest inner task followed by the dependent outer task. Curves show the lower-envelope run-level completion time and bands span the observed minimum--maximum range. The logarithmic axes are identical to @fig:sequential-prover-time. The monolithic curves are single-host references: comparison with them is not hardware-normalized. The model assumes one comparable machine for each proof task that runs in parallel and excludes communication, coordination, and competition for shared host resources.
  ],
) <fig:distributed-prover-time>

@fig:distributed-prover-time shows that distribution changes waiting time, not total computation. External sort initially benefits from shorter segments, then converges as glue becomes critical. At $n=4000$, plain-sort takes $38.3$ seconds at $K=4$ and $37.5$ seconds at $K=8$, while committed-sort remains near $41.5$ seconds for both.

Product retains the separation by $K$: plain-product falls from $75.3$ to $40.0$ and $21.0$ seconds, with committed-product nearly identical. Its critical task continues to shrink with the segment instead of reaching a glue floor.

Recursion retains a dependent tail. Its estimates are $96.5$, $81.0$, and $101.4$ seconds for $K=2$, $4$, and $8$: four segments give the lowest value at this checkpoint, while eight transfer enough work to the outer stage to reverse the benefit of shorter inner tasks.

Every distributed estimate at $n=4000$ lies below the $147.8$-second monolithic time only after additional machines are introduced. The same architectural regimes persist at $n=5000$, where no monolithic comparison is available.

#subsection([Schedule Bottlenecks], label: <sub:schedule-phase-composition>)

We use $n=4000$, the largest checkpoint shared by monolithic sort and every composite configuration. @fig:time-breakdown-n4000 separates aggregate sequential work, the distributed critical path, and the witness and proof phases that produce each schedule. Monolithic product is absent rather than extrapolated.

#figure(
  placement: top,
  image("/assets/figures/time_breakdown_n4000.pdf"),
  caption: outline-caption(short: [Prover-time schedule composition at $n=4000$.])[
    Sequential and fully distributed online prover-time composition for all constructions at $n=4000$. Filled distributed bars show the critical task or dependent task sequence; for external recombination, the unfilled outline is the parallel task that finishes earlier and is not added. Hatching distinguishes glue and the recursive outer stage. White rules divide aggregate segment witness-plus-proof time into $K$ equal normalization shares rather than measured invocation boundaries. The blue bar and vertical rule mark the $147.8$-second monolithic Merkle-sort reference. Monolithic product is unavailable at this checkpoint.
  ],
) <fig:time-breakdown-n4000>

Sort crosses from segment-bound to glue-bound. In plain-sort, the longest segment exceeds glue by $64.6$ to $40.6$ seconds at $K=2$; at $K=8$, glue remains at $37.5$ seconds while the segment falls to $16.1$ seconds. Committed-sort follows the same pattern. Its global coverage glue also spends substantial time generating the witness, so gate count alone does not predict the timing floor.

Product remains segment-bound. Its glue finishes in less than one second, while the longest segment falls from approximately $75$ to $40$ and $21$ seconds. Distribution can therefore approach the available $K$-way reduction even though the sequential total still contains every invocation.

In recursion, the longest inner task shrinks from approximately $75$ to $40$ and $22$ seconds, while outer proof generation grows from $21$ to $41$ and $79$ seconds. The $K=4$ row is the shortest dependent sequence; at $K=8$, constrained verification makes the outer stage dominant.

@table:prover-time-n4000 records the exact complete times and the schedule compression $T_"seq"\/T_"dist"$.
The product mechanisms and structural-privacy levels differ, so the common table maps the timing frontier rather than ranking every row as like-for-like (@sec:aggregate-gate-work). For RQ2, the timing result is conditional: decomposition can extend the successfully evaluated range on one constrained host at the cost of serialized time, or expose independent work that additional workers can overlap.

#figure(
  placement: none,
  block(width: 100%, breakable: false)[
    #set text(size: 9pt)
    #set par(justify: false)
    #table(
      columns: (1.45fr, 0.35fr, 1fr, 1.25fr, 0.95fr),
      stroke: none,
      align: (left, center, center, center, center),
      inset: (x: 4pt, y: 4pt),

      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Construction]],
        text(font: "Libertinus Sans")[$K$],
        text(font: "Libertinus Sans")[#smallcaps[Sequential] \ #smallcaps[time (s)]],
        text(font: "Libertinus Sans")[#smallcaps[Fully distributed] \ #smallcaps[time (s)]],
        text(font: "Libertinus Sans")[$T_"seq" \/ T_"dist"$],
      ),
      table.hline(stroke: 0.6pt),

      [monolithic sort], [--], [147.8], [147.8], [1.00×],
      table.hline(stroke: 0.3pt),
      [plain sort], [2], [169.7], [64.6], [2.63×],
      [plain sort], [4], [163.9], [38.3], [4.28×],
      [plain sort], [8], [166.3], [37.5], [4.43×],
      table.hline(stroke: 0.3pt),
      [committed sort], [2], [192.5], [75.6], [2.55×],
      [committed sort], [4], [201.8], [41.5], [4.86×],
      [committed sort], [8], [209.6], [41.5], [5.06×],
      table.hline(stroke: 0.3pt),
      [plain product], [2], [149.0], [75.3], [1.98×],
      [plain product], [4], [160.4], [40.0], [4.01×],
      [plain product], [8], [168.3], [21.0], [8.03×],
      table.hline(stroke: 0.3pt),
      [committed product], [2], [149.8], [75.5], [1.98×],
      [committed product], [4], [160.6], [40.0], [4.01×],
      [committed product], [8], [168.4], [21.0], [8.02×],
      table.hline(stroke: 0.3pt),
      [recursive product], [2], [171.5], [96.5], [1.78×],
      [recursive product], [4], [197.2], [81.0], [2.43×],
      [recursive product], [8], [246.2], [101.4], [2.43×],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Sequential and distributed prover time at $n=4000$.])[
    Sequential and fully distributed online prover time at $n=4000$. Times are lower-envelope composed schedules in seconds. $T_"seq"\/T_"dist"$ uses unrounded values. Distributed times assume additional comparable workers and are not measured cluster speedups. Product rows are not mechanism-matched comparisons with monolithic product.
  ],
) <table:prover-time-n4000>

#section([Verifier Load], label: <sec:verifier-load>)

External recombination presents the final verifier with $K$ segment proofs, one glue proof, and public values that must be reconciled across them. Recursion consumes the inner proofs as private witness data and exposes only the outer proof. We account for the encoded proof and public-input artifacts and the wall-clock time of the required `bb verify` commands. Reconciliation remains necessary for soundness, but we report it as a number of equality checks rather than timing an application-specific coordinator.

#subsection([Proof Package and Public Surface], label: <sub:verifier-interface>)

Every recorded UltraHonk proof is $14\,656$ bytes, matching the monolithic result in @sub:monolithic-prover-scaling. An external proof package contains $K+1$ such proofs; monolithic and recursive constructions expose one.

Each proof also carries its own public-input vector. For an externally recombined construction, the aggregate number of public-input slots processed by the final verifier is

$ S#h(1pt)_"pub"^"external" = K dot S#h(1pt)_"pub"^"segment" + S#h(1pt)_"pub"^"glue". $

@table:verifier-interface applies this accounting to every construction and also records the equalities required after the individual proofs have verified.

#figure(
  placement: none,
  block(width: 100%, breakable: false)[
    #set text(size: 10pt)
    #set par(justify: false)
    #table(
      columns: (1.3fr, 0.7fr, 1.2fr, 1.05fr),
      stroke: none,
      align: (left, center, center, center),
      inset: (x: 3pt, y: 5pt),

      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Construction]],
        text(font: "Libertinus Sans")[#smallcaps[Proof checks]],
        text(font: "Libertinus Sans")[#smallcaps[Aggregate public-input slots]],
        text(font: "Libertinus Sans")[#smallcaps[External equality checks]],
      ),
      table.hline(stroke: 0.6pt),

      [monolithic sort], [1], [2], [none],
      table.hline(stroke: 0.3pt),
      [plain sort], [$K+1$], [$2n+7K+2$], [$n+4K$],
      [committed sort], [$K+1$], [$3K+2$], [$2K$],
      table.hline(stroke: 0.3pt),
      [plain product], [$K+1$], [$15K+4$], [$9K$],
      [committed product], [$K+1$], [$4K+3$], [$3K$],
      table.hline(stroke: 0.3pt),
      [recursive product], [1], [2], [none],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Final-verifier interface accounting.])[
    Final-verifier interface accounting. External aggregate slots equal $K$ segment interfaces plus the glue interface, using $K dot M=n$ for plain-sort. Each slot occupies $32$ bytes in the current artifact format. External equality checks bind the proof set after backend acceptance. Recursion performs the corresponding binding inside the outer circuit.
  ],
) <table:verifier-interface>

Plain-sort duplicates the node list across the segment and glue interfaces, so its aggregate public surface grows with $n$ as well as $K$. The compact external constructions depend only on $K$, while recursion retains the monolithic two-field interface. The equality counts describe a separate layer: they are application-level bindings performed after backend acceptance and are not additive with the public-input slots.

Excluding setup verification keys, the encoded payload consists of the proof files plus $32$ bytes for each public-input slot. Every evaluated package remains below $0.4$ MiB, while recursive-product and monolithic sort remain at approximately $14.4$ KiB.

#subsection([Backend Verification Time], label: <sub:backend-verification-time>)

For an externally recombined construction, the backend time is the sequential sum

$ V#h(1pt)_"BB"^"external" = sum_(i=0)^(K-1) v_i^"segment" + v^"glue". $

Recursive and monolithic verification each require one command. Complete values are composed within matched runs before lower-envelope selection under @sub:measurement-protocol. The metric includes process startup and artifact loading as well as proof verification. It excludes the application-level reconciliation counted in @table:verifier-interface, so it measures the backend portion of verifier load rather than complete application latency.

@fig:verify-time-sweep shows this backend time across the complete evaluation grid. Verification time separates primarily by proof count. External constructions require one backend invocation for every segment proof and one for glue, so their curves rise with $K$. Differences among constructions at the same $K$ are small and variable, and no construction exhibits systematic growth with $n$ over the measured grid. Even plain-sort's growing public-input vector does not produce a resolved wall-clock trend above command-level variation, so the grid does not isolate the marginal cost of additional public inputs.

At $n=4000$, external backend verification spans $27.6$--$126.3$ milliseconds, approximately 1.5×--6.7× the monolithic-sort reference of $18.8$ milliseconds, while recursive verification spans $12.8$--$15.6$ milliseconds. These absolute times remain small beside prover schedules of tens or hundreds of seconds. Backend verification therefore does not determine architectural feasibility on the evaluated host and stack.

#figure(
  placement: top,
  image("/assets/figures/verify_time_sweep.pdf"),
  caption: outline-caption(short: [Backend verification time across the evaluation grid.])[
    Aggregate `bb verify` wall-clock across the evaluation grid. External points sum the $K+1$ required backend commands within each matched run; recursive points contain only the final outer verification. Curves show lower-envelope complete times and bands span the observed run-level minimum--maximum intervals. All panels use the same linear time scale and a logarithmic $n$-axis. Open markers identify the last measured reference points.
  ],
) <fig:verify-time-sweep>
