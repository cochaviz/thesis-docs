#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/noteworthy:0.2.0": *
#import "@preview/ilm:1.4.2": *
#import "@preview/frame-it:1.2.0": *
#show: codly-init.with()

#codly(languages: codly-languages)

#show: ilm.with(
  paper-size: "a4",
  title: "Botnet in a Bottle",
  abstract: [A practical approach to scalable botnet analysis],
  author: "Zohar Cochavi",
  raw-text: (custom-font: "ibm plex mono"),
  table-of-contents: none,
)

= Abstract

Distributed Denial-of-Service (DDoS) attacks are a common use of botnets.
Monitoring the command-and-control (C2) traffic of such a botnet yields valuable
intelligence about the attack, but mapping C2 commands to concrete behavior
typically requires labor-intensive reverse engineering of malware samples and
custom client implementations, limiting scalability. Instead, we present bottle,
an alternative approach that allows unmodified malware to safely communicate
with its original C2 infrastructure while inferring behavior purely from
observed network traffic, eliminating the need for manual reverse engineering.

This talk shows how we safely execute unmodified malware samples, identify C2
endpoints, and enable the capture of DDoS attack traffic without participating
in attacks. We combine these methods into a tool called bottle: a modular
pipeline that executes, monitors, and analyzes malware samples long-term to not
only find what the malware is capable of, but what it is actually used for.

We showcase this tool by showing series of DDoS attacks that are captured live,
where we can observe victims in real time from a large number of botnets. These
attacks allow us to better understand the behavior and usage of infected
devices. We discuss what we have learned from the months we have been running
the tools at scale, with a focus on criminal activity and larger targets.


