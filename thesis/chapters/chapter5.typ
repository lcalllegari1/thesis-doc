#import "/theme/headings.typ": *
#import "/theme/utils.typ": *
#import "/vendor/lovelace/lib.typ": *
#import "@preview/cetz:0.5.2"
#import "@preview/showybox:2.0.4": showybox

#let routesegment = pid("segment")
#let sortednodes = pid("sorted_nodes")
#let startnode = pid("start")
#let endnode = pid("end")
#let partialcost = pid("partial_cost")
#let allsortednodes = pid("all_sorted")
#let startnodes = pid("starts")
#let endnodes = pid("ends")
#let partialcosts = pid("partial_costs")
#let startfields = pid("starts_f")
#let endfields = pid("ends_f")
#let partialcostfields = pid("partial_costs_f")
#let boundarycosts = pid("boundary_costs")
#let productvalue = pid("product")
#let products = pid("products")
#let hin = pid("in_anchor")
#let hout = pid("out_anchor")
#let hins = pid("in_anchors")
#let houts = pid("out_anchors")
#let prod = pid("computed_product")
#let commitment = pid("commitment")
#let commitments = pid("commitments")
#let blind = pid("blind")
#let blinds = pid("blinds")
#let values = pid("values")
#let allnodes = pid("all_nodes")
#let edgecosts = pid("edge_costs")
#let siblings = pid("siblings")
#let pathbits = pid("path_bits")
#let sorted = pid("sorted")
#let total = pid("total")
#let lhs = pid("combined_product")
#let rhs = pid("target_product")
#let proofs = pid("proofs")
#let pubs = pid("pubs")
#let roots = pid("roots")
#let terminal = pid("terminal")
#let terminals = pid("terminals")
#let challenges = pid("challenges")
#let innerinputs = pid("inner_inputs")

#chapter([Composite Proofs], label: <chap:composite-proofs>)

This chapter develops composite proof architectures in response to the monolithic memory wall. We divide the route into independently provable segments, identify how the cut affects the constraints we have to enforce, and restore the global statement through recombination. The constructions differ in how they represent information, what they disclose, and whether recombination is external or recursive.

#section([Proof Decomposition], label: <sec:proof-decomposition>)

The refined monolithic circuit holds the complete route in one witness, so it can sort all $n$ nodes, authenticate every selected arc, and enforce the threshold directly. Decomposition replaces it with $K$ independently proved segments. Each segment sees only part of the witness, so recombination must recover the global constraints and bind the segment proofs into one claim about relation @eq:relation.

#subsection([Route Decomposition], label: <sub:route-decomposition>)

We partition $pi = (pi_0, dots, pi_(n-1))$ into $K$ consecutive, non-overlapping segments. We require $K$ to divide $n$, so each segment contains $M=n\/K$ nodes:

$ R_i = (pi_(i M), dots, pi_((i+1) M-1)), quad 0 <= i < K. $

All segments therefore share one circuit shape for fixed $(n,M)$. #footnote[The constructions additionally require $M>2$. Uneven segments would require constrained padding or multiple circuit shapes and verification keys.]

The cut preserves route order and keeps most arcs within a segment. Each segment contains $M-1$ internal arcs, giving $K(M-1)=n-K$ across the route. The remaining $K$ arcs cross segment boundaries: boundary $i$ connects $R_i [M-1]$ to $R_((i+1) mod K) [0]$. The modular index includes the wrap-around arc from the last segment to the first.

Because the segments do not overlap, each route position belongs to one segment circuit. An overlapping cut would process boundary nodes twice and require an additional check that both segments used the same value.

The segment proofs can be generated independently: one worker may produce them sequentially while holding one segment circuit at a time, or multiple workers may run them in parallel. Each proving unit contains $M$ route nodes rather than $n$, creating the possibility of lower per-task memory. The complete architecture must still perform recombination, so segmentation alone does not establish a lower end-to-end peak.

#subsection([Local Proofs and Global Obligations], label: <sub:monolith-strength>)

The cut leaves relation @eq:relation unchanged; it changes which circuit can see enough witness information to enforce each constraint. The relation requires coverage of every node exactly once, authentication of every selected arc cost, and a total cost at most $T$, as introduced in @sub:naive-constraints.

Coverage and threshold depend on the complete route, so no segment can settle them alone. Arc authentication needs only one arc's endpoints, claimed cost, and Merkle opening against the public root, so it can be placed wherever both endpoints are available. Segment $i$ holds both endpoints of its $M-1$ internal arcs, allowing it to authenticate them and certify their sum as the partial cost

$ L_i = sum_(j=0)^(M-2) C_(R_i [j], R_i [j+1]). $

No segment holds both endpoints of a boundary arc. The cut therefore divides the original guarantees and introduces a fourth obligation to keep the separate proofs consistent. @table:decomposition-obligations summarizes the resulting split.

#figure(
  block(width: 100%, breakable: false)[
    #set text(size: 9.25pt)
    #set par(justify: false)
    #table(
      columns: (.9fr, 1.4fr, 1.5fr),
      stroke: none,
      align: (left, left, left),
      inset: (x: 4pt, y: 4pt),
      row-gutter: 5pt,
      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Required guarantee]],
        text(font: "Libertinus Sans")[#smallcaps[A segment establishes]],
        text(font: "Libertinus Sans")[#smallcaps[What remains global]],
      ),
      table.hline(stroke: 0.6pt),
      [Coverage], [Evidence bound to its own $M$ nodes], [Every node $0, dots, n-1$ occurs once],
      [Arc authentication], [Its $M-1$ internal arcs], [The $K$ boundary arcs],
      [Threshold], [Its authenticated partial cost $L_i$], [Aggregate all partial and boundary costs and enforce $T$],
      [Consistency], [Validity of its own statement], [Bind all segment claims to one instance],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Local and global obligations after decomposition.])[
    What each segment can establish locally and what recombination must recover for the complete route.
  ],
) <table:decomposition-obligations>


Coverage remains global even when every segment honestly certifies its own node content. Two valid local claims may repeat one node and omit another, and neither segment can observe the conflict. Likewise, an authenticated partial cost $L_i$ accounts for only one part of the route cost and cannot establish the full threshold.

Independence also removes implicit consistency. Verifying one segment proof establishes only its own statement, so $K$ valid proofs may use different roots or describe unrelated route pieces. Recombination must bind the segment claims to the same instance, creating the composition obligation identified in @sub:security-layers.

Recombination must therefore establish global coverage, authenticate the $K$ boundary arcs, aggregate all costs and enforce $T$, and bind the independently certified segment claims into one statement. These four obligations form the recombination contract developed next.

#subsection([Recombination Contract], label: <sub:recombination-contract>)

To discharge these four obligations, recombination needs each segment to certify coverage evidence, its two endpoints, and its authenticated partial cost. We collect them in the logical summary

$ sigma_i = ("cov"_i, "start"_i, "end"_i, L_i). $

Here, $"cov"_i$ denotes the construction-specific evidence that binds coverage to $R_i$. It may contain the segment nodes themselves or a product summary together with the values that bind its challenge. The remaining fields identify the boundary endpoints and the authenticated partial cost of the $M-1$ internal arcs.

Given the $K$ summaries, recombination first combines their coverage evidence to establish the global coverage claim. It then uses the endpoints to restore the arcs removed by the cut. For every $0 <= i < K$, it obtains the boundary cost

$ b_i = C_("end"_i, "start"_((i+1) mod K)) $

and authenticates it with a Merkle path under the matrix root. Finally, it combines the boundary costs with the segment partial costs and enforces the threshold $T$.

These global checks are meaningful only if they use the summaries certified by the segment proofs. If recombination could use independently chosen values, it could establish coverage and the threshold for segments that were never proved. _Composition binding_ closes this gap by tying every recombination summary to its corresponding segment claim. It also binds every segment to the authenticated matrix root used for the boundary openings and ensures that recombination uses the intended $T$.

With these bindings in place, backend knowledge soundness associates each accepted segment proof with a valid witness $R_i$. Their ordered concatenation defines the candidate route

$ hat(pi) = R_0 plus.double R_1 plus.double dots plus.double R_(K-1). $

The certified coverage evidence establishes that $hat(pi)$ contains every required node exactly once: exactly under sorting, or except with the stated failure probability under product coverage. The segment proofs authenticate the internal arcs, while recombination authenticates the boundary arcs, all under the same root. These two sets partition the route arcs, so

$ "cost"(hat(pi)) = sum_(i=0)^(K-1) L_i + sum_(i=0)^(K-1) b_i <= T. $ <eq:recombined-cost>

The reconstructed route therefore witnesses relation @eq:relation for the authenticated instance.

The constructions that follow differ in where they place these summaries. Plaintext and committed constructions use external composition, exposing either the summaries or their commitment digests; recursion carries the summaries and segment proofs into an outer circuit. That placement determines structural disclosure at the public-interface boundary defined in @sub:adversarial-model and studied in @sub:trade-offs-rq. We begin with external composition, where the final verifier binds independent segment and recombination proofs.

#subsection([External Composition], label: <sub:external-composition>)

External composition realizes the binding requirement of @sub:recombination-contract with $K$ segment proofs and one independent recombination proof, which we call the _glue proof_. The glue establishes the global recombination checks over its own summary copies but never receives the segment proofs. The verifier completes the contract by binding these copies to the summaries authenticated by the segment proofs.

Segment proof $i$ exposes $(sigma_i^"seg", root)$, while the glue exposes the corresponding $sigma_i^"glue"$ values, the same root, and $T$. After checking all $K+1$ proofs under the authenticated keys and checking $root$ and $T$ against the intended instance, the verifier requires

$ sigma_i^"seg" = sigma_i^"glue", quad 0 <= i < K. $

Together with the common-root check, these equalities prevent a valid glue claim from being paired with segment proofs for different summaries or a different instance. They establish composition binding, after which the route-level implication follows from @sub:recombination-contract under the trust boundary of @sub:trust-assumptions. @fig:plain-external-composition shows this direct public-summary topology.

#[
  #set text(font: "Libertinus Sans", size: 10pt)
  #let external-public-color = rgb("#2b6f9f")
  #let external-private-color = rgb("#a34f32")
  #let external-schematic-box(
    body,
    fill: white,
    radius: 3pt,
    inset: (x: 6pt, y: 5pt),
  ) = box(
    width: 100%,
    height: 100%,
    stroke: 0.65pt,
    fill: fill,
    radius: radius,
    inset: inset,
    align(center + horizon, body),
  )
  #let external-schematic-title-box(
    title,
    body,
    inset: (x: 7pt, y: 7pt),
  ) = block(
    width: 100%,
    height: 100%,
    align(center + horizon, showybox(
      title: title,
      width: 100%,
      frame: (
        title-color: luma(246),
        body-color: white,
        border-color: black,
        inset: inset,
        radius: 3pt,
        thickness: 0.65pt,
      ),
      title-style: (
        color: black,
        weight: "regular",
        align: center,
        boxed-style: (
          anchor: (x: center, y: horizon),
          radius: 2pt,
        ),
      ),
      body-style: (align: center),
      shadow: none,
      body,
    )),
  )
  #let external-schematic-edge-label(
    body,
    color: black,
    size: 8.5pt,
    padding: (x: 6pt, y: 4pt),
  ) = box(
    fill: white,
    inset: padding,
    align(center, text(size: size, fill: color, body)),
  )
  #let external-schematic-legend = box(
    fill: white,
    inset: (x: 5pt, y: 3pt),
    align(left, [
      #set text(size: 8.25pt)
      #set par(leading: 0.45em)
      #box(width: 12pt, height: 0.9pt, fill: external-private-color)
      #h(2pt) private witness \
      #box(width: 12pt, height: 0.9pt, fill: external-public-color)
      #h(2pt) public input \
      #box(width: 12pt, height: 0.65pt, fill: black)
      #h(2pt) proof
    ]),
  )
  #figure(
    cetz.canvas(length: 1cm, {
      import cetz.draw: *

      content(
        (5.7, 11.4),
        (7.7, 12.05),
        external-schematic-box([*Prover*], fill: luma(246)),
        name: "external-prover",
      )
      content((6.7, 10.55), external-schematic-legend, name: "external-legend")

      content(
        (0.25, 7.55),
        (5.35, 10),
        external-schematic-title-box([#smallcaps[Segment circuits]], [
          #set text(size: 9.1pt)
          $K$ independent segment relations \
          certify local route data and $sigma_i^"seg"$ \
          for all #text(size: 8.35pt)[$0 <= i < K$]
        ]),
        name: "external-segments",
      )
      content(
        (8.05, 7.55),
        (13.15, 10),
        external-schematic-title-box([#smallcaps[Recombination circuit]], [
          #set text(size: 8.3pt)
          consumes $sigma_i^"glue"$, authenticates \
          boundary arcs, aggregates \
          costs and establishes global \
          coverage and threshold constraints
        ]),
        name: "external-glue",
      )

      // The prover supplies independent witnesses and distinct public copies
      // to the segment and glue circuits. There is no segment-to-glue path.
      line(
        (5.7, 11.82),
        (1.45, 11.82),
        (1.45, 10.15),
        stroke: 0.85pt + external-private-color,
        mark: (end: ">"),
      )
      content(
        (1.45, 11),
        external-schematic-edge-label(
          [segment witnesses],
          color: external-private-color,
        ),
      )
      line(
        (5.7, 11.6),
        (3.85, 11.6),
        (3.85, 10.15),
        stroke: 0.85pt + external-public-color,
        mark: (end: ">"),
      )
      content(
        (3.85, 11),
        external-schematic-edge-label(
          [$(sigma_i^"seg", root)$],
          color: external-public-color,
        ),
      )
      line(
        (7.7, 11.6),
        (9.55, 11.6),
        (9.55, 10.3),
        stroke: 0.85pt + external-public-color,
        mark: (end: ">"),
      )
      content(
        (9.55, 11),
        external-schematic-edge-label(
          [#v(3pt)$(sigma_i^"glue", root, T)$],
          color: external-public-color,
        ),
      )
      line(
        (7.7, 11.82),
        (11.95, 11.82),
        (11.95, 10.3),
        stroke: 0.85pt + external-private-color,
        mark: (end: ">"),
      )
      content(
        (12.85, 11),
        external-schematic-edge-label(
          [recombination \ witness],
          color: external-private-color,
          size: 7.8pt,
          padding: (x: 2pt, y: 2pt),
        ),
      )

      content(
        (3.4, 4.00),
        (10, 6.55),
        external-schematic-title-box([*Verifier*], [
          #set text(size: 8.3pt)
          verifies $K+1$ proofs, \
          checks $root$ and $T$ against the intended instance, \
          requires $sigma_i^"seg" = sigma_i^"glue"$ for every $0 <= i < K$
        ]),
        name: "external-verifier",
      )

      // Proofs and public inputs reach the verifier independently.
      line(
        (0.8, 7.55),
        (0.8, 5.05),
        (3.35, 5.05),
        stroke: 0.65pt,
        mark: (end: ">"),
      )
      content(
        (0.8, 5.05),
        external-schematic-edge-label([$K$ segment \ proofs], size: 8pt),
      )
      line(
        (3.85, 7.55),
        (3.85, 6.15),
        stroke: 0.85pt + external-public-color,
        mark: (end: ">"),
      )
      content(
        (3.85, 6.95),
        external-schematic-edge-label(
          [$(sigma_i^"seg", root)$],
          color: external-public-color,
        ),
      )
      line(
        (9.55, 7.4),
        (9.55, 6.15),
        stroke: 0.85pt + external-public-color,
        mark: (end: ">"),
      )
      content(
        (9.55, 6.875),
        external-schematic-edge-label(
          [#v(3pt)$(sigma_i^"glue", root, T)$],
          color: external-public-color,
        ),
      )
      line(
        (12.55, 7.4),
        (12.55, 5.05),
        (10.05, 5.05),
        stroke: 0.65pt,
        mark: (end: ">"),
      )
      content(
        (12.6, 5.05),
        external-schematic-edge-label([recombination \ proof], size: 8pt),
      )

      content(
        (0.25, 0.1),
        (13.15, 1.5),
        external-schematic-title-box(
          [#smallcaps[Logical segment summary]],
          [
            #set text(size: 8.5pt)
            #set par(leading: 0.55em)
            $sigma_i = ("cov"_i, "start"_i, "end"_i, L_i)$ \
            #text(size: 8pt)[The matrix root is common to all proofs; $T$ belongs to recombination.]
          ],
        ),
        name: "external-specializations",
      )
      content(
        (6.7, 2.6),
        align(center, [
          *Composition Binding Established* \
          #text(size: 8.5pt)[Recombination uses the exact values \
          certified by segment proofs.]
        ]),
        name: "external-consequence",
      )
      line(
        "external-verifier.south",
        (6.7, 3.45),
        stroke: 0.65pt,
        mark: (end: ">"),
      )
    }),
    caption: outline-caption(short: [External composition with public summaries.])[
      Direct external composition with public summaries. The verifier checks $K$ segment proofs and one independent recombination proof, checks their root and threshold against the intended instance, and binds the two copies of each segment summary.
    ],
  ) <fig:plain-external-composition>
]

#subsection([Stitching Tax], label: <sub:stitching-directions>)

The cut changes where the original relation is enforced, but relocated work is not composition overhead. The _stitching tax_ introduced in @sec:contributions is the net work added to recover one global claim from the segment proofs. @table:stitching-tax summarizes its main components.

#v(-10pt)
#figure(
  block(width: 100%, breakable: false)[
    #set text(size: 9.25pt)
    #set par(justify: false)
    #table(
      columns: (1fr, 2fr, 1.3fr),
      stroke: none,
      align: (left, left, left),
      inset: (x: 4pt, y: 4pt),
      row-gutter: 5pt,
      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Component]],
        text(font: "Libertinus Sans")[#smallcaps[Placement after decomposition]],
        text(font: "Libertinus Sans")[#smallcaps[Net effect]],
      ),
      table.hline(stroke: 0.6pt),
      [Arc authentication],
      [$n-K$ internal openings in the segments and $K$ boundary openings in recombination],
      [Conserved at $n$ openings],
      [Cost accumulation],
      [Segments form $L_i$; recombination adds every $L_i$ and $b_i$],
      [$bigoh()(K)$ partial-cost aggregation],
      [Coverage],
      [Local evidence followed by a global check whose form depends on the mechanism],
      [Representation-dependent],
      [Proof binding],
      [External equality checks or in-circuit recursive verification],
      [Introduced by the cut],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Components of the stitching tax.])[
    How decomposition redistributes the original relation and which operations add composition work.
  ],
) <table:stitching-tax>
#v(-10pt)

Arc authentication is conserved exactly. The segments open the $n-K$ internal arcs and recombination opens the $K$ boundary arcs, giving the same $n$ authenticated costs as the refined monolithic circuit. Every route cost is likewise included once. The additional arithmetic comes from combining the $K$ segment partial costs with the boundary costs, which adds $bigoh()(K)$ aggregation.

Coverage depends on its representation. With sorting, the recombination circuit retains the monolithic $n$-node sort, while the segment circuits add $K$ local $M$-node sorts to bind their private routes to public coverage evidence. A fixed-size fingerprint can remove the $n$-entry interface and change the global check, but producing the fingerprints and binding their challenge adds work elsewhere. This motivates the product construction developed later in the chapter.

Decomposition makes each segment proving unit smaller, while the complete architecture still proves the full relation and pays for every stage. Smaller segments may lower per-task memory and can be scheduled independently, but the end-to-end peak still includes the glue or outer stage. Chapter 6 measures whether the smaller proving units survive this recombination cost as a complete memory advantage.

With the contract, external topology, and cost accounting fixed, we first instantiate external recombination through two plaintext-summary constructions. Plain-sort retains exact sorting, while plain-product replaces the public node lists with fixed-size product fingerprints.

#section([Plain Constructions], label: <sec:plain-composite>)

These constructions use external composition with plaintext segment summaries. Each segment proof certifies its summary against a private route segment, an independent glue proof consumes a corresponding copy, and the verifier binds the two statements through the equalities of @sub:external-composition.

Both variants share the same route and cost structure. The segment proofs authenticate internal arcs under a common matrix root and bind their endpoints and partial costs. The glue uses those endpoints to authenticate the missing boundary arcs, combines all costs, and enforces the threshold. The variants differ in their coverage evidence: plain-sort publishes each segment's sorted node multiset, while plain-product replaces that list with a product fingerprint and the values needed to bind its challenge.

#subsection([Plain Sort], label: <sub:plain-sort>)

Plain-sort applies the exact sort mechanism of @sub:permutation-selection at both levels. For an ordered segment $R_i$, let $S_i = sort(R_i)$ be its sorted node multiset. The public segment summary is

$ sigma_i^"sort" = (S_i, "start"_i, "end"_i, L_i). $

The glue cannot access $R_i$, so each public field must carry one part of the local claim across the proof boundary. The segment circuit binds those fields to the same private route segment; @table:plain-sort-summary records how recombination uses them.

#figure(
  placement: top,
  block(width: 100%, breakable: false)[
    #set text(size: 9.25pt)
    #set par(justify: false)
    #table(
      columns: (1fr, 2fr, 2fr),
      stroke: none,
      align: (left, left, left),
      inset: (x: 4pt, y: 4pt),
      row-gutter: 5pt,
      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Public value]],
        text(font: "Libertinus Sans")[#smallcaps[Segment binding]],
        text(font: "Libertinus Sans")[#smallcaps[Recombination use]],
      ),
      table.hline(stroke: 0.6pt),
      [$S_i$],
      [$S_i = sort(R_i)$],
      [Exact global coverage],
      [Start and end],
      [First and last nodes of $R_i$],
      [Boundary-arc authentication],
      [$L_i$],
      [Authenticated sum of the $M-1$ internal costs],
      [Full-route threshold],
      [$root$],
      [Internal Merkle paths reach the common root],
      [Boundary paths use the same matrix instance],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Plain-sort summary fields and recombination roles.])[
    How each public value is bound to the private segment and used by recombination.
  ],
) <table:plain-sort-summary>

The segment circuit witnesses the $M$ nodes of $R_i$ in visit order, the $M-1$ internal costs, and their Merkle authentication paths. Its public statement contains $S_i$, the two endpoints, $L_i$, and the common root. #footnote[These are statement inputs, not return values: the circuit constrains their relation to the witness, it does not compute them on the prover's behalf.]

The circuit sorts $R_i$ and requires the result to equal $S_i$ position by position. The constrained sort follows @sub:permutation-selection: witness generation proposes the sorted array, while the circuit proves that it is ordered and is a permutation of $R_i$. The circuit also binds the published endpoints to $R_i [0]$ and $R_i [M-1]$, authenticates each internal arc, and requires $L_i$ to equal their sum. These checks make every summary field refer to the same private segment.

Before forming a Merkle index, the circuit also requires every node of $R_i$ to be smaller than $n$. Global coverage would eventually reject an out-of-range node, but the local guard protects the segment's own authenticated reads. Without it, the index $R_i [j] dot n + R_i [j+1]$ could enter the zero-padded region of the tree and open a zero-cost leaf. @fig:plain-segment collects these checks.

#[
    #set text(font: "Libertinus Sans", size: 12pt)
    #figure(
      placement: none,
      kind: "listing",
      supplement: "Listing",
      caption: outline-caption(short: [Plain-sort segment circuit.])[#set text(font: "Libertinus Serif"); One plain-sort segment: range check (a), exact multiset binding (b), endpoint binding (c), and authenticated internal costs accumulated into the partial cost (d). The authenticated read is @fig:merkle-open with global leaf index $u dot n + v$.],
      box(width: 0pt, height: 0pt)[]
    ) <fig:plain-segment>
    #v(-2em)
    #line(length: 100%, stroke: 1pt)
    #v(-0.7em)
    #pseudocode-list(hooks: 0.5em, booktabs: false)[
        + *circuit* #fn[plain-sort-segment]$(n, M, depth)$ #h(1fr)
          + *public* $sortednodes[rng(0, M-1)], med startnode, med endnode, med partialcost, med root$
          + *private* $routesegment[rng(0, M-1)], med edgecosts[rng(0, M-2)]$
          + *private* $siblings[rng(0, (M-1) dot depth - 1)]$
          + *private* $pathbits[rng(0, (M-1) dot depth - 1)]$
          - #hide("")
          - #lc[(a) range: each node is a valid index, guarding the leaf-index arithmetic]
          + *for* $i$ *in* #fn[range]$(0, M)$:
            + *require* $routesegment[i] < n$
          - #hide("")
          - #hide("")
          - #lc[(b) the published multiset is this segment's nodes]
          + $sorted arrow.l$ #fn[sort]$(routesegment)$
          + *for* $i$ *in* #fn[range]$(0, M)$:
            + *require* $sorted[i] = sortednodes[i]$
          - #hide("")
          - #lc[(c) endpoints are the segment's true first and last nodes]
          + *require* $startnode = routesegment[0]$
          + *require* $endnode = routesegment[M-1]$
          - #hide("")
          - #lc[(d) the $M-1$ internal arcs, authenticated against the committed root]
          + $total arrow.l 0$
          + *for* $i$ *in* #fn[range]$(0, M-1)$:
            + #fn[authenticated-read]\($routesegment[i], med routesegment[i+1], med edgecosts[i]$,
            - #h(7.9em)$n, i, med root, med depth$\)
            + $total arrow.l total + edgecosts[i]$
          - #hide("")
          + *require* $total = partialcost$
    ]
    #v(-0.7em)
    #line(length: 100%, stroke: 1pt)
    #v(1em, weak: true)
  ]

Binding $S_i$ to $R_i$ does not establish that the segment nodes are distinct, and one segment cannot detect a node repeated by another. Coverage therefore remains global. The glue receives $S_0 plus.double S_1 plus.double ... plus.double S_(K-1)$, sorts their $n$ entries, and requires the identity sequence $0, dots, n-1$. Any repetition leaves some required node absent, whether the duplicate occurs within one segment or across two proofs, so this single check establishes exact global coverage.

The glue also receives the $K$ starts, ends, and partial costs, together with $T$ and the common root. Its private witness contains the $K$ boundary costs and their Merkle authentication paths. For every $0 <= i < K$, it authenticates the arc from the end of segment $i$ to the start of segment $(i+1) pmod K$; the final index wraps to segment $0$ and closes the cycle. Each path must reach the common root at row-major leaf index $endnodes[i] dot n + startnodes[(i+1) pmod K]$.

Writing $b_i$ for the authenticated outgoing boundary cost of segment $i$, the glue enforces

$ sum_(i=0)^(K-1) L_i + sum_(i=0)^(K-1) b_i <= T. $ <eq:composite-threshold>

The glue cannot recompute the partial costs because it receives each segment's node multiset, not its visit order. Their validity comes from the segment proofs, while external composition binds the values used by the glue to those certified claims. @fig:plain-glue gives the resulting circuit.

#[
    #set text(font: "Libertinus Sans", size: 12pt)
    #figure(
      placement: none,
      kind: "listing",
      supplement: "Listing",
      caption: outline-caption(short: [Plain-sort recombination circuit.])[#set text(font: "Libertinus Serif"); The recombination circuit for plain-sort. It checks that the concatenated public node multisets cover $0, dots, n-1$, each exactly once (a), authenticates the $K$ boundary arcs $endnodes[i] -> startnodes[(i + 1) pmod K]$ against the committed root while accumulating their costs (b), and combines the boundary costs with the published segment partial costs for the final threshold check (c). The external equality checks that bind these public arrays to the corresponding segment proofs follow @sub:external-composition.],
      box(width: 0pt, height: 0pt)[]
    ) <fig:plain-glue>
    #v(-2em)
    #line(length: 100%, stroke: 1pt)
    #v(-0.7em)
    #pseudocode-list(hooks: 0.5em, booktabs: false)[
        + *circuit* #fn[plain-sort-glue]$(n, K, depth)$ #h(1fr)
          + *public* $allsortednodes[rng(0, n-1)], med startnodes[rng(0, K-1)], med endnodes[rng(0, K-1)]$
          + *public* $partialcosts[rng(0, K-1)], med T, med root$
          + *private* $boundarycosts[rng(0, K-1)]$
          + *private* $siblings[rng(0, K dot depth - 1)], med pathbits[rng(0, K dot depth - 1)]$
          - #hide("")
          - #lc[(a) coverage: the segment node multisets tile the global node set]
          + $sorted arrow.l$ #fn[sort]$(allsortednodes)$
          + *for* $i$ *in* #fn[range]$(0, n)$:
            + *require* $sorted[i] = i$
          - #hide("")
          - #lc[(b) connection: authenticate each missing boundary arc]
          + $total arrow.l 0$
          + *for* $i$ *in* #fn[range]$(0, K)$:
            + $u arrow.l endnodes[i]$
            + $v arrow.l startnodes[(i + 1) pmod K]$
            + #fn[authenticated-read]\($u, med v, med boundarycosts[i]$,
            - #h(7.9em)$n, i, med root, med depth$\)
            + $total arrow.l total + boundarycosts[i]$
          - #hide("")
          - #hide("")
          - #lc[(c) threshold: partial costs plus authenticated boundary costs]
          + *for* $i$ *in* #fn[range]$(0, K)$:
            + $total arrow.l total + partialcosts[i]$
          + *require* $total <= T$
    ]
    #v(-0.7em)
    #line(length: 100%, stroke: 1pt)
    #v(1em, weak: true)
  ]

#subsection([Product Coverage], label: <sub:plain-product-coverage>)

_Plain-product_ compresses this growing interface while keeping the external architecture of @fig:plain-external-composition fixed. It replaces each sorted list $S_i$ with one public field element $P_i$. At a common challenge point $X$, segment $i$ represents the multiset of its $M$ nodes by

$ P_i = product_(j=0)^(M - 1) (X + R_i [j]). $

If the $K$ segments together contain exactly the nodes $0, dots, n - 1$, their products satisfy

$ product_(i=0)^(K - 1) P_i = product_(j=0)^(n - 1) (X + j). $ <eq:target>

The equality replaces the global sort over $S_0 plus.double dots plus.double S_(K-1)$. Each segment proof gives $P_i$ its meaning by deriving it from the same private $R_i$ used for the segment's endpoints and internal costs. The verifier-side equalities then bind the certified $P_i$ to the corresponding value consumed by recombination. The left-hand side of @eq:target is therefore the product induced by the nodes the segments actually contain, with repetitions retained.

To state the coverage condition before sampling $X$, define the polynomials

$
F_"segments" (Z) &= product_(i=0)^(K-1) product_(j=0)^(M-1) (Z + R_i [j]), quad
F_"target" (Z) &= product_(j=0)^(n-1) (Z + j).
$

Factorization records each node with its multiplicity, so $F_"segments" = F_"target"$ exactly when the combined segment multiset contains every target node once. Otherwise, $F_"diff" #h(1pt)\(Z) = F_"segments" (Z) - F_"target" (Z)$ is nonzero. Both source polynomials are monic of degree $n$, so their leading terms cancel and we have $deg(F_"diff") <= n-1$. By the Schwartz--Zippel lemma of @sub:schwartz-zippel, if $X$ is unpredictable once the candidate multiset is fixed, then

$ "Pr"[F_"diff"(X) = 0] <= (n-1) / q, $

where $q$ is roughly $2^(254)$ in the field used here. One evaluation replaces the $M$-element node-list component of each public segment summary with one fingerprint; the route-binding values introduced next add a constant number of fields per segment. Recombination replaces the $n$-node sort with the $K$-factor left-hand product and the $n$-factor target product, but the guarantee is now probabilistic. If the prover can choose $X$ after fixing a false multiset, the few roots of $F_"diff"$ become values to search for rather than a negligible random event. Plain-product must therefore bind $X$ to the route without relying on an interactive verifier.

#subsection([Binding the Challenge to the Route], label: <sub:plain-product-challenge>)

An interactive verifier could enforce the required order by first receiving a binding commitment to the route and then sampling $X$. The polynomial would be fixed before its evaluation point is revealed. Plain-product has no later verifier message, so it derives the challenge through the non-interactive mechanism of @sub:fiat-shamir, directly from the route.

For the complete ordered route $pi = (pi_0, dots, pi_(n-1))$, define

$
h_j = cases(
  gap: #10pt,
  med 0 & quad "if" j = 0,
  med H(h_(j-1), pi_(j-1)) & quad "if" 1 <= j <= n
)
$

Here $H$ is the Poseidon2 hash @poseidon2. Let $h^"term"=h_n$ be the terminal value and derive the challenge as $X=H(h^"term")$. Changing the route order or its contents changes the route-bound challenge except through a hash collision. A route with repeated nodes still induces a valid chain, but recombination will detect it and reject the proof.

Every route node must enter the chain. If it stopped before a suffix of the route, the prover could learn $X$ and then choose that suffix against the known challenge. The initial value is likewise fixed at $h_0=0$. A prover-controlled start would create multiple terminal values, and therefore multiple challenge trials, for the same route, Merkle openings, and costs.

Because no segment circuit sees the complete route, the chain's iterative state must cross the segment boundaries. Segment $i$ publishes an incoming anchor $hin$ and an outgoing anchor $hout$, and proves that folding its private $R_i$ from $hin$ reaches $hout$. The glue collects these values into $hins$ and $houts$ and stitches the certified stretches by requiring

$
hins[0] &= 0, \
hins[i + 1] &= houts[i] quad (0 <= i < K - 1), \
houts[K - 1] &= h^"term".
$

These equations connect only the copies supplied to the glue. The external verifier must also equate each anchor and product with the corresponding value certified by its segment proof, and require all $K+1$ proofs to use the same $h^"term"$ and $X$. The glue checks $X=H(h^"term")$, while every segment binds its product and chain transition to the same private $R_i$. Together, these checks reconstruct one chain over all $n$ nodes and evaluate every segment product at the challenge derived from that route.

#subsection([Plain Product], label: <sub:plain-product>)

Plain-product realizes the preceding product and challenge mechanisms within the external architecture already used by plain-sort. It retains the segment range, endpoint, internal-arc authentication, and partial-cost checks, together with the glue's boundary and threshold checks. The published sorted list and the local and global constrained sorts disappear. From the same private segment $R_i$, the segment circuit instead certifies a product fingerprint and one stretch of the route hash chain.

For segment $i$, the public statement is

$ ("start"_i, "end"_i, L_i, root, P_i, h_i^"in", h_i^"out", h^"term", X). $

The endpoints, partial cost, and root retain their roles from @sub:plain-sort. The product carries the new coverage fingerprint, the chain anchors bind its challenge to the route, and $h^"term"$ and $X$ are common route-wide values. The private inputs remain $R_i$, its $M-1$ internal costs, and their Merkle authentication paths.

The range, endpoint, authenticated-read, and partial-cost constraints therefore follow @fig:plain-segment. Starting from $h_i^"in"$, the circuit folds every node of $R_i$ through the hash chain and requires the result to equal $h_i^"out"$. Over the same $R_i$, it multiplies the factors $X+R_i [j]$ and binds the result to $P_i$. The circuit also checks $X=H(h^"term")$. This check is redundant once the glue derivation and verifier-side equalities hold, but keeps each segment statement internally consistent. Because all these constraints use the same private array, the product, chain transition, endpoints, and internal costs cannot describe different segment orders. Distinctness remains global: a repeated node contributes a repeated factor to $P_i$ and is handled by @eq:target under the product-coverage guarantee established above. @fig:plain-product-segment records the interface and the constraints introduced by plain-product.

#block(breakable: true)[
    #set text(font: "Libertinus Sans", size: 12pt)
    #figure(
      placement: none,
      kind: "listing",
      supplement: "Listing",
      caption: outline-caption(short: [Plain-product segment circuit.])[#set text(font: "Libertinus Serif"); Plain-product segment interface. Range, endpoint, authenticated-cost, and partial-cost checks follow @fig:plain-segment(a), (c), and (d); its sort binding (b) is omitted. The listing shows the hash-chain (a), product (b), and challenge (c) constraints.],
      box(width: 0pt, height: 0pt)[]
    ) <fig:plain-product-segment>
    #v(-2em)
    #line(length: 100%, stroke: 1pt)
    #v(-0.7em)
    #pseudocode-list(hooks: 0.5em, booktabs: false)[
        + *circuit* #fn[plain-product-segment]$(n, M, depth)$ #h(1fr)
          + *public* $startnode, med endnode, med partialcost, med root$
          + *public* $productvalue, med hin, med hout, med terminal, med X$
          + *private* $routesegment[rng(0, M-1)], med edgecosts[rng(0, M-2)]$
          + *private* $siblings[rng(0, (M-1) dot depth - 1)]$
          + *private* $pathbits[rng(0, (M-1) dot depth - 1)]$
          - #hide("")
          - #lc[inherited: apply @fig:plain-segment(a), (c), and (d) to the inputs above]
          - #lc[the sorted-list binding in @fig:plain-segment(b) is omitted]
          - #hide("")
          - #lc[(a) the segment links the route hash chain]
          + $h arrow.l hin$
          + *for* $j$ *in* #fn[range]$(0, M)$:
            + $h arrow.l$ #fn[H]$(h, routesegment[j])$
          + *require* $h = hout$
          - #hide("")
          - #lc[(b) the published segment product matches the private nodes]
          + $prod arrow.l 1$
          + *for* $j$ *in* #fn[range]$(0, M)$:
            + $prod arrow.l prod dot (X + routesegment[j])$
          + *require* $prod = productvalue$
          - #hide("")
          - #lc[(c) the challenge is bound to the full-chain terminal]
          + *require* $X =$ #fn[H]$(terminal)$
    ]
    #v(-0.7em)
    #line(length: 100%, stroke: 1pt)
    #v(1em, weak: true)
  ]


The segment proof now certifies the product and chain anchors that replace $S_i$ in the shared summary. It cannot join the $K$ chain stretches or test coverage over the complete route, so these checks remain with recombination.

For every segment $i$, the recombination circuit receives the public summary $("start"_i, "end"_i, L_i, P_i, h_i^"in", h_i^"out")$, together with the common root, threshold $T$, terminal $h^"term"$, and challenge $X$. Its private witness remains the $K$ boundary costs and their Merkle authentication paths.

The circuit first stitches the anchors into one chain beginning at $0$ and ending at $h^"term"$, then checks $X=H(h^"term")$. At that challenge, it multiplies the $K$ segment products and compares them with the target product over the sequence $0, dots, n-1$. It then authenticates the $K$ boundary arcs under the common root, adds their costs to the segment partial costs, and enforces $T$. Chain stitching, challenge derivation, and the product equality replace the global sort; boundary authentication and the threshold check retain the recombination logic of @fig:plain-glue. @fig:plain-product-glue records the interface and the replacement constraints.

#[
    #set text(font: "Libertinus Sans", size: 12pt)
    #figure(
      placement: none,
      kind: "listing",
      supplement: "Listing",
      caption: outline-caption(short: [Plain-product recombination circuit.])[#set text(font: "Libertinus Serif"); Plain-product recombination interface. Chain stitching (a), challenge derivation (b), and product coverage (c) replace the global sort. Boundary authentication and the threshold check follow @fig:plain-glue(b) and (c).],
      box(width: 0pt, height: 0pt)[]
    ) <fig:plain-product-glue>
    #v(-2em)
    #line(length: 100%, stroke: 1pt)
    #v(-0.7em)
    #pseudocode-list(hooks: 0.5em, booktabs: false)[
        + *circuit* #fn[plain-product-glue]$(n, K, depth)$ #h(1fr)
          + *public* $startnodes[rng(0, K-1)], med endnodes[rng(0, K-1)], med products[rng(0, K-1)]$
          + *public* $partialcosts[rng(0, K-1)], med T, med root$
          + *public* $hins[rng(0, K-1)], med houts[rng(0, K-1)], med terminal, med X$
          + *private* $boundarycosts[rng(0, K-1)]$
          + *private* $siblings[rng(0, K dot depth - 1)]$
          + *private* $pathbits[rng(0, K dot depth - 1)]$
          - #hide("")
          - #lc[(a) chain stitching: the supplied anchors form one chain]
          + *require* $hins[0] = 0$
          + *for* $i$ *in* #fn[range]$(0, K-1)$:
            + *require* $hins[i+1] = houts[i]$
          + *require* $houts[K-1] = terminal$
          - #hide("")
          - #lc[(b) challenge derivation check]
          + *require* $X =$ #fn[H]$(terminal)$
          - #hide("")
          - #lc[(c) coverage test: compare the segment and target products]
          + $lhs arrow.l 1$
          + *for* $i$ *in* #fn[range]$(0, K)$:
            + $lhs arrow.l lhs dot products[i]$
          + $rhs arrow.l 1$
          + *for* $j$ *in* #fn[range]$(0, n)$:
            + $rhs arrow.l rhs dot (X + j)$
          + *require* $lhs = rhs$
          - #hide("")
          - #lc[inherited: apply @fig:plain-glue(b) and (c) to the inputs above]
    ]
    #v(-0.7em)
    #line(length: 100%, stroke: 1pt)
    #v(1em, weak: true)
]

The glue proves these conditions over its public summary copies, so the verifier completes the external binding contract of @sub:external-composition. The verifier does not recompute the chain or product equality. The glue establishes those facts, while the external equalities ensure that it uses the segment-certified values. With these bindings, the accepted package of $K$ segment proofs and one glue proof establishes the existence of $K$ valid segments whose summaries satisfy the chain, coverage, connection, and threshold checks of the recombination contract.

#subsection([Plain Construction Trade-offs], label: <sub:plain-tradeoffs>)

Both plain constructions use the same external topology: $K$ segment proofs, one glue proof, and verifier-side equalities that bind their public summary copies. For either variant under a sequential schedule,

$ "peak-mem"#h(1pt)_"external" = max("peak-mem"#h(1pt)_"segment"#h(1pt), #h(5pt) "peak-mem"#h(1pt)_"glue"). $

The segments remain independently schedulable, but neither a lower end-to-end peak nor a wall-clock speedup follows before the glue stage is included. The two variants differ in the coverage-specific interface and the work used to check it. Their endpoints, partial costs, root, threshold, boundary checks, and proof topology are common and omitted from @table:plain-tradeoffs.

#v(-10pt)
#figure(
  block(width: 100%, breakable: false)[
    #set text(size: 8.9pt)
    #set par(justify: false)
    #table(
      columns: (1.05fr, 1.45fr, 1.7fr),
      stroke: none,
      align: (left, left, left),
      inset: (x: 4pt, y: 4pt),
      row-gutter: 4pt,
      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Dimension]],
        text(font: "Libertinus Sans")[#smallcaps[Plain-sort]],
        text(font: "Libertinus Sans")[#smallcaps[Plain-product]],
      ),
      table.hline(stroke: 0.6pt),
      [Coverage evidence],
      [$S_i = sort(R_i)$],
      [$P_i$, $h_i^"in"$, and $h_i^"out"$, with common $(h^"term",X)$],
      [Coverage-specific public surface],
      [$n$ node identifiers],
      [$K$ products, $2K$ anchors, and $(h^"term",X)$],
      [Coverage work],
      [$K$ local $M$-node sorts and one global $n$-node sort],
      [Segment products and $n$ chain hashes; the glue forms the $K$-factor and $n$-factor products],
      [Coverage guarantee],
      [Exact multiset equality],
      [Failure at most $Q(n-1)\/q$ under the route-bound random-oracle model],
      [Additional disclosure],
      [Exact membership of each segment],
      [Tests for candidate segment multisets and orders],
      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Trade-offs between the plain constructions.])[
    Coverage-specific differences between plain-sort and plain-product. Shared route and cost fields, boundary checks, and proof topology are omitted.
  ],
) <table:plain-tradeoffs>
#v(-10pt)

The two public interfaces share substantial disclosure, but in different forms. Public endpoints reveal the segment boundaries, while each $L_i$ reveals one segment's internal cost. Since $C$ is public, the endpoints also determine every boundary cost. The verifier can therefore recover

$ sum_(i=0)^(K-1) L_i + sum_(i=0)^(K-1) C_("end"_i, "start"_((i+1) mod K)) $

even though relation @eq:relation asks only whether this cost is at most $T$. Zero-knowledge hides the values that remain in the witnesses; it does not conceal these statement fields.

Plain-sort additionally reveals the exact node multiset $S_i$ of every segment. Once its two endpoints are fixed, at most $(M-2)!$ internal orders remain, and the public matrix and partial cost can reject candidates with the wrong cost. Plain-product replaces this explicit membership with two confirmation surfaces. Given public $X$, anyone can evaluate $product_j (X+a_j)$ for a candidate multiset and compare it with $P_i$. The anchors similarly test a candidate order by folding it from $h_i^"in"$ and comparing the result with $h_i^"out"$. Plain-product therefore avoids enumerating segment membership while still allowing plausible guesses to be checked.

Every recombination input and the matrix $C$ are public in both variants, so the verifier could perform the glue relation directly. It could run the selected coverage check, recover the boundary costs, aggregate the full cost, and enforce $T$. The glue proof delegates this public computation succinctly. Removing it would move those checks to the verifier rather than eliminate them.

The monolithic circuit applies coverage, arc authentication, and the threshold to one route witness and exposes only $(root,T)$. No cross-proof consistency condition is needed. Under backend knowledge soundness, an accepted composite package instead yields $K$ valid segment witnesses and a valid glue witness. The authenticated keys, common instance, and external equalities bind the glue's summary copies to the values certified by those segments. Their ordered concatenation then witnesses relation @eq:relation by the argument of @sub:recombination-contract.

#section([Committed Constructions], label: <sec:committed-composite>)

The committed constructions retain the recombination contract and $K+1$ proofs. Segment $i$ derives a summary $V_i$ but publishes only its commitment digest $D_i$. The glue receives the opening as private witness, checks the digest, and applies the same coverage, connection, and threshold constraints as before.

The _committed-sort_ construction applies this layer to the exact sort-based construction; _committed-product_ applies it to the hash-chain and grand-product construction. Their coverage mechanisms are inherited from @sec:plain-composite; only the treatment of their segment summaries at the public interface changes.

#subsection([Commitment Layer], label: <sub:commitment-layer>)

The Merkle root in @sec:committed-matrix binds the public matrix $C$ while replacing its $n^2$ entries with one public value. A segment commitment instead protects a private recombination summary. As distinguished in @sub:commitment-schemes, it must provide _binding_, so the segment and glue cannot use different summaries, and _hiding_, so its public value does not reproduce the disclosure it removes.

For a value sequence $V = (v_0, dots, v_(ell-1))$ and a blinding value $r$, define its fold through the two-input Poseidon2 hash as

$
  d_j = cases(
    gap: #10pt,
    med r & quad "if" j = 0,
    med H(d_(j-1), v_(j-1)) & quad "if" 1 <= j <= ell
  ) med med med .
$ <eq:segment-commitment>

The final value $d_ell$ is the commitment to $V$, written $"Commit"_r (V)$. For segment $i$, $V_i$ denotes the summary, $r_i$ its secret blinding value, $(V_i,r_i)$ its opening, and $D_i = "Commit"_(r_i) (V_i)$ its public digest. Each circuit fixes the length and order of $V_i$, giving the opening one interpretation. Treating Poseidon2 as a random oracle in the sense of @sub:hash-functions, a fresh unknown $r_i$ makes $D_i$ computationally hiding because testing a summary guess also requires guessing the blinding. Collision resistance provides binding: two distinct openings for the same digest would induce a collision in $H$.

The host-side builder samples $128$ fresh random bits from the operating system for each $r_i$ and embeds them in the field. The implementation uses the same two-input Poseidon2 compression for Merkle nodes, route-chain links, and commitment folds without prepending the domain tags described in @sub:hash-functions. Fixed circuit interfaces remove ambiguity within each construction, but explicit domain separation remains an unimplemented deployment hardening measure.

The segment circuit constrains $(V_i,r_i)$ to $D_i^"seg"$, the glue constrains $(tilde(V)_i,tilde(r)_i)$ to $D_i^"glue"$, and the verifier equates the two public digest copies after verifying the $K+1$ proofs. The verifier also applies the shared-root and instance checks of @sub:external-composition. @fig:commitment-layer shows which parts of this binding flow are private, public, and external to the circuits.

#[
  #set text(font: "Libertinus Sans", size: 10pt)
  #let diagram-box(body, fill: white, radius: 3pt) = box(
    width: 100%,
    height: 100%,
    stroke: 0.65pt,
    fill: fill,
    radius: radius,
    inset: (x: 6pt, y: 5pt),
    align(center + horizon, body),
  )
  #let public-color = rgb("#2b6f9f")
  #let private-color = rgb("#a34f32")
  #let edge-label(body, color: black, padding: (x: 6.5pt, y: 4.5pt)) = box(
    fill: white,
    inset: padding,
    align(center, text(size: 9pt, fill: color, body)),
  )
  #let titled-box(title, body) = block(
    width: 100%,
    height: 100%,
    align(center + horizon, showybox(
      title: title,
      width: 100%,
      frame: (
        title-color: luma(246),
        body-color: white,
        border-color: black,
        inset: (x: 7pt, y: 7pt),
        radius: 3pt,
        thickness: 0.65pt,
      ),
      title-style: (
        color: black,
        weight: "regular",
        align: center,
        boxed-style: (
          anchor: (x: center, y: horizon),
          radius: 2pt,
        ),
      ),
      body-style: (align: center),
      shadow: none,
      body,
    )),
  )
  #figure(
    placement: none,
    cetz.canvas(length: 1cm, {
      import cetz.draw: *

      content(
        (0.35, 7.35),
        (5.15, 9.55),
        titled-box([#smallcaps[Segment circuits]], [
          #set text(size: 9.25pt)
          $D_i^"seg" = "Commit"_(r_i)(V_i)$ \
          #text(size: 8.5pt)[$0 <= i < K$]
        ]),
        name: "segments",
      )

      content(
        (8.25, 7.35),
        (13.05, 9.55),
        titled-box([#smallcaps[Glue circuit]], [
          #set text(size: 9.25pt)
          $D_i^"glue" = "Commit"_(tilde(r)_i)(tilde(V)_i)$ \
          #text(size: 8.5pt)[$0 <= i < K$]
        ]),
        name: "glue",
      )

      content(
        (5.7, 10.35),
        (7.7, 11.0),
        diagram-box(
          [*Prover*],
          fill: luma(246),
          radius: 3pt,
        ),
        name: "prover",
      )
      content(
        (6.7, 9.7),
        box(
          fill: white,
          inset: (x: 5pt, y: 3pt),
          align(left, [
            #set text(size: 8.25pt)
            #set par(leading: 0.45em)
            #box(width: 12pt, height: 0.9pt, fill: private-color)
            #h(2pt) private witness \
            #box(width: 12pt, height: 0.9pt, fill: public-color)
            #h(2pt) public input \
            #box(width: 12pt, height: 0.65pt, fill: black)
            #h(2pt) proof
          ]),
        ),
        name: "input-legend",
      )

      // Private openings and public digests enter each proof on distinct,
      // orthogonal paths. The public paths continue below the circuit boxes.
      line(
        (5.7, 10.78),
        (1.45, 10.78),
        (1.45, 9.55),
        stroke: 0.85pt + private-color,
        mark: (end: ">"),
      )
      content((1.45, 9.95), edge-label([$(V_i, r_i)$], color: private-color))
      line(
        (5.7, 10.57),
        (3.75, 10.57),
        (3.75, 9.55),
        stroke: 0.85pt + public-color,
        mark: (end: ">"),
      )
      content((3.75, 9.85), edge-label([$D_i^"seg"$], color: public-color))
      line(
        (7.7, 10.57),
        (9.65, 10.57),
        (9.65, 9.55),
        stroke: 0.85pt + public-color,
        mark: (end: ">"),
      )
      content(
        (9.65, 9.85),
        edge-label(
          [$D_i^"glue"$],
          color: public-color,
          padding: (x: 6.5pt, y: 6pt),
        ),
      )
      line(
        (7.7, 10.78),
        (11.95, 10.78),
        (11.95, 9.55),
        stroke: 0.85pt + private-color,
        mark: (end: ">"),
      )
      content((11.95, 9.95), edge-label([$(tilde(V)_i, tilde(r)_i)$], color: private-color))

      content(
        (5.2, 5.15),
        (8.2, 6.25),
        diagram-box(
          [
            #set par(leading: 0.25em)
            *Verifier* \ #v(-3pt)
            #text(size: 8.5pt)[verifies $K+1$ proofs]
          ],
          fill: luma(246),
          radius: 3pt,
        ),
        name: "verifier",
      )

      // Circuit outputs meet the verifier through right-angled routes.
      // Public digests retain the same horizontal position through each box.
      line(
        (0.9, 7.35),
        (0.9, 5.45),
        (5.2, 5.45),
        stroke: 0.65pt,
        mark: (end: ">"),
      )
      content((3.05, 5.45), edge-label([$K$ segment proofs]))
      line(
        (3.75, 7.35),
        (3.75, 5.95),
        (5.2, 5.95),
        stroke: 0.85pt + public-color,
        mark: (end: ">"),
      )
      content((3.75, 6.62), edge-label([$D_i^"seg"$], color: public-color))
      line(
        (9.65, 7.35),
        (9.65, 5.95),
        (8.2, 5.95),
        stroke: 0.85pt + public-color,
        mark: (end: ">"),
      )
      content(
        (9.65, 6.62),
        edge-label(
          [$D_i^"glue"$],
          color: public-color,
          padding: (x: 6.5pt, y: 6pt),
        ),
      )
      line(
        (12.5, 7.35),
        (12.5, 5.45),
        (8.2, 5.45),
        stroke: 0.65pt,
        mark: (end: ">"),
      )
      content((10.30, 5.45), edge-label([glue proof]))

      content(
        (3.6, 2.95),
        (9.8, 4.6),
        titled-box([#smallcaps[External digest equality]], [
          $D_i^"seg" = D_i^"glue" quad "for every" 0 <= i < K$
        ]),
        name: "checks",
      )
      line("verifier.south", (6.7, 4.6), stroke: 0.65pt, mark: (end: ">"))

      content(
        (6.7, 1.5),
        align(center, [
          *Binding established* \
          $V_i = tilde(V)_i$ for every $0 <= i < K$ \
          #text(size: 10pt)[The segment and glue proofs use the same summary.]
        ]),
        name: "binding",
      )
      line((6.7, 2.95), (6.7, 2.4), stroke: 0.65pt, mark: (end: ">"))
    }),
    caption: outline-caption(short: [External composition with committed summaries.])[
      Committed specialization of @fig:plain-external-composition. Each circuit binds a private opening to its public digest copy, and the verifier requires the two copies to match.
    ],
  ) <fig:commitment-layer>
]

The binding flow is identical across variants; only $V_i$ changes. @table:committed-variant-flow lists the two sequences and their fixed lengths.

#[
  #set text(size: 10.75pt)
  #figure(
    placement: none,
    table(
      columns: (1.6fr, 4fr, 0.85fr),
      stroke: none,
      align: (left, left, center),
      inset: (x: 7pt, y: 8pt),
      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans")[#smallcaps[Variant]],
        text(font: "Libertinus Sans")[#smallcaps[Committed sequence]],
        text(font: "Libertinus Sans")[#smallcaps[Length]],
      ),
      table.hline(stroke: 0.6pt),
      [_sort_],
      [$V_i = (R_i [0], dots, R_i [M-1], L_i)$],
      [$M+1$],
      [_product_],
      [$V_i = (P_i, h_i^"in", h_i^"out", "start"_i, "end"_i, L_i)$],
      [$6$],
      table.hline(stroke: 1pt),
    ),
    caption: outline-caption(short: [Committed summaries by construction.])[
      Committed sequence for each variant.
    ],
  ) <table:committed-variant-flow>
]

Committed-sort can use the hidden visit order to establish coverage and derive the endpoints. Committed-product carries only the six derived values consumed by its existing recombination checks.

#place.flush()

#subsection([Committed Sort], label: <sub:committed-sort>)

Committed-sort replaces the public plain-sort summary with a commitment to the segment in visit order and its internal partial cost:

$ D_i = "Commit"_(r_i)(R_i [0], dots, R_i [M-1], L_i). $ <eq:committed-sort-summary>

Plain-sort published $S_i=sort(R_i)$ because exposing $R_i$ would also expose the internal traversal. That representation required every segment circuit to sort its private route and publish its endpoints separately, since sorting removed their positional meaning. Here the opening remains private. Both circuits can therefore use the same visit-ordered $R_i$: the segment binds it to $D_i$, while the glue sorts it for global coverage and reads its first and last positions for the boundary arcs. The $K$ local sorts and separate endpoint fields disappear; the one global $n$-node sort remains.

The segment circuit exposes only $(root,D_i)$. Its witness contains $R_i$, the internal costs and their Merkle paths, and $r_i$. It retains the range and internal-arc checks of plain-sort, derives $L_i$, and constrains @eq:committed-sort-summary. @fig:committed-sort-segment shows the resulting interface and the new commitment block.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: none,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Committed-sort segment circuit.])[#set text(font: "Libertinus Serif"); Committed-sort segment interface. Range and authenticated internal-cost checks follow @fig:plain-segment(a) and (d); the listing shows the commitment to the visit-ordered nodes and their derived partial cost.],
    box(width: 0pt, height: 0pt)[]
  ) <fig:committed-sort-segment>
  #v(-2em)
  #line(length: 100%, stroke: 1pt)
  #v(-0.7em)
  #pseudocode-list(hooks: 0.5em, booktabs: false)[
    + *circuit* #fn[committed-sort-segment]$(n, M, depth)$ #h(1fr)
      + *public* $root, med commitment$
      + *private* $routesegment[rng(0, M-1)], med edgecosts[rng(0, M-2)]$
      + *private* $siblings, med pathbits, med blind$
      - #hide("")
      - #lc[inherited: range-check the segment as in @fig:plain-segment(a)]
      - #lc[inherited: authenticated internal arc costs and derive $partialcost$ as in @fig:plain-segment(d)]

      - #hide("")
      - #lc[bind the ordered nodes and partial cost to the public digest]
      + $values arrow.l routesegment plus.double [partialcost]$
      + *require* $commitment =$ #fn[commit]$(blind, values)$
  ]
  #v(-0.7em)
  #line(length: 100%, stroke: 1pt)
  #v(1.5em, weak: true)
]

The glue exposes $(root,T,D_0,dots,D_(K-1))$ and receives all $K$ openings privately. After checking them, it concatenates the ordered segments and sorts their $n$ nodes to establish exact coverage. Their fixed positions identify each boundary arc, so the glue authenticates those $K$ costs, combines them with the opened partial costs, and enforces $T$. @fig:committed-sort-glue specifies this complete flow.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: none,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Committed-sort glue circuit.])[#set text(font: "Libertinus Serif"); Committed-sort glue circuit: private openings (a), exact coverage (b), positional boundary authentication (c), and threshold enforcement (d).],
    box(width: 0pt, height: 0pt)[]
  ) <fig:committed-sort-glue>
  #v(-2em)
  #line(length: 100%, stroke: 1pt)
  #v(-0.7em)
  #pseudocode-list(hooks: 0.5em, booktabs: false)[
    + *circuit* #fn[committed-sort-glue]$(n, K, M, depth)$ #h(1fr)
      + *public* $root, med T, med commitments[rng(0, K-1)]$
      + *private* $allnodes[rng(0, n-1)], med partialcosts[rng(0, K-1)]$,
      + *private* $blinds[rng(0, K-1)]$
      + *private* $boundarycosts[rng(0, K-1)], med siblings, med pathbits$
      - #hide("")
      - #lc[(a) privately open every public commitment]
      + *for* $i$ *in* #fn[range]$(0, K)$:
        + $values arrow.l allnodes[rng(i dot M, (i+1) dot M - 1)] plus.double$
        - #h(8.3em)$[partialcosts[i]]$
        + *require* $commitments[i] =$ #fn[commit]$(blinds[i], values)$
      - #hide("")
      - #lc[(b) establish exact global coverage]
      + $sorted arrow.l$ #fn[sort]$(allnodes)$
      + *for* $j$ *in* #fn[range]$(0, n)$:
        + *require* $sorted[j] = j$
      - #hide("")
      - #hide("")
      - #lc[(c) derive positional endpoints and authenticate every boundary arc]
      + $total arrow.l 0$
      + *for* $i$ *in* #fn[range]$(0, K)$:
        + $u arrow.l allnodes[i dot M + M - 1]$
        + $v arrow.l allnodes[((i+1) pmod K) dot M]$
        + #fn[authenticated-read]$(u, v, boundarycosts[i], n, i, root, depth)$
        + $total arrow.l total + boundarycosts[i] + partialcosts[i]$
      - #hide("")
      - #lc[(d) enforce the public threshold]
      + *require* $total <= T$
  ]
  #v(-0.7em)
  #line(length: 100%, stroke: 1pt)
  #v(1.5em, weak: true)
]

#subsection([Committed Product], label: <sub:committed-product>)

Committed-product retains plain-product's fixed-size recombination summary and hides its six segment-specific values behind one digest:

$ D_i = "Commit"_(r_i)(P_i, h_i^"in", h_i^"out", "start"_i, "end"_i, L_i). $ <eq:committed-product-summary>

The fixed order in @eq:committed-product-summary is part of the circuit interface. From the same private $R_i$, the segment derives $P_i$ and the chain anchors, takes the endpoints from the first and last positions, and computes $L_i$ from the authenticated internal arcs. The glue consumes these six consequences rather than the route nodes themselves. Binding them to $D_i$ therefore gives the glue the segment-certified coverage, chain, boundary, and cost summary through an opening whose length is independent of $M$.

The segment exposes $(root,X,D_i)$. Its incoming chain anchor and blinding join the route, internal costs, and Merkle paths in the witness; the terminal $h^"term"$ is no longer a segment input. The circuit retains the local checks of plain-product, derives the six values from one $R_i$, and folds them into $D_i$. @fig:committed-product-segment keeps the complete interface and the constraints that form the committed summary.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: none,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Committed-product segment circuit.])[#set text(font: "Libertinus Serif"); Committed-product segment interface. Local checks follow @fig:plain-segment(a) and (d); the shown blocks derive and commit the six-value summary.],
    box(width: 0pt, height: 0pt)[]
  ) <fig:committed-product-segment>
  #v(-2em)
  #line(length: 100%, stroke: 1pt)
  #v(-0.7em)
  #pseudocode-list(hooks: 0.5em, booktabs: false)[
    + *circuit* #fn[committed-product-segment]$(n, M, depth)$ #h(1fr)
      + *public* $root, med X, med commitment$
      + *private* $routesegment[rng(0, M-1)], med edgecosts[rng(0, M-2)]$,
      + *private* $siblings, med pathbits$
      + *private* $hin, med blind$
      - #hide("")
      - #lc[inherited: range-check the segment as in @fig:plain-segment(a)]
      - #lc[inherited: authenticate its internal arcs and derive $partialcost$ as in @fig:plain-segment(d)]
      - #hide("")
      - #lc[(a) derive the route-chain transition and segment product]
      + $h arrow.l hin$
      + $productvalue arrow.l 1$
      + *for* $j$ *in* #fn[range]$(0, M)$:
        + $h arrow.l$ #fn[H]$(h, routesegment[j])$
        + $productvalue arrow.l productvalue dot (X + routesegment[j])$
      - #hide("")
      - #lc[(b) bind all six derived summary values to the public digest]
      + $values arrow.l [productvalue, hin, h,$
      - #h(8.3em)$routesegment[0], routesegment[M-1], partialcost]$
      + *require* $commitment =$ #fn[commit]$(blind, values)$
  ]
  #v(-0.7em)
  #line(length: 100%, stroke: 1pt)
  #v(1em, weak: true)
]

The glue exposes $(root,T,X,D_0,dots,D_(K-1))$ and receives the six-value openings, blindings, and terminal $h^"term"$ as witness. It checks every digest, stitches the private anchors from $0$ to $h^"term"$, requires $X=H(h^"term")$, and recombines the private products for global coverage. The opened endpoints and partial costs then feed the same boundary and threshold checks as plain-product. @fig:committed-product-glue specifies the new opening, chain, and coverage logic.

#[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: none,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Committed-product glue circuit.])[#set text(font: "Libertinus Serif"); Committed-product glue interface. The listing shows private openings (a), chain and challenge binding (b), and product coverage (c); boundary authentication and threshold enforcement follow @fig:plain-glue(b) and (c) over the opened endpoints and partial costs.],
    box(width: 0pt, height: 0pt)[]
  ) <fig:committed-product-glue>
  #v(-2em)
  #line(length: 100%, stroke: 1pt)
  #v(-0.7em)
  #pseudocode-list(hooks: 0.5em, booktabs: false)[
    + *circuit* #fn[committed-product-glue]$(n, K, depth)$ #h(1fr)
      + *public* $root, med T, med X, med commitments[rng(0, K-1)]$
      + *private* $products[rng(0, K-1)], med hins[rng(0, K-1)]$,
      + *private* $houts[rng(0, K-1)]$
      + *private* $startnodes[rng(0, K-1)], med endnodes[rng(0, K-1)], med partialcosts[rng(0, K-1)]$
      + *private* $blinds[rng(0, K-1)], med terminal$
      + *private* $boundarycosts, med siblings, med pathbits$
      - #hide("")
      - #lc[(a) privately open every public commitment]
      + *for* $i$ *in* #fn[range]$(0, K)$:
        + $values arrow.l [products[i], hins[i], houts[i],$
        - #h(8.3em)$startnodes[i], endnodes[i], partialcosts[i]]$
        + *require* $commitments[i] =$ #fn[commit]$(blinds[i], values)$
      - #hide("")
      - #hide("")
      - #lc[(b) stitch the route chain and bind its terminal to the public challenge]
      + *require* $hins[0] = 0$
      + *for* $i$ *in* #fn[range]$(0, K-1)$:
        + *require* $hins[i+1] = houts[i]$
      + *require* $houts[K-1] = terminal$
      + *require* $X =$ #fn[H]$(terminal)$
      - #hide("")
      - #lc[(c) recombine the segment products and test global coverage]
      + $lhs arrow.l 1$
      + *for* $i$ *in* #fn[range]$(0, K)$:
        + $lhs arrow.l lhs dot products[i]$
      + $rhs arrow.l 1$
      + *for* $j$ *in* #fn[range]$(0, n)$:
        + $rhs arrow.l rhs dot (X + j)$
      + *require* $lhs = rhs$
      - #hide("")
      - #lc[inherited: apply @fig:plain-glue(b) and (c) to the opened endpoints and partial costs]
  ]
  #v(-0.7em)
  #line(length: 100%, stroke: 1pt)
  #v(1em, weak: true)
]

#subsection([Committed Construction Trade-offs], label: <sub:committed-disclosure>)

Both committed variants retain the external topology of @sub:external-composition: $K$ segment proofs, one glue proof, and verifier-side equalities that bind their shared public inputs. Relative to the plain constructions, digest equalities replace plaintext-summary equalities. This interface change can be summarized as

$ "public summary" arrow.r.long ("private opening", "public digest") med . $

The segment derives a summary and folds it into $D_i$; the glue receives the same summary and blinding as witness, repeats the fold, and applies the inherited coverage, boundary, and threshold checks. Commitment binding makes the digest equalities meaningful, as established in @sub:commitment-layer.

Committed-sort folds $M+1$ values in each segment and repeats every fold in the glue. Since $K dot  M=n$, this gives $2K(M+1)=2(n+K)$ fold steps. It removes the $K$ local sorts used by plain-sort, but retains the global sort over $n$ nodes and node-dependent commitment work. Committed-product folds six values per segment and repeats those folds in the glue, for $2K dot 6=12K$ steps. Its commitment work is therefore fixed per segment, while the chain, product, and target-product checks remain.

The digests move node membership, products, chain anchors, endpoints, and partial costs from the public interface into the glue witness. Zero-knowledge hides those witnesses, while computational hiding prevents testing a guessed summary against a digest without knowing its blinding. Because the endpoints and partial costs are no longer public, the public matrix $C$ no longer suffices to recover the boundary costs or the exact route cost.

Both variants reveal $K$ through the $K$ digests and the $K+1$ proof topology. Committed-product also publishes the route-derived challenge $X$, which allows a guessed complete ordered route to be tested by recomputing its chain. Committed-sort has no corresponding unblinded route-derived value. The monolithic construction exposes only $(root,T)$; committed-sort adds the topology and digests, while committed-product additionally exposes $X$. Commitments therefore improve structural privacy over the plain constructions without reproducing the monolithic public surface.

Soundness follows the same recombination contract as before. The external digest equalities and commitment binding force the glue to use the summaries certified by the segments. The argument of @sub:recombination-contract then yields one route witness satisfying coverage, arc authentication, and the threshold.

#section([Recursive Construction], label: <sec:recursive-composite>)

The recursive construction replaces external composition with an _outer_ relation. The outer circuit receives the $K$ segment proofs and their public inputs as private witness, verifies each proof, and applies the recombination contract of @sub:recombination-contract to the certified inputs. It produces one outer proof with public statement $(root,T)$, which is the only proof checked by the final verifier.

The proofs authenticate the $n-K$ internal arcs, while the outer circuit restores global coverage, authenticates the $K$ boundary arcs, aggregates all costs, and enforces $T$. The construction therefore requires both a segment relation whose public-input vector the outer circuit can certify and consume, and an outer relation that performs recombination over those certified inputs.

#subsection([Inner Circuit Selection], label: <sub:recursive-inner-selection>)

Each segment proof now serves as an inner proof. Its public-input vector must be supplied to the in-circuit verifier and constrained within the outer circuit, once for every segment. Since recursion already invokes $K$ proof verifiers, the selected interface should avoid an additional term that grows with the segment length $M$.

The commitment layer of @sub:commitment-layer hides summaries that remain public under external composition. Here each inner proof and its nominally public inputs become private witness to the outer proof, whose zero-knowledge guarantee hides them from the final verifier. A committed inner relation would still require the outer circuit to receive the opening and check its digest before recombination. That alternative trades fewer inner public inputs for commitment-opening constraints and is not evaluated here; this construction selects between the direct plain-sort and plain-product relations.

A plain-sort proof carries $M$ sorted node identifiers, two endpoints, one partial cost, and one root. Plain-product instead carries the fixed nine-field public-input vector specified in @sub:plain-product:

$ x_i^"inner" = ("start"_i, "end"_i, L_i, root_i, P_i, h_i^"in", h_i^"out", h_i^"term", X_i). $ <eq:recursive-inner-interface>

Across all $K$ segments, the corresponding interface widths are

$ "plain-sort:" quad K(M+4)=n+4K, quad "plain-product:" quad 9K. $

The selection concerns dependence on $M$. Plain-sort contributes an $n$-entry node-list term, whereas plain-product keeps this part of the outer workload proportional to $K$. We therefore select the plain-product segment of @fig:plain-product-segment as the inner relation. The outer circuit remains nonconstant: it must still invoke $K$ proof verifiers and perform global recombination, including the target product involving $n$ factors.

This choice carries plain-product's route-bound coverage guarantee into recursion. Its failure probability remains at most $Q(n-1)\/q$ under @sub:plain-product-challenge and is negligible for feasible $Q$ at the field and instance sizes considered here. Recursion therefore does not recover the exact coverage guarantee of sorting.

With the inner relation fixed, @fig:recursive-composition shows how its proofs flow through recursive composition.

#[
  #set text(font: "Libertinus Sans", size: 10pt)
  #let recursive-public-color = rgb("#2b6f9f")
  #let recursive-private-color = rgb("#a34f32")
  #let recursive-schematic-box(
    body,
    fill: white,
    radius: 3pt,
    inset: (x: 6pt, y: 5pt),
  ) = box(
    width: 100%,
    height: 100%,
    stroke: 0.65pt,
    fill: fill,
    radius: radius,
    inset: inset,
    align(center + horizon, body),
  )
  #let recursive-schematic-title-box(
    title,
    body,
    inset: (x: 7pt, y: 7pt),
  ) = block(
    width: 100%,
    height: 100%,
    align(center + horizon, showybox(
      title: title,
      width: 100%,
      frame: (
        title-color: luma(246),
        body-color: white,
        border-color: black,
        inset: inset,
        radius: 3pt,
        thickness: 0.65pt,
      ),
      title-style: (
        color: black,
        weight: "regular",
        align: center,
        boxed-style: (
          anchor: (x: center, y: horizon),
          radius: 2pt,
        ),
      ),
      body-style: (align: center),
      shadow: none,
      body,
    )),
  )
  #let recursive-schematic-edge-label(
    body,
    color: black,
    size: 8.5pt,
    padding: (x: 6pt, y: 4pt),
  ) = box(
    fill: white,
    inset: padding,
    align(center, text(size: size, fill: color, body)),
  )
  #let recursive-schematic-legend = box(
    fill: white,
    inset: (x: 5pt, y: 3pt),
    align(left, [
      #set text(size: 8.25pt)
      #set par(leading: 0.45em)
      #box(width: 12pt, height: 0.9pt, fill: recursive-private-color)
      #h(2pt) private witness \
      #box(width: 12pt, height: 0.9pt, fill: recursive-public-color)
      #h(2pt) public input \
      #box(width: 12pt, height: 0.65pt, fill: black)
      #h(2pt) proof
    ]),
  )
  #figure(
    cetz.canvas(length: 1cm, {
      import cetz.draw: *

      content(
        (10.0, 10.95),
        recursive-schematic-legend,
        name: "recursive-legend",
      )
      content(
        (5.7, 11.4),
        (7.3, 12.05),
        recursive-schematic-box([*Prover*], fill: luma(246)),
        name: "recursive-prover",
      )

      content(
        (2.1, 9.0),
        (10.9, 10.45),
        recursive-schematic-title-box([#smallcaps[Segment circuits]], [
          #set text(size: 9pt)
          $K$ plain-product circuits produce $K$ inner proofs \
          with nine-field public-input vectors $x_i^"inner"$, $0 <= i < K$
        ]),
        name: "recursive-segments",
      )

      content(
        (3.45, 11.98),
        recursive-schematic-edge-label(
          [segment witnesses],
          color: recursive-private-color,
        ),
      )
      line(
        "recursive-prover.west",
        (1.25, 11.72),
        (1.25, 9.7),
        (2.1, 9.7),
        stroke: 0.85pt + recursive-private-color,
        mark: (end: ">"),
      )

      content(
        (1.4, 3.9),
        (11.6, 6.85),
        recursive-schematic-box([]),
        name: "recursive-outer",
      )
      content(
        (5.1, 6.58),
        (7.9, 7.18),
        recursive-schematic-box(
          text(size: 9pt)[#smallcaps[Outer circuit]],
          fill: luma(246),
        ),
      )
      content(
        (1.8, 4.3),
        (6.1, 5.9),
        align(center + horizon, block(
          width: 100%,
          height: 100%,
          stroke: 0.65pt,
          fill: luma(250),
          radius: 3pt,
          inset: (x: 5pt, y: 4pt),
        )[
          #set text(size: 8.25pt)
          #set par(leading: 0.4em)
          *1. Verify* \
          $K$ proofs under fixed $"vk"_"segment"$ \
          $arrow$ certified inputs $x_i^"inner"$
        ]),
        name: "recursive-verify",
      )
      content(
        (6.9, 4.3),
        (11.2, 5.9),
        align(center + horizon, block(
          width: 100%,
          height: 100%,
          stroke: 0.65pt,
          radius: 3pt,
          inset: (x: 5pt, y: 4pt),
        )[
          #set text(size: 8.25pt)
          #set par(leading: 0.4em)
          *2. Recombine* \
          coverage and chain \
          boundary costs and total $<= T$
        ]),
        name: "recursive-recombine",
      )
      line(
        "recursive-verify.east",
        "recursive-recombine.west",
        stroke: 0.65pt,
        mark: (end: ">"),
      )

      // Public instance bus. The same root and threshold enter the outer
      // relation and the final verification without crossing the inner-proof
      // interface.
      content(
        (11.5, 8.2),
        recursive-schematic-edge-label(
          [$(root,T)$],
          color: recursive-public-color,
        ),
      )
      line(
        "recursive-prover.east",
        (12.35, 11.72),
        (12.35, 1.9),
        stroke: 0.85pt + recursive-public-color,
      )
      line(
        (12.35, 5.1),
        (11.6, 5.1),
        stroke: 0.85pt + recursive-public-color,
        mark: (end: ">"),
      )
      line(
        (12.35, 1.9),
        (10.2, 1.9),
        stroke: 0.85pt + recursive-public-color,
        mark: (end: ">"),
      )

      // Inner proofs and their nominally public inputs become private witness
      // at the outer-proof boundary.
      line(
        (6.5, 8.75),
        (6.5, 7.18),
        stroke: 0.85pt + recursive-private-color,
        mark: (end: ">"),
      )
      content(
        (6.5, 8.1),
        recursive-schematic-edge-label(
          [#set par(leading: 0.4em); $K$ inner proofs + $x_i^"inner"$ \
          *private outer witness*],
          color: recursive-private-color,
          size: 7.75pt,
          padding: (x: 5pt, y: 4pt),
        ),
      )

      content(
        (2.8, 1.15),
        (10.2, 2.65),
        recursive-schematic-title-box([*Verifier*], [
          #set text(size: 9pt)
          one proof check under $"vk"_"outer"$
        ]),
        name: "recursive-verifier",
      )
      line(
        (6.5, 3.9),
        (6.5, 2.65),
        stroke: 0.65pt,
        mark: (end: ">"),
      )
      content(
        (6.5, 3.28),
        recursive-schematic-edge-label([Single Outer Proof], size: 8.5pt),
      )
    }),
    caption: outline-caption(short: [Recursive composition with certified inputs.])[
      Recursive composition of the segment proofs. Each inner proof exposes a nine-field public-input vector $x_i^"inner"$ at the inner-proof boundary; the proof and its vector together become private witness to the outer circuit. The outer circuit verifies the proofs under the fixed segment key, recombines their certified inputs, and emits a single outer proof with public interface $(root,T)$.
    ],
  ) <fig:recursive-composition>
]

#subsection([Outer Circuit], label: <sub:recursive-outer>)

The outer circuit exposes only the matrix root and threshold $(root,T)$. Its witness contains the $K$ segment proofs, their nine-field public-input vectors $x_i^"inner"$ from @eq:recursive-inner-interface, bounded representations of the endpoints and partial costs, and the $K$ boundary costs with their Merkle paths. Acceptance means that the proofs certify segments that recombine into a route whose costs are authenticated against $root$ and whose total is at most $T$.

Each witnessed $x_i^"inner"$ is initially only a claimed input to an inner proof. The outer circuit therefore verifies the corresponding proof against $x_i^"inner"$ under the fixed segment key for shape $(n,M,depth)$. A successful check certifies the vector's endpoints, partial cost, root, product, chain anchors, terminal, and challenge under the intended plain-product segment relation. Without this check, the prover could choose values that satisfy recombination but arise from no valid segment.

The certified endpoints and partial costs are field elements, whereas Merkle indices and bounded cost arithmetic require bounded integers. The witness therefore supplies bounded mirrors, and the circuit constrains each mirror to equal its proof-certified field element. These equalities prevent the prover from using one value for inner-proof verification and another for the bounded Merkle and cost operations.

Recombination then uses only these certified inputs. Following the plain-product glue of @fig:plain-product-glue, the circuit requires every segment root to equal $root$ and all terminals and challenges to agree. It stitches the chain anchors from $0$ to the common terminal $h^"term"$, checks $X = H(h^"term")$, and multiplies the certified segment products to establish coverage of $0, dots, n-1$. Finally, it authenticates the $K$ boundary costs using the certified endpoints, adds them to the certified partial costs, and enforces the threshold $T$.

In @fig:recursive-outer, #fn[verify-proof] abstracts the backend's in-circuit verification gadget; its key arguments are compile-time constants authenticated as described in @sub:recursive-verification.

#block(breakable: true)[
  #set text(font: "Libertinus Sans", size: 12pt)
  #figure(
    placement: none,
    kind: "listing",
    supplement: "Listing",
    caption: outline-caption(short: [Recursive outer circuit.])[#set text(font: "Libertinus Serif"); The recursive outer circuit. Each inner proof is checked against its witnessed public-input vector under the fixed segment key (a). Tuple equalities bind the proof-certified endpoints and partial cost to bounded mirrors and require common $root$, $h^"term"$, and $X$ (b). The inherited plain-product recombination constraints then consume only certified inputs (c). Only the root and threshold are public.],
    box(width: 0pt, height: 0pt)[]
  ) <fig:recursive-outer>
  #v(-2em)
  #line(length: 100%, stroke: 1pt)
  #v(-0.7em)
  #pseudocode-list(hooks: 0.5em, booktabs: false)[
    + *circuit* #fn[recursive-outer]$(n, K, depth)$ #h(1fr)
      + *constant* $"vk"_"segment", med "vkhash"_"segment"$
      + *public* $root, med T$
      + *private* $proofs[rng(0, K-1)], med innerinputs[rng(0, K-1)]$
      + *private* $startnodes[rng(0, K-1)], med endnodes[rng(0, K-1)]$
      + *private* $partialcosts[rng(0, K-1)]$
      + *private* $boundarycosts[rng(0, K-1)]$
      + *private* $siblings[rng(0, K dot depth - 1)], med pathbits[rng(0, K dot depth - 1)]$
      - #hide("")
      - #lc[(a) certify and unpack each inner public-input vector]
      + *for* $i$ *in* #fn[range]$(0, K)$:
        + #fn[verify-proof]$("vk"_"segment", "vkhash"_"segment", proofs[i], innerinputs[i])$
        + $(startfields[i], endfields[i], partialcostfields[i]) arrow.l innerinputs[i][rng(0, 2)]$
        + $(roots[i], products[i]) arrow.l innerinputs[i][rng(3, 4)]$
        + $(hins[i], houts[i]) arrow.l innerinputs[i][rng(5, 6)]$
        + $(terminals[i], challenges[i]) arrow.l innerinputs[i][rng(7, 8)]$
      - #hide("")
      - #lc[(b) bind the certified fields to the outer relation]
      + *for* $i$ *in* #fn[range]$(0, K)$:
        + *require* $(startnodes[i], endnodes[i], partialcosts[i])$
        - #h(7.2em)$= (startfields[i], endfields[i], partialcostfields[i])$
        + *require* $(roots[i], terminals[i], challenges[i])$
        - #h(7.2em)$= (root, terminals[0], challenges[0])$
      - #hide("")
      - #lc[(c) recombine only the certified values]
      - #lc[inherited: apply @fig:plain-product-glue(a)--(c) to the products and chain values]
      - #lc[inherited: apply @fig:plain-glue(b)--(c) to the bounded values and boundary witness under $root$ and $T$]
  ]
  #v(-0.7em)
  #line(length: 100%, stroke: 1pt)
  #v(1em, weak: true)
]

#subsection([Proof Verification], label: <sub:recursive-verification>)

The final verifier receives one outer proof and the public inputs $(root,T)$. The root must derive from the agreed matrix and $T$ must equal the intended threshold. Two keys govern this verification at different levels: the outer circuit uses the embedded _segment key_ $"vk"_"segment"$ to verify the witnessed inner proofs, while the final verifier uses the _outer key_ $"vk"_"outer"$ to verify the proof it receives.

In the external constructions, the final verifier selects the segment and glue keys and checks those proofs directly. Recursion delegates segment verification to the outer circuit, so the final verifier no longer selects the segment key directly. The key and its expected hash must therefore be compile-time constants rather than prover inputs, and the outer key must authenticate that fixed choice.

For fixed $(n,K,depth)$, the canonical plain-product segment circuit is compiled first. Its verification key and expected hash are embedded when the outer circuit is compiled, producing the canonical outer key. The final verifier obtains that key through the authenticated mechanism of @sub:trust-assumptions and rejects any key supplied unauthenticated with the proof. A different embedded segment key produces a different outer key, so the resulting proof does not verify under the canonical one.

#subsection([Recursive Construction Trade-offs], label: <sub:recursive-disclosure>)

Recursion folds the $K$ segment-proof checks and the recombination relation into one outer proof. The external constructions instead expose $K$ segment proofs and one glue proof, leaving the verifier to check all $K+1$ proofs and reconcile their public copies. The recursive inner proofs and $x_i^"inner"$ become private outer witness. Refined monolithic sort has the same final proof count, but proves a whole-route witness directly rather than verifying inner proofs and recombining their claims. The recursive prover must first generate the $K$ inner proofs and then prove the dependent outer circuit.

The endpoints, partial costs, products, chain anchors, $h^"term"$, and $X$ remain witness values of the outer proof, leaving the final public interface $(root,T)$ as in refined monolithic sort. Unlike the externally recombined variants, this interface contains no per-segment summaries, digests, or route-derived challenge. The outer proof's zero-knowledge guarantee protects those values under the public-interface boundary of @sub:adversarial-model, so a separate segment-commitment layer is unnecessary.

This protection concerns the final verifier. The outer prover necessarily holds the inner proofs and their nominally public inputs because they form its witness. The segment count $K$ also remains visible through the selected outer circuit and key. It identifies the circuit parameterization but reveals no segment boundaries, node membership or order, summaries, or costs.

The segment proofs retain the independent generation established in @sub:route-decomposition, but the outer proof cannot begin until all of them exist. Each segment circuit contains $M=n\/K$ route nodes rather than $n$. Under the sequential single-worker schedule used for comparison with the external constructions, complete recursive peak memory is

$ "peak-mem"_"recursive" = max("peak-mem"_"segment", "peak-mem"_"outer"). $

The outer stage therefore adds a dependent memory and proving-time floor: it executes $K$ in-circuit proof verifiers together with the recombination relation.

Under backend knowledge soundness and the authenticated outer key, an accepted outer proof yields inner proofs that verify under the intended plain-product segment key. Soundness of those proofs yields valid segment witnesses and their certified inputs. Because the outer relation verifies and consumes the same $x_i^"inner"$, the recombination contract of @sub:recombination-contract binds those segments into one route claim. The external constructions obtain the corresponding binding through verifier-side equality checks over plaintext or digest copies; recursion needs neither those external equalities nor segment-commitment binding.

Refined monolithic sort and recursion both authenticate all $n$ selected arcs under $root$ and enforce the complete threshold. Their coverage guarantees differ. Monolithic sort establishes exact coverage algebraically, whereas recursion inherits plain-product's route-bound product check, its random-oracle assumption, and the failure bound $Q(n-1)\/q$ from @sub:plain-product-challenge. Recursion additionally depends on the authenticated inner-to-outer key chain and correct in-circuit proof verification. Both constructions retain the backend knowledge-soundness and Merkle-authentication assumptions.

#section([The Architectural Frontier], label: <sec:architectural-frontier>)

Decomposition replaces one whole-route proving unit with $K$ segment units and a recombination stage. Recombination must restore global coverage, authenticate the $K$ boundary arcs, aggregate all costs and enforce $T$, and bind the independently certified segment values into one statement. The five constructions satisfy this common contract but differ in their coverage evidence, binding topology, and composition disclosure. @fig:architectural-frontier organizes those choices.

Two coverage mechanisms divide the rows. Sorting restores exact coverage; route-bound product fingerprints replace the growing node-list interface with the computational guarantee of @sub:plain-product-challenge. Commitments change what external composition reveals without changing its $K+1$-proof topology. Recursion changes both the topology and the final public surface: it hides per-segment values behind one outer proof while moving $K$ proof verifications and recombination into a dependent outer proving stage.

#figure(
  block(width: 100%, breakable: false)[
    #set text(hyphenate: false)
    #set par(justify: false)
    #table(
      columns: (0.9fr, 1.3fr, 1.3fr, 1.4fr),
      stroke: none,
      align: (left, left, left, left),
      inset: (x: 4pt, y: 6pt),
      table.hline(stroke: 1pt),
      table.header(
        text(font: "Libertinus Sans", size: 9.5pt)[#smallcaps[Construction]],
        text(font: "Libertinus Sans", size: 9.5pt)[#smallcaps[Coverage restoration]],
        text(font: "Libertinus Sans", size: 9.5pt)[#smallcaps[Binding and topology]],
        text(font: "Libertinus Sans", size: 9.5pt)[#smallcaps[Composition disclosure]],
      ),
      table.hline(stroke: 0.6pt),
      text(size: 9.5pt)[_plain sort_],
      text(size: 9.5pt)[Exact global sort],
      text(size: 9.5pt)[Public equalities; \ $K+1$ proofs],
      text(size: 9.5pt)[Node sets, endpoints, and partial costs],

      text(size: 9.5pt)[_plain product_],
      text(size: 9.5pt)[Grand product at $X$],
      text(size: 9.5pt)[Public equalities; \ $K+1$ proofs],
      text(size: 9.5pt)[Endpoints, costs, and testable summaries],

      text(size: 9.5pt)[_committed sort_],
      text(size: 9.5pt)[Exact global sort],
      text(size: 9.5pt)[Digest equalities; \ $K+1$ proofs],
      text(size: 9.5pt)[$K$ blinded digests],

      text(size: 9.5pt)[_committed product_],
      text(size: 9.5pt)[Grand product at $X$],
      text(size: 9.5pt)[Digest equalities; \ $K+1$ proofs],
      text(size: 9.5pt)[$K$ digests and public $X$],

      text(size: 9.5pt)[_recursive_],
      text(size: 9.5pt)[Grand product at $X$],
      text(size: 9.5pt)[In-circuit verification; one final proof],
      text(size: 9.5pt)[No per-segment values; \ $K$ remains architectural metadata],

      table.hline(stroke: 1pt),
    )
  ],
  caption: outline-caption(short: [Architectural frontier of composite constructions.])[
    Architectural frontier of the five composite constructions. All authenticate the $K$ boundary arcs, aggregate the complete cost, and enforce $T$; the common public instance $(root,T)$ is omitted from the disclosure column.
  ],
) <fig:architectural-frontier>

The five constructions now have defined coverage guarantees, recombination topologies, and disclosure profiles. Chapter 6 tests whether their smaller segment proving units retain an advantage after the stitching tax, interpreting the measured costs against those disclosure differences.
