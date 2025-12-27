// slides
#import "@preview/shadowed:0.2.0": *
#import "@preview/grape-suite:3.1.0": slides
#import slides: *

// fancy codly stuff
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()
#codly(languages: codly-languages)

// tick boxes
#import "@preview/cheq:0.3.0": checklist
#show: checklist

// customization
#show heading: it => {
  pagebreak()
  it
}

#show figure.caption: set text(20pt)
#show figure: set align(center + horizon)
#show raw: set text(15pt)

#show: slides.with(
  title: [*Botnet in a Bottle* | Toward A Consolidated Botnet Analysis Pipeline],
  author: "Zohar Cochavi",
  show-date: false,
  show-semester: false,
  no: 15,
)


= Research Question

#align(
  left + horizon,
  quote(block: true)[_
  "How can we infer IoT botnet DDoS attack targets, DDoS attack methods, infection
  targets, and infection methods from sandboxed network traffic alone while
  restricting allowed communications to the C2 server?"_],
)

== Subquestions

- [x] _RQ1_: How can we allow just C2 network traffic while capturing and
  sinkholing non-C2 traffic to avoid collateral damage?
- [ ] _RQ2_: What traffic features (flow metadata, timing/periodicity, header
  semantics, inter-flow correlations) best distinguish common IoT DDoS attack
  types?
- [ ] _RQ3_: How accurate is DDoS attack target and DDoS attack kind extraction?
- [?] _RQ4_: What features distinguish spreading behavior from DDoS attacking behavior?

= Previously On...

First-stage review! Went pretty well, but:

- [ ] Clear need to investigate malware analysis risks
- [ ] Optimizing VMs to use less resources
- [ ] Migrate to shared ClickHouse database
- [ ] Store PCAPs in ClickHouse

And from now on:
- [ ] Keep writing

= This Week's Progress

First-stage review! Went pretty well, but:

- [x] Clear need to investigate malware analysis risks
- [ ] Optimize VMs to use less resources
- [x] Migrate to shared ClickHouse database
- [ ] Store PCAPs in ClickHouse

And from now on:
- [x] Keep writing

= Threat Analysis

Long story short:

- QEMU doesn't give security guarantees
- We should minimize impact first, then harden sandbox

With that,

- No access to intranet, save _rhodos_ on port _9000_.
- Separate ClickHouse credentials with minimal insert-only permissions
- SSH access through separate VPN with minimal ACL permissions
- Active monitoring with an EDR

== May be Overkill

#grid(
  columns: 2,
  column-gutter: 5cm,
  [
    Did a bit of reporting on this, so let me know if you'd like to read it!
  ],
  shadowed(radius: 4pt, inset: 12pt, image("/assets/image-10.png", height: 80%)),
)

== But not Complete

There are some things which might be interesting to add:

- We don't cover the NFTables configuration
- Possible impact on Proxmox (effectively the same, just another layer)
- Routing configuration on Proxmox
- Routing of traffic beyond Proxmox (e.g. Thunderlab setup)

I'll probably include this in the thesis as a separate chapter?

= Continuing Experiments

A couple of considerations:

- We can continue this way, and increase scale later
- But first, we should implement the recommendations
- Ensure the necessary information is centralized (bottle ledger?)

Profit?

- I also need to do something with n8n, but I'm not sure where to put it...

= BotConf

The deadline is in two weeks:

- A short talk is okay?
- Should I include results in the proposal? (if so what?)

I think it would be super cool to participate!

= Next On...

Ensure we can run the experiments:

- [ ] Implement recommendations
- [ ] Ensure PCAP data is stored in ClickHouse

Maybe:

- [ ] Write ledger events to ClickHouse?

As for writing:

- [ ] I'll start on _How Botnets Work_


= Cool Stuff

This is pretty interesting:

- https://polygonben.github.io/malware%20analysis/Compromising-Threat-Actor-Communications/#case-study
- https://www.virustotal.com/gui/file/9ef489493d3fffa0d8e43b6a189d471430ba0fdc33def06d0e43d809413d5837/detection
