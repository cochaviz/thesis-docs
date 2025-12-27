#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/noteworthy:0.2.0": *
#import "@preview/ilm:1.4.2": *
#import "@preview/frame-it:1.2.0": *
#show: codly-init.with()

#codly(languages: codly-languages)

#show: ilm.with(
  paper-size: "a4",
  title: "Bottle Threat Analysis",
  author: "Zohar Cochavi",
  raw-text: (custom-font: "IBM Plex Mono"),
)

= Scope and Assumptions

Let's consider the most permissive scenario: the long-term pinholed analysis.
Any risk during the first-stage analysis will be reduced by the second stage,
but not eliminated: the first stage can still fingerprint the environment,
probe escape feasibility, and attempt denial-of-service or resource exhaustion.
The second stage does effectively perform the same experiment with more
permissions, but it does not retroactively undo any compromise or probing that
may have occurred during the first stage.

During this analysis, the malware has the following important capabilities:

- Root access to the QEMU VM
- Access to a single host address on the internet
- Access to inetsim

Because we expose this malware to the internet in a limited fashion, we have to
consider the impact on both our infrastructure and the internet as a whole. We
have discussed the possible impact on external infrastructure, but we have yet
to consider the risk and impact on the internal infrastructure.

The biggest concern is for the malware to somehow escape the sandbox through
some of the exposed interfaces: either through misconfigurations or known
vulnerabilities. This would mean an actor would have access to the host as the
user executing the virtual machines, with the possibility of lateral movement
and/or privilege escalation.

To estimate and mitigate this risk, we will first provide an inventory of the
paths an attacker could take to escape the sandbox, and consider the options for
impact once an escape took place. Mitigating these risks can, and should be,
multi-layered: not only should it be hard to escape the sandbox, it should also
be hard to make an impact once an actor has managed to escape. We will thus
propose various methods for hardening the sandboxes and the security on the
host.

Considering attack paths an adversary might take starts with understanding the
weakest parts of QEMU and how it should be configured. Either an attacker can
use a known or unknown vulnerability in QEMU, or abuse a (mis)configuration we
have implemented.

= Escape Paths

== Known Vulnerabilities

According to _Google Project Zero_, "the large majority of disclosed
vulnerabilities and all publicly available exploits affect QEMU and its support
for emulated/paravirtualized devices."
#footnote[https://projectzero.google/2021/06/an-epyc-escape-case-study-of-kvm.html]

This is something we can not eliminate: we deliberately run untrusted workloads,
we need to run multiple architectures, and our goal is not to make malware
"believe" it is on bare metal. In other words, QEMU is part of the trusted
computing base of the lab.

That said, QEMU is not a single blob. The attack surface is largely determined
by which virtual devices are exposed to the guest. In broad terms, QEMU can
expose either (1) emulated devices that mimic real hardware (legacy NICs, IDE,
USB controllers, etc.), or (2) paravirtualized devices such as VIRTIO, which use
a negotiated protocol (shared descriptor rings + notifications) implemented by
guest drivers.

Given the nature of paravirtualization, it is generally less prone to
vulnerabilities than emulation, and so there is an opportunity for risk
reduction there #footnote[Note that VIRTIO is easier for malware to detect than
  emulated hardware, resulting in potentially triggering anti-sandbox behavior.],
although risk is not completely mitigated. VIRTIO devices are still parsers of
guest-controlled data that run in the QEMU process, so memory corruption bugs
remain possible.

For this reason, keeping the host up-to-date and adopting defence-in-depth is
necessary.

== Misconfigurations

Preventing misconfigurations is hard or impossible, but can be aided by using
frameworks and/or libraries. Instead of using QEMU directly, we use `libvirt`
which, among other things, runs QEMU as a non-privileged user by default.
Investigating the consequences of the default network and domain configurations
#footnote[A _domain_ or _domain definition_ is the word `libvirt` uses to refer
  to a VM specification] we pass to `libvirt` is therefore a reasonable starting
point to scrutinize.

We discuss the base VM configuration (see @domain_base_config) and the devices
attached to the VM (see @domain_device_config), and we will look at the
configuration for the amd64 and arm64 VMs (see @domain_arch_profiles). After
which we will discuss the network configuration (see @domain_network_config).

= Configuration Analysis

In creating _bottle_, the primary goal of the configurations displayed here were
functional; prior to this analysis, hardening was not the primary design
objective. With that said, the analysis here will primarily consider the
security implications of the various configurations, and that in a limited
fashion. The actual implementations of the template configurationn are only
considered for two architectures for the sake of brevity, and a _worst case_
assumption is still the most appropriate.

== Base Domain Configuration

#figure(
  ```xml
  <domain type='qemu'>
    <name>{{ .Name }}</name>
    <memory unit='MiB'>{{ .RAM }}</memory>
    <currentMemory unit='MiB'>{{ .RAM }}</currentMemory>
    <vcpu placement='static'>{{ .VCPUs }}</vcpu>
    <os>
      <type{{ if .VirtArch }} arch='{{ .VirtArch }}'{{ end }}{{ if .Machine }} machine='{{ .Machine }}'{{ end }}>hvm</type>
  {{ if .KernelPath }}
      <kernel>{{ .KernelPath }}</kernel>
  {{ end }}
  {{ if .InitrdPath }}
      <initrd>{{ .InitrdPath }}</initrd>
  {{ end }}
  {{ if .KernelCmdline }}
      <cmdline>{{ .KernelCmdline }}</cmdline>
  {{ end }}
  {{ if not .KernelPath }}
      <boot dev='hd'/>
  {{ end }}
    </os>
    <features>
      <acpi/>
      <apic/>
    </features>
    <clock offset='utc'/>
    <on_poweroff>destroy</on_poweroff>
    <on_reboot>restart</on_reboot>
    <on_crash>destroy</on_crash>
    <devices>
      <!-- [...] -->
    </devices>
  </domain>
  ```,
  caption: [Non-device configuration for a lab VM.],
) <domain_base_config>

The base configuration is relatively standard, but it is worth noting that we
intentionally support booting either from a disk image (`<boot dev='hd'/>`) or
from a provided kernel/initrd (see `.KernelPath` and `.InitrdPath`). This means
the guest can execute a wide range of kernels, and therefore can adopt a wide
range of strategies for interacting with QEMU device models. In particular, a
guest with root access can load kernel modules and craft low-level interactions
with devices. In other words, we should assume the guest is able to exercise
device models adversarially.

== Storage Configuration

#figure(
  ```xml
  <devices>
      <disk type='file' device='disk'>
        <driver name='qemu' type='qcow2'/>
        <source file='{{ .Overlay }}'/>
        <target dev='{{ .DiskTarget }}' bus='{{ .DiskBus }}'/>
      </disk>
  {{ if .SetupDisk }}
      <disk type='file' device='cdrom'>
        <driver name='qemu' type='raw'/>
        <source file='{{ .SetupDisk.File }}'/>
        <target dev='{{ .SetupDisk.Target }}' bus='{{ .CDBus }}'/>
        <readonly/>
      </disk>
  {{ end }}
  {{ if .SampleDisk }}
      <disk type='file' device='cdrom'>
        <driver name='qemu' type='raw'/>
        <source file='{{ .SampleDisk.File }}'/>
        <target dev='{{ .SampleDisk.Target }}' bus='{{ .CDBus }}'/>
        <readonly/>
      </disk>
  {{ end }}
  {{ range .ExtraDisks }}
      <disk type='file' device='cdrom'>
        <driver name='qemu' type='raw'/>
        <source file='{{ .File }}'/>
        <target dev='{{ .Target }}' bus='{{ $.CDBus }}'/>
        <readonly/>
      </disk>
  {{ end }}
      <!-- ... -->
  ```,
  caption: [Disk configuration for a lab VM.],
) <domain_device_config>

The primary disk uses the qcow2 format and is attached using the configured
`.DiskBus`. For the architectures we currently deploy, `.DiskBus` is configured
as `virtio` (see @domain_arch_profiles). This is a good default: it avoids
exposing legacy storage controllers (e.g., IDE) and instead uses a VIRTIO block
device, which reduces the amount of device emulation code a hostile guest can
exercise.

However, note that read-only CD-ROM images are also attached. These are
configured as raw files and explicitly marked `<readonly/>`, which prevents the
guest from modifying the backing files. This reduces the risk of the guest using
the CD-ROM as a persistence mechanism or corrupting shared media. Nonetheless,
"read-only media" does not imply "no attack surface": the attack surface is
defined by the bus/controller and the device model, not by the mutability of
the backing file. A guest can still send adversarial command sequences to the
virtual controller and CD-ROM device.

We should therefore treat the CD bus (`.CDBus`) as an explicit attack-surface
decision: different buses pull in different controller/device code paths.

== Network and Peripheral Devices

#figure(
  ```xml
      <interface type='network'>
  {{ if .NetworkMAC }}
        <mac address='{{ .NetworkMAC }}'/>
  {{ end }}
        <source network='{{ .Network }}'/>
        <model type='{{ .NetworkModel }}'/>
      </interface>
      <console type='pty'>
        <target type='serial' port='0'/>
      </console>
      <serial type='pty'>
        <target port='0'/>
      </serial>
      <channel type='unix'>
        <target type='virtio' name='org.qemu.guest_agent.0'/>
      </channel>
      <rng model='virtio'>
        <backend model='random'>/dev/urandom</backend>
      </rng>
      <memballoon model='virtio'/>
    </devices>
  ```,
  caption: [Non-disk device configuration for a lab VM.],
)

The network interface is configured through `.NetworkModel`. For the VMs we
currently deploy, this is pinned to `virtio` (see @domain_arch_profiles). This
is important: older emulated NIC models (such as rtl8139, e1000, pcnet) have
historically had a disproportionate number of guest-to-host vulnerabilities.
Using VIRTIO reduces this legacy attack surface, though it does not eliminate
risk: VIRTIO-net remains a parser of guest-controlled descriptors and can still
contain vulnerabilities.

The serial console uses a pseudo-terminal. This is operationally useful and
allows us to observe boot and runtime behavior. While it is not typically a
primary VM escape surface, we should ensure that the host-side tooling that
consumes these PTYs treats output as untrusted (e.g., avoid terminal escape
sequence issues in log viewers).

== Guest Orchestration Interfaces

The configuration includes a VIRTIO channel intended for the QEMU Guest Agent
(`org.qemu.guest_agent.0`). This channel provides a structured host–guest
control interface that can be used for operations such as command execution,
file transfer, and lifecycle coordination.

In the current design, some orchestration functionality relies on the
availability of the QEMU Guest Agent. This implicitly expands the host–guest
interface surface: even though the guest is assumed to be compromised, QEMU
must still parse and process agent traffic, and host-side tooling may rely on
agent responses to drive automation.

However, the presence of the guest agent is not a strict requirement. The same
functionality can, in principle, be achieved using alternative mechanisms such
as automated execution of scripts during provisioning or controlled SSH access
to the VM. These approaches trade structured control for more conventional
interfaces, but they avoid exposing a dedicated host–guest control channel
implemented inside QEMU itself.

Given that this lab executes adversarial workloads, we should treat the guest
agent channel as an explicit design decision rather than a default. If the
guest agent is not strictly required, disabling this channel removes an entire
class of QEMU-facing protocol parsing. If the guest agent remains in use, we
must assume that the guest agent process is compromised and avoid host-side
workflows that implicitly trust agent responses or expose high-impact
operations through the agent interface.

The RNG and memory balloon devices are VIRTIO-based. These devices are smaller
interfaces than full legacy emulation, but they still expand the set of device
models exposed to an adversarial guest and therefore must be kept patched.

== Network Configuration

#figure(
  ```xml
  <network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
    <name>{{ .Name }}</name>
    <forward mode='route'/>
    <bridge name='{{ .Bridge }}' stp='off' delay='0'/>
    <ip address='{{ .GatewayIP }}' netmask='{{ .Netmask }}'>
      <dhcp>
        <range start='{{ .DHCPRangeStart }}' end='{{ .DHCPRangeEnd }}'/>
      </dhcp>
    </ip>
    <dnsmasq:options>
        <dnsmasq:option value='dhcp-option=3,{{ .GatewayIP }}'/>
  {{- if .DNSServers }}
        <dnsmasq:option value='dhcp-option=6,{{ join .DNSServers "," }}'/>
  {{- end }}
    </dnsmasq:options>
  </network>
  ```,
  caption: [Configuration of the network on to which the lab VMs attach. As we
    have custom routing rules atop of this, this is not representative of the full
    configuration.],
) <domain_network_config>

At the libvirt layer, the network is a routed virtual network with DHCP via
dnsmasq. The security-relevant aspect is not DHCP itself, but where this network
is allowed to route to. Since the malware has root in the guest, it should be
assumed capable of crafting arbitrary traffic, scanning any reachable address
space, and attempting to exploit reachable services.

For this reason, the enforcement point for "a single host address on the
internet" must be treated as a critical control. This control should not rely
on the guest, and it should not rely on "expected" traffic patterns. It must be
enforced on the host, ideally at multiple layers (routing policy and firewall),
and it should default-deny.

== Architecture Profiles

#figure(
  ```go
  makeSpec(
  	"debian-bookworm-amd64",
  	"amd64",
  	"ttyS0",
  	"https://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux",
  	"https://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz",
  	sandbox.DomainProfile{
  		Arch:         arch.X86_64,
  		VCPUs:        2,
  		RAMMB:        4096,
  		DiskBus:      "virtio",
  		DiskTarget:   "vda",
  		CDBus:        "sata",
  		CDPrefix:     "sd",
  		NetworkModel: "virtio",
  		ExtraArgs:    []string{"console=ttyS0,115200n8"},
  	},
  ),
  ```,
  caption: [Variables used in order to configure the AMD64 lab VM.],
)

#figure(
  ```go
  makeSpec(
  	"debian-bookworm-arm64",
  	"arm64",
  	"ttyAMA0",
  	"https://ftp.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/linux",
  	"https://ftp.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz",
  	sandbox.DomainProfile{
  		Arch:         arch.AArch64,
  		Machine:      strPtr("virt"),
  		CPUModel:     strPtr("cortex-a72"),
  		VCPUs:        2,
  		RAMMB:        4096,
  		DiskBus:      "virtio",
  		DiskTarget:   "vda",
  		CDBus:        "scsi",
  		CDPrefix:     "sd",
  		NetworkModel: "virtio",
  		ExtraArgs:    []string{"console=ttyAMA0,115200"},
  	},
  ),
  ```,
  caption: [Variables used to configure the ARMv7 (64 bit) lab VM.],
) <domain_arch_profiles>

The architecture profiles confirm that the main storage and networking devices
are pinned to VIRTIO (`DiskBus: "virtio"` and `NetworkModel: "virtio"`). This is
a deliberate risk reduction compared to exposing legacy device models.

However, the profiles also show that CD-ROM devices are attached via different
buses depending on the architecture:

- For amd64, `.CDBus` is set to `sata`, which implies use of a SATA/AHCI
  controller with an ATAPI CD-ROM device behind it.
- For arm64, `.CDBus` is set to `scsi` on the `virt` machine type.

These choices matter because controller/device emulation is a frequent source of
memory corruption vulnerabilities. A read-only ISO does not prevent the guest
from sending malformed or unexpected command sequences to the emulated
controller and device.

Given this, there are two opportunities for reducing risk in our current
configuration:

- Prefer paravirtualized or simpler controller models for CD-ROM attachments,
  rather than legacy SATA/AHCI where possible.
- If CD-ROM devices are only needed during provisioning, ensure they are not
  attached during long-term analysis runs.

Finally, note that the Debian installer kernel and initrd are retrieved from
Debian infrastructure. This is operationally convenient, but it should be
treated as part of the lab's trusted supply chain. To reduce exposure to
transient network issues or mirror compromise, it is preferable to cache these
artifacts locally and verify them (e.g., via published hashes or signatures).

= Defence in Depth

== Segmentation and Least Privilege

We have clearly shown that there is no guarantee that bad actors are fully
isolated in the lab. This means we should try to make escaping the sandbox
worthless and lateral movement or privilege escalation as hard as possible. In
effect, this comes down to maximal segmentation and applying least privilege
principles.

Currently, the lab host is connected to the TU Delft intranet in a limited
fashion, although it's not entirely clear to what extent. The functionality of
the lab relies on SSH access to control the experiments, and a connection with
the internal ClickHouse database to store results. To minimize the attack
surface, we should deny all connections with the intranet, save the database on
its native port (`9000`). The host can then still be reached via SSH over the
regular internet using a separate VPN.

The database credentials are stored in plaintext in files that are only
accessible to the root user, but the adversary could still escalate privileges
to access these credentials. Since the lab only needs to add data, we should
create a service user that is only allowed to insert rows in the table
`zohar.suricata_raw`. The worst-case impact the actor can immediately have on
the database is inserting many rows, potentially compromising availability.

In addition, we should assume that "insert-only" does not automatically imply
"low impact": an adversary can attempt to exhaust disk space, create pathologic
insert patterns that increase resource usage, or attempt to exploit ClickHouse
itself over the exposed port. As such, rate limiting, quotas, and strict network
allowlisting to the database host are required.

== Remote Access

If a separate VPN is used, the potential for escape from that VPN should also be
minimized. The current VPN is Tailscale, which allows for the creation of access
policies that (dis)allow traffic to flow from one member/device to another.
Concretely, we will only allow the user `zohar` to SSH into that machine,
disallowing all other access over the VPN.

== Monitoring and Detection

Even though this segmentation limits movement, they might be able to abuse many
other vectors which are unaccounted for; in the worst case, we are not limiting,
but merely slowing down. Slowing down an adversary is only valuable insofar as
it allows more time to discover a compromise. For this reason, monitoring is
incredibly important, and an EDR should be run on the lab host to minimize the
response time. In addition, logs should be shipped off the host (so they remain
available even if the host is compromised).

= Sandbox Hardening

The recommendations above focus on impact reduction: they are intended to limit
what an adversary can do _after_ an escape. Only once impact is minimized does
it make sense to further reduce the probability of escape by hardening the
sandbox itself.

Sandbox hardening in this context primarily means reducing the number and
complexity of QEMU device models exposed to the guest, and ensuring QEMU is
executed with the strongest feasible confinement.

Concretely:

- Prefer VIRTIO devices for disk and networking (already the case).
- Avoid legacy device models (e.g., rtl8139/e1000/pcnet NICs, USB controllers,
  audio devices, and graphics acceleration) unless strictly necessary.
- Avoid attaching CD-ROM devices during analysis unless needed, and prefer
  simpler or paravirtualized controllers where available.
- If the QEMU Guest Agent is not strictly required, disable the agent channel
  entirely and rely on alternative mechanisms such as automated script
  execution or SSH-based access for orchestration. This removes a dedicated
  host–guest control interface implemented inside QEMU.
- If the guest agent is required, assume the agent is compromised and restrict
  host-side usage accordingly; do not rely on agent-provided data or actions
  for security-sensitive decisions.
- Ensure the host and hypervisor stack (Linux kernel, QEMU, libvirt) receive
  security updates promptly to reduce exposure to known vulnerabilities.

These measures do not guarantee isolation, but they reduce exposure to the most
bug-dense parts of the virtualization stack.

= Recommendations

The mitigations below are prioritized by impact reduction first and escape
probability reduction second. The goal is not to assume that escape is
impossible, but to ensure that an escape yields minimal leverage.

1. Enforce a host-level default-deny policy for all lab traffic, and explicitly
  allow only: (a) the single permitted internet destination for pinholed
  analysis, (b) inetsim where applicable, and (c) the ClickHouse destination on
  TCP port 9000. This policy should be enforced independently of guest
  configuration, and ideally at multiple layers (routing policy and firewall).

2. Maximize segmentation between the lab host and the TU Delft intranet. The lab
  host should not be able to reach the intranet except the ClickHouse host on
  its native port. Administrative access to the lab host should occur only via
  a separate VPN, and the host should not provide unintended routing or transit
  between VPN, intranet, and VM networks.

3. Minimize the value of host compromise by applying least privilege for all
  credentials and services. Specifically, create a ClickHouse service account
  that can only insert rows in `zohar.suricata_raw`, and apply quotas and rate
  limits to preserve availability. Store any database credentials such that the
  QEMU user cannot read them by default.

4. Add monitoring sufficient to detect and respond to compromise. At minimum,
  run an EDR on the lab host and ship logs off-host so they remain available if
  the host is compromised. Treat unexpected QEMU crashes, repeated VM resets,
  or unusual traffic patterns as high-priority indicators.

5. Keep the host kernel, QEMU, and libvirt patched. Automatic updates should be
  enabled where operationally feasible, since known guest-to-host
  vulnerabilities are most commonly exploited when patching lags behind.

6. Reduce sandbox attack surface by minimizing exposed QEMU device models. Pin
  storage and networking to VIRTIO (already the case), avoid legacy device
  models, and avoid attaching CD-ROM devices during long-term analysis unless
  needed. Prefer simpler or paravirtualized controllers over legacy SATA/AHCI
  where possible.

7. Treat guest orchestration interfaces as optional. If the QEMU Guest Agent is
  not strictly required, disable the agent channel and use alternative methods
  such as automated script execution or SSH access. If the guest agent is
  required, assume it is compromised and ensure host-side automation does not
  implicitly trust agent responses.

= Conclusion

In this lab, we execute adversarial workloads with root inside the guest and
with constrained but real network access. Under these assumptions, sandbox
escape must be treated as plausible, since QEMU and its device models are part
of the lab's trusted computing base and are an historically frequent target for
guest-to-host vulnerabilities. We therefore prioritize impact reduction over the
assumption that escape can be prevented. The lab host must be maximally
segmented, run with least privilege, and monitored as if compromise is expected,
so that a successful escape yields minimal leverage and minimal opportunity for
lateral movement. Once the post-escape impact is minimized, sandbox hardening
should further reduce escape probability by minimizing device models and
optional interfaces, preferring VIRTIO where appropriate, and keeping the
virtualization stack patched.
