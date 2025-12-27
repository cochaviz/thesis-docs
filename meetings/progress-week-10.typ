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
  no: 10,
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

Of course:

- [ ] Run long-running samples until something interesting happens (by hand for now!)
- [ ] Replace Suricata alerting with `gomon` in the sandbox environment.

But also:

- [ ] Add C2 detection functionality in `gomon` to formalize RQ2 (ideally, this
  would also work in the context of long-running samples).


== This Week's Progress

Eh...

- [-] Run long-running samples until something interesting happens (by hand for now!)
- [ ] Replace Suricata alerting with `gomon` in the sandbox environment.

But also:

- [ ] Add C2 detection functionality in `gomon` to formalize RQ2 (ideally, this
  would also work in the context of long-running samples).

== This Week's Summary

Not a very productive week, I was mainly working on dashboard-related stuff.

- Overview of long-running samples and their behavior (attacks, C2 traffic)
- Overview of C2 servers and their associated samples
- Run a whole lot of samples collected by Murtaza (no reliable results)

Also some quality-of-life improvements to the `talkbox` daemon, and:

- Allow stopping sandboxes after an alert has not triggered for a configurable
  amount of time.

= Running Many Samples

Interesting moments:

- Sample clearly showed being deactivated, I think because it did not contribute to an attack #footnote[MD5: `24dc82d5cf6ed929fa931f38be674fef12256c10d6dbbccab4123cb7d047173f`].
- Sample attacking netdata-capable host, as Maarten said: could be interesting
  for determining botnet size #footnote[C2: `196.251.88.204`].
- Sample using alternative DNS servers for C2 domain resolution #footnote[MD5: `1a1999152e039a3fb1fcbbeaeb4396c09a6d261bdd9a3638a79e11a03227719f`].

This was in the period of Thursday (6 November) to Tuesday (11 November).

== Dying Samples

I have noticed samples that don't receive any data from the C2 server after a
while don't seem to get reactivated.

I have opted to keep as many samples running, even though they don't seem to do
anything because we might be able to provide data on this suspicion. (Actually
interesting?)

- This provides a nice 'heuristic' for sample activity: if a sample
  stops receiving data from the C2 server, it is likely deactivated.

Effectively *C2Miner* functionality (?).

== C2 Detection

Given the low risk involved in opening a single IP for a particular VM, we can:

- If we guess a particular IP is a C2 server, open it up for that VM.
- Check whether a full connection is established with data from the C2 server.
- If so, it will stay alive, otherwise, we mark the VM as 'stale' and it is closed by the daemon.

This is only possible because we now have the daemon that checks the EVE logs in
order to determine and act on activity.

= Issues at Hand

The biggest issues:

- *Stability*: The solution is simple, just keep going at it, Python is not ideal
  for this circumstance, but oh well... (mainly in the form of not breaking down resources reliably enough such as forwarded IPs.)
- *Sample activation*: Samples that give interesting IPs, but won't
  necessarily do anything interesting.
- *Sample duration*: Many samples will stop receiving commands after hours or days.

The last two might be solved by the aforementioned approach.

= Next Time On...

Clearly:

- [ ] Fix stability issues with `talkbox` daemon (I don't like Python). #footnote[I like the name bottle?]
- [ ] Run long-running samples until something interesting happens.
- [ ] Add `gomon` into the `talkbox` daemon (attack PCAP data).
- [ ] Run long-running samples until something interesting happens.

And I think that'll be enough for now. #footnote[Don't forget progress review in MaRe.]
