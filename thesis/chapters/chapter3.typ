#import "/theme/headings.typ": *
#import "/theme/utils.typ": *
#import "@preview/cetz:0.5.2"

#chapter([Background], label: <chap:background>)

This chapter supplies the concepts needed to read the constructions that follow. It gives a compact formal account of zero-knowledge arguments, arithmetic circuits, the proving stack, cryptographic commitments, authenticated data, and randomized algebraic checks. The final section states the security model that connects those tools to the claims made in Chapters 4 and 5.

#section([Zero-Knowledge Arguments], label: <sec:zk-proofs>)

@chap:introduction introduced zero-knowledge through an interactive protocol. Its formal definitions specify what the prover claims, what the verifier learns, and what acceptance implies. The later constructions are non-interactive arguments of knowledge, but use the same underlying relation between a public statement and a private witness.

#subsection([Statements and Witnesses], label: <sub:statements-witnesses>)

A relation $R$ connects public _statements_ $x in ccal("X")$ with private _witnesses_ $w in ccal("W")$:

$ R subset.eq ccal("X") times ccal("W"). $

We write $R(x,w)=1$ when $w$ certifies $x$. The corresponding language $ccal("L")_R$ contains every statement with at least one valid witness, and it is defined as follows:

$ ccal("L")_R = {x in ccal("X") : exists w in ccal("W"), med R(x,w)=1}, $

Checking $(x,w)$ must be efficient; finding a suitable $w$ need not be.

For relation @eq:relation, $x=(C,T)$ contains the agreed cost matrix and threshold, while the witness $w=pi$ is the route. Later circuits replace the matrix entries on the proof interface with a Merkle root. That is a representation change. The semantic claim remains that $pi$ is valid and feasible for the agreed $C$ and $T$.

In the interactive form, the prover $P$ knows $(x,w)$ and exchanges messages with a verifier $V$ that receives $x$. Their ordered messages form a transcript, security is parameterized by $lambda$, and $"negl"(lambda)$ denotes a negligible function. Formal treatments of these conventions and the definitions below are given by @goldwasser1989 and @brassard1988.

#subsection([Security Properties], label: <sub:security-properties>)

_Completeness_ requires an honest prover with a valid witness to be accepted. For every $(x,w)$ such that $R(x,w)=1$,

$ "Pr"[chevron.l P(w), V chevron.r(x) = 1] >= 1 - "negl"(lambda), $

where $chevron.l P(w),V chevron.r(x)$ denotes their interaction on common input $x$, with the prover having additional knowledge of $w$.

For every false statement, _soundness_ bounds the success of a cheating prover $P^star$:

$ "Pr"[chevron.l P^star, V chevron.r(x) = 1] <= "negl"(lambda). $

The constructions in this thesis are _arguments_: soundness is guaranteed against efficient provers under computational assumptions, rather than against an unbounded prover @brassard1988.

_Zero-knowledge_ requires that every efficient verifier strategy $V^star$ have an efficient simulator $S$ that can reproduce its view without the witness:

$ "View"_(V^star)^(P(w))(x) approx S#h(1pt)_(V^star)(x). $

Here, $"View"_(V^star)^(P(w))(x)$ includes the transcript, randomness, and internal state available to $V^star$, while $approx$ denotes indistinguishability. Whatever the verifier obtains from the real interaction could therefore have been produced from the public statement alone @goldwasser1989.

In _perfect_ zero-knowledge the two distributions are identical. In _statistical_ zero-knowledge their distance is negligible even to an unbounded observer. In _computational_ zero-knowledge only an efficient observer is unable to distinguish them. This classification concerns disclosure and is independent of whether soundness is that of a proof or an argument.

Because the simulator receives $x$, zero-knowledge does not hide the public statement. If a composite construction publishes endpoints, node sets, or partial costs, those values are disclosed by its interface even when the backend is zero-knowledge. This boundary between public statement and private witness determines the structural privacy studied in @sub:trade-offs-rq.

#subsection([Knowledge Soundness], label: <sub:knowledge-soundness>)

Soundness rules out false statements; _knowledge soundness_ additionally ties acceptance to possession of a witness. If a strategy $P^star$ convinces the verifier with sufficient probability, an efficient extractor using $P^star$ as a subroutine must obtain

$ "Ext"#h(1pt)^(P^star)(x) arrow w quad "such that" quad R(x,w)=1. $

The extractor is part of the definition, not the verification procedure. Precise formulations account for its running time, its access to the prover, and a possible knowledge error @bellare1992pok. This thesis relies on the knowledge-soundness guarantee of the backend rather than constructing an extractor for each circuit.

The backend establishes knowledge of an assignment satisfying a circuit; the construction must show that the circuit expresses the intended relation. Chapters 4 and 5 therefore justify the permutation, cost-binding, threshold, and composition constraints rather than treating backend soundness as a proof of correct encoding.

#section([SNARKs and Arithmetic Circuits], label: <sec:snarks>)

The relation and its inputs follow two paths. The static path arithmetizes $R$ into constraints and compiles them into backend gates. The input-dependent path generates an assignment from $(x,w)$. Proving joins both paths to produce a proof. This section follows that flow, then introduces memory and recursion because both shape the constructions evaluated later.

#subsection([Arithmetic Circuits], label: <sub:arithmetic-circuits>)

An arithmetic circuit is a fixed collection of algebraic constraints over a finite field. Addition and multiplication fit this definition directly; Boolean logic, comparisons, bounded integers, and array access must be _arithmetized_ into field constraints @parno2013pinocchio. Arithmetization employs a constraint system to turn a computation into a set of equations. A Rank-1 Constraint System, R1CS for short, is a widely used constraint system in this context. To understand the intuition behind it, consider the following example.

Let public $y$ and private $u$ satisfy $y=u dot (u+1) dot (u+2)$. If we want to express this using an R1CS, we first need to perform flattening, since one R1CS constraint multiplies only two linear forms. We thus flatten by using the auxiliary value $t=u dot (u+1)$.

Each flattened constraint has the R1CS form @groth2016

$ chevron.l bold(a), bold(z) chevron.r dot chevron.l bold(b), bold(z) chevron.r - chevron.l bold(c), bold(z) chevron.r = 0. $

For the example assignment $bold(z)=(1,y,u,t)$, where the leading $1$ supplies constants, the coefficient vectors are

#v(10pt)

#align(center)[
  #set text(size: 11pt)
  #table(
    columns: (auto, auto, auto, auto),
    stroke: none,
    align: center,
    inset: (x: 4pt, y: 1.5pt),
    row-gutter: 10pt,

    table.header([constraint], [$bold(a)$], [$bold(b)$], [$bold(c)$]),
    [$u dot (u+1)-t=0$], [$[0,0,1,0]$], [$[1,0,1,0]$], [$[0,0,0,1]$],
    [$t dot (u+2)-y=0$], [$[0,0,0,1]$], [$[2,0,1,0]$], [$[0,1,0,0]$],
  )
]

#v(10pt)

The rows select $(u,u+1,t)$ and $(t,u+2,y)$, reproducing the flattened claim. The constraints are fixed by the relation, while $bold(z)$ supplies the values for one public statement and private witness.

Source languages hide much of this expansion. A comparison or array access may become range checks, auxiliary values, lookups, or memory constraints, so source-level operation counts do not determine backend gate counts.

Once the constraints are fixed, the prover must construct a complete assignment. Route finding occurs first and supplies $w$; _witness generation_ derives intermediate values and may compute other auxiliary values off circuit as _hints_. Constraints must check every property of a hint that affects acceptance.

#subsection([The Proving Stack], label: <sub:proving-stack>)

The arithmetic circuit and witness generation now provide fixed constraints and a complete assignment. The concrete stack compiles those constraints into backend gates, then a SNARK combines the gates and assignment into a proof @bitansky2012. @fig:proving-flow shows where the two paths meet.

#[
  #let flow-color = rgb("#7A0010")
  #let flow-box(body, fill: white) = box(
    width: 100%,
    height: 100%,
    stroke: 0.65pt,
    fill: fill,
    radius: 3pt,
    inset: (x: 5pt, y: 4pt),
    align(center + horizon, text(size: 7.5pt, hyphenate: false, body)),
  )
  #figure(
    cetz.canvas(length: 0.82cm, {
      import cetz.draw: *

      content(
        (0.1, 3.1),
        (2.7, 4.1),
        flow-box([Noir Code \ Relation $R$], fill: luma(247)),
        name: "flow-relation",
      )
      content(
        (4.0, 3.1),
        (6.55, 4.1),
        flow-box([ACIR \ constraints]),
        name: "flow-acir",
      )
      content(
        (7.85, 3.1),
        (10.5, 4.1),
        flow-box([Barretenberg \ gates]),
        name: "flow-gates",
      )

      content(
        (0.1, 0.35),
        (3.0, 1.35),
        flow-box([Public $x$ \ Private $w$], fill: luma(247)),
        name: "flow-inputs",
      )
      content(
        (4.0, 0.35),
        (6.55, 1.35),
        flow-box([Assignment $z$]),
        name: "flow-assignment",
      )
      content(
        (7.85, 0.35),
        (10.5, 1.35),
        flow-box([UltraHonk \ prover], fill: luma(247)),
        name: "flow-prover",
      )
      content(
        (11.55, 0.35),
        (13.15, 1.35),
        flow-box([Proof]),
        name: "flow-proof",
      )

      line((2.7, 3.6), (4.0, 3.6), stroke: 0.9pt + flow-color, mark: (end: ">"))
      content((3.35, 4.5), text(size: 7pt, fill: flow-color)[arithmetization])
      line((6.55, 3.6), (7.85, 3.6), stroke: 0.9pt + flow-color, mark: (end: ">"))
      content((7.2, 4.5), text(size: 7pt, fill: flow-color)[backend compilation])

      line((3.0, 0.85), (4.0, 0.85), stroke: 0.9pt + flow-color, mark: (end: ">"))
      content((3.5, 1.8), text(size: 7pt, fill: flow-color)[witness generation])
      line((9.175, 3.1), (9.175, 1.35), stroke: 0.9pt + flow-color, mark: (end: ">"))
      line((6.55, 0.85), (7.85, 0.85), stroke: 0.9pt + flow-color, mark: (end: ">"))
      line((10.5, 0.85), (11.55, 0.85), stroke: 0.9pt + flow-color, mark: (end: ">"))
      content((11.025, 1.8), text(size: 7pt, fill: flow-color)[proving])
    }),
    caption: outline-caption(short: [Noir-to-UltraHonk proving pipeline.])[
      From relation to proof: static compilation and input-dependent witness generation join at the UltraHonk prover.
    ],
  ) <fig:proving-flow>
]

Noir arithmetizes the source relation into the Abstract Circuit Intermediate Representation (ACIR) and completes the witness @noir2026. Barretenberg compiles ACIR into UltraHonk gates, then proves or verifies the circuit @barretenberg2026. The verifier receives the proof and public inputs, not the private assignment or represented computation.

UltraHonk belongs to the Plonkish family originating with PLONK and uses a universal structured reference string @gabizon2019plonk. A new ceremony is not required for every circuit, but the system is not setup-free. The associated assumption is stated in @sub:trust-assumptions.

This staging explains the evaluation metrics. ACIR opcodes have nonuniform gate expansions, while gate count describes the backend circuit but omits witness construction. The evaluation therefore measures opcodes, gates, witness-generation time, proving time, verification time, proof size, and peak memory separately.

Keeping the stack fixed isolates alternative arithmetizations and public-private interfaces rather than competing SNARK protocols. Succinctness also does not remove public-input processing, so interface size affects privacy and performance. Memory makes the gap between source operations and backend work especially visible.

#subsection([Memory Inside a Circuit], label: <sub:circuit-memory>)

An ordinary program can choose an array address at runtime; a fixed circuit cannot change its wiring. A constant index connects a predetermined wire. If the witness determines the address of some memory access, the circuit must instead prove that the claimed address and value are consistent with the encoded memory. Matrix access through a private route has this form.

The prover performs such accesses during witness generation, records their addresses and values, and proves a consistency condition over the resulting log. This is an _offline memory check_ @blum1991memory.

Read-only memory binds each claimed value to immutable contents at its claimed address. Read-write memory must additionally respect access order: a read returns the latest preceding write to that address.

Lookup arguments can prove table membership efficiently @gabizon2020, but memory consistency must also bind the value to its address and, for updates, its place in the access order. Witness-selected access therefore creates constraint and witness work that fixed wiring avoids.

The permutation and matrix-access mechanisms compared in Chapter 4 differ along this fixed-versus-witness-selected boundary.

#subsection([Recursive Verification], label: <sub:proof-recursion>)

The preceding pipeline produces one proof for one circuit. Composite constructions may instead need one circuit to consume proofs produced by other circuits. Proof verification is itself a fixed computation, so an _outer_ circuit can receive an _inner_ proof and its public inputs, verify it, and prove that verification accepted. This is _recursive verification_ or _proof recursion_ @bowe2019halo.

Inner public values may become private inputs of the outer circuit. The final verifier then sees only the outer statement, while the outer prover pays for in-circuit verification and a dependent proving stage.

The inner verification key must be fixed or constrained by the outer circuit; otherwise the prover could substitute a proof for another relation. The final verifier must then authenticate the outer key, which identifies the circuit and its embedded inner key. Chapter 5 instantiates this chain.

#section([Cryptographic Primitives], label: <sec:hashes-commitments>)

The later circuits need short public values that remain linked to larger or private data. Hash functions compress encoded values into digests. Commitments add an opening relation and can also hide the committed value. Merkle trees extend hash-based binding to an ordered collection and allow individual positions to be opened.

#subsection([Cryptographic Hash Functions], label: <sub:hash-functions>)

A hash function maps an encoded input message to a fixed-length digest:

$ H: ccal("D") arrow.r ccal("Y"), quad m in ccal("D") mapsto d = H(m) in ccal("Y"). $

The constructions use two standard properties of cryptographic hash functions @rogaway2004hash:

- _Preimage resistance:_ given $d$, an efficient adversary cannot find $m$ such that $H(m)=d$.
- _Collision resistance:_ an efficient adversary cannot find $u != v$ such that $H(u) = H(v)$.

Neither property makes a deterministic hash hiding. If $m$ comes from a small or predictable set, an observer can hash each candidate and compare the result with $d$.

A _random oracle_ is an idealized function that assigns an independently sampled output to each new input and returns the same output on repeated queries @bellare1993randomoracle. The later analyses use this model for blinded hash commitments and Fiat--Shamir challenges. The implementation instead evaluates the concrete Poseidon2 hash, whose field-native operations are designed for efficient arithmetization in Plonkish systems @poseidon2. Treating it as a random oracle is a modeling assumption.

#subsection([Commitment Schemes], label: <sub:commitment-schemes>)

A commitment publishes a short handle $D$ for a message $m$ and later verifies an opening:

$ D arrow.l "Commit"(m;r), quad "Open"(D,m,r)=1, $

where $r$ denotes fresh randomness. Its two security properties are independent @naor1991commitment:

- _Binding:_ an efficient committer cannot produce accepted openings $(m,r)$ and $(m',r')$ for the same $D$ with $m != m'$.
- _Hiding:_ an efficient observer cannot distinguish which candidate message produced $D$.

The blinded hash commitments used later take the form

$ D=H("encode"(m,r)). $

Collision resistance gives computational binding. With fresh, secret $r$ drawn from a sufficiently large space, the construction is computationally hiding in the random-oracle model. Reusing $r$ can reveal equality or other relationships @halevi1996hashcommit.

A commitment is not encryption: the verifier or a later circuit cannot recover $m$ from $D$. To use $m$ inside another proof, the prover supplies $(m,r)$ privately and the circuit checks the opening. Other commitment families offer different properties and interfaces: Pedersen commitments are perfectly hiding and computationally binding, while KZG commitments provide compact polynomial-evaluation openings under additional algebraic and setup assumptions @pedersen1991 @kate2010.

The thesis uses commitments in two roles. Chapter 4 needs only a binding representative of the public cost matrix, which the verifier can recompute. Chapter 5 commits to private segment summaries, so those commitments must also hide their openings from the final verifier.

#subsection([Merkle Trees], label: <sub:merkle-trees>)

A _Merkle tree_ applies a hash recursively to bind an ordered collection @merkle1987. For example, let $bold(v) = (v_0, dots, v_i, dots, v#h(1pt)_7)$ . Starting from leaves $u_i^(0)=v_i$, it computes each higher level as

$ u_j^(ell+1)=H(u_(2j)^ell,u_(2j+1)^ell), $

until one _Merkle root_ remains.

To open a leaf at a given index, an authentication path supplies one sibling and one left-or-right direction per level, on the path from that leaf to the root. Padding $N$ leaves to the next power of two gives depth $ceil(log_2 N)$ and a path from any leaf to the root with a length of $bigoh()(log N)$.

The verifier follows the directions, combines the opened leaf with each sibling, and reconstructs the root in $bigoh()(log N)$ hashes. @fig:merkle-path shows the opening of leaf $v#h(.5pt)_5$ in an eight-leaf tree.

#[
  #let path-color = rgb("#7A0010")
  #let sibling-fill = luma(200)
  #figure(
    cetz.canvas(length: 1cm, {
      import cetz.draw: *
      let tree-node(pos, fill: white, stroke: black, radius: 0.12) = circle(
        pos,
        radius: radius,
        fill: fill,
        stroke: 0.7pt + stroke,
      )

      // Complete tree.
      for (a, b) in (
        ((0.6, 0.45), (1.4, 1.75)),
        ((2.2, 0.45), (1.4, 1.75)),
        ((3.8, 0.45), (4.6, 1.75)),
        ((5.4, 0.45), (4.6, 1.75)),
        ((7.0, 0.45), (7.8, 1.75)),
        ((8.6, 0.45), (7.8, 1.75)),
        ((10.2, 0.45), (11.0, 1.75)),
        ((11.8, 0.45), (11.0, 1.75)),
        ((1.4, 1.75), (3.0, 3.05)),
        ((4.6, 1.75), (3.0, 3.05)),
        ((7.8, 1.75), (9.4, 3.05)),
        ((11.0, 1.75), (9.4, 3.05)),
        ((3.0, 3.05), (6.2, 4.35)),
        ((9.4, 3.05), (6.2, 4.35)),
      ) {
        line(a, b, stroke: 0.65pt + luma(105))
      }

      // Authentication path from v_5 to the root.
      line((8.6, 0.45), (7.8, 1.75), stroke: 1.5pt + path-color)
      line((7.8, 1.75), (9.4, 3.05), stroke: 1.5pt + path-color)
      line((9.4, 3.05), (6.2, 4.35), stroke: 1.5pt + path-color)

      // Leaves. The selected leaf is dark; its first sibling is gray.
      for (i, x) in (0.6, 2.2, 3.8, 5.4, 7.0, 8.6, 10.2, 11.8).enumerate() {
        let fill = if i == 5 { path-color } else if i == 4 { sibling-fill } else { white }
        let stroke = if i == 5 { path-color } else { black }
        tree-node((x, 0.45), fill: fill, stroke: stroke)
        content((x, 0.05), text(size: 8.5pt, fill: if i == 5 { path-color } else { black })[$v_#i$])
      }

      // Internal path nodes and supplied siblings.
      for pos in ((1.4, 1.75), (4.6, 1.75), (7.8, 1.75), (11.0, 1.75), (3.0, 3.05), (9.4, 3.05)) {
        tree-node(pos)
      }
      tree-node((11.0, 1.75), fill: sibling-fill)
      tree-node((3.0, 3.05), fill: sibling-fill)
      tree-node((7.8, 1.75), fill: path-color, stroke: path-color)
      tree-node((9.4, 3.05), fill: path-color, stroke: path-color)
      tree-node((6.2, 4.35), fill: black, stroke: black, radius: 0.14)

      content((6.2, 4.72), text(size: 8.5pt)[root])
    }),
    caption: outline-caption(short: [Merkle leaf $v_5$ authentication path.])[
      Authentication path for leaf $v_5$ in an eight-leaf Merkle tree. The dark path is recomputed from the opened leaf; the gray nodes are the three sibling hashes supplied with the opening. Their left or right positions bind the opening to index $5$.
    ],
  ) <fig:merkle-path>
]

Reconstructing the expected root proves that the leaf is consistent with the tree along the supplied path. To authenticate a required position, the verifier or circuit must also check that the directions encode the required index; otherwise the prover could open a convenient value elsewhere in the tree.

Under collision resistance, the root computationally binds the ordered leaves once their encoding, count, and padding convention are fixed. It therefore acts as a binding commitment to the collection. Hiding requires an additional mechanism, since predictable candidate collections can be reconstructed and compared with the root, while authentication paths reveal further hashes.

A valid path proves consistency with a root, so the application must authenticate that root. For public data, the verifier can recompute it. Private data instead requires an authenticated reference, such as a published root or a signature over the root and its instance metadata.

#section([Randomized Algebraic Checks], label: <sec:randomized-checks>)

The composite constructions compress large equality checks into polynomial evaluations. This introduces a soundness error whose bound depends on the polynomial degree, field size, and order in which the claim and challenge are fixed.

#subsection([Polynomial Identity Testing], label: <sub:schwartz-zippel>)

Let $p$ and $q$ be distinct univariate polynomials over a finite field $bb(F)$, with $deg(p-q)<=d$. For uniform $X in bb(F)$,

$ "Pr"[p(X) = q(X)] <= deg(p-q) / abs(bb(F)) <= d / abs(bb(F)). $

This is the univariate Schwartz--Zippel bound used here @schwartz1980, @zippel1979. A genuine identity always passes; a false one passes only when $X$ is one of at most $d$ roots of $p-q$.

When $d << abs(bb(F))$, one evaluation is a compact fingerprint of a much larger equality. Constructing that fingerprint may still process every element, so the interface shrinks without necessarily removing the underlying work. Chapter 5 applies this test to product polynomials whose roots encode route-node multisets.

The polynomials must be fixed before $X$ is known. Otherwise the prover can choose a false polynomial tailored to the evaluation point, outside the condition covered by the bound.

#subsection([Non-Interactive Challenges], label: <sub:fiat-shamir>)

An interactive verifier can sample $X$ after receiving a message that fixes the claim. Fiat--Shamir reproduces this dependency non-interactively by hashing the statement and preceding transcript @fiat1986:

$ X = H("encode"#h(1pt)\(x, tau)). $

The transcript $tau$ must bind every value that determines the polynomial. Changing the claim then changes the hash input and, in the random-oracle model, produces a fresh challenge @bellare1993randomoracle.

The prover may still try several claims and keep one whose derived challenge is favorable, in a process called _grinding_. After $Q$ fresh random-oracle queries, a union bound gives error at most $Q dot d\/abs(bb(F))$. These are hash queries rather than completed proofs, so the guarantee relies on the prover being computationally bounded; the bound remains small when $Q dot d << abs(bb(F))$.

#section([Security Model and Trust Boundaries], label: <sec:security-model>)

An accepted proof is relative to a circuit, verification key, and public instance. The security model separates what the proof establishes from what the surrounding application must authenticate.

#subsection([Adversarial Model], label: <sub:adversarial-model>)

The prover is computationally bounded but may otherwise deviate arbitrarily. It controls the route, auxiliary values, Merkle paths, blindings, segment summaries, and proof data. No trust is placed in the solver, witness generator, or other prover-side preprocessing; their outputs acquire meaning only through constraints and cryptographic checks.

The verifier follows the complete procedure: it uses the expected key, parses public inputs in their specified order, performs the required cross-proof checks, and obtains the matrix root and threshold independently of the proof package.

Privacy is defined against any efficient party that receives the proof and its public inputs. The backend protects private witness values; the architecture determines what appears in the public statement.

#subsection([Security Layers], label: <sub:security-layers>)

Three layers connect acceptance to relation @eq:relation. First, UltraHonk completeness, knowledge soundness, and zero-knowledge govern satisfying assignments under a fixed verification key. These backend properties are assumed rather than reproved for each circuit.

Second, the encoding of the relation must show that a satisfying assignment contains a route that covers the target nodes, uses the matrix's costs, and meets the threshold. Deterministic constraints give exact implications. Merkle openings additionally rely on collision resistance; product-based coverage relies on the randomized soundness bound and challenge model of @sec:randomized-checks.

Third, composition must bind the local segment statements into one route. External constructions enforce the interface equalities in the verifier procedure; recursion verifies and reconciles the segment proofs inside the outer circuit.

#subsection([Trust Assumptions and Scope], label: <sub:trust-assumptions>)

The stack uses a universal, updatable structured reference string: one setup supports circuits up to a size bound, followed by circuit-specific key generation @gabizon2019plonk. Security requires at least one honest contributor to destroy its update randomness @groth2018crs and the backend's stated cryptographic assumptions. The verification key fixes the circuit, interface, and structural parameters; the verifier must obtain it from an authenticated artifact, registry, manifest, or configuration. Under recursion, the outer key authenticates the embedded segment key.

The verifier similarly derives the matrix root from the public matrix and obtains $T$ from the application. If only a root is available, an external source must bind it to the intended matrix; accepting a prover-selected root or threshold proves a prover-selected instance.
