#import "@preview/lilaq:0.5.0" as lq

#let show_diagram(
  data: "",
  show_events: false,
  attack_start: none,
  show_x_title: true,
) = {
  let data = json(data)
  let xs = data.rate.t_s
  let ys = data.rate.pps_30s
  let mean = data.rate.mean
  let evxs = data.events.t_s

  lq.diagram(
    width: 100%,
    height: 7cm,
    xlabel: if show_x_title {
      [Time since start (s)]
    } else {
      []
    },
    ylabel: [Packets / s],

    // 1) 30 s rate curve
    lq.plot(xs, ys, label: [Rate]),

    // 2) global mean line
    lq.hlines(mean, stroke: (dash: "dashed", paint: red), label: [Mean]),

    // 3) packet events (optional)
    if show_events {
      lq.vlines(
        ..evxs,
        stroke: (dash: "dashed", paint: black, thickness: 0.3pt),
        label: [Packet events],
      )
    },

    // 4) start-of-attack line (only if provided and > 0)
    if attack_start != none and attack_start > 0 {
      lq.vlines(
        attack_start,
        stroke: (paint: black, thickness: 0.5pt),
        label: [Start of attack],
      )
    },

    // Optional legend placement
    legend: (position: top + right),
  )
}

/// Plot unique IPs per second (trailing 30s), cropped to selected span.
/// - data: JSON text (use `read("scan_unique_ips.json")`)
/// - attack_start: optional seconds mark for vertical marker
#let show_unique_ip_rate(
  data: text,
  attack_start: none,
  show_x_title: true,
) = {
  let d = json(data)
  let xs = d.new_unique_ips.t_s
  let ys = d.new_unique_ips.ips_per_sec
  let mu = d.new_unique_ips.mean

  lq.diagram(
    width: 100%,
    height: 7cm,
    xlabel: if show_x_title { [Time since start (s)] } else { [] },
    ylabel: [New unique IPs / s (vs previous 30s)],

    lq.plot(xs, ys, label: [New unique IPs rate]),
    lq.hlines(mu, stroke: (dash: "dashed", paint: red), label: [Mean]),

    if attack_start != none and attack_start > 0 {
      lq.vlines(attack_start, stroke: (thickness: 0.5pt), label: [Start of attack])
    },

    legend: (position: top + right),
  )
}

