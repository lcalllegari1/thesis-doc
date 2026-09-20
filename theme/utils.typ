#let outline-caption-marker = "thesis:short-outline-caption"

// Keep the full caption in the document body while exposing an optional short
// title to the custom lists of figures, tables, and listings.
#let outline-caption(short: none, body) = {
  metadata((role: outline-caption-marker, short: short))
  body
}

#let inline(code) = text(
  font: "Libertinus Sans",
  fill: gray.darken(100%),
  code
)

#let ccal(ch) = text(font: "cmsy10", ch)
#let bigoh() = ccal("O")
#let lc(body) = text(fill: gray.darken(40%))[#body]   // gray comments / group headers
#let fn(name) = [#emph(name)#h(1pt)]

#let pid(name) = smallcaps(text(font: "Libertinus Sans", name))

#let cycle = pid("cycle")
#let route = pid("route")
#let sorted = pid("sorted")
#let invperm = pid("inv-perm")
#let idx = pid("idx")
#let matrix = pid("matrix")
#let visited = pid("visited")
#let total = pid("total")
#let lhs = pid("lhs")
#let rhs = pid("rhs")
#let actual = pid("actual")
#let expected = pid("expected")
#let depth = pid("depth")
#let edgecosts = pid("arc_costs")
#let siblings = pid("siblings")
#let pathbits = pid("path_bits")
#let leafidx = pid("leaf_idx")
#let node = pid("hash_acc")
#let root = pid("root")

#let pos = "pos"
#let sort = "sort"

// Index range for array declarations: $matrix[rng(0, N^2 - 1)]$
// renders as matrix[0 .. N²−1] with consistent spacing.
#let rng(a, b) = $#a med .. med #b$

// The mod operator with text-operator spacing: $(i+1) pmod N$.
#let pmod = math.op("mod")
