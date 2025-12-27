#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/noteworthy:0.2.0": *
#import "@preview/ilm:1.4.2": *
#import "@preview/frame-it:1.2.0": *
#show: codly-init.with()

#codly(languages: codly-languages)

#show: ilm.with(
  paper-size: "a4",
  title: "Thesis Notes",
  author: "Zohar Cochavi",
  raw-text: (custom-font: "IBM Plex Mono"),
)

= Week 41

== Build Issues

I've managed to tackle most of the missing architecture pieces, and now I'm back
to _integration hell_. The most pressing issue is that building doesn't work? I
seem to get and IP address and everything, but for some reason there is no
internet connection? At least, it keeps hanging when 'Checking the Debian mirors'.

== Potential for Scaling Up!

On the brighter side, I've found a project that implements the whole virtualization
orchestration stack on Kubernetes: [KubeVirt](https://kubevirt.io/). It doesn't do
everything of course, but this should fit perfectly into the driver layer when
we do want to use multiple nodes.

The current version is still very useful for small-scale deployments and I'm definitely
going to steal their interface when it comes to configurations so that they're compatible
in the future!

(It's written in Go, is this the universe telling me it's time to use Go?)

== Slowly but Steadily

I've managed to get building and running a sandbox working again! Now, on to testing the
analysis pipeline...

== Talkbox Results

In the meanwhile I've been running `talkbox` in the background, these are the
results I have been able to gather.

- `unknown_hash`: `http://eagle1997.executorstresser[.]ru/` seems to be the stager for a
  stressor. We not only have access to all the builds, but also the _debug_ build!
  (Debug build ended up being stripped?! But the `arm7` version wasn't!)
- `173490aebb63a7d86b3d7c605a8095782f21841e47327343e51982c9b429005d`: Connects
  to 65.222.202[.]53 over port 80. Nothing particularly interesting other than the
  use of malformed DNS packets. I've seen this more often and it might be somehting
  like firewall detection?

== Streaming?

I've just realized that the current batch-analysis method is not ideal. Mostly because
we want to run long sandbox sessions and I've currently implemented each session to
return data.

Either we have to run many short sessions or we have to implement a streaming analysis
pipeline. The latter might be the best option, but I think we can at least have some
results before doing that.

The streaming is also a good excuse to start using some sort of messaging queue, which we
can then also use for the communication between the services; ensuring that we
don't completely lock up when consuming at the top end of available resources.

Using Python primitives and iterative approach, I think we should be able to migrate the
batch-based analysis to a streaming analysis pipeline once the former is complete.

== Running Two-stage Analysis

Now that I'm running a two-stage analysis, I can see that IPv6 might be an issue:

```log
"stdout_tail": ";; communications error to 1.1.1.1#53: timed out\n;; communications error to 1.1.1.1#53: timed out\n;; communications error to 1.1.1.1#53: timed out\n\n; <
<>> DiG 9.18.33-1~deb12u2-Debian <<>> google.com @1.1.1.1\n;; global options: +cmd\n;; no servers could be reached\nPING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.\n\n--- 1.1.1
.1 ping statistics ---\n5 packets transmitted, 0 received, 100% packet loss, time 4105ms\n\n",
"stderr_tail": "--2025-10-12 07:19:44--  http://google.com/\nResolving google.com (google.com)... 142.250.185.206, 2a00:1450:4001:82f::200e\nConnecting to google.com (goog
le.com)|142.250.185.206|:80... failed: Connection timed out.\nConnecting to google.com (google.com)|2a00:1450:4001:82f::200e|:80... failed: Network is unreachable.\n",
```

Now that I've allowed partial access to DNS, it might be necessary to do some
IPv6 forwarding, but given that most malware do A requests, I think this might
be something that's not necessary in most cases.

== Too Much Data

Running some initial experiments with the long-term analysis, I can see that I
have so much predictable data that it's hard to find the needle in the haystack.
Especially since I can only manually look through the PCAPs and I get otherwise
very limited information, I need to automate this process.

= Week 42

== Observability

I spent Tuesday night and yesterday working on making tracking the experiments
easier. Especially for the longer-running experiments (after first-stage
analysis), I can't just be looking at the logs manually all the time. In
general, the pcaps are also analyzed by suricata during analysis according to
the following configuration:

```yaml
# outputs: keep only EVE JSON (compact, easy to parse)
outputs:
    - eve-log:
          enabled: yes
          filetype: regular
          # relative to the -l log dir you pass on CLI
          filename: eve.json
          types:
              - alert
              - http
              - dns
              - tls
              - flow
              - files
              - stats
```

This keeps track of most of the important information while keeping the size of
the logs manageable. Notice `stats` and `alert` which will allow us to track specific
events and anomalies in network traffic. This is especially useful in long-running
experiments.

For the alerting, we have the following configuration:

#figure(
  ```rules
  # 1) C2 -> VM: any TCP payload to the sample
  #    We require an established flow and nonzero payload toward the client (the VM).
  alert tcp $C2_SERVER any -> $HOME_NET any ( msg:"SANDBOX C2 -> VM: TCP payload"; flow:established,to_client; dsize:>0; sid:1000001; rev:1; )

  # 2a) VM -> external non-C2: new TCP connection attempts (SYN)
  #     Fires on the SYN packet so you see connection attempts even if the handshake fails.
  alert tcp $HOME_NET any -> ![$HOME_NET,$C2_SERVER] any ( msg:"SANDBOX VM -> non-C2 external: TCP SYN"; flags:S; flow:stateless; sid:1000002; rev:1; )

  # 2b) VM -> external non-C2: established flows with payload
  #     Useful when the pcap starts mid-stream (no SYN) or to catch data after connect.
  alert tcp $HOME_NET any -> ![$HOME_NET,$C2_SERVER] any ( msg:"SANDBOX VM -> non-C2 external: TCP payload"; flow:established,to_server; dsize:>0; sid:1000003; rev:1; )
  ```,
  caption: [Suricata basic detection rules for generic interesting events.],
)

The first is important to detect commands to the sample, while the latter is
useful for detecting attacks, scanning, and other suspicious activities.

== Initial Results

There was something in me that thought we might miss certain information when
using suricata flows instead of `pyshark`, but it seems to go rather well!

This is an example of what it looks like when we get an alert in

#figure(
  image("assets/kibana_alert.png"),
  caption: [Example of an alert in Kibana.],
)

There are, however, two discrepancies:

- Alert containing IP address which is not in the analysis output: `185.11.138.90`
- Analysis output containing IP address which is not in any alert: `81.88.18.108`

The first is strange as it should contain a reference to the sample name (in our
case a hash) in which the event was found, but it's missing. The only way to
track where this result is coming from is by using the source IP. Looking in the
only PCAP that has that source IP, it's completely empty. Another clue is the
destination port which is `123`, indicating this is probably NTP traffic.
Currently, I'm not using the tshark filter I was using before (something like
`!ntp and !arp`), so I think that's a result of this. It's still strange that
the PCAP is empty since we split the datastream for file write and suricata, but
maybe it's just a malformed packet that wireshark has difficulty with.

The second is more interesting, and it seems due to some limitations of the Suricata flow logging.

#figure(
  image("assets/missing_ip_kibana.png"),
  caption: [Regular Suricata flows don't always capture all events. It failed to recognize the aborted connection.],
)

This simply is an issue with the 'depth' of the analysis that either method
allows for. There are two options here:

1. Also push analysis data to elasticsearch, and correlate the data there.
2. Use Suricata only, and patch odd behavior as we go.

In this case, I've opted to include _some_ alerting when running the intial
analysis. The problem is that the flows Suricata uses in EVE aren't sufficient
for all cases, and we need to account for that. The simplest solution here is
to just create an alert for outgoing connections, regardless of whether they
are established or not:

```rules
# 1) We want to detect all outgoing connections initiated by the VM.
alert tcp $VM_HOST any -> any any (flags:S; msg:"VM initiated outgoing connection"; tag:session,packets,2; sid:1000001;)
```

In the suricata configuration, this is handled as:

```j2
default-rule-path: /home/john/research/talkbox/suricata
rule-files:
{% if c2_ip %}
    - c2.rules
{% else %}
    - init.rules
{% endif %}
```

== Goals

I was struggling with figuring out what to do next, now that short and long
analyses sort of work (not ideal for large-scale deployments, but that doesn't
matter). The thing is that I have a 'tool' or some solution, but the problem
wasn't not clear enough. I need a more specific question to answer in order to
do some useful data anlysis, or at least to find useful information within the
swaths of data I'm collecting.

With that said, I have the following two 'cases' which should give direction to
what to do with the data:

1. Determine whether the C2 server is still alive. Currently, there aren't good
  blacklists that also determine when IPs have become benign. (This is
  effectively why rule with SID `1000001` is useful.)

2. Determine impact of the botnet, or at least that of our bot. Using the non-C2
  external IPs, we can track what goals the botnet is trying to achieve. (This
  is why we have rules `1000002` and `1000003`.)

The first is significantly easier to achieve than the second, and data from the
first can be used to achieve the second. For that reason, we'll first focus on
this before moving on to do the rest. However, I have some ideas for the second
case as well.

Esentially, we are trying to gather intelligence about the adversaries, the
botnet is just a means to an end. For this reason, it's interesting to
understand what the C2 server is doing, as it is directly controlled by the
adversaries. Because we can't monitor the C2 server directly, we abuse the bot
to understand what the C2 server is doing. This means we want to _correlate_ the
botnet's activities with the C2 server's commands.

We can collect the activity from the C2 server to the botnet, and try to
correlate it with specific events from the bot's activities. This is why these
three rules are useful, it allows us to investigate how outgoing traffic
corresponds to the C2 server's incoming traffic, which hopefully corresponds to
the C2 commands and botnet behavior respectively.

== Next Steps

After talking with Maarten, we have decided the most important thing is to get
the whole analysis pipeline working even if that means manually setting up the
long-running samples. The next steps are:

1. Solve small stability and cleanup issues in the current analysis pipeline.
2. Deploy self-contained version of the analysis pipeline on TUDelft VM (`inetsim` only).
3. Create some bash scripts implementing common attacks to detect
4. Create detection rules in Suricata for these.

Perhaps we will later try to detect scanning activity, but that is not a
priority right now. The main goal is to get the analysis pipeline working
reliably and to be able to detect some common attacks. By the time this works,
we might continue to work on the reimplementation.

== Academic Relevancy

All of this is very applied research, but I want it to be academically relevant
as well. Therefore, we should emphasize the novelty of the approach and _why_ it
works better than existing approaches.

= Week 43

Finished last week with being able to run the stage-one analysis pipeline on the
TU Delft server, and ironing out the last kinks in the Suricata configuration. Now,
the focus will be on the second stage: detecting attacks.

== Attack Detection

I'm struggling slightly, because I can think of two approaches:

1. Start small with, for example, detecting Mirai-specific attacks. This should
  be super easy as we know exectly what their characteristics are, but the added
  value is somewhat limited.
2. Try to create a more general kind of detection mechanism that looks at packet
  rate. This should be relatively doable, but testing this will be significantly
  more involved.

I have already made some small test scripts in the form of `godos`
#footnote("https://github.com/cochaviz/godos"), but thinking about the kind of
detection I need for each of the implemented attacks (`syn-flood` and
`udp-flood` for now), they come down to the 'rate' of packets. This is a perfect
candidate for 'anomaly detection', but the hard part here is the baseline. We
don't know how 'active' a malware sample will be. It might immediately start
scanning or attacking, or it might wait for hours before doing anything.

One thing we do know is what C2 communication looks like, since we know what the
C2 server is. Taking the packet rate of this behavior as the baseline, we can then try to
detect deviations from this behavior, labeling this as 'anomalous'. Now the question is
how to do we distinguish between scanning and attacks in anomalous behavior?

The purpose of scanning in botnets is to find vulnerable hosts to attack. Therefore,
scanning behavior should be more 'spread out' over many IP addresses, while an
attack should be more focused on a single IP address. This means that there should
not only be an anomaly in the number of packets per second, but also in number of
unique destination IP addresses.

If we see a spike in both the packet rate and the _IP rate_, we can be fairly
certain that scanning is taking place. If we see a spike in only the number of
packets per second, we can be fairly certain that an attack is taking place.

To increase the certainty further, we can look at the spread of the packet rate
over time for a particular host. If this looks more like a 'burst', then it's
more likely to be scanning.

This means we have three metrics to look at:

1. Packet rate (packets per second)
2. Unique destination IP addresses (per second)
3. Burstiness of packet rate per host

If we see that there is an anomaly in only the packet rate, and that the
burstiness is low, then we can be fairly certain that an attack is taking place.
If we see that there is an anomaly in both the packet rate and the number of
unique destination IP addresses, and the traffic is bursty, then we can be
fairly certain that scanning is taking place.

== An Actual Plan

Right now I have two attacks `synflood` and `udpflood`. In terms of attacks,
this is fine for now; the only thing we still need is `scanning`, but that's not
hard: `nmap`. However, we do have everything we need in order to start working on
the first detection mechanism.

First, we need a baseline, $lambda_0(t)$, which is composed of the standard
baseline of a non-infected, benign, host, $lambda_b$, and the C2 traffic $lambda_(c
2)(t)$ estimated of over a time window $[t-w, t]$ (where $w$ the size of the window).

$
  lambda_0(t) = lambda_b + lambda_(c 2)(t)
$

We have make a reasonable guess as to what timewindow $w$ we should use. This
strongly depends on the strengh of the 'benign' baseline $lambda_0$, so we will
calculate that first by doing a simple 'null' experiment. Running the
`null_test.sh` script for 5 iterations, each lasting 2 minutes, we observed the
following baseline behavior #footnote[Used command: `talkbox analysis run tests/null_test.sh --arch amd64 --no-guess-arch --iterations 5`].

#import "diagrams.typ": *

#figure(
  show_diagram(
    data: "baseline_calculations/null_pps.json",
    show_events: true,
  ),
  caption: [Packet rates observed during the null test experiments ($mu = 0.13$ packets per second)  ],
)

We can clearly see that the benign baseline is very stable, and only seems to
contain traffic occuring at regular intervals. For the purposes of a static
value, this perfectly fine (as can be seen by Mean), but the dynamic
baseline_calculation of the rate can suffer from _aliasing_ which can be observed in the diagram in the form of the 'sawtooth' pattern.

Here, aliasing occurs because the window size $w$ is slightly smaller than the
interval at which the periodic traffic occurs, and the relatively high sampling
rate (one sample per 5 seconds). If we would match the sample rate with the
window size, the number of dips because of the aliasing would be reduced, but
not eliminated.

For this calculation, this is not a problem, but for calculating $lambda_(c
2)(t)$ we need to be more careful. In the worst case, our sampling rate is some
divisor of the interval at which C2 traffic occurs, meaning we might miss it
completely.

== Stop Thinking so Complex

I'm a doofus: _just filter out the C2 traffic, and there is no periodicity
issue_. We have complete control over based on which packets we calculate the
packet rate, so we can just ignore the C2 traffic when calculating the packet
rate. This means that we can just use a fixed window size and sampling rate
without worrying about aliasing. The average interarrival times of a DOS attack
is much smaller than our window of 30 seconds, meaning that we can easily detect
these attacks without fear of significant aliasing.

Now, let's run a simple `synflood` attack (see @godos_synflood) using the a
timeout of 2 minutes, and a start delay of 30 seconds #footnote[Used command: `talkbox analysis run tests/godos --timeout 180 --sample-delay 30 --sample-args "synflood 100.100.100.100"`].

#figure(
  show_diagram(
    data: "baseline_calculations/synflood_pps.json",
    attack_start: 30,
  ),
  caption: [Packet rates observed during the `synflood` test experiments ($mu approx 25$ packets per second)  ],
)

Clearly, we can see a massive spike in the packet rate during the attack. As for
the justification for why this test would be 'valid' in a real-world scenario,
we can simiply look at the Mirai source code which does not contain any
throttling mechanism for the SYN flood attack
#footnote[https://github.com/jgamblin/Mirai-Source-Code/blob/master/mirai/bot/attack_tcp.c#L117].

For good measure, I've also run a `udpflood` attack which shows similar results,
albeit with a significantly slower packet rate #footnote[Used command: `talkbox analysis run tests/godos --timeout 180 --sample-delay 30 --sample-args "udpflood 100.100.100.100"`].

#figure(
  show_diagram(
    data: "baseline_calculations/udpflood_pps.json",
    attack_start: 30,
  ),
  caption: [Packet rates observed during the `udpflood` test experiments ($mu approx 8$ packets per second)  ],
)

I don't truly understand why this is the case, but oh well.

=== Scanning

Now, on to scanning! I've copied the implementation of Mirai and made a simple
`telnetscan` that checks port 23 and 2323 on random external IP addresses
#footnote[Used command: `talkbox analysis run tests/godos --timeout 180
--sample-delay 30 --sample-args "telnetscan"`]. The results are incredibly
similar to that of the `syncflood`/`udpflood` attacks, save for the 'scale'
(this is due to rate-limiting introduced in the flood attacks which wasn't
present here). The scale might vary from one bot to another, but most
importantly is that it's a significant _sustained_ increase in packet rate
compared to the `null` case.

#figure(
  show_diagram(
    data: "baseline_calculations/telnetscan_pps.json",
    attack_start: 30,
  ),
  caption: [Packet rates observed during the `telnetscan` test experiments ($mu approx 15$ packets per second)  ],
)

Now, how to detect scanning vs attacks? My first thought was to look at the
packet rate per unique IP address, but this doesn't seem to work well since
there are only two packets sent per destination. Since we calculate this on a
basis of a 30 second window, this means that the maximum packet rate per unique
IP address is `2 / 30s = 0.0666` packets per second, which is very low, much too
close to the noise floor of the `null` test.

For this reason, we will instead look at the number of unique IP addresses per
second. Where unique IP addresses are addresses in this window that weren't present in the last window.


#let telnet_iprate = show_unique_ip_rate(
  data: "baseline_calculations/telnetscan_ipps.json",
  show_x_title: false,
  attack_start: 30,
)
#let synflood_iprate = show_unique_ip_rate(
  data: "baseline_calculations/synflood_ipps.json",
  attack_start: 30,
)

#figure(
  grid(
    columns: 1,
    rows: 4,
    row-gutter: 10pt,
    telnet_iprate,
    synflood_iprate,
  ),
  caption: [IP rates observed during the `telnetscan` (top) and `synflood` (bottom) test experiments. Note the significant difference in scale. ],
)

#let synflood_many_iprate = show_unique_ip_rate(
  data: "baseline_calculations/synflood_many_ipps.json",
  show_x_title: false,
  attack_start: 30,
)
#let synflood_many_pktrate = show_diagram(
  data: "baseline_calculations/synflood_many_pps.json",
  show_x_title: false,
  attack_start: 30,
)

There have been moments in the past where both supervisors have seen many IPs
being targeted at the same time. Since this might be a problem for our detection
mechanism, I've also run a `synflood_many` test where we flood a `/24` range of
different IP addresses at the same time (255 addresses total). Given that these
are all being attacked at the same time, we should see a significant increase in
the unique IP rate, but only for a short amount of time.

#figure(
  grid(
    columns: 1,
    rows: 4,
    row-gutter: 10pt,
    synflood_many_pktrate,
    synflood_many_iprate,
  ),
  caption: [IP rates observed during the `synflood_many` test experiments (bottom, $mu_("ip","synflood_many") approx 2$) compared to packet rates (top). Note the difference in spread between the IP rate of the attack and that of scanning.],
)

Indeed, even though the packet rate is sustained high, because we attack the
same targets repeatedly, the unique IP rate quickly drops back to (near) zero.
Even though the top of the spike is close to that of scanning, it is still 5x
lower than the sustained plateau of scanning. The plateau might be significantly
lower if a lower packet rate is set, so ideally we would look at the spread of
the unique IP rate beyond a certain threshold.

For now, we will take a simple threshold, assuming that if the unique IP rate,
$lambda_(i p)$, is above 4 IPs per second, we are scanning, otherwise it's an
attack. Therfore, we get the final detection mechanism as:

#figure(
  $
    "attack"(lambda_("pkt"), lambda_("ip")) := cases(
      1 "if" lambda_("pkt") > lambda_0 + 3 sigma_(lambda_0),
      1 "if" lambda_("ip") < lambda_("ip","synflood_many"),
      0 "else",
    ) \
    "scan"(lambda_("pkt"), lambda_("ip")) := cases(
      1 "if" lambda_("pkt") > lambda_0 + 3 sigma_(lambda_0),
      1 "if" lambda_("ip") > lambda_("ip","synflood_many"),
      0 "else",
    )
  $,
  caption: [Final detection mechanism for attacks and scanning based on packet rate ($lambda_("pkt")$) and unique IP rate ($lambda_("ip")$). $sigma_(lambda_0)$ is the standard deviation of the baseline packet rate.],
)

== Log Rotation

One thing I'm now seeing is that it will be necessary to implement log rotation on the pcap files. There are a couple of options in `tcpdump` itself:

```bash
man tcpdump

# -C file_size
#     Before writing a raw packet to a savefile, check whether the file is currently larger than file_size and, if so, close the current savefile and open a new one.
# -G rotate_seconds
#     If specified, rotates the dump file specified with the -w option every rotate_seconds seconds.
# -W filecount
#     Used in conjunction with the -C option, this will limit the number of files created to the specified number, and begin overwriting files from the beginning, thus creating a 'rotating' buffer.
```

Not sure about the values, yes, but I'll fiddle with that later. I'll probably
create a new file every hour (`-G 3600`), and keep 48 files (`-W 48`) (two days)
for long-running samples, capping them at 10MB each (`-C 10MB`) so we'll never
have more than 480MB of logs. The short-running samples can just keep
everything, and I'll clear those out when I've inspected the results.

One downside here is that when there is an attack with sufficiently high packet
rate, we lose a lot of since packets will be quickly overwritten. Ideally, we
would _cap_ the size of each file and only start a new one after a certain time,
throwing away data that overflows.

== I have become One of Them

While I've always complained about researchers making shit code, I have become
one of them. There is absolutely no excuse for the level of code quality I've
been producing lately, other than that it only serves as a proof of concept. My
current goal is to finish this poc as soon as possible, as to be able to
implement something of actual value.

The current goals are as follows:
1. Convert the weird 'iterative' flag to just 'long-running' and use the helper
  scripts to automate setting that up.
2. Make sure this is somehow done 'on its own'.

However, I can already see that this is gonna take more time than I want it to:
looking through alerts and running that command. I need a solution, but I don't
want to touch the code, but my inner McGyver has solved it: Kibana actions.

Whenever an interesting alert fires, I have the sample which triggered it. This
will launch an alert action that sends a request to a sever running all the
long-running samples. On this server, there will be one sad little endpoint
which only takes the sample hash and identified C2 IP address, and launch the
long-running analysis for that sample.

Am I proud of this solution? No. Is it quick and dirty and works? Yes.

I have become one of them.

== Finetuning Interesting IP Detection

Given the previous aspiration, and the fact that it's quite late and my brain is
fried, I just did some small finetuning of the interesting IP detection rules in
Kibana. One of the things I've done is to exclude the `::` source address since
the targets targets are all IPv6 addresses, and I think these are not interesting.

#figure(
  image("assets/interesting_alert_ipv6.png"),
  caption: [Excluding `::` source address from interesting alerts.],
)

I'm not sure why, I should look into why they are there in the first place, so this
is my mental not to investigate this tomorrow! Otherwise, this seems much more
reliable.

== Improving Talkbox Usability

I've made some small improvements to the usability of `talkbox`, mostly
regarding the long-running analysis. Currently, I can just run the analysis with

```bash
talkbox analysis run-long <sample_hash> <c2_ip>
```

Passing `--malwarebazaar-api-key` will also fetch the sample from MalwareBazaar if
it's not already present locally. This has made my life _so_ much easier, and it should
be really easy to expose a small endpoint that triggers this command with the right
arguments.

However, I've started enthusiastically running samples and I was greeted by some
stupid sample scanning to their heart's content, eating up all the resources of
my Kibana instance. While I don't care that they start scanning (be my guest), I
don't want to save all the scanning data.

The problem is that I need every fragment of a full flow to understand what the
bot is doing, but I don't care about scanning flows, or any high-volume flows
for that matter (even attacking). Suricata is currently set up to also log TCP
SYN, ACK, FIN, etc. packets, so I can simply turn that off, but, again, I need
to know that these happen.

_Meanwhile_...

= Week 44

== An Incident

I cut off the last part, because I just wanted to start collecting some data.
The problem, however, came in the form of actual attacks being launched in the
samples! #footnote[Yay!]. While this is great for data collection, it does mean
that my Kibana instance and the VM I'm running the collector on, is being
flooded with data. A single sample was happily running without much trouble, but
managed to eat about 16GiB worth of PCAP from a handful of attacks (not to
mention the EVE JSON logs).

Now, what to do? I have some solutions for ensuring we don't get flooded with
data, but I first want to investigate whether everything is working as intended.

#figure(
  image("assets/kibana_mirai_attacking.png", width: 90%),
  caption: [Example of a Mirai sample (probably) launching attacks. Note the
    high packet rate and number of unique IP addresses. We can guess these are
    attacks because of the sustained high packet rate against for example
    `171.255.233.68`. Time range is from 26 October, around 18:00, to 23:00.],
)

#figure(
  image("assets/kibana_mirai_scanning.png", width: 90%),
  caption: [Example of a Mirai sample (probably) running a scan. Note the high packet rate
    and the 'Other' label in the bottom-right legend, indicating many unique IP
    addresses.],
)

Scrolling through the logs, could see that there was a surprising amount of
traffic coming from one of the C2 servers. This is sort of strange, since we
don't expect much traffic from the C2 server, and I wouldn't expect inetsim
sending us so much traffic either. I started increasingly to worry as I could see the gateway of my network having allowed more bandwith through than I expected.

#figure(
  image("assets/incident_unifi_network.png", width: 90%),
  caption: [Network usage of the PC running the analysis. Note the spike around
    18:00 on 26 October, corresponding to the time the Mirai sample started
    attacking. In total, 2.7GB of unlabeled SSL/TLS data was sent during the
    period.],
)

Sadly, I couldn't find any more information about this traffic in the logs. What
I care most about at this point, is to be able to say where that 3GB of data
went. Since it's only about 2.5GB, this is not all the traffic generated by the
sample, but I am concerned whether there is anything wrong with the setup. If
all this traffic is just C2, then it's not a problem, but if it's something
else, then I need to fix it.

The weird thing, is the the source IP of the active sample is `10.13.37.138`
which is not mentioned anywhere in the `nftables` rules (@nftables_ruleset). I
have saved the output of the running process, which gives us the content shown
in @long_running_log_output and clearly shows that the IP is removed from the
table when the process crashes due to insufficient memory. The IP address that
was allowed when running the sample is `213.209.143.62`.

I highly doubt something is seriously wrong with the setup, even though I've
adjusted some things in order to make it easier to work with (consolidated the
scripts and the suricata C2 reference, etc.). We can simply test this by sending
some traffic to for example Google's DNS server (`8.8.8.8`) and running
`tcpdump` on the outbound interface.

Using for example the following command:

```bash
talkbox analysis run-long ./tests/godos 100.100.100.100 --sample-args "synflood 1.1.1.1 --rate 1"
```

We do see that traffic is being sent to `1.1.1.1` (the default destination port
is `80`, but since only `udp 53` is allowed this should behave like any other
destination), but it doesn't appear on the `ens18` bridge which is used for
outbound traffic. Indeed, we do see traffic on the `br_inet` interface which
contains the DNATed addresses, and `br_lab` contains the addresses we expect
with the source in the VM range (`10.13.37.112`) and the destination `1.1.1.1`.

If we now change `100.100.100.100` to `1.1.1.1`, we _should_ see traffic on the
`ens18` interface:

#figure(
  ```bash
  # tcpdump -i ens18 host 1.1.1.1
  tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
  listening on ens18, link-type EN10MB (Ethernet), snapshot length 262144 bytes
  07:04:42.718325 IP debian.25685 > one.one.one.one.http: Flags [S], seq 3022054465, win 14600, length 0
  07:04:42.723052 IP one.one.one.one.http > debian.25685: Flags [S.], seq 3921024218, ack 3022054466, win 65280, options [mss 960], length 0
  07:04:42.726039 IP debian.25685 > one.one.one.one.http: Flags [R], seq 3022054466, win 0, length 0
  # [...]
  07:04:47.717396 IP debian.25685 > one.one.one.one.http: Flags [S], seq 2465218492, win 14600, length 0
  07:04:47.725803 IP one.one.one.one.http > debian.25685: Flags [S.], seq 3999145591, ack 2465218493, win 65280, options [mss 960], length 0
  07:04:47.726099 IP debian.25685 > one.one.one.one.http: Flags [R], seq 2465218493, win 0, length 0
  ```,
  caption: [Traffic being sent to `1.1.1.1` is visible on the outbound interface
    `ens18`, showing that whitelisting is working as intended.],
)

This shows that the whitelisting is working as intended, and that there is
probably nothing wrong with either the `inetsim` DNAT configuration, or the
whitelisting. Moreover, this means that the only IP address that this traffic
could have gone to is the C2 server, or at least, the whitelisted IP address
(`213.209.143.62`).

Looking throught the logs for this IP address, I really only see super small
amounts of traffic, nothing that would explain the multiple gigabytes of data
being sent. If anything, the most likely explanation is that because this
happened when I was trying to improve the automation, I might have manually
allowed some IPs by mistake (which is something I do remember vaguely). I think
the most straightforward solution here is to set up some monitoring on the
outbound interface, alerting me when significant amounts of data are being sent.

== HA

it's literally just the elastic agent... mfw

== Continuing With Suricata

I'm running into some issues with Suricata again. It seems that setting xbits in alerts
runs per rule hit, not per trigger. One of the strange things that happened was
that I also got alerts for, for example, `1.1.1.1` while I was flooding
`3.3.3.3`. Take the following:

#figure(
  ```rules
  alert udp $HOME_NET any -> !$HOME_NET any (
    msg:"mark dst: high UDP packet rate (30s)";
    flow:to_server,stateless;
    detection_filter: track by_dst, count 150000, seconds 30;
    xbits:set, single_high_flow, track ip_dst, expire 30;
    noalert;
    sid:1000102; rev:2;
  )

  alert ip $HOME_NET any -> !$HOME_NET any (
    msg:"DDoS: destination under high packet rate (hot dst)";
    xbits:isset, single_high_flow, track ip_dst;
    threshold: type limit, track by_dst, count 1, seconds 30;
    tag:host,100,packets,dst; # keep the current + next 100 packets
    classtype:attempted-dos;
    sid:1000103; rev:3;
  )
  ```,
  caption: [Rules that are supposed to detect high rates of UDP packets by
    setting the `xbit` for a particular destination. Using the `tag` keyword, we
    would save a certain number of packets for further analysis.],
) <suricata_packet_rate_rules>

You'd think that the first rule would set the xbit if a particular destination
exceeds the given threshold, but you would be mistaken. The thresholding is only
applied to the alert that is raised, meaning that the xbit is set for every single
packet that matches the first rule, regardless of whether the threshold has been
exceeded.

This is also what happens when we use tagging (see
@suricata_packet_rate_rules:14) -- every packet that matches the second rule is
tagged, regardless of whether the threshold has been exceeded.  This means that
if we tag the first 100 packets after the rule is matched, we will actually save
_all_ packets that match the rule in the 30 second window, because the rule is
constantly matched, the alert is just not raised.

We _can_ use these rules to detect high packet rates, but this comes at the cost
of being able to save packets for further analysis. Before, this might have been
acceptable, but now that we want to analyze attacks, this won't fly. Either we
have to be creative, or implement our own solution.


= Week 45

== Suricata, WHY?

All right, after trying hard to make Suricata work, I've come to the conclusion
that it's just not worth the hassle. The xbit setting and thresholding is just
too weird to deal with effectively. Therefore, I've opted to go back to the Go
implementation, and include a feature where it dumps a certain amount of packets
in case of an attack. Introducing: `gomon`.

#quote(block: true)[
  `gomon` ingests live traffic or PCAP captures generated by sandboxed bots and
  identifies time windows that exceed packet-rate or destination-IP thresholds. The tool logs
  structured alerts that highlight scans or bursts of suspicious activity.
]

Taking some of the examples such as `synflood_high` and `telnetscan`:

#figure(
  ```json
  {
      "time": "2025-11-06T10:36:20.399347+01:00",
      "level": "INFO",
      "msg": "Detected an attack",
      "type": "event",
      "classification": "attack",
      "scope": "local",
      "@timestamp": "2025-10-23T11:22:36.348563+02:00",
      "packet_rate": 58121.933333333334,
      "packet_threshold": 5,
      "src_ip": "10.13.37.109",
      "dst_ip": "100.100.100.100"
  }
  ```,
  caption: [Example alert generated by `gomon` when detecting a SYN flood attack.],
)

#figure(
  ```json
  {
      "time": "2025-11-06T10:34:28.505231+01:00",
      "level": "INFO",
      "msg": "Detected a scan",
      "type": "event",
      "classification": "scanning",
      "scope": "global",
      "@timestamp": "2025-10-22T16:41:02.39798+02:00",
      "packet_rate": 376.2,
      "packet_threshold": 5,
      "ip_rate": 375.46666666666664,
      "ip_rate_threshold": 10,
      "src_ip": "10.13.37.145"
  }
  ```,
  caption: [Example alert generated by `gomon` when detecting a scanning activity.],
)

The nice thing is that we can, as mentioned before, also easily dump packets
when an attack is detected. This is done by specifying a `--save-packets` flag
which will save that many number of packets for each event that is generated
(for now only attacks).

Ideally, we would do all the analyses here, such as detecting C2 traffic, but for
now this is sufficient. We can always extend this later. Now, two things:

1. Ensure that `gomon` runs in `talkbox` long-running analyses.
2. Ingest the generated alerts into Kibana.

== Allowing for Incident Investigations

In line with the experience last week, I'm also running suricata in a very basic
configuration on the Sandbox Host to allow for investigations of incidents if
they are to occur. I've just turned off DNS logging since this is something we
_do_ allow in a rate-limited fashion. There is no ruleset, although we might be
able to do alerting through Kibana by checking for C2 IPs in the logs of the
host Suricata is running on.

== What Next

I'm annoyed at a couple of things:

- I can't clearly see which samples are running long-term analyses.
- If stuff crashes, I would have to restart all the samples.
- Even if I have PCAPs of attacks, I still have to manually inspect them.

Let's start with the first two points. I think the best method would literally just be a
file which contains the list of currently running long-term analyses. This way, I can easily
see which samples are running, and if something crashes, I can just read the file
and restart the analyses. Simple as that.

For the last point, I think I'll just worry about this when I actually have the
amount of data to analyze. For now, I just want to get the data.

What might actually be more important is to formalize extracting the C2 address
from a running sample by implementing it in `gomon`. If I can manage to do this
somewhat reliably (even if it's just a heuristic), then I can 'formally' call
*RQ2* done.

== It's Going Baby

I've updated `talkbox` to run as systemd services with proper logging and
everything. This makes it so much easier to manage long-running analyses, and
ensure that things are running properly. Updating is also much easier, since I
just pull the latest version and restart the services.

While ideally I would use `gomon`, I'm currently just using Suricata alerts to
detect C2 traffic, attacks, etc. This is mostly because I want to get data as
soon as possible, and setting up `gomon` properly in `talkbox` will take some
time.

One of the things I've seen happen is the following, where the DNS resolution
will exceed the rate-limit and, I think, it defaults back to using inetsim as
the resolver:

#image("assets/kibana_interesting_ip.png")

== Automatic 'Dying' of Long-Running Analyses

While scaling up production, I've noticed samples often keep receiving data from
the C2 server even if idling for a long time. If there is no data coming in,
it's generally not interesting to keep the sample running, so I've implemented a
mechanism where if no _data_ (i.e. no PSH/ACK packets) is received for a certain
amount of time, the sample will be automatically stopped.

== Too Many things

I'm encountering so many potentially interesting avenues to explore that I'm not
sure what to do next. These are the things that I can think of right now:

Implementation:

- Implement `gomon` properly in `talkbox` to generate alerts and dump packets.
- Implement C2 detection heuristics in `gomon` to automatically extract C2 IPs
  from running samples.
- Implement automatic shutdown of long-running analyses after a certain amount of
  idle time.

Analysis:
- Analyze strange stop-start behavior in Mirai sample (seems to be explicitly
  turned off by the C2 server).
- Analyze strange use of DNS in particular sample where many DNS servers are
  used.

The analysis I can always do later. I guess the point now is to ensure I have as
much interesting data in order to analyze later. Therefore, I think the most
important next step is to implement `gomon` properly in `talkbox` so that I can
start collecting alerts and packet dumps for further analysis.

In line with this, I've updated `gomon` to be compatible with the Suricata
`eve.json` logs, making it easy to ingest existing logs into `gomon` for
analysis. After this, I've finished the couple of improvements for `talkbox` and
I am about to test whether this new setup works as intended. After the new `talkbox`
updates have been tested, I can integrate `gomon` into `talkbox`. With that, these are
the current long-running samples:

#figure(
  ```
  1. analysis run-long fad74bfd46c1473d56b6d40b3a6715c0f6cb6042a60f8117bc75be8582db68d4 196.251.66.212 [pid=1258411]
  2. analysis run-long 944a636126ececd0737b54418cc82bac38d3cf5a50696f8fdf40a2c187fcfd75 82.147.85.212 [pid=1258412]
  3. analysis run-long a5af8a3b9df5a58788f5f57e8ae7206c469ab566f6c5b4caecec4a32f44fcf52 84.201.5.31 [pid=2569363]
  4. analysis run-long faf35aa84f6fbb18c2404aa2622a968374b69e158f29c14113e1cfabfc731c56 98.235.88.109 [pid=2564773]
  5. analysis run-long afa78ad97b923ad40b2b8f8fddf66561ffd6d9f3cb867a1dfce3fa9ee745d084 196.251.72.110 [pid=2560895]
  6. analysis run-long 74017ac31f136246137c96d70f696e92bafbee2d893af905a09adea616394655 156.231.113.109 [pid=341405]
  7. analysis run-long 767ca499e9a7b6f1ef385f1f15233d07de1bf929af4a685afacae59d8e092ffa 160.30.136.37 [pid=190560]
  8. analysis run-long 0165942d9b8d742c06314183248313f5f30c45ca8ad0928ffbfcd1b09eab1826 143.20.185.225 [pid=196633]
  9. analysis run-long a7e4a8a3e820f0694211d21228136a78b42e83c53d6a4635653d1b74ff182ce4 213.209.143.41 [pid=201167]
  10. analysis run-long 36497c369fe3888656b6631812e02b76309c64e994ee36b1ed7e31beff735bf 151.243.109.14
  11. analysis run-long 24dc82d5cf6ed929fa931f38be674fef12256c10d6dbbccab4123cb7d047173f 94.154.35.153 [pid=196634]
  12. analysis run-long 6920359391e39f67f68fd77bf6f5ed2570c70ec8bcc0b660f43f6a0f4f39ca2e 65.222.202.53 [pid=192897]
  13. analysis run-long 3d7c0f1f1db4925e3d4c610dd14aa71fddbcd1d7e03cead186719d3f6f2422a5 196.251.72.110 [pid=1923697]
  14. analysis run-long 1a1999152e039a3fb1fcbbeaeb4396c09a6d261bdd9a3638a79e11a03227719f 176.65.132.77 [pid=1953788]
  ```,
  caption: [Currently running long-term analyses in `talkbox`.],
)

= Week 46

It's been a while since I've written anything here. Last week was a bit rough as
I was incredibly stressed, lesson learnt: fun things can still bring stress. The
project, however, is going well.

I am kind of going all over the place because I am nearing the end of the
features we want to add/need to answer the research questions. Furthermore, I
have proof that the setup works as intended and I was running into stability
issues with Python and libvirt.

The idea was that I would integrate `gomon` into `talkbox` and iteratively fix
the stability issues. Over the weekend, however, I played around with libvirt in
Go and before I knew it, I had a working prototype of `talkbox` written in Go.
This was already much more stable than the Python version, so I decided to just
_go_ all in and rewrite the entire thing in Go.

== Project Components

During this reimplementation, I have also separated out some of the
functionality into different components in order to make development easier. In
true _Go_ philosophy, I've made smaller components that do one thing well, and can
be composed together to form the final product. The components are as follows:

- `godos`: A small tool to generate different types of network traffic. This is
  mostly useful for testing and generating traffic in the sandboxed VMs.
- `gomon`: A tool to monitor network traffic and generate alerts based on
  packet rates and unique IP rates. This is mostly useful for detecting attacks
  and scanning activity in the sandboxed VMs.
- `bottle`: The core library to deploy analyses through libvirt and additional
  instrumentation. It provides functionality to create VMs, configure networking,
  and run analyses. Most importantly for this project, is that it exposes a daemon
  `bottled` which can be used to launch analyses through a unix socket.
- `bottle-warden`: A small daemon that runs on the sandbox host and exposes an
  HTTP API to launch analyses through `bottled` and monitors analyses through the
  eve logs generated by the instrumentation. Using this data, it can decide to stop
  analyses to save on resources. It also integrates with MalwareBazaar to fetch samples
  if they are not present locally, and watches for new samples being submitted to the
  platform.

Currently, I'm confident in the implementation of `bottle` which is a
significant part. Everything in `bottle-warden` is still rough (and highly
generated); ideally I would implement this in Elixir (free concurrency and all
that), but for now, Go will have to do. The important part is that I can launch
analyses and monitor them properly.


= Week 47

I've been running the new Go-based `talkbox` implementation for a couple of days
now, and it seems to be working well. The stability has improved significantly,
and I can easily launch and monitor analyses. I've just started running it on
the TU Delft servers again, so we will see how it goes.

What to do next? Well, I have a first-stage review planned for the 12th of
December (in two weeks). Until then, I want to collect as much data as possible.

== Isolation Questions

Should c2 passthrough prohibit communication over DNS and NTP ports? No, because
we can't spoof source IP, we can't use these for amplification attacks.

== Post-progress Meeting Throughts

I need to get back to focusing on the research questions instead of engineering.
I have things:

- _What was the cause of the many file reads?_ I need proxmox logs to be able to
  investigate (I think). I have a couple of hyptheses:
  - Networking instrumentation is interpreted as file reads. Possible, need to
    investigate.
  - The VM is swapping. Unlikely, since I have plenty of RAM, but we can verify this.
- Limit the number of concurrent no-c2 analyses. These are only short-lived, so I can
  just queue them up.

This week I only have one goal: *get as much data as possible*.

== Fixes and fixes

I'm currently working mainly on fixing bugs in gomon. There were some issues
with data included in eve logs (or lack thereof) and I'm mainly running tests to
ensure that everything is working as intended.

An example issue is that of missing protocols and ports in the reported alerts.
The ports are necessary to determine whether something could be an 'interesting'
outbound connection. For example, 123 and 53 are not (necessarily) interesting
because DNS and NTP are expected to be used. Since we use this information to
determine C2 candidates it's important to note that we, thus, disregard these
protocols from consideration. If DNS and NTP are used for C2, then we would miss
these.

== C2 Detection

I'm also working on improving the C2 detection heuristics, and I've come to the
following conclusion. We're explicitly trying to look for C2 traffic that
corresponds to an explicit C2 server.

I'm running into an intesesting problem with stagers. Some of the samples
seem to be stagers that download the actual payload from a C2 server. This is
problematic because the stager might not have any interesting C2 traffic, but
the actual payload does.

== Automatic Long-running Analysis

For implementing automatic long-running analyses, we have the following limitations:

- We need to be able to extract the C2 IP address from the initial analysis:
  This means that multi-stage samples won't work, and that C2 communication over
  DNS/NTP won't be detected.
- In order to establish 'interesting' IPs, one of the main issues is scanning.
  Currently, we can detect scanning activity and ensure that we do not emit
  'outbound connection' events in `gomon`. However, some IPs might lie just
  outside the window and will still be considered 'interesting'.

The first point is not necessarily problematic, I'm happy to accept this as a
limitation. The second point is more annoying as it might lead to a large number
of unnecessary analyses that could overwhelm the system.

As it stands, we can limit the number of concurrent analyses with and without C2
address. I've currently set the limits as follows:

#figure(
  ```yaml
  orchestrator:
      max_concurrent_no_c2: 3
      max_concurrent: 30

  monitoring:
      enabled: true
      eve_path: /var/log/suricata/eve.json
      check_interval: 35s # slightly larger than default gomon timewindow of 30s
      default_timeout: 6h # can be very large since malwarebazaar has a separate timeout
      analysis_timeout: 0m # disable analysis timeout
      alerts:
          - sid: 1000011 # C2 Traffic: C2 Communicates with Sandbox (PSH)
            timeout: 12h

  malwarebazaar:
      enabled: true
      api_key: <no-chance-cowboy>
      base_url: https://mb-api.abuse.ch/api/v1/
      sample_dir: data/samples
      watcher:
          enabled: true
          watch_interval: 1h
          instrumentation: /opt/bottle-warden/instrumentation/default.yaml
          timeout: 5m
          lookback_hours: 1
          signatures:
              - mirai
  ```,
  caption: [ The current configuration of `bottle` for orchestrating analyses. ],
)

What we want to limit here is the number of concurrent analyses with the same
sample. This is to prevent the system from being overwhelmed by a single
sample that has many different 'interesting' IPs. Adding that feature is not
hard, but given that the 'timeout' is quite large (12 hours), the risk of
missing important info is quite large because of quick C2 turnover.

There are a couple of solutions to this:
- Ensure that the _most_ interesting IPs are analyzed first. This way, we can
  ensure that even if we miss some IPs, we at least get the most important ones.
- Introduce a new timeout system in the alert monitor that times out based on time
  since start.

= Week 48

== ELASTIIIC

Elastic search has decided the _trial_ has expired and now I am without alerts.
Woop-die-woop I have to do a whole-ass migration to ensure I can still run
scheduled searches. The alternative would have been to somehow do searches in
elastic from code or whatever, but since I had already been thinking about what
I would need in order to migrate to clickhouse I decided that might be the most effective approach.

'Lo and behold, we are making progress. The database and schema are up,
`eve.json` is pushed to clickhouse using a _Vector_ agent, and we can start
analyses from _n8n_ by doing various searches. I just want to collect data, why is the universe doing this to me.

== Interesting IPs

Right now I have an SQL query 'interesting IPs' from any active analysis. Since
we're now able to distinguish between scans and regular connections, we can
somewhat safely let any sample connect with a new IP address that is not
associated with DNS and/or NTP traffic, a scan, or is otherwise 'attacked'. We
extract these both from connection attempts, as well as dns resolutions.

This is rather fickle, and I haven't really tested this, but it's worth a shot.
The primary goal of this approach is to allow for the same C2 detection
capability with or without a whitelisted C2 server. It works perfectly fine for
non-whitelisted runs, but might be problematic in the context of a C2 server:

- If a second stage is downloaded and executed, we can restart the analysis with
  a new C2, but this will not activate.
- If the sample gets a new C2 server from the current C2, restarting the
  analysis with the new C2 will not activate.

In case a 'round robin' approach is used and the sample tries to connect to
various C2 servers that are tracked internally, this should work _in theory_.
One solution to the above could be allowing multiple hosts at once if we're
confident that both are actual C2 servers and not victims. For now, this is
considered too risky.

== Full Automation

I've just made the full pipeline of determining an interesting IP and then
submitting the analysis!

== Most of the kinks are out!

One of the things I'm still struggling with is stagers. Because they do talk
with the C2 server once, we no longer treat it as 'from_start' and these
timeouts are much larger. We might instead require a minimum time between the
first and last alert to allow for the sample to be considered 'active'.

== Pushing SOTA?

Something cool is actually that we can find C2 addresses that for example
hatching triage isn't able to find. We can clearly see that the following hash
doesn't have a corresponding C2 server in hatching triage:
#link("https://tria.ge/251205-wxa1zstmhl")[`08db6057a8dd814e12530d62c955db924c4b6aa0373102012b18df8dd64ff605`].

This hash appears twice in the running analyses (and many more times actually) because of many interesting IPs found in the initial stage.

#figure(
  image("/assets/image-3.png"),
  caption: [Screencapture of the list of analyses automatically started for the aforementioned hash.],
)

For bot alerts, we can see when the last time a particular C2/beaconing alert has triggered:

#figure(
  table(
    columns: 4,
    [_Analysis ID_], [_C2 IP (guess)_], [Sandbox to C2 (SYN)], [C2 to Sandbox (+Data)],
    [*aae72411*], [*45.153.34.74*], [*12/5/2025 | 9:55:29 PM*], [*12/5/2025 | 9:55:14 PM*],
    [890e234b], [104.131.23.252], [None], [None],
  ),
  caption: [The bottle 'monitor' keeps track of various beaconing/c2 traffic related alerts. We can see that the analysis ip 45.153... (bold) has triggered relevant alerts while the other hasn't],
)

Investigating the IP address in _Censys_
#footnote[https://platform.censys.io/hosts/45.153.34.74], we find that the
service is hosted in a bulletproof hosting provider (according to censys)
indicating that this is at least suspicious. This indication together with the
beaconing to that IP _only_ indicates strongly that this is actually a C2 server.


= Week 49

Oh yeah, bby. This is gonna be a good one (hopefully).

== Interesting Stuff at Dec 5 22:15

It seems like a lot happened, but the results are (in hindsight) a bit strange.
Looking at @stuff_dec_5, we see that a lot of attacks are (seemingly) performed,
the source of these alerts is Suricata, but we would also expect `gomon` alerts
for that same traffic.

#figure(
  image("/assets/Screenshot 2025-12-04 at 23.34.04.png"),
  caption: [
    It seems like many attacks have been executed which makes sense given the
    active C2 traffic (notice the PSH events, ignore 'Last Command' it didn't
    work at the time). However, `gomon` doesn't seem to throw events which is
    unexpected.
  ],
) <stuff_dec_5>

After reviewing, there was a mistake in the query for the Attack panel. The updated version can be found in @stuff_dec_5_updated

#figure(
  image("/assets/image-4.png"),
  caption: [
    updated 'Attacks' panel with working query. Notice that only a single attack
    was found by `gomon` which was a day earlier than the other events (this was
    a separate run).
  ],
) <stuff_dec_5_updated>

Even more strange, is that the analysis host died shortly after the last series
of attacks. The fact that `gomon` didn't raise alerts in the second section and
and the host died shortly after are, I think, not coincidences.

If we look at the RAM usage in @vm_resource_usage, we can see when such a
'death' scenario occurs. As shown, the RAM is saturated, and the number of
'reads' is very high. One explanation might be swap use in the 'inner' VMs,
however, this should reflect high reads _and_ writes.

#figure(
  grid(
    rows: 2,
    gutter: .5cm,
    image("/assets/image-5.png"),
    image("/assets/image-7.png"),
  ),
) <vm_resource_usage>

== Fixes in Gomon, cool results

Okay, great little moment. About a week ago I was monitoring a sample with the
hash `2df09bfb9a61837bdc68cd2c895e4802deb2148198d76e4b5988bc90c01980c4`. At that
point, it was communicating with C2 address `131.153.171.146` as shown in
@stuff_dec_5. Now, I have restarted that analysis _and_, we see beaconing to a
different IP address in @sample_diff_c2

#figure(
  grid(
    rows: 2,
    gutter: .5cm,
    image("/assets/image-8.png"),
    image("/assets/image-9.png"),
  ),
  caption: [
    Old sample and C2 address, that worked in a previous analysis, doesn't
    display any interesting behavior other than beaconing to another IP (top). This IP
    is then picked up by the pipeline and restarted as a functional sample (bottom).
  ],
) <sample_diff_c2>

= Week 50

Nice, we've just passed the first-stage review! Now, on to preparing for
analysis and scaling up! One thing to add is that there are some concerns with
regard to the isolation of the malware in the VMs, so we will first provide a
attack surface analysis of the malware on the VMs and prioritized mitigations to
reduce this risk.

== Threat Analysis is Done

Nice, just finished the report! Now, what can I do?

== What still needs to be done

- Replace old builds of VMs with new ones
- Ensure we also have working MIPs and ARMv5 builds

- PCAP ingestion (need Harm)
- ClickHouse credentials service account (need Harm)

- Increase segmentation of lab VM (need Maarten)

= Appendix

#figure(
  ```go
  // github.com/cochaviz/godos/internal/synflood.go
  // [...]

  	// create packet
  	packet, err := makeSynPacket(srcIP, srcPort, dstIP, dstPort)
  	if err != nil {

  	}

  	// send at the rate until context is done
  	for {
  		if ctx.Err() != nil {
  			return ctx.Err()
  		}

  		if err := syscall.Sendto(fd, packet, 0, sa); err != nil {
  			return err
  		}

  		sleep := time.Second / time.Duration(rate)
  		time.Sleep(sleep)
  	}

  // [...]
  ```,
  caption: [Simplified code snippet of the SYN flood implementation in `godos`.],
) <godos_synflood>


#figure(
  ```sh
  INFO | Target 30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541 not found locally. Downloading from MalwareBazaar into samples/malwarebazaar
  INFO | Downloaded sample 30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541 to samples/malwarebazaar/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  INFO | [1/1] Analyzing samples/malwarebazaar/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  DEBUG:pwnlib.elf.elf:'/home/john/research/talkbox/samples/malwarebazaar/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf' is statically linked, skipping GOT/PLT symbols
  INFO | Auto-detected sample architecture: i386 (from 'i386')
  INFO | Launching sandbox for iterative analysis with infinite iterations (timeout=120s)
  INFO | Starting sandbox domain 'sandbox-i386-205927' with sample '30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf' on network 'lab_net'
  INFO | Domain sandbox-i386-205927 started; preparing guest environment (mounts and networking)
  INFO | Guest prepared: setup_mount=/mnt/setup sample_mount=/mnt/sample staged_sample=/root/sample/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf vm_ip=10.13.37.138
  INFO | Domain sandbox-i386-205927 started. Setup mounted at /mnt/setup, Sample mounted at /mnt/sample, Staged sample at /root/sample/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf, IP: 10.13.37.138
  INFO | Executing pin DHCP lease for sandbox VM via /home/john/research/talkbox/init_host/network/pin_dhcp_lease.sh sandbox-i386-205927 lab_net
  VM:        sandbox-i386-205927
  Network:   lab_net
  MAC:       52:54:00:d1:3b:d1
  Lease IP:  10.13.37.138
  Pinning lease with: <host mac='52:54:00:d1:3b:d1' ip='10.13.37.138'/>
  Updated network lab_net live state
  Updated network lab_net persistent config
  Done. Lease pinned for sandbox-i386-205927 on 'lab_net' -> 10.13.37.138
  INFO | Executing whitelist 213.209.143.62 for sandbox VM sandbox-i386-205927 via /home/john/research/talkbox/init_host/network/whitelist_ip_for_vm.sh 10.13.37.138 213.209.143.62
  [+] Added: allow:10.13.37.138->213.209.143.62
  INFO | Auto-selected interface vnet108 for domain sandbox-i386-205927
  INFO | Initialized analysis helpers for domain sandbox-i386-205927: capture=/home/john/research/talkbox/logs/20251026-114050-30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541-10_13_37_138/20251026-114050-30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541-10_13_37_138.pcap
  INFO | Identified executable sample: /root/sample/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  INFO | Delaying execution by 2 seconds
  INFO | Background execution started for sample /root/sample/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf (pid=<unknown>)
  INFO | Iteration 1/∞ running for sample 30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  INFO | analysis_iteration
  INFO | Iteration 2/∞ running for sample 30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  [...]
  INFO | Iteration 343/∞ running for sample 30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  INFO | analysis_iteration
  INFO | Iteration 344/∞ running for sample 30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf
  INFO | Stopping sandbox after iterative analysis
  INFO | Stopping tcpdump capture
  INFO | Executing remove pinned DHCP lease for sandbox-i386-205927 via /home/john/research/talkbox/init_host/network/pin_dhcp_lease.sh --remove sandbox-i386-205927 lab_net
  Error: Domain 'sandbox-i386-205927' not found.
  INFO | Executing remove whitelist 10.13.37.138->213.209.143.62 via /home/john/research/talkbox/init_host/network/whitelist_ip_for_vm.sh -r 10.13.37.138 213.209.143.62
  [-] Removed: allow:10.13.37.138->213.209.143.62 (if it existed)
  WARNING | Failed to clean up host network access: Failed to remove pinned DHCP lease for sandbox-i386-205927: Command '['/home/john/research/talkbox/init_host/network/pin_dhcp_lease.sh', '--remove', 'sandbox-i386-205927', 'lab_net']' returned non-zero exit status 1.
  ERROR | [1/1] Failed to analyze samples/malwarebazaar/30bb3dc856c0b73e0e467eb55c98dd736f545e2d6aa2f73e81985f1a7768b541.elf: [Errno 28] No space left on device
  OSError: [Errno 28] No space left on device

  During handling of the above exception, another exception occurred:

  Traceback (most recent call last):
    File "/home/john/research/talkbox/talkbox/cli.py", line 275, in _run_analysis_batch
      snapshots = run_long_analysis(
                  ^^^^^^^^^^^^^^^^^^
      ...<3 lines>...
      if not snapshots:
      ^
    File "/home/john/research/talkbox/talkbox/analysis/run.py", line 919, in run_iterative_analysis
      suricata_uses_global_logs=prep_result.suricata_uses_global_logs,
    File "/usr/lib/python3.13/pathlib/_local.py", line 557, in write_text
      return PathBase.write_text(self, data, encoding, errors, newline)
             ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/usr/lib/python3.13/pathlib/_abc.py", line 651, in write_text
      with self.open(mode='w', encoding=encoding, errors=errors, newline=newline) as f:
           ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  OSError: [Errno 28] No space left on device
  ```,
  caption: [Output of running long-running analysis which ran out of disk space. Note the VM IP `10.13.37.138`.],
)<long_running_log_output>


#figure(
  ```nft
  table ip lab_nat {
  	chain prerouting {
  		type nat hook prerouting priority dstnat; policy accept;
  		ip saddr 10.13.37.105 ip daddr 65.222.202.53 counter packets 8700 bytes 522000 accept comment "allow:10.13.37.105->65.222.202.53"
  		ip saddr 10.13.37.111 ip daddr 213.209.143.62 counter packets 2 bytes 120 accept comment "allow:10.13.37.111->213.209.143.62"
  		ip saddr 10.13.37.105 ip daddr 196.251.70.188 counter packets 0 bytes 0 accept comment "allow:10.13.37.105->196.251.70.188"
  		ip saddr 10.13.37.124 ip daddr 144.172.109.62 counter packets 56616 bytes 3396960 accept comment "allow:10.13.37.124->144.172.109.62"
  		ip saddr 10.13.37.0/24 counter packets 9246327 bytes 1756620407 meta nftrace set 1
  		ip saddr 10.13.37.0/24 ip daddr { 1.1.1.1, 8.8.8.8 } udp dport 53 limit rate 60/minute burst 30 packets counter packets 376925 bytes 26476182 accept
  		ip saddr 10.13.37.0/24 ip daddr { 1.1.1.1, 8.8.8.8 } tcp dport 53 limit rate 60/minute burst 30 packets counter packets 0 bytes 0 accept
  		ip saddr 10.13.37.0/24 udp dport 53 counter packets 183027 bytes 12829540 dnat to 10.66.66.2:53
  		ip saddr 10.13.37.0/24 tcp dport 53 counter packets 0 bytes 0 dnat to 10.66.66.2:53
  		ip saddr 10.13.37.0/24 ip daddr != { 10.13.37.0/24, 10.66.66.0/24, 224.0.0.0/4, 255.255.255.255 } meta l4proto { tcp, udp } counter packets 6915458 bytes 1444154608 dnat to 10.66.66.2
  		ip saddr 10.13.37.0/24 icmp type echo-request ip daddr != { 10.13.37.0/24, 10.66.66.0/24, 224.0.0.0/4, 255.255.255.255 } counter packets 0 bytes 0 dnat to 10.66.66.2
  	}

  	chain postrouting {
  		type nat hook postrouting priority srcnat; policy accept;
  		ip saddr 10.13.37.0/24 counter packets 7540521 bytes 1487397187 masquerade
  	}
  }
  table inet lab_flt {
  	chain input {
  		type filter hook input priority filter; policy accept;
  	}

  	chain output {
  		type filter hook output priority filter; policy accept;
  	}

  	chain forward {
  		type filter hook forward priority -100; policy drop;
  		ip saddr 10.13.37.105 ip daddr 65.222.202.53 counter packets 37113 bytes 2125976 accept comment "allow:10.13.37.105->65.222.202.53"
  		ip saddr 10.13.37.111 ip daddr 213.209.143.62 counter packets 8 bytes 442 accept comment "allow:10.13.37.111->213.209.143.62"
  		ip saddr 10.13.37.105 ip daddr 196.251.70.188 counter packets 0 bytes 0 accept comment "allow:10.13.37.105->196.251.70.188"
  		ip saddr 10.13.37.124 ip daddr 144.172.109.62 counter packets 239984 bytes 13239180 accept comment "allow:10.13.37.124->144.172.109.62"
  		ct state established,related counter packets 7696270 bytes 339358995 accept
  		ip saddr 10.13.37.0/24 ip daddr { 1.1.1.1, 8.8.8.8 } udp dport 53 limit rate 60/minute burst 30 packets counter packets 377238 bytes 26496434 accept
  		ip saddr 10.13.37.0/24 ip daddr { 1.1.1.1, 8.8.8.8 } tcp dport 53 limit rate 60/minute burst 30 packets counter packets 0 bytes 0 accept
  		oifname "br_inet" ip saddr 10.13.37.0/24 counter packets 90090185 bytes 33833530427 accept
  	}
  }
  ```,
  caption: [Current `nftables` ruleset for the lab network. Note the absence of any rules for `10.13.37.138`.],
) <nftables_ruleset>
