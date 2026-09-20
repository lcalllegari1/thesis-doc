#import "../theme/headings.typ"


= Abstract

#[

  #set text(size: 10pt)

Zero-knowledge proofs let a prover convince a verifier that a statement is true without revealing anything beyond that fact. This thesis studies succinct, non-interactive zero-knowledge arguments (zk-SNARKs) through the Traveling Salesman Problem (TSP). For a complete graph of $n$ nodes, the prover claims knowledge of a Hamiltonian cycle costing at most a public threshold while keeping the route and its exact cost private.

A monolithic circuit expresses this statement in one proving task and produces a single succinct proof object. The task grows with the graph size $n$, until its memory exceeds the available memory on fixed hardware. 

We develop a refined monolithic construction that serves as a baseline, and then explore composite constructions. In those, we divide the route into $K$ segments, prove them in smaller circuits, and recombine their local claims into the original global statement about the entire route. We implement every construction in Noir, using UltraHonk as the proof system through the Barretenberg backend engine @zktsp2026. 

Composite constructions recombine segment proofs either externally or recursively, resulting in different proof topologies and architectural trade-offs. In external recombination, a separate glue proof establishes the global checks, and the verifier binds its claims to those of the segment proofs. In recursive recombination, the same binding is performed internally on the prover side, where an outer circuit verifies the segment proofs, enforces the global checks, and combines their claims into a single proof object.
Both approaches introduce a recombination surface for reconstructing the global claim from the segments; we study this surface and refine the constructions to keep the route and its cost private.

At $n=4000$ on the consumer host, monolithic proving reaches a peak of $12.95$ GiB. External recombination reduces this peak to $8.8$ GiB when node coverage remains in the glue circuit, and to $1.6$ GiB at $K=8$ when compact computational coverage summaries are used. Recursive recombination reaches its lowest peak, $4.03$ GiB, at $K=4$, after which the outer circuit becomes the limiting task. All composite architectures produce proofs at $n=5000$, beyond the largest successful monolithic checkpoint. None reduces sequential proving time on the same host, and lower estimated completion times require additional workers to exploit parallelism.

]

= Acknowledgements

To my parents, thank you for your love, for believing in me, and for supporting me throughout my studies. I am deeply grateful to have you beside me and to share this moment with you.

Mauro Conti, thank you for your time, for introducing me to Martin Ochoa, and for your enthusiasm about working on this project. Martin, thank you for your constant guidance and feedback, and for the time and care you have given to this work. I am grateful to you both for your patience throughout, and for the opportunity to work with you.

To my friends and colleagues, thank you for sharing these years with me, for your support, and for the company that has made them so much more enjoyable.

Finally, I would like to acknowledge the use of AI tools to assist with proofreading, formatting, and text polishing, as well as with parts of the experimental harness and implementation code. This included assistance with Noir syntax, dependency configuration, and code for plot generation and benchmarking.
