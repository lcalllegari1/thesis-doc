#import "../theme/colors.typ": colors

#let thesis-title = "Architectural Trade-offs in Zero-Knowledge Proof Decomposition"
#let thesis-author = "Leonardo Callegari"

#let title-page() = {
  // Local page settings leave the thesis's binding margins and marginals intact.
  page(
    paper: "a4",
    margin: 25mm,
    numbering: none,
    header: none,
    footer: none,
    background: image("../assets/background_image.jpg"),
  )[
    #set text(font: "Libertinus Serif", size: 14pt, fill: black)
    #set par(justify: false, first-line-indent: 0pt, leading: 0.65em)

    #align(center)[
      #grid(
        columns: (1fr, 1fr),
        column-gutter: 12mm,
        align: center + horizon,
        image("assets/university-logo.pdf", width: 65mm),
        // Original image extracted without alteration from the department's PDF:
        // https://www.math.unipd.it/files/20240731-integrativa-ingegneria-bando.pdf
        image("assets/department-logo.png", width: 65mm),
      )
      #v(7mm)
      #text(font: "Libertinus Sans", size: 18pt)[
        *University of Padua* \
        Department of Mathematics
      ]
    ]

    #v(10mm)
    #align(center)[
      #set par(leading: 0.45em)
      #line(length: 100%, stroke: 2pt + colors.primary)
      #v(5mm)
      #text(font: "Libertinus Sans", size: 24pt, fill: colors.primary, weight: 600)[
        Architectural Trade-offs in \
        Zero-Knowledge Proof
        Decomposition
      ]
      #v(4mm)
      #text(size: 20pt)[A Traveling-Salesman Case Study]
      #v(5mm)
      #line(length: 100%, stroke: 2pt + colors.primary)
      #v(6mm)
      #text(font: "Libertinus Sans", size: 18pt)[Master's Degree in Cybersecurity]
    ]

    #v(3em)
    #let role(body) = text(font: "Libertinus Sans", size: 16pt, fill: colors.primary, body)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 12mm,
      align: (left, right),
      [
        #role[Candidate] 
        #v(5pt)
        *#thesis-author* 
        #v(20pt)
        #role[Student ID]
        #v(5pt)
        *2159085*
      ],
      [
        #set text(size: 14pt)
        #role[Supervisor]
        #v(2mm)
        *Prof. Mauro Conti* \
        #text(size: 12pt)[University of Padua]
        #v(7mm)
        #role[External Supervisor]
        #v(2mm)
        *Prof. Martin Ochoa* \
        #text(size: 12pt)[zkSecurity]
      ],
    )

    #v(3em)
    #align(center)[_Graduation Date_\ September 25, 2026]
  ]

  // A blank verso preserves the physical parity of every existing thesis page.
  page(numbering: none, header: none, footer: none)[#box()]
}
