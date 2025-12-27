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
  no: 8,
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

- [ ] Integrate detection 'script' (let's _Go_) with the scrappy pipeline on
  long-running samples
- [ ] Hope that something happens

There are some things I would also like to do:

- [ ] C2 Health Overview
- [ ] Log rotation (so my PC doesn't suddenly die)


== How are we Doing?

Of course:

- [-] Integrate detection 'script' (let's _Go_) with the scrappy pipeline on long-running samples
- [-] Hope that something happens

There are some things I would also like to do:

- [-] C2 Health Overview
- [?] Log rotation (so my PC doesn't suddenly die)


== Why Like This?

*Relatively non-productive* week with a lot of random things:

- Missed one day of work
- Possibly an incident at home of traffic leaking out of the sandbox environment
- VM ran out of storage because of attacks causing crazy amounts of traffic (not
  a surprise)

I did find that *Suricata _can_ do monitoring on packet rate and selectively
extract packets based on alerts*.

= Sandbox Leakage Incident

I've had a small incident where traffic seems to have leaked out of the sandbox
environment on my local network:

- I don't think it actually left the network
- I'm quite sure what we can do fix this specific incident
- For now, I think we're best off running these experiments on my personal VM
  for a period of time

== Mirai Attacking

Let's start positive, we did spot attacks!

#figure(
  image("../diary/assets/kibana_mirai_attacking.png", height: 9cm),
)

== Mirai Scanning

And we saw scanning as well:

#figure(
  image("../diary/assets/kibana_mirai_scanning.png", height: 9cm),
)

== The problem

However, looking at the traffic going out of the sandbox on my local network:

- About 3 GB of upload around 02:00 to 06:00 on Monday
- Is closely related to some activity of one of the samples
- I can't find the destination IPs in Unifi

But the PCAP was about 16GB, so it doesn't seem like all the traffic leaked out.

#figure(
  image("../diary/assets/incident_unifi_network.png", height: 90%),
  caption: [Notice the
    volume and the timing.],
)

#align(
  center + horizon,
  figure(
    image("../diary/assets/incident_source_multicast.png", width: 100%),
    caption: [Source multicast traffic going out of the sandbox,
      matching closely with the leaked traffic.],
  ),
)

== Investigating

Because of the size of the PCAP, I've had difficulty analyzing it fully. But I
think the following happend:

- One of the samples uses multicast traffic for some reason.
- Elastic mislabels this as `source.ip`.
- I'm not DNATing multicast traffic to `inetsim`.
- This traffic leaves the sandbox to the local network.
- Because it is multicast, it is sent to all devices on the local network, but
  not beyond.

== Evidence (1/2)

I have among other things the following line in the `setup_network.sh` script:

#figure(
  ```bash
  # Generic "internet" trap (exclude local subnets + mcast/bcast)
  ip saddr $VM_NET ip daddr { $VM_NET, 10.66.66.0/24, 224.0.0.0/4, 255.255.255.255
  } \ meta l4proto { tcp, udp } counter dnat to 10.66.66.2

  # ICMP echo → INetSim (ping to public IPs)
  ip saddr $VM_NET ip protocol icmp icmp type echo-request ip daddr { $VM_NET,
  10.66.66.0/24, 224.0.0.0/4, 255.255.255.255 } \ counter dnat to 10.66.66.2
  ```,
  caption: [Notice `` ],
)

== Evidence (2/2)

Furthermore:

- I've ran tests and all regular traffic seems to be DNATed correctly to
  `inetsim`#footnote[I  have honestly not tried targeting a multicast address in a
    test case!].

It's really annoying I can't find more information on the exact flows in unifi
:(

== What do You Think?

It seems likely to me that:

- This would explain the significant discrepancy between the PCAP size and the
  leaked traffic size.

- This would explain the strange `source.ip` labeling in Elastic.

The alternative would be that traffic is leaked in very particular scenarios
with large traffic, which seems less likely.


= Other Progress

I _have_ made some progress on other fronts as well:

- We can use Suricata to monitor packet rates and extract packets based on
  alerts.
- Included a dashboard which displays relevant metrics for C2 activity
  monitoring.

Furthermore, I have come to the conclusion that:

- We can use Elastic actions to start long-running analyses based on new
  interesting IPs (which have also improved in quality).


= Questions

Since we're slowly starting to approach answers to the research questions:

- What is going to be the focus?  - DDoS attack type detection?  - Bot spreading
  behavior detection?

- What should be the scope of the tool?  - I'm trying to the tool as minimal as
  possible, should we formalize the requirements?

= Next On...

Clearly:

- [ ] Run long-running samples until something interesting happens (by hand for now?)

But also use collected data to start answering RQ1 (DDoS attack type detection):

- [ ] Investigate last attack for potential features
- [ ] Find methods for the data analysis (hopefully within Elastic, start with
  basic KNN clustering?)
- [ ] C2 Server TAXII Feed?!!?

= Fun Stuff

- #link("https://shadowserver.org", [ Shadowserver ]) is pretty cool! Do you
  think it's worth talking to them?
