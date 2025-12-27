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
  title: [Toward A Consolidated Botnet Analysis Pipeline],
  author: "Zohar Cochavi",
  show-date: false,
  show-semester: false,
  no: 11,
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

- [?] _RQ1_: What traffic features (flow metadata, timing/periodicity, header
  semantics, inter-flow correlations) best distinguish common IoT DDoS attack
  types?
- [-] _RQ2_: How can we allow just C2 network traffic while capturing and
  sinkholing non-C2 traffic to avoid collateral damage?
- [?] _RQ3_: How accurate is DDoS attack target and DDoS attack kind extraction?
- [ ] _RQ4_: What features distinguish spreading behavior from DDoS attacking behavior?


= Previously On...

Clearly:

- [ ] Fix stability issues with `talkbox` daemon (I don't like Python). #footnote[I like the name bottle?]
- [ ] Run long-running samples until something interesting happens.
- [ ] Add `gomon` into the `talkbox` daemon (attack PCAP data).
- [ ] Run long-running samples until something interesting happens.

And I think that'll be enough for now. #footnote[Don't forget progress review in MaRe.]

== This Week's Progress

Clearly:

- [-] Fix stability issues with `talkbox` daemon (I don't like Python). #footnote[I like the name bottle?]
- [ ] Run long-running samples until something interesting happens.
- [-] Add `gomon` into the `talkbox` daemon (attack PCAP data).
- [ ] Run long-running samples until something interesting happens.

== Why

I was bored, and started writing in Go. Then it was almost finished, and it felt
better. Maybe a waste of time, but oh well...

With that said, we now have:

- `godos`: a Go module to perform DDoS attacks from network traffic metadata
- `gomon`: a Go module to monitor Go processes and extract PCAP data on DDoS attacks
- `bottled`: a Go daemon to replace `talkbox`, with `gomon` integration
- `bottle`: Orchestrator, monitor and controller for `bottled` analyses

= Overview

I want to:

- Give a quick overview of the new architecture
- Show the integration with `gomon` and show how instrumentation works

== Architecture

#figure(
  image("assets/bottle_architecture.pdf", height: 80%),
)

= Next Week On...

I'm going to announce a full feature freeze, the only thing I will work on is
stability and bugfixing. Thus:

- [ ] Fix stability issues with `bottled` daemon.
- [ ] Run long-running samples until something interesting happens.

*Midterm review planning?*

