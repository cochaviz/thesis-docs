
// slides
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
  title: [Toward A Consolidated Botnet Analysis Pipeline | First Stage Review],
  author: "Zohar Cochavi",
  show-date: false,
  show-semester: false,
  no: 13,
)


= Introduction

Currently,

- A great deal of intelligence can be gathered from understanding and intercepting C2 communications of botnets.

- This is often done by reverse-engineering the malware to extract its network behavior.

But this is slow, leading to:

- Potentially missing out on new botnets due to the quick turnover.

- Scalability issues.

== Research Question

#align(
  left + horizon,
  quote(block: true)[_
  "How can we infer IoT botnet DDoS attack targets, DDoS attack methods, infection
  targets, and infection methods from sandboxed network traffic alone while
  restricting allowed communications to the C2 server?"_],
)


== Subquestions

- [ ] _RQ1_: How can we allow just C2 network traffic while capturing and
  sinkholing non-C2 traffic to avoid collateral damage?
- [ ] _RQ2_: What traffic features (flow metadata, timing/periodicity, header
  semantics, inter-flow correlations) best distinguish common IoT DDoS attack
  types?
- [ ] _RQ3_: How accurate is DDoS attack target and DDoS attack kind extraction?
- [ ] _RQ4_: What features distinguish spreading behavior from DDoS attacking behavior?


= Solution Design

Must have:

- Network activity monitoring.
- Limited manual intervention.
- Traffic filtering to isolate C2 communications.
- Run different architectures (e.g., ARM, MIPS).

Should have:

- Automated C2 identification.
- Attack PCAP logging.

== Architecture

With that, we found the following components suitable:

- QEMU to sandbox malware samples.
- NFTables to filter (and rate limit) traffic.
- Suricata/custom monitoring to log traffic features.

= Current Progress

This idea has been fleshed out into a modular pipeline, with the following
components implemented:

= Preliminary Results

= Planning
