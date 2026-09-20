#import "/theme/headings.typ": *
#import "/theme/utils.typ": *
#import "/vendor/lovelace/lib.typ": *



#chapter([Monolithic Proofs], label: <chap:monolithic-proofs>)

This chapter develops the monolithic proof used as the baseline for the rest of the thesis. We first translate relation @eq:relation directly, then refine two independent parts of the resulting circuit: the permutation check and the representation of the cost matrix.

#section([Naive Construction], label: <sec:naive-circuit>)

A monolithic proof handles the whole route in one circuit and enforces every part of the relation itself. The naive construction follows that relation directly: it exposes the original problem data, keeps the route private, and translates validity and feasibility into three constraint groups.

#subsection([Inputs], label: <sub:naive-inputs>)

Relation @eq:relation separates the values known to the verifier from the witness known only to the prover. For the naive construction, the public instance is $x=(C,T)$ and the private witness is the route $w=pi$. The implementation flattens $C$ row by row into

$ matrix[0 med .. med n^2 - 1], $

where the cost of the arc from node $i$ to node $j$ is stored at $matrix[i dot n+j]$. The matrix and threshold $T$ are public inputs to the proof system. This is the most literal interface: the backend receives the same matrix that defines the TSP instance, in the representation used by the cost lookup.

Making the matrix a proof-system public input reveals no additional information because $C$ already belongs to the public problem instance. The choice still has a cost. The backend must process all $n^2$ entries even though one route selects only $n$ of them. @sec:committed-matrix later replaces the full matrix with a Merkle root derived from it.

The witness is the array $route[0 med .. med n-1]$, corresponding to the sequence $pi=(pi_0, pi_1, ..., pi_(n-1))$ of @sub:formulation. The entry $route[i]$ identifies the node visited at step $i$. The array stores nodes rather than arcs, so the circuit derives each arc from two consecutive entries. The closing arc is implicit as explained in @sub:formulation: $route[n-1]$ returns to $route[0]$, and $(i+1) mod n$ therefore defines the destination for every $i$, including the last position.

The route's total cost also remains private. It is not an independent witness value that the prover may choose: the circuit derives it by retrieving and summing the costs of these $n$ arcs. This leaves only the route as the private input to the construction.

#subsection([Constraints], label: <sub:naive-constraints>)

Given this interface, the circuit must establish that the route is valid and that its cost satisfies the threshold. It divides this claim into three constraint groups.

- *Permutation.* For every $0 <= i < n$, the circuit requires $route[i] < n$; for every $i<j$, it requires $route[i] != route[j]$. The range checks restrict the entries to the $n$ valid node identifiers, while pairwise distinctness prevents any identifier from appearing twice. Since the route contains $n$ distinct values drawn from an $n$-element set, the pigeonhole principle guarantees that it contains every node exactly once. Throughout the thesis, _permutation_ and _coverage_ refer to this same property. Without this condition, a prover could reduce the claimed cost by repeating cheap nodes and omitting expensive ones.

- *Cost binding.* For each position $i$, the circuit obtains the selected arc cost from
  $ matrix[route[i] dot n + route[(i+1) mod n]]. $
  The two route entries identify the source and destination, and the row-major expression identifies their unique entry in the matrix. Reading that entry binds the sum to the graph instead of allowing the prover to supply convenient costs. @sec:committed-matrix changes how the circuit authenticates the selected value, but preserves this requirement.

- *Threshold.* The circuit sums the bound costs and enforces
  $ "cost"(pi) = sum_(i=0)^(n - 1) matrix[route[i] dot n + route[(i + 1) mod n]] <= T. $ <eq:sum-costs>
  Cost binding ensures that every term in @eq:sum-costs is the cost of the corresponding graph arc. The final inequality can therefore establish feasibility by comparing the legitimate total with $T$.

Together, these groups hold exactly when the witness encodes a valid route whose cost is at most $T$. Their meaning remains fixed throughout the thesis, while later constructions replace the enforcement mechanisms for permutation and cost binding.

#subsection([Circuit Specification])

The circuit in @fig:flat-pairwise realizes the three groups: it range-checks the route and compares every pair of positions, reads each selected cost from the public matrix, and constrains the resulting sum by $T$.

Throughout the listings, #inline[require] $P$ means that $P$ is added to the circuit constraints. The Noir implementation uses `assert`, but the operation does not wait until runtime and abort on failure like an ordinary program assertion. Arithmetization translates it into algebraic conditions, and proof generation succeeds only when the witness satisfies them, as described in @sub:arithmetic-circuits.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: top,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Naive monolithic circuit.])[ #set text(font: "Libertinus Serif"); The naive monolithic circuit. The matrix and the threshold are public, while the route is private. Group 1 is enforced by range checks plus pairwise distinctness. Group 2 is a direct lookup into the public cost matrix. Group 3 is a simple inequality constraint.],
    pseudocode-list(hooks: 0.5em, booktabs: true, booktabs-stroke: 1pt)[
      + *circuit* #fn[monolithic-full-pairwise]$(n)$ #h(1fr)
        + *public* $matrix[rng(0, n^2 - 1)], med T$
        + *private* $route[rng(0, n - 1)]$
        - #hide("")
        - #lc[Group 1: _permutation by range check + pairwise distinctness_]
        + *for* $i$ *in* #fn[range]$(0, n)$:
          + *require* $route[i] < n$
        + *for* $i < j$ *in* #fn[range]$(0, n)$:
          + *require* $route[i] != route[j]$
        - #hide("")
        - #lc[Group 2: _cost binding by direct lookup into the public matrix_]
        + $total arrow.l 0$
        + *for* $i$ *in* #fn[range]$(0, n)$:
          + $total arrow.l total + matrix[route[i] dot n + route[(i + 1) mod n]]$
        - #hide("")
        - #lc[Group 3: _threshold_]
        + *require* $total <= T$
    ]
  ) <fig:flat-pairwise>
]

The pairwise check illustrates the gap between source code and circuit work. The source expression #inline[require] $a != b$ resembles a primitive comparison, but an arithmetic circuit must express the inequality through field equations. Let $v=a-b$. A field element is nonzero exactly when it has a multiplicative inverse, so witness generation supplies the auxiliary value $u=v^(-1)$ and the circuit constrains $v dot u = 1.$

When $a=b$, we have $v=0$, and no choice of $u$ can satisfy the equation. When they differ, the inverse exists and the constraint holds. Computing $u$ adds no constraint, but remains witness-generation work; checking it adds one multiplication constraint. This is the hint pattern introduced in @sub:arithmetic-circuits: the prover derives an auxiliary value outside the circuit, while the circuit verifies the property that affects acceptance. Pairwise distinctness repeats this process for all $n(n-1)\/2$ pairs.

The matrix read exposes a second gap between the source program and its circuit. The positions in $route[i]$ and $route[(i+1) mod n]$ are fixed when the loop is unrolled. The values stored there are private, but the compiler already knows which two route wires to connect. Those values then determine the outer matrix index. Since they arrive with the witness, the compiler does not know which matrix position the route will select.

This timing determines the kind of array access. A circuit is a static wiring diagram built before the witness exists. A fixed-index read connects a predetermined array entry to the next operation. A read from $matrix[k]$, where $k$ depends on the route, cannot choose that connection after compilation. Public matrix values can therefore require dynamic-access machinery when a private witness selects their address.

Noir realizes this witness-indexed access as a read-only lookup backed by an offline memory check, as described in @sub:circuit-memory. Each dynamic read contributes records, constraints, and witness-solving work; a fixed-index read needs only a predetermined wire.

The naive circuit has two independent quadratic costs. Pairwise distinctness contributes $n(n-1)\/2=bigoh()(n^2)$ constrained inequalities. The matrix representation contributes exactly $n^2$ public inputs even though the route performs only $n$ dynamic reads. The first cost follows from how permutation is enforced; the second follows from how the cost matrix is represented.

These source-level counts do not directly determine gate counts. Inequalities, range checks, memory operations, and public inputs compile into different backend primitives, so equal asymptotic growth can hide a large concrete difference. The measurements later in this chapter show that the full public matrix costs substantially more gates than the pairwise comparisons and dominates the naive circuit.

The two costs also affect different parties. The prover pays for the internal permutation constraints, while the verifier must process the public matrix entries. Exposing $n^2$ entries therefore makes verification time grow quadratically in $n$, although proof size remains constant. The next section replaces the pairwise permutation check; @sec:committed-matrix later replaces the public matrix interface and its direct cost lookup.

#section([Permutation Mechanisms], label: <sec:perm>)

@sec:naive-circuit enforces coverage with range checks and pairwise inequalities. The construction is exact, but its $n(n-1)\/2$ comparisons make it quadratic. We therefore compare three scalable alternatives: an indicator vector, an inverse permutation map, and a sorted route.

Only the coverage mechanism changes. Cost binding and threshold enforcement remain fixed, so the comparison isolates how each alternative uses constraints, memory, and auxiliary witness computation. All three mechanisms are exact; their concrete cost and their ability to transfer to decomposition determine which one is carried forward. @chap:composite-proofs introduces product coverage separately, when decomposition creates an interface that its probabilistic compression can reduce.

For each alternative, we first establish why its constraints imply coverage, then separate the work enforced in-circuit from the auxiliary work performed during witness generation.

#subsection([Indicator Vector])

The indicator mechanism initializes a boolean array $visited[0 med .. med n-1]$ to false and scans the route once. At position $i$, the circuit requires $route[i] < n$, reads $visited[route[i]]$, requires the cell to be false, and then marks it true. A repeated node reaches a cell that was already marked, so the witness fails.

The range check completes the argument. It restricts all $n$ route entries to the $n$ valid node identifiers, while the state update makes those entries distinct. The pigeonhole principle then forces the route to contain every identifier exactly once, so a final pass requiring all cells to be true would add no guarantee. The range check also guards the memory access itself: because $route[i]$ selects an address in $visited$, the circuit must prove that this address lies within the allocated array.

The mechanism performs $n$ initialization writes, $n$ reads, $n$ marking writes, and $n$ range checks. Its constrained work is linear, but it uses read-write memory because every later read must respect the preceding updates. The indicator vector keeps a simple witness interface because it introduces no explicit auxiliary permutation hint.

#subsection([Inverse Permutation Map], label: <sub:invperm>)

The inverse-map mechanism asks the prover for a private array $invperm$, where $invperm[v]$ claims the position of node $v$ in the route. This array is an explicit hint: witness preparation computes the inverse relation, while the circuit checks every claim rather than reconstructing the map itself. For every $0 <= v < n$, it enforces

$ invperm[v] < n, quad route[invperm[v]] = v. $

This changes the direction of the proof. Pairwise distinctness compares route positions with one another; the inverse map instead asks once for the location of each expected value. The circuit can therefore replace all-pairs comparisons with one checked claim per node.

The equality checks make the claimed positions distinct without comparing them directly. If $invperm[a]=invperm[b]$ for $a != b$, the same route entry would have to equal both values. The $n$ claims therefore identify distinct positions, and the range checks place them in an array with exactly $n$ positions. By the pigeonhole principle, the claims cover every route position. Since the second constraint also places each node at its claimed position, the route is a permutation of ${0,...,n-1}$.

Checking the hint requires $n$ range checks and $n$ read-only accesses at prover-chosen positions. The route itself never changes, so these accesses require no read-write consistency; they only need to bind each retrieved value to the requested address. This gives the mechanism a linear in-circuit account, although the dynamic reads still incur the offline-memory work described in @sub:circuit-memory.

Constructing $invperm$ requires one off-circuit scan of the route. In this implementation, that scan and the serialization of the resulting array occur before witness generation, so the reported witness time measures only the in-circuit checks. An end-to-end implementation must also pay for the omitted preprocessing. Its linear cost is unlikely to dominate at the evaluated sizes, so including it would provide more precise measurements, but it would not significantly affect the overall behavior and the comparison.

#subsection([Sorted Route])

A route covers ${0, dots, n-1}$ exactly when sorting it produces the identity sequence. Computing a full sort through constrained comparisons would add unnecessary circuit work, so the built-in follows the hint pattern: witness generation constructs a candidate ordering, and the circuit verifies it. The mechanism therefore enforces

$ sort(route) = (0, dots, n-1). $

@fig:flat-sort gives the circuit specification. The built-in sort constructs the candidate during witness generation, and the circuit then fixes each position to its expected node identifier.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Sort-based permutation check.])[#set text(font: "Libertinus Serif"); The sort mechanism for the permutation constraint group, shown on its own and operating on the private $route$.],
    pseudocode-list(hooks: 0.5em, booktabs: true, booktabs-stroke: 1pt)[
      + _sort-permutation-check_#h(1pt)\($route$) #h(10pt) #h(1fr)
        +  $sorted arrow.l $ _sort_#h(1pt)\($route$) #h(10pt) #lc[built-in _sort_ function]
        + *for* $i$ *in* #fn[range]$(0, n)$:
          + *require* $sorted[i] = i$
    ]
  ) <fig:flat-sort>
]

The candidate $sorted$ is auxiliary witness data, so the circuit cannot accept it without checking its relation to $route$. In the pinned Noir release, the built-in constructs $sorted$ with an unconstrained quicksort, constrains adjacent entries to be ordered, and uses an auxiliary shuffle map to prove that $sorted$ and $route$ contain the same multiset @noir2026. The identity checks in @fig:flat-sort then fix that multiset to ${0, dots, n-1}$, so the complete check establishes exact coverage without trusting the unconstrained sort. The ordering check is redundant for this particular use: the identity checks already make $sorted$ ordered. Noir nevertheless performs it as part of the general-purpose sort, so the circuit still pays for its $n-1$ inequalities.

In-circuit, the mechanism uses $n$ identity checks, $n-1$ ordering inequalities, and about $2n$ read-only accesses for the shuffle-map constraints that bind $sorted$ to $route$. These operations grow linearly with $n$. The built-in generates both the sorted candidate and shuffle map during witness generation, so their cost is included in the measured witness time, unlike the externally prepared inverse map. 

Off-circuit, the implementation performs an average-case $bigoh()(n log n)$ quicksort, with quadratic worst case, and an $bigoh()(n^2)$ shuffle-map search.

#subsection([Mechanism Evaluation])

Operation counts predict growth but cannot price the mechanisms directly. Range checks, read-write operations, read-only lookups, and direct comparisons compile differently, so @table:perm-mechanisms keeps their costs separate and records the auxiliary work performed during witness construction.

#[
  #set text(size: 11pt)
#figure(
    table(
      columns: (1.25fr, 1.9fr, 1.8fr, 1.3fr),
      stroke: none,
      align: left + horizon,
      inset: (x: 8pt, y: 7pt),

      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Mechanism]],
        text(font: "Libertinus Sans")[#smallcaps[In-Circuit]],
        text(font: "Libertinus Sans")[#smallcaps[Off-Circuit]],
        text(font: "Libertinus Sans")[#smallcaps[Memory]],
      ),
      table.hline(stroke: 0.6pt),
      [Pairwise \ Distinctness],
      [$bigoh()(n)$ range, \ $bigoh()(n^2)$ inequalities],
      [$bigoh()(n^2)$ inverses],
      [None],
      table.hline(stroke: 0.4pt),

      [Indicator \ Vector],
      [$bigoh()(n)$ range, \ $bigoh()(n)$ read-write ops],
      [None],
      [Read-Write],
      table.hline(stroke: 0.4pt),

      [Inverse \ Permutation],
      [$bigoh()(n)$ range, \ $bigoh()(n)$ dynamic reads],
      [$bigoh()(n)$ scan],
      [Read-Only],
      table.hline(stroke: 0.4pt),

      [Sorted \ Route],
      [$bigoh()(n)$ equalities, \ $bigoh()(n)$ orderings,\ $bigoh()(n)$ dynamic reads],
      [$bigoh()(n log n)$ sort, \ $bigoh()(n^2)$ shuffle map],
      [Read-Only],
      table.hline(stroke: 1pt),
    ),
    caption: outline-caption(short: [Asymptotic costs of permutation mechanisms.])[
      The four permutation mechanisms by asymptotic cost: the work each constrains in-circuit, the unconstrained work the prover performs to build its hints, and the
    dynamic memory used by the permutation mechanism. The common read-only memory used for cost binding is excluded. The sorting bound is average-case for the built-in quicksort,
    whose worst case is quadratic.
    ],
) <table:perm-mechanisms>
]

Pairwise is quadratic both in constrained comparisons and in the inverses constructed for those comparisons. The other mechanisms remain linear in constrained work but mix different operations and memory models, so their shared growth rate does not rank them.

We benchmark the four complete circuits up to $n=480$, a range large enough for the quadratic pairwise trend to separate from the alternatives. Every circuit uses the same public matrix, route, cost binding, and threshold; only coverage enforcement changes. We record gates, ACIR opcodes, witness and proving time, verification time, proof size, and maximum Barretenberg-reported proving memory under the protocol of @sub:measurement-protocol. Gate count captures the circuit presented to the backend, while witness time exposes hint construction and memory-solving work that gates may not predict.

@fig:mech-size compares the resulting gate and opcode counts.

#figure(
  image("../../assets/figures/mech_size_panel.pdf"),
  caption: outline-caption(short: [Circuit size across permutation mechanisms.])[
    Three views of circuit size for different permutation mechanisms. Top left and top right show gate count and ACIR opcodes against the number of nodes, respectively. Bottom relates the two whole-circuit totals; it should not be interpreted as the gate price of an individual opcode.
  ],
) <fig:mech-size>

Pairwise emits substantially more ACIR operations because it compares every pair of positions. The difference narrows after lowering to backend gates: all four circuits still process the same $n^2$ matrix inputs, whose common gate cost dominates the coverage mechanism. The three linear alternatives are consequently almost indistinguishable in gates, while pairwise is about thirteen percent larger at $n=480$.

Gate count omits the work needed to construct and solve the witness. @fig:mech-witness therefore plots witness-generation time against both $n$ and gate count.

#figure(
  image("../../assets/figures/mech_witness_panel.pdf"),
  caption: outline-caption(short: [Witness-generation time across permutation mechanisms.])[
    Witness-generation time for the four permutation mechanisms on one canonical route per size. Left: time against the number of nodes. Right: the same time against gate count. Each line is the minimum of five sequential runs, used as a lower-envelope estimate; the shaded band spans the observed minimum and maximum.
  ],
) <fig:mech-witness>

Witness time separates the mechanisms that gate count leaves tied. Pairwise is slowest, consistent with the inverse hints generated for its quadratic inequalities. At the endpoint, the indicator vector and inverse map each require about $1.18$ seconds, while sorting requires $1.52$ seconds, roughly thirty percent more.

Pairwise is unsuitable as the scalable mechanism because it adds quadratic circuit and witness work. The three alternatives are effectively tied in circuit size, while witness generation favors the indicator vector and inverse map. Proving time and maximum reported memory largely follow the compiled circuit size and its padded proving domain; their curves reinforce the rejection of pairwise but do not rank the linear mechanisms, so we omit them as redundant. Verification time and proof size likewise show no mechanism-dependent difference.

#subsection([Mechanism Selection], label: <sub:permutation-selection>)

The inverse map is the strongest measured monolithic candidate: it has the smallest circuit and shares the fastest witness-time tier, subject to its preprocessing qualification. We nevertheless select sorting as the canonical exact mechanism because the same check transfers directly to composite proofs, where the route is decomposed into segments.

For the decomposition considered in the next chapter, assume that $K$ divides $n$ and split the route into $K$ consecutive, non-overlapping segments of $M=n\/K$ nodes each. Let $R_i$ be the private visit order of segment $i$, and let $S_i$ be its $M$-entry target list, ordered by increasing node identifier. A segment must prove that both arrays contain the same nodes, while recombination must prove that the concatenation $S_0 plus.double S_1 plus.double ... plus.double S_(K-1)$ covers ${0,...,n-1}$. The target of a segment is therefore arbitrary instance data rather than the canonical identity sequence, and its representation must cross the boundary between the segment proof and recombination.

The indicator vector loses its direct addressing rule in this setting. An $n$-cell bitmap preserves $visited[v]$ but defeats segment locality; an $M$-cell bitmap needs a constrained translation from each global node identifier to its position in $S_i$, while retaining read-write memory.

The inverse map adapts through a private positional hint $pos_i$, where $pos_i [j]$ gives the claimed position of target node $S_i [j]$ in the segment order $R_i$. A segment can then enforce $pos_i [j] < M$ and $R_i [pos_i [j]]=S_i [j]$. Once recombination establishes that the target entries are distinct, the claimed positions cover the segment. This target-relative construction remains linear and is a credible optimization, but it adds an explicit hint.

Sorting keeps the same form at both levels:

$ sort(R_i) = S_i, $

for every segment, followed by the global check

$ sort(S_0 plus.double S_1 plus.double ... plus.double S_(K-1)) = (0, dots, n-1), $

where $plus.double$ denotes concatenation. The monolithic, segment, and recombination circuits can therefore use the same exact standard-library mechanism against different targets.

The inverse map may retain its witness-time advantage after decomposition and therefore should remain a suitable candidate, but sorting provides the simpler controlled baseline for comparing monolithic and composite proofs.

#section([Committed Cost Matrix], label: <sec:committed-matrix>)

The naive circuit supplies all $n^2$ matrix entries as proof-system public inputs although the route reads only $n$ costs. This quadratic surface, identified in @sec:naive-circuit, also sets the scale of the mechanism comparison: the three linear coverage mechanisms in @sec:perm differ in gates by only a fraction of a percent because they all carry the same matrix.

We replace those entries with one Merkle root and authenticate each selected cost against it. Only the proof-system representation changes: $C$ and $T$ remain public problem data, but the matrix contributes one public field element to the proof-system interface alongside $T$. The verifier derives the expected root from $C$ and accepts a proof for $(C,T)$ only when its public root matches that value.

Following the interface of @sub:merkle-trees, leaf $i dot n+j$ stores the row-major entry $C_(i,j)$. The $n^2$ leaves are padded with zeros to the next power of two, giving

$ depth = ceil(log_2(n^2)). $

The construction instantiates the binary Merkle tree of @merkle1987 with the Poseidon2 hash $H$ @poseidon2. Every internal node is $H("left", "right")$; the fixed row-major order, leaf count, and padding convention make the matrix encoding unambiguous.

The circuit can no longer retrieve a selected cost from a public array. For the arc leaving route position $i$, the prover instead supplies $edgecosts[i]$, one sibling hash per tree level, and one Boolean direction bit per level. The paths for all $n$ arcs are flattened: level $d$ of path $i$ is stored at

$ siblings[i dot depth+d], quad pathbits[i dot depth+d]. $

Starting from $edgecosts[i]$, the circuit uses each direction bit to place the running node on the left or right of its sibling, hashes the pair, and requires the final node to equal the public root. This authenticates the supplied cost at the leaf encoded by the path. It does not yet show that the leaf is the one selected by the route: without a position check, the prover could open a genuine cheaper entry elsewhere in the matrix.

The same direction bits therefore reconstruct the opened leaf index. Writing $b_(i,d)=pathbits[i dot depth+d]$ in least-significant-bit-first order, the path claims

$ p_i = sum_(d=0)^(depth-1) b_(i,d) 2^d. $

The row-major index required by the route is

$ q_i = route[i] dot n + route[(i+1) mod n], $

the same address used by the direct lookup in @sec:naive-circuit. The circuit requires $p_i=q_i$. Root equality binds the cost to the committed matrix; index equality binds it to the required arc. @fig:merkle-open specifies both checks.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: top,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Authenticated committed-matrix read.])[ #set text(font: "Libertinus Serif"); One authenticated read for the arc leaving $route[i]$. The index check (a) binds the path to the matrix entry selected by the route; the root check (b) binds the supplied cost to the committed matrix.],
    pseudocode-list(hooks: 0.5em, booktabs: true, booktabs-stroke: 1pt)[
      + *procedure* #fn[merkle-tree-cost-binding]$(n, i, root, depth)$ #h(1fr)
        + *private* $route[rng(0, n - 1)], med edgecosts[rng(0, n - 1)]$
        + *private* $siblings[rng(0, n dot depth - 1)], med pathbits[rng(0, n dot depth - 1)]$
        - #hide("")
        - #lc[(a) Index constraint: the proof must open the correct cost]
        + $leafidx arrow.l 0$
        + *for* $d$ *in* #fn[range]$(0, depth)$#h(1pt):
          + *if* $pathbits[i dot depth + d]$#h(1pt):
            + $leafidx arrow.l leafidx + 2^d$
        + *require* $leafidx = route[i] dot n + route[(i + 1) mod n]$
        - #hide("")
        - #lc[(b) Merkle proof]
        + $node arrow.l edgecosts[i]$
        + *for* $d$ *in* #fn[range]$(0, depth)$#h(1pt):
          + *if* $pathbits[i dot depth + d]$#h(1pt):
            + $node arrow.l$ #fn[H]$(siblings[i dot depth + d], node)$
          + *else*:
            + $node arrow.l$ #fn[H]$(node, siblings[i dot depth + d])$
        + *require* $node = root$
    ]
  ) <fig:merkle-open>
]

Applying this read to every route arc replaces $n^2$ public inputs with $n$ paths of $depth=bigoh()(log n)$ hashes. Cost binding therefore contributes $bigoh()(n log n)$ Poseidon2 invocations. Building the tree still touches all $n^2$ entries, but that is reusable instance preprocessing: one tree serves every proof against the same agreed matrix.

Under collision resistance, the root computationally binds the openings to $C$, following @sub:commitment-schemes and @sub:merkle-trees. It need not hide because $C$ is public, and the verifier authenticates the root by recomputing it. A confidential-matrix relation would instead require a hiding commitment and an authenticated reference root, as described by the trust boundary in @sub:trust-assumptions.

Other commitment interfaces offer different costs. KZG commitments provide constant-size evaluation openings, while KZG-backed Verkle trees use a higher branching factor to shorten authentication paths @kate2010, @kuszmaul2018verkle. Verifying those openings inside the circuit adds elliptic-curve pairing arithmetic and another setup-dependent commitment layer. Committed-lookup arguments such as Caulk, cq, and Lasso instead batch the position--cost rows selected from the table @zapico2022caulk, @eagen2022cq, @setty2023lasso. We retain a binary Poseidon2 tree because it is field-native, transparent, and supported by the existing stack. It provides a controlled baseline for measuring the representation change without claiming an optimal committed lookup.

#section([Refined Circuit Construction], label: <sec:optimized-circuit>)

Combining the committed matrix with the selected sorted-route permutation mechanism gives the refined monolithic circuit in @fig:flat-merkle. The circuit takes only the Merkle root and the threshold $T$ as public inputs. The route, selected arc costs, and authentication paths remain private.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: none,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Refined monolithic Merkle-sort circuit.])[#set text(font: "Libertinus Serif"); The refined circuit composes sort-based coverage with the authenticated committed-matrix read of @fig:merkle-open, then checks the accumulated cost against $T$.],
    pseudocode-list(hooks: 0.5em, booktabs: true, booktabs-stroke: 1pt)[
      + *circuit* #fn[monolithic-merkle-sort]$(n, depth)$ #h(1fr)
        + *public* $root, med T$
        + *private* $route[rng(0, n-1)], med edgecosts[rng(0, n-1)]$
        + *private* $siblings[rng(0, n dot depth - 1)], med pathbits[rng(0, n dot depth - 1)]$
        - #hide("")
        - #lc[Group 1: _permutation by sorting_]
        + $sorted arrow.l$ #fn[sort]$(route)$
        + *for* $i$ *in* #fn[range]$(0, n)$:
          + *require* $sorted[i] = i$
        - #hide("")
        - #lc[Group 2: _cost binding by authenticated reads_]
        + $total arrow.l 0$
        + *for* $i$ *in* #fn[range]$(0, n)$:
          + #fn[merkle-tree-cost-binding]$(n, i, root, depth)$
          + $total arrow.l total + edgecosts[i]$
        - #hide("")
        - #lc[Group 3: _threshold_]
        + *require* $total <= T$
    ]
  ) <fig:flat-merkle>
]

We call this circuit _monolithic-merkle-sort_. We isolate the two refinements through three circuits. _Monolithic-full-pairwise_ is the naive construction of @sec:naive-circuit; _monolithic-full-sort_ changes only coverage; _monolithic-merkle-sort_ additionally changes the matrix representation. The first transition therefore measures the permutation mechanism, and the second measures commitment independently of it.

All three circuits use the same instances and routes through $n=1000$, their largest shared checkpoint. Following @sub:measurement-protocol, gate counts are deterministic, timings use the lower envelope, and memory is the median of the run-level maximum Barretenberg-reported checkpoints. Proof size is omitted because every configuration produces the same $14\,656$-byte proof. @fig:flat-refined-cost and @fig:flat-refined-behavior give the growth curves.

#figure(
  image("/assets/figures/13_flat_refined_cost.pdf"),
  caption: outline-caption(short: [Cost scaling across monolithic refinements.])[
    Circuit size, proving time, and maximum Barretenberg-reported proving memory through $n=1000$, on logarithmic axes. The _full_ circuits retain the quadratic public-matrix surface; Merkle commitment replaces it with a constant-size interface. Timing curves show minima, memory curves show medians of the per-run maxima, and bands span the observed ranges, following @sub:measurement-protocol.
  ],
) <fig:flat-refined-cost>

The two transitions affect different terms. Sorting removes the quadratic pairwise check, but both full circuits retain the $n^2$ public matrix, so their overall growth remains quadratic and the improvement is a constant factor. Commitment removes that common term and replaces the selected reads with $bigoh()(n log n)$ hashing. Poseidon2's fixed cost makes the committed circuit larger at small $n$; gates and reported memory cross near $n approx 176$, while proving time crosses near $n approx 290$. Beyond those points, the removed matrix dominates the added hashes.

#figure(
  image("/assets/figures/14_flat_refined_behavior.pdf"),
  caption: outline-caption(short: [Witness and verification time across refinements.])[
    The two metrics not captured by gate count. Left: witness-generation time. Right: verification time. Times follow the lower-envelope convention of @fig:mech-witness.
  ],
) <fig:flat-refined-behavior>

The matrix representation also determines verifier work. The full circuits expose $n^2$ matrix entries and require about $3.4$ seconds to verify at the endpoint; the committed circuit exposes one root and verifies in about $12$ milliseconds. @fig:flat-refined-behavior shows the full-interface cost growing with $n$, while the two-value interface keeps the committed verifier near the same scale.

Witness time reflects the operations hidden by the gate total. Sorting removes the $bigoh()(n^2)$ inverse hints of pairwise inequality. Commitment removes the witness-indexed lookup over the public matrix described in @sec:naive-circuit: instead of laying out an $n^2$ table and resolving its access log, the solver evaluates the fixed-index path arrays and straight-line hashes of @sec:committed-matrix.

Sorting reduces constants within the full-matrix architecture; commitment changes its dominant term and public interface. Past the observed crossovers, _monolithic-merkle-sort_ is smaller and faster across the varying metrics, but it still places the whole route in one growing proving task. The next chapter changes the architecture through decomposition.
