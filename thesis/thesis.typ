#import "@preview/classy-tudelft-thesis:0.1.0": *
#import "cover.typ": makecoverpage

// Main styling, containg the majority of typesetting including document layout, fonts, heading styling, figure styling, outline styling, etc. Some parts of the styling are customizable.
#show: base.with(
  title: `bottle`,
  name: "Zohar Cochavi",
)

#makecoverpage(
  title: [Bottle],
  subtitle: [Botnet in a],
  name: [Zohar Cochavi],
  main-titlebox-fill: rgb(0, 109, 128),
)

#maketitlepage(
  title: [Botnet in a Bottle],
  subtitle: [A practical approach to large-scale botnet analysis],
  name: "Zohar Cochavi",
  defense-date: datetime.today().display("[weekday] [month repr:long] [day], [year]") + " at 10:00",
  student-number: 4962281,
  project-duration: [September 2025 - May 2026],
  daily-supervisor: [Maarten Weyns],
  thesis-committee: (
    [Harm Griffioen],
    [TU Delft, Supervisor],
    [George Smaragdakis],
    [TU Delft, Committee],
    [?],
    [TU Delft.],
  ),
  cover-description: [Photo by _myself_],
  publicity-statement: none,
)

#heading(numbering: none, [Preface])

This is a preface where I sound incredibly grateful and inspired.

#heading(numbering: none, [Abstract])

Here is were I am surprisingly concrete for a section that is called abstract.

#outline()

#show: switch-page-numbering

= Introduction

Availability is a foundational property of online services. Modern societies
increasingly rely on digital infrastructure under the assumption that critical
services will be reachable when needed. Recent and not-so-recent incidents, such
as the Ukraine power grid blackout, demonstrate how disruptions of online
availability can lead to significant societal and economic damage
@finkleUSFirmBlames2016. As a result, effective mitigation of Denial of Service
(DoS) attacks remains a central challenge in cybersecurity. Addressing this
challenge requires more than traffic filtering alone; it demands an
understanding of the actors, incentives, and organizational structures behind
such attacks.

A clear illustration of this need can be found in the _Distributed DoS_ (DDoS)
activity attributed to the “Gorilla” ecosystem, which surged in September 2024
@ddpsBriefTechnicalAnalysis. During this period, a Swiss national
critical-infrastructure operator experienced overload attacks that temporarily
disrupted the availability of its online services. Subsequent analysis by the
Swiss National Cyber Security Centre (NCSC) linked these incidents to a
DDoS-as-a-service operation advertised via Telegram under names such as “Gorilla
Services.” The attacks were executed using a botnet (a network of compromised
machines remotely controlled by an operator) combined with rented,
high-bandwidth infrastructure capable of generating large volumes of traffic
@weynsExploringGorillasMalware2025.

In this ecosystem, infected devices run malware that communicates with Command
and Control (C2) servers, which distribute attack instructions and coordinate
activity across the botnet. Beyond this technical infrastructure, Gorilla
actively markets its services and maintains payment and communication channels,
enabling it to rapidly recover from platform takedowns, such as the removal and
replacement of its Telegram channels reported by the NCSC
@ddpsBriefTechnicalAnalysis. This organizational complexity demonstrates that
contemporary DDoS attacks are not merely technical events, but coordinated
socio-technical operations. Consequently, effective defensive measures depend on
actionable intelligence about both the underlying botnet infrastructure and the
actors who operate it.

One approach to obtaining such intelligence is to study botnet activity at a
high level, including which botnets are active, which targets they select, and
which techniques they use to execute attacks. However, comprehensive and
publicly available overviews of botnet activity are currently lacking. This is
due to several factors, including legal and ethical constraints, as well as the
technical difficulty of collecting such intelligence at scale.

A common method for extracting botnet activity is to analyze the Command and
Control (C2) server that distributes instructions to infected hosts. This
typically involves reverse-engineering the malware binary used to enroll a host
into a botnet [citation]. By understanding how a bot communicates with its C2
server, it is possible to emulate this communication and collect information
without directly participating in attacks. Applications that implement this
approach are commonly referred to as C2 miners [citation].

While effective, C2 mining through reverse-engineering does not scale easily, as
each botnet family requires significant manual effort and specialized expertise.
As a result, maintaining a comprehensive and timely overview of botnet activity
remains a largely manual and fragmented process. Addressing this limitation
requires an alternative approach to large-scale botnet intelligence gathering.

== Botnet in a Bottle

In addressing the challenge of scalable botnet intelligence gathering, this
thesis proposes _bottle_, an approach that observes the behavior of botnet
malware in a controlled environment rather than relying on detailed
reverse-engineering of individual botnet implementations. At a high level, the
idea is to allow malware to communicate with its command infrastructure while
preventing harm. By executing malware without modification, this approach
reduces the amount of manual, botnet-specific effort required to extract
intelligence from newly emerging malware families.

This shift from botnet-specific reverse-engineering to behavioral monitoring
aims to enable the scalable collection of technical intelligence about active
botnets and their operational characteristics, while remaining agnostic to
individual malware implementations.

== Thesis Structure

This thesis is organized into three parts. Part 1 provides a general introduction
and outlines the high-level problem addressed in this work, as well as the core
idea proposed to address it. It is intended to be accessible to readers without
a background in cybersecurity or malware analysis.

Part 2 presents the technical background required to understand the proposed
approach. This includes an introduction to botnets (@botnets), how intelligence
about botnet activity can be used defensively (@intelligence), and the tools and
techniques used to observe malware behavior in controlled environments
(@sandboxes and @network).

Part 3 consists of a scientific article that presents the proposed approach and
its evaluation. The article builds directly on the background introduced in Part 2
and focuses on the design, implementation, and analysis of the system proposed in
this thesis.


= Background <background>

This part of the thesis provides the background and terminology required to make
the scientific article presented in @paper accessible to non-expert readers. It
introduces the fundamental concepts needed to understand both the problem
domain and the proposed approach.

Section @botnets and @intelligence describe the basic operation of botnets and
explain how intelligence about their activity can be used to improve cyber
defences. Then, @sandboxes and @network cover the technical foundations
necessary to understand the implementation discussed in the scientific paper.

== How Botnets Work <botnets>

== Intelligence for Defenders <intelligence>

== Malware Sandboxes <sandboxes>

== Network Traffic Analysis <network>


= Botnet in a Bottle <paper>

#bibliography(
  "thesis.bib",
  title: [References],
  style: "american-physics-society",
)

#show: appendix

= Network Configuration
