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
  title: [*Botnet in a bottle* | Toward A Consolidated Botnet Analysis Pipeline],
  author: "Zohar Cochavi",
  show-date: false,
  show-semester: false,
  no: 12,
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

I'm going to announce a full feature freeze, the only thing I will work on is
stability and bugfixing. Thus:

- [ ] Fix stability issues with `bottled` daemon.
- [ ] Run running samples until something interesting happens.

== This Week's Progress

I'm going to announce a full feature freeze, the only thing I will work on is
stability and bugfixing. Thus:

- [?] Fix stability issues with `bottled` daemon.
- [?] Run running samples until something interesting happens.

I didn't have access to the VM in the weekend, so I also made a web interface... Oops

== Why

I started running experiments last night, but it seems like the VM was overwhelmed...

#figure(
  image("/assets/image-1.png"),
  caption: [Time of death: \~02:00 ECT],
)

I think this happened because of the persistent scanning behavior of some samples.

= Some Results

Long story short, I don't have anything interesting to show, but these are some results:

- Persistent scanning is really annoying to deal with. Is this interesting enough to keep around?

- Cool DNS response I'm not sure what to do with.

== Persistent Scanning (Maybe) Kills (1/2)

#figure(
  image("/assets/image.png", height: 80%),
)

== Persistent Scanning (Maybe) Kills (2/2)

The picture describes:

- No-C2 analysis with persistent scanning behavior.
- Afterwards, multiple long-term runs were executed with different C2 passthrough
  settings.
- I saw errors in `gomon` that the maximum number of hosts were reached, indicating consistent scanning.
- Finally, the VM became unresponsive.

This could be due to a new batch from malwarebazaar, but I am going to adjust concurrency settings.

== DNS Response (1/3)

#figure(
  image("/assets/image-2.png", height: 80%),
)

== DNS Response (2/3)

The response of `bobbot.xcvx[.]online` has the form `MTNiMzQ0MThkNzRmMTQ0ZDA4ODY3Yzlm`, which seems like Base64?

- From Base64: `13b34418d74f144d08867c9f`
- From Hex: `.³D.×O.M..|.`

There is a sibling called `www.xcvx[.]online` which points to `
91.195.240[.]19`.

== DNS Reponse (3/3)

#figure(
  ```
  > GET / HTTP/1.1
  > Host: 91.195.240.19
  > User-Agent: curl/8.7.1
  > Accept: */*
  >

  < HTTP/1.1 442
  < date: Fri, 28 Nov 2025 09:25:31 GMT
  < content-length: 0
  < server: Parking/1.0
  <
  ```,
  caption: [Response `442` _No Reason Phrase_],
)

= Next Week On...

It's really an engineering project at this point:

- [ ] Ensure it doesn't break:
  - [ ] Intruduce static concurrency limits (No-C2 and with-C2).
  - [ ] Profiling for resource usage (investigate why VM died)
  - [ ] Ideally: dynamic concurrency limits

An of course:

- [ ] Run samples until something interesting happens.
