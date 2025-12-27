#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/noteworthy:0.2.0": *
#import "@preview/ilm:1.4.2": *
#import "@preview/frame-it:1.2.0": *
#show: codly-init.with()

#codly(languages: codly-languages)

= Introduction and Motivation

Monitoring C2 communication provides valuable intelligence about bot and botnet
behavior. Interpreting this communication, however, requires mapping C2 commands
to concrete bot behavior, a task that typically depends on reverse engineering
previously unseen malware. A process further complicated by the need to
implement alternative clients capable of interacting with proprietary or
obfuscated C2 protocols, resulting in significant manual effort and limited
scalability.

This presentation introduces an alternative approach to monitoring botnet
activity that allows the original malware to communicate with its C2 server
while inferring bot behavior from observed network traffic, bypassing manual
reverse engineering and improving scalability. By redirecting all non-C2
traffic to an isolated internet simulator, we can safely capture PCAPs of DDoS
attacks without causing harm, enabling not only more intelligence to be
collected, but also qualitatively different forms of analysis.

We concretize this approach in a stack of tools and applications referred to as
*bottle* which has successfully recorded real DDoS attack traffic without manual
intervention. The system demonstrates that scalable botnet analysis can be
performed in practice using live malware, without requiring reverse engineering
or compromising safety.


= Two-Stage Analysis Methodology

The proposed methodology ultimately requires knowledge of a bot's command-and-
control (C2) server address, which in practice must first be inferred. For this
reason, *bottle* operates in two stages: (1) identification of candidate C2
addresses, and (2) botnet activity analysis for each candidate address.

In the first stage, samples are executed with only minimal network access. All
outbound connection attempts are recorded, and contacted IP addresses that are
not associated with basic infrastructure services such as DNS or NTP are
considered potential C2 candidates. This stage is intentionally permissive and
prioritizes coverage over precision.

In the second stage, a distinct sandbox session is started for each candidate C2
address. During a given analysis run, the bot is constrained to communicate with
exactly one internet-accessible endpoint. This design ensures that the bot cannot
execute attacks against real-world victims. The safety argument relies on the
assumption that coordinated attacks are initiated exclusively in response to
C2 commands: either the bot is connected to a C2 server while no other hosts are
reachable, or it is not connected to the C2 server and therefore cannot receive
attack instructions. In our experiments, we have not observed behavior that
violates this assumption.

Observed C2 communication is further used to control the lifetime of an
analysis. Periods of sustained inactivity cause an analysis to terminate
automatically. This heuristic allows false-positive C2 candidates to be
discarded while preserving long-running analyses for bots with active C2
connectivity. In the long term, this ensures *bottle* only monitors active
botnets while automatically ignoring inactive ones, maintaning a an accurate
overview of botnets relevant for intelligence gathering.


= Sandbox Environment and Isolation Measures

All malware samples are executed in QEMU virtual machines running a standard
Debian Linux installation and are provided with strictly limited network
connectivity. Specifically, each sandbox permits:

1. Rate-limited DNS access to a small set of large public resolvers, such as
  Google and Cloudflare.
2. Unconstrained network access to a single specified external address when
  performing analysis for a candidate C2 endpoint.

All other network traffic is redirected to the internet simulation framework
*INetSim*. This provides basic network services (e.g., NTP) and increases the
likelihood that malware exhibits network activity, while preventing interaction
with external systems.


= System Architecture

bottle is implemented as a modular pipeline composed of cooperating components
designed to support long-running botnet analyses. Each component can be used
independently, allowing researchers to adopt only those parts of the system
relevant to their investigative needs.

The bottle orchestrator coordinates the lifecycle of analyses. It maintains a
ledger of sandbox executions, monitors alerts produced by the network analysis
layer, and automatically requeues malware samples as needed. The orchestrator
can also ingest new samples from external feeds such as MalwareBazaar, enabling
continuous operation. By automatically processing newly observed samples, the
system can capture attack traffic without manual intervention, as described in
the introduction.

The bottle daemon (bottled) provides a controlled execution environment for
malware samples. It ensures consistent execution and strict network isolation,
enabling reproducible observation of malware network behavior. The daemon wraps
virtualization and firewalling primitives and can be run standalone for rapid
inspection of individual samples. It further exposes a hackable interface that
supports the addition of new network analysis instrumentation through templated
Suricata configurations and extensible command-line hooks.

Network traffic generated by sandboxed samples is analyzed by the monitoring
component, botmon. This component aggregates traffic into sliding time windows,
evaluates predefined behavioral thresholds, and emits alerts compatible with
Suricata. When alerts are triggered, botmon extracts corresponding traffic
snapshots in the form of PCAPs, enabling targeted inspection of attack behavior.

All collected telemetry is stored in ClickHouse and visualized using Grafana,
enabling near-real-time inspection of observed C2 activity, attack dynamics, and
broader behavioral trends.


= Behavioral Detection of Botnet Activity

To determine whether a sample is exhibiting scanning behavior, participating in
an attack, or merely maintaining regular outbound communication, bottle relies
on two network-level metrics computed over sliding time windows:

- Packet rate per destination, where a destination is defined as an IP and port pair.
- New destination rate, defined as the number of previously unseen destinations
  appearing in the current time window, normalized by the window duration.

The latter metric is particularly useful for distinguishing between scanning and
attack regimes. Scanning behavior is typically characterized by a high rate of
newly contacted destinations, whereas many attack scenarios involve sustained
traffic toward a limited set of targets. Although this distinction is heuristic
in nature, empirical observations suggest that the discrepancy between these
regimes is often sufficient for simple threshold-based classification.

An important observation motivating this approach is that, while malware samples
frequently initiate scanning autonomously, coordinated attacks are generally
triggered only after receiving external commands. Consequently, attack-like
behavior observed after selective C2 connectivity provides a higher-confidence
indicator of active botnet control.

When such behavior is detected, the system can capture traffic snapshots of
arbitrary duration for subsequent offline analysis. These artifacts may be
valuable for improving detection and mitigation techniques, particularly in the
context of distributed denial-of-service attacks.


= Results



= Conclusion

This presentation argues that behavioral observation in constrained sandbox
environments can serve as a practical and scalable alternative to traditional
reverse engineering-based C2 mining. By allowing malware to communicate with its
command infrastructure under strict containment and by focusing on network-level
indicators of activity, bottle enables systematic monitoring of botnet behavior
across a wide range of samples with reduced manual effort.

The proposed talk will present the design, implementation, and empirical
observations of bottle, discuss its limitations and ethical considerations, and
position it within the broader context of botnet and malware ecosystem research.
