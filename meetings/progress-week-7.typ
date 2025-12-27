#import "@preview/grape-suite:3.1.0": slides
#import "@preview/cheq:0.3.0": checklist
#import slides: *

#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()

#codly(languages: codly-languages)

#show figure.caption: set text(18pt)

#show: slides.with(
  title: [Toward A Consolidated Botnet Analysis Pipeline],
  author: "Zohar Cochavi",
  show-date: false,
  show-semester: false,
  no: 7,
)
#show: checklist


#pagebreak()
= Research Question

#quote(block: true)[
  How can we infer IoT botnet DDoS attack targets, DDoS attack methods, infection
  targets, and infection methods from sandboxed network traffic alone while restricting
  allowed communications to the C2 server?
]

#pagebreak()

== Subquestions

- [?] _RQ1_: What traffic features (flow metadata, timing/periodicity, header semantics, inter-flow correlations) best distinguish common IoT DDoS attack types?
- [-] _RQ2_: How can we allow just C2 network traffic while capturing and sinkholing non-C2 traffic to avoid collateral damage?
- [?] _RQ3_: How accurate is DDoS attack target and DDoS attack kind extraction?
- [ ] _RQ4_: What features distinguish spreading behavior from DDoS attacking behavior?

#pagebreak()
== Previously On...

- I feel like I'm close to the following goal:
  - [ ] Determine whether C2 server is alive or not (time since last `C2->VM`, or time since last `VM->C2->VM`?)
  - [ ] Use that rule to create overview of active C2 domains.

- The next would be attack/scanning analysis:
  - [ ] Create 'unit tests' for DDoS attacks
  - [ ] See how to be write detection rules for those (Suricata/Zeek/Custom)


#pagebreak()
== How Are we Doing?

- I feel like I'm close to the following goal:
  - [ ] Determine whether C2 server is alive or not (time since last `C2->VM`, or time since last `VM->C2->VM`?)
  - [ ] Use that rule to create overview of active C2 domains.

- The next would be attack/scanning analysis:
  - [-] Create 'unit tests' for DoS attacks
  - [-] See how to be write detection rules for those (Suricata/Zeek/Custom)

#pagebreak()
== Why Like This?

The C2 server health was more of an idea than a plan per-se.

- Did not maintain running analyses over last week
- Not sure how big of a priority this is?
- Kind of just forgot about it while working on the DoS tests.

#pagebreak()
= Start of Behavioral Detection

Over the last week I've run the following experiments:

- Determine viability of *_packet rate_ for anomaly detection* feature for attacking/scanning behavior
- Determine viability of *_new IP rate_ and _per IP packet rate_ as distinguishing feature* for attacking/scanning behavior

In short:
- The sandboxes are incredibly low-noise environments: packet rate with a simple set threshold is perfect
- New IP rate works very well within, but per IP packet not.

#pagebreak()
== Packet Rate
#import "assets/diagrams.typ": *

We calculate the packet rate $lambda^"pkt"$ based on a 30 second window ($w$) in
which we count the packets ($N(t_0, t_1)$) and normalize by the size of the
window.

$
  lambda^"pkt" (t) = (N^"pkt" (t-w, t)) / w
$

(I've never used math equations in Typst, this was my excuse to practice, please
let me know if it's too much!)

#pagebreak()
== Anomaly Detection: Creating a baseline

To do anomaly detection, we need a baseline $lambda_0$ which is composed of
uninfected machine base packet ($lambda_b$) rate _and_ the C2 packet rate
($lambda_"c2"$):

$
  lambda_0 (t) = lambda_b + lambda_"c2" (t)
$

The time-dependency is annoying because we would have to recalculate
the threshold every time.

However, since we know the C2 address, we can just filter this out, and use a
static baseline!

#pagebreak()
== Calculating the Baseline

Quick notes:

- I've opted to use relatively low packet rates:
  - Large amounts of data to parse
  - If we test with very weak attacks, then our approach is more likely to work in the wild
- Most experiments start and end with a 30 second grace period:
  - While we should look 'backward' in time (window: $(t-w, t]$), I'm not sure this is always the case here?
  - Doesn't actually matter since it's consistent per experiment, and the grace times are symmetrical.

=== Null
#figure(
  show_diagram(
    data: "/sidequests/baseline_calculations/null_pps.json",
    show_events: true,
  ),
  caption: [Packet rates observed during the null test experiments ],
)

#pagebreak()
=== Synflood

#figure(
  show_diagram(
    data: "/sidequests/baseline_calculations/synflood_pps.json",
    attack_start: 30,
  ),
  caption: [Packet rates observed during the `synflood` test experiments ],
)

#pagebreak()
=== TelnetScan
#figure(
  show_diagram(
    data: "/sidequests/baseline_calculations/telnetscan_pps.json",
    attack_start: 30,
  ),
  caption: [Packet rates observed during the `telnetscan` test experiments ],
)

#pagebreak()
== Attack vs Scanning Detection

For determining whether a bot is actually attacking, we have to distinguish
between attacks and scans.

My first thought was the packet rate per destination IP address, but this
doesn't work since we only send one/two packets in the case of the `telnetscan` per IP address. With a window of 30 seconds, this will become indistinguishable from $lambda_0$.

(I don't think I've saved the figures, but I can make them if it's interesting)

#pagebreak()
== New IP Rate

Instead, I've opted for the metric where we count the number of unique IPs
($N^"ip" (t_0, t_1)$) we haven't seen in the last window, and normalize that
over the size of the window:

$
  lambda^"ip" = (| { "ip" | "ip is unique in" (t-w, t] } - {"ip" | "ip is unique in" (t-2w, t-w]} |) / w
$

*This should also be able to deal with attacks with many targets*

(I just wanted to play with math notation, probably overkill...)

#pagebreak()
=== Synflood

#let synflood_iprate = show_unique_ip_rate(
  data: "/sidequests/baseline_calculations/synflood_ipps.json",
  attack_start: 30,
)

#figure(
  synflood_iprate,
  caption: [IP rates observed during the `synflood` test experiment. ],
)


#pagebreak()
=== Telnetscan

#let telnet_iprate = show_unique_ip_rate(
  data: "/sidequests/baseline_calculations/telnetscan_ipps.json",
  attack_start: 30,
)

#figure(
  telnet_iprate,
  caption: [IP rates observed during the `telnetscan` test experiment. ],
)

#pagebreak()
=== Synflood Many


#let telnet_iprate = show_unique_ip_rate(
  data: "/sidequests/baseline_calculations/synflood_many_ipps.json",
  attack_start: 30,
)

#figure(
  telnet_iprate,
  caption: [IP rates observed during the `synflood_many` test experiment: `synflood` on 255 hosts at once.],
)

#pagebreak()
== Conclusion

Works pretty well I think! :)

For now, we use simple thresholds, but there are plenty of improvements and
extensions to be made.

My personal favorite is to use some statistical methods for determining the
spread in $lambda^"ip"$ in addition to the peak, where narrower means more
likely to be attacking instead of scanning.

#pagebreak()
= Next Week On...

Of course:

- [ ] Integrate detection 'script' (let's _Go_) with the scrappy pipeline on long-running samples
- [ ] Hope that something happens

There are some things I would also like to do:

- [ ] C2 Health Overview
- [ ] Log rotation (so my PC doesn't suddenly die)


#pagebreak()
= Post-meeting notes

- Consider focusing on attack types by clustering on their payload, possibly dropping _Q4_.
- Possible extension on scanning detection is to detect _High-entropy IP sets_
- Consider extending C2 Activity:
  - Accessible: Full three-way handshake
  - Alive: Responds with payload
  - Active: Bot shows activity/commands are sent
- We haven't thought much about rotating C2 servers, other than re-using the heuristic in the first stage.


