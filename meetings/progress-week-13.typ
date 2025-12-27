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
  no: 13,
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
- [x] _RQ2_: How can we allow just C2 network traffic while capturing and
  sinkholing non-C2 traffic to avoid collateral damage?
- [?] _RQ3_: How accurate is DDoS attack target and DDoS attack kind extraction?
- [ ] _RQ4_: What features distinguish spreading behavior from DDoS attacking behavior?



= Previously On...

It's really an engineering project at this point:

- [ ] Ensure it doesn't break:
  - [ ] Intruduce static concurrency limits (No-C2 and with-C2).
  - [ ] Profiling for resource usage (investigate why VM died)
  - [ ] Ideally: dynamic concurrency limits

An of course:

- [ ] Run samples until something interesting happens.


= Previously On...

It's really an engineering project at this point:

- [x] Ensure it doesn't break:
  - [x] Intruduce static concurrency limits (No-C2 and with-C2).
  - [ ] Profiling for resource usage (investigate why VM died)
  - [ ] Ideally: dynamic concurrency limits

An of course:

- [x] Run samples until something interesting happens.

- [x] Move to a new database?!

== Why

- I've found that not only the number of new analyses matters, but also the rate at which they are started.

- Elastic apparently ran on a trial, which passed. Now, we can't trigger alerts anymore :(

Introducing:

- _Clickhouse_ as the database
- _Grafana_ for dashboarding
- _Vector_ for log-forwarding
- _n8n_ for automation

= Concurrency limits

First, some of the changes in `bottle` can be summarized with new configuration options:

== Orchestrator

```yaml
orchestrator:
    ledger_path: data/ledger.jsonl
    daemon_socket: /var/run/bottle/daemon.sock
    poll_interval: 5s
    max_concurrent: 0
    max_concurrent_no_c2: 0
    max_concurrent_same_sample: 0
    start_interval: 1m # minimum delay between starting consecutive analyses (defaults to 1m if unset)
    constraints:
        allow_duplicate_sample: false
        allow_duplicate_c2: false
```

== Monitor

```yaml
monitoring:
    enabled: true
    eve:
        path: /var/log/suricata/eve.json
        search_timeout: 5s
    clickhouse:
        addr: ""
        username: ""
        password: ""
        database: logs
    check_interval: 35s # slightly larger than default gomon timewindow
    default_start_timeout: 30m
    default_inactive_timeout: 6h
    analysis_timeout: 0m # disable analysis timeout
    alerts:
        - sid: 1000011 # C2 Traffic: C2 Communicates with Sandbox (PSH)
          start_timeout: 6h
          inactive_timeout: 12h
          c2_ip_column: src_ip
        - sid: 1000031 # C2 Traffic: Sancbox Communicates with C2 (heartbeat)
          start_timeout: 15m
          inactive_timeout: 12h
          c2_ip_column: dest_ip
```

= Clickhouse Migration

Using _Vector_, we forward `eve.json` from *tud-02* to Clickhouse on *tud-01*:

- JSON Object in `logs.suricata_raw` table
- Using _materialized view_, put insert in `logs.suricata_events`

Now, we can also read latest events from Clickhouse instead of `eve.json` in the monitor!

- 'Last event tracking' now actually works, so VMs are killed based on events (or lack thereof).

= Full Automation

We also have full end-to-end analysis going on through #link("http://automation.mime.cochaviz.internal/workflow/ThSPVDlfzxxAFxls")[_n8n_]:

1. Interesting #footnote[Any IP that hasn't appeared in the last day that is not mentioned in a DNS resolution for any domain ending with 'ntp.org' and doesn't have port 53 or 123 as a destination.] IPs and their generated hashes are read from Clickhouse
2. Filtered for duplicates (not necessary but cleaner)
3. Submitted to *bottle*.
4. Killed by the *bottle* monitor if inactive (configurable)

Note that (most) IPs from scans are excluded because

= First end-to-end Attack (probably)

#figure(
  image("/assets/Screenshot 2025-12-04 at 23.34.04.png", height: 80%),
  caption: [Notice the attacks, ignore some of the broken stuff... I'm still learning Grafana],
)

= Next Week On...

One thing is that the host VM died again, but the resulst are promising:

- [ ] I will _actually_ have to investigate why that happened in order to avoid random dying.
- [ ] Investigate PCAPs from the aforementioned attacks
- [ ] Use the group's Clickhouse instance instead, so data isn't lost
- [ ] Use the group's Grafana instance so we can maybe show publicize?
- [ ] Push attack PCAPs to central storage location?
- [ ] *Keep it running until something interesting happens.*

== First-stage Review

- Do you want to see the slides?
