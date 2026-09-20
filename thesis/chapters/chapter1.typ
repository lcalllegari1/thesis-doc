#import "/theme/headings.typ": *
#import "/theme/utils.typ": *

#chapter([Introduction], label: <chap:introduction>)

This chapter introduces zero-knowledge proofs through an interactive example. We then state the problem, research questions, and contributions of this thesis.

#section([Motivation], label: <sec:motivation>)

Imagine a ring-shaped cave whose entrance branches into passages $A$ and $B$ with a locked door connecting them at the far end. Alice knows the secret word that opens it and wants to prove this to Bob without telling him the word @quisquater1990. Bob stays outside the cave while Alice goes inside, and he cannot see which branch she takes. Only then does he randomly call $A$ or $B$ and ask her to return that way. If Alice knows the word, she can cross through the hidden door when necessary and always comply. Without it, she is trapped on the side she chose and succeeds only when Bob happens to name that side, with probability $1\/2$.

A single successful round is therefore weak evidence: an impostor may simply have guessed Bob's request correctly. Repeating the protocol makes a false acceptance increasingly unlikely. In each round, Alice _commits_ by entering before she knows the request, Bob issues a random _challenge_ by requesting one of the two sides, and Alice _responds_ by emerging from the requested side. Because each challenge follows the commitment and determines the response, the evidence develops through a live, interactive exchange. To succeed, an impostor must guess every challenge, so after $r$ independent rounds the chance of passing all of them falls to $2^(-r)$.

This example showcases the original form of a zero-knowledge proof: an _interactive protocol_ @goldwasser1989 between two parties. Alice plays the prover, while Bob plays the verifier. The example also introduces the three crucial properties such a proof must have.
An honest prover always succeeds (_completeness_#h(1pt)); a prover without the secret succeeds only with negligible probability after enough rounds (_soundness_#h(1pt)); and the verifier learns nothing beyond the prover's knowledge of the secret (_zero-knowledge_#h(1pt)). We formally define all three properties in @sec:zk-proofs.

Zero-knowledge proofs now support applications across several domains. Zcash's shielded transactions use them to hide the payment's origin, destination, and amount while allowing the network to verify that the transaction preserves value @zerocash.
Identity systems can use zero-knowledge proofs to let people prove selected attributes, such as meeting an age threshold, without disclosing additional personal information @selfxyz, @google-age-zkp. These systems build on earlier work on data-minimizing wallets and anonymous credentials @babel2023, @brands2000, @camenisch2001.
For general computation, zero-knowledge virtual machines (zkVMs) let a prover certify the execution of ordinary code while hiding private inputs or execution data. RISC Zero, SP1, and Jolt are concrete systems built around this model @risczero, @sp1, @jolt2023.

These diverse applications require a general-purpose proof system that can handle any efficiently checkable statement, without keeping prover and verifier online at the same time, while producing small proofs that remain fast to verify as the computation grows. These properties are _generality_, _non-interactivity_, and _succinctness_.

Zero-Knowledge Succinct Non-Interactive Arguments of Knowledge (zk-SNARKs) provide these guarantees @bitansky2012. The prover demonstrates knowledge of a private _witness_ that makes a public statement true, while a fixed arithmetic circuit encodes the computation that checks that statement @parno2013pinocchio. The statement supplies public inputs, the witness supplies private values, and the circuit constrains them through addition and multiplication gates; the application changes this circuit, whereas the proving machinery remains the same. Because its gates and wires are fixed before proving, the computation must be finite: loops must be unrolled to a fixed bound or represented by a bounded execution trace, so no finite circuit can certify the completion of a non-terminating computation @parno2013pinocchio, @bensasson2013snarksc.

Strictly, a SNARK is an _argument_, not a proof~#footnote[Cryptographic writing often still calls arguments _proofs_ when the distinction is not central.]~@brassard1988: its soundness holds only against computationally bounded provers, under hardness assumptions rather than against an unbounded adversary. Practical SNARK soundness therefore rests on assumptions that certain problems are infeasible for a realistic adversary. For example, recovering $x$ from $g$ and $g^x$ in a suitable cryptographic group is assumed infeasible (the discrete-logarithm problem) @diffie1976. Integer factorization provides another example of a computational hardness assumption @rivest1978.

This thesis fixes one zk-SNARK backend and compares proof architectures through the Traveling Salesman Problem (TSP), a well-known problem in the literature @applegate2006, @dantzig1954. On a complete weighted graph, the optimization problem asks for the cheapest Hamiltonian cycle, whereas the decision version asks whether a cycle of cost at most a threshold $T$ exists. The optimization problem is NP-hard and the decision problem NP-complete, both in the worst case @applegate2006. In the decisional TSP, finding a suitable route can be difficult, but once a candidate is available, a verifier can check it in polynomial time by confirming that every node appears once, summing the arc costs, and comparing the result with $T$.

This makes decisional TSP a good fit for a zero-knowledge proof: a route is easy to check even when it's hard to find, so there is value in keeping a route private while being able to prove properties about it to another party. In this work, we assume the prover already holds a route below a public threshold, and the starting point is proving a route satisfies a cost threshold while keeping the route and the exact cost private.

This separation between a public bound and a private route models settings in which compliance conflicts with secrecy. For example, a logistics or security firm could prove that a planned delivery or transit route meets a public time limit without revealing proprietary routing choices, GPS traces, timing windows, or stop durations.

#section([Problem Definition], label: <sec:problem-definition>)

We now formally express the statement in the context of the TSP problem as a relation, specifying public problem data and a private route.

#subsection([Mathematical Formulation], label: <sub:formulation>)

We use a complete directed graph $G=(ccal("N"),ccal("A"))$ with $n=|#h(1pt)ccal("N")#h(2pt)|$ nodes. The node set is $ccal("N")={0,dots,n-1}$, and the arc set is
$ccal("A") = { (i, j) : i, j in ccal("N"), i != j }$, since the graph is assumed to be complete. An $n times n$ matrix $C$ stores the nonnegative integer arc costs, with $c#h(1pt)\(i,j)$ denoting the cost from node $i$ to node $j$.

A _valid_ route is a Hamiltonian cycle: it visits every node once and returns to its start. We represent it by the ordering $pi=(pi_0,pi_1,dots,pi_(n-1))$. The return to the first node, after visiting $pi_(n-1)$, is not included in the sequence but is accounted for when computing the total cost of the route. In other words, the last arc is implicit and we adopt the convention $pi_n = pi_0$. Thus $pi$ is a permutation of $ccal("N")$, a property enforced by the circuits in later chapters.

The cost of such a route is the sum of the costs of its $n$ arcs,
$ "cost"#h(1pt)\(pi) = sum_(i=0)^(n-1) c#h(1pt)\(pi_i, pi_(i+1)) med . $
The problem fixes a public threshold $T$, and we call a route _feasible_ when $"cost"#h(1pt)\(pi) <= T$.

We can now formalize the exact proposition we want to prove. The public data consists of the cost matrix $C$ and the threshold $T$. The private witness is the route $pi$. The conditions for a valid and feasible route are captured by the relation

$ R = { chevron.l (C, T), pi chevron.r : pi "is a permutation of" ccal("N") "and" "cost"#h(1pt)\(pi) <= T }. $ <eq:relation>

The prover claims knowledge of a witness $pi$ for which $chevron.l (C,T),pi chevron.r in R$, revealing neither the route nor its exact cost.

#subsection([Computational Bottlenecks], label: <sub:computational-bottleneck>)

Succinctness keeps a proof with a constant-size public interface small and quick to verify even as the statement grows. It does not remove the prover's work: compilation, witness generation, proving time, and memory still grow with the instance size $n$. Of these, memory imposes a hard limit on fixed hardware: a proving task remains feasible, however long it takes, only while it fits in the available capacity; once it does not, proof generation fails.

@chap:monolithic-proofs expresses relation @eq:relation in one circuit whose size and memory requirement grow with $n$. A fixed memory budget therefore sets a ceiling that hardware, circuit design, and the proving backend can move but cannot remove: one prover must still hold the complete route-level computation. This motivates the composite constructions of @chap:composite-proofs.

#section([Research Questions], label: <sec:research-questions>)

#block(above: 1em, below: 1em, breakable: false, stroke: (left: 1pt + colors.primary), inset: (left: 10pt, top: 5pt, bottom: 5pt))[
    #block()[
        #set text(font: "Libertinus Sans", style: "italic", fill: colors.primary)
        Leading Research Question
    ]
    How do monolithic and composite zero-knowledge proof architectures behave when proving a globally constrained statement, and what advantages and trade-offs arise from decomposing and recombining the proof?
]

Three specific questions separate the design of the monolithic baseline, the possible advantages of decomposition, and the problem of private recombination.

#subsection([The Monolithic Baseline], label: <sub:monolithic-rq>)

A meaningful and credible comparison begins with the design of the monolithic construction. A deliberately naive circuit could make decomposition appear beneficial for reasons unrelated to the architecture itself. We treat refinement as part of the study: compare plausible constraint mechanisms, remove dominant avoidable costs, and characterize the resulting construction as the instance grows. The study seeks a well-engineered, refined baseline within the fixed proving stack.

#block(above: 1em, below: 1em, breakable: false, stroke: (left: 1pt + colors.primary), inset: (left: 10pt, top: 5pt, bottom: 5pt),)[
#block()[
#set text(font: "Libertinus Sans", style: "italic", fill: colors.primary)
Research Question #text(style: "normal")[(1)]
]
How should the monolithic proof be designed to provide a credible baseline for comparison, and how does the resulting architecture behave as the instance size grows?
]

#subsection([The Advantages of Decomposition], label: <sub:composite-rq>)

A composite construction cuts the route into $K$ segments and proves them separately before recovering the claim at the global-route level. Because each segment is roughly $n\/K$ in size, its circuit is structurally smaller and it could allow smaller proving tasks and independent work to be scheduled in parallel, or extend the range of instances that can be handled. Recombination may preserve, reduce, or outweigh those advantages, depending on how the global conditions are restored.

#block(above: 1em, below: 1em, breakable: false, stroke: (left: 1pt + colors.primary), inset: (left: 10pt, top: 5pt, bottom: 5pt))[
#block()[
#set text(font: "Libertinus Sans", style: "italic", fill: colors.primary)
Research Question #text(style: "normal")[(2)]
]
What advantages can decomposition provide over the refined monolithic proof, and how do segmentation and recombination choices determine whether those advantages survive end to end?
]

#subsection([Recombination and Structural Privacy], label: <sub:trade-offs-rq>)

Decomposition removes the global view that lets one circuit enforce node coverage, connection, and total cost directly. Recombination must recover those properties from evidence about the separate segments. The form and placement of that evidence determine both the work of recombination and what reaches the final verifier.

_Structural privacy_ captures what the verifier learns about the route partition. A public recombination interface may disclose segment contents, endpoints, or partial costs. Commitments can hide those values while retaining external proof checks, whereas recursion can move the complete interface into an outer witness. These choices redistribute work between prover and verifier and change the topology of the final proof.

#block(above: 1.5em, below: 1em, breakable: false, stroke: (left: 1pt + colors.primary), inset: (left: 10pt, top: 5pt, bottom: 5pt))[
#block()[
#set text(font: "Libertinus Sans", style: "italic", fill: colors.primary)
Research Question #text(style: "normal")[(3)]
]
How can segment proofs be recombined into the original global claim while preserving structural privacy, and what trade-offs among prover cost, verifier work, and disclosure arise from different recombination strategies?
]

#section([Contributions], label: <sec:contributions>)

This thesis makes three contributions to the design of zk-SNARK architectures for globally constrained statements, using the TSP relation as a benchmark.

- _Refined monolithic baseline_. We compare four permutation mechanisms, select sorting as the canonical exact mechanism, and replace the quadratic public cost-matrix interface with a Merkle root. The resulting circuit provides a comparison-ready monolithic baseline for relation @eq:relation.

- _Recombination architectures and costs_. Starting from a route that has already been found, we divide its verification into segment proofs and specify the recombination contract required to restore global coverage, continuity, cost binding, and threshold satisfaction. We construct external, commitment-protected, and recursive variants, and measure their _stitching tax_: the work required to turn locally certified segments into the original global claim. The constructions expose trade-offs among peak prover memory, scheduling, verifier work, proof topology, and structural privacy.

- _Controlled architectural comparison_. We evaluate constrained work, peak prover memory, completion schedules, and verifier load under one proving stack. Direct cost comparisons hold coverage and structural privacy fixed, separating architectural effects from savings caused by weaker guarantees or greater disclosure.

#section([Outline], label: <sec:outline>)

The remainder of the thesis follows three stages. Chapters 2 and 3 position the problem in related work and establish the cryptographic and technical foundations. Chapters 4 and 5 develop the monolithic baseline and composite constructions. Chapters 6 and 7 evaluate these architectures and interpret their trade-offs.
