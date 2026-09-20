#import "/theme/headings.typ": *

#chapter([Related Work], label: <chap:related-work>)

This chapter positions the thesis within the work on general-purpose zero knowledge, scalable proving, proof composition, and graph-specific verification. The organizing question is where a large proof computation is divided. A backend may distribute the algebra for one circuit; a generic system may split a circuit or execution into composed pieces; an application may expose smaller semantic statements; or a prover may reduce memory without distributing the computation.

#section([Generality and Verifiable Computation], label: <sec:related-general-vc>)

Goldwasser, Micali, and Rackoff formalized zero knowledge and its simulation-based privacy requirement @goldwasser1989. Goldreich, Micali, and Wigderson then showed, assuming one-way functions, that every language in NP has a zero-knowledge proof system @goldreich1991. Relation @eq:relation belongs to NP because a verifier can check a candidate route, its costs, and the threshold in polynomial time. This establishes existence; efficient implementation remains a separate problem.

Pinocchio and _SNARKs for C_ show how general-purpose proving works in practice. A statement is expressed as a computation, compiled into algebraic constraints, and then proved by a reusable backend. Pinocchio translated arithmetic circuits into quadratic arithmetic programs and used circuit-specific preprocessing to obtain short proofs with fast verification @parno2013pinocchio. _SNARKs for C_ extended the same pipeline to programs with data-dependent control flow and memory by compiling C to TinyRAM and proving a valid execution trace @bensasson2013snarksc.

This thesis fixes both the constraint language and the proof backend. The TSP relation is written directly in Noir, and every construction uses UltraHonk. Later chapters can therefore compare how the same route checks (permutation, authenticated cost lookups, and the threshold) are encoded in one circuit or divided and recombined across several proofs. Holding the stack fixed isolates the effect of those architectural choices.

#section([TSP as a Verification Benchmark], label: <sec:related-tsp-benchmark>)

Blum used knowledge of a Hamiltonian cycle as a canonical statement @blum1986, while Igari et al. recently constructed physical protocols for Hamiltonian cycle and TSP @igari2026physicalzkp. Those works are relevant, but they use problem-specific interactive protocols, rather than the succinct circuit-proof setting studied here.

The closest early circuit benchmark is the rectilinear TSP experiment in _SNARKs for C_ @bensasson2013snarksc. Its witness is a low-weight Hamiltonian path beginning at a public source in a fixed coordinate graph. This thesis proves a Hamiltonian cycle over an agreed weighted matrix, including the closing arc. The common core is a private ordering constrained by a public cost bound; the relation and representation differ. 

The same paper proposed _computing in blocks_ to reduce prover space. Blocking divides backend work while preserving the application relation, circuit, public interface, and final proof. Here, route segmentation divides the relation itself. Each segment loses the global view needed to enforce coverage, cyclic continuity, and the total cost, so recombination becomes part of the application design.

#section([Scalable Proving Architectures], label: <sec:related-distributed-proving>)

Scalable proving systems move different resource boundaries. The distinction relevant here is whether work distribution remains hidden below one relation or creates separately certified pieces with an explicit interface.

#subsection([Backend-Level Distribution], label: <sub:related-one-circuit>)

DIZK distributes the state and dominant algebraic operations of one R1CS prover across a cluster @wu2018dizk. Pianist applies a similar external model to PLONK: workers process circuit portions and a coordinator combines their contributions into one proof @liu2024pianist. Other systems refine nearby points: deVirgo distributes the prover used by zkBridge, Soloist targets distributed R1CS proving with constant proof size, and Cirrus adds accountability for identifying a misbehaving worker @xie2022zkbridge @li2026soloist @wang2026cirrus. HyperFond extends this with transparent, post-quantum distributed proving @yu2026hyperfond. The protocols differ, but the application still presents one circuit and the verifier still receives one claim.

#subsection([Circuit-Level Decomposition], label: <sub:related-other-cuts>)

HEKATON divides an arbitrary circuit into subcircuits, proves them separately, and aggregates the proofs @rosenberg2024hekaton. A global-memory abstraction enforces agreement on wires crossing the cut. This establishes the generic decompose--prove--aggregate pattern and shows that horizontal scaling need not expose several proofs to the final verifier.

Here, the cut follows semantic boundaries. Consecutive route segments become separate statements, so the lost global conditions are route properties: Hamiltonian coverage, cross-segment continuity, matrix-bound costs, and one total threshold. They have to be restored from the segment proofs in a recombination step that also ensures consistency of all the pieces.

Scribe streams prover intermediate states through disk while retaining one circuit @baweja2026scribe; Sparrow gives space-efficient proving for data-parallel circuits @pappas2024sparrow. These systems address the same resource pressure through a different proof system or storage model, without introducing an application-level recombination interface.

Collaborative zk-SNARKs divide something else again: mutually distrustful parties jointly prove a statement over witness shares that no single party owns @ozdemir2022collaborative. This thesis assumes one logical owner of the complete route and divides proof work, not witness ownership.

#section([Proof Composition], label: <sec:related-recursion-pcd>)

Valid local proofs do not establish the relation among them. Composition must certify both local validity and cross-piece consistency through recursion, folding, aggregation, commitment linking, or a combination of these mechanisms.

#subsection([Recursion and Folding], label: <sub:related-recursion-folding>)

Recursive composition verifies earlier proofs inside a new proof. Proof-carrying data generalizes this pattern to distributed computations whose outputs carry proofs of their histories @chiesa2010pcd. Later work studied complexity-preserving recursion and applied PCD to MapReduce-style computation @bitansky2013pcd @chiesa2015cluster. In every case, privacy depends on which values the composed statement exposes.

Halo demonstrated recursive composition without a trusted setup @bowe2019halo. Nova replaced repeated in-circuit verification with folding, which accumulates instances before a final check @kothapalli2022nova. Mangrove combines folding with parallel and low-memory proving @nguyen2024mangrove. These are generic composition frameworks. The recursive construction in @sec:recursive-composite is a narrower, bounded two-level design: one outer circuit verifies $K$ segment proofs and restores the route-wide relation.

#subsection([Aggregation and Commitment Linking], label: <sub:related-aggregation-linking>)

Aggregation compresses the verification of several proofs. SnarkPack, for example, aggregates Groth16 proofs into a compact object @groth2016 @gailly2022snarkpack. Aggregation alone here would not establish common inputs, connected endpoints, complete coverage, or a total threshold; those remain application relations among the certified statements.

Commit-and-prove systems bind separate relations to hidden shared values. LegoSNARK provides a general framework for composing proofs around committed data @campanelli2019legosnark. The committed constructions of @sec:committed-composite use the same interface idea without claiming to instantiate that framework: segment summaries remain hidden behind blinded digests, while a recombination proof checks their openings. Recursion moves both proof verification and reconciliation into the outer circuit; external recombination leaves more work and structure at the verifier interface.

#section([Graph and Path Specialization], label: <sec:related-graph-path>)

Graph-aware systems exploit structure that a generic compiler would otherwise treat as arbitrary computation.

LaPathZK is the closest recent path-specific system @zhu2026lapathzk. It uses a distributed lattice-based protocol to prove that a hidden path satisfies a public cost threshold. This thesis proves a different relation: an ordered Hamiltonian cycle must cover every vertex exactly once, connect segment boundaries and the closing arc, and bind each cost to the committed matrix. LaPathZK designs a new distributed proof system; this work fixes Noir and UltraHonk and compares public, commitment-protected, and recursive recombination interfaces.

#section([Layers of Decomposition], label: <sec:related-synthesis>)

The literature therefore supplies three adjacent foundations. Backend distribution and low-memory systems retain one application relation while changing how its proof is computed or stored. Generic decomposition, recursion, and folding split compiled computation and restore consistency through shared state or proof composition. Graph-specific systems tailor constraints or protocols to graph and path structure.

This thesis provides a controlled architectural comparison at the semantic-relation layer. It implements the same Hamiltonian-cycle claim as a refined monolithic proof and as several segmented proofs under one Noir and UltraHonk stack. The segmentation makes route-wide coverage, continuity, matrix binding, and threshold enforcement explicit recombination duties.
