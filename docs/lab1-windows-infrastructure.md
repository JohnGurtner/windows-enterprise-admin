# Lab 1: Microsoft Windows Infrastructure

**Goal:** Install Windows Server 2022 on three bare-metal workstations and build an Active Directory
forest with a parent domain and two child domains, with remote access, automatic updates and time sync.

[← Back to overview](../README.md)

## Addressing plan

| Item | Value |
| --- | --- |
| Group subnet | 44.38.3.0/24, gateway 44.38.3.1 |
| G03SRV01 / G03SRV02 / G03SRV03 | 44.38.3.2 / .3 / .4 |
| Lab DNS servers | 44.2.1.44, 44.2.1.45 |
| Time sources | tick.cit.lcl / tock.cit.lcl |

| Server | Domain |
| --- | --- |
| G03SRV01 | `group03.c24200.cit.lcl` (forest root, NetBIOS `GROUP03`) |
| G03SRV02 | `c242-03-b.group03.c24200.cit.lcl` (child) |
| G03SRV03 | `c242-03-a.group03.c24200.cit.lcl` (child) |

## Procedure

### 1. Build the install media
1. Connected to the lab network over the department's OpenVPN profile.
2. Copied the Windows Server 2022 ISO, the Windows 11 ISO, the network drivers and Ventoy 1.0.99 from the
   lab file server to a USB drive.
3. Made the USB bootable with **Ventoy**, so one drive could boot any of the ISOs.

### 2. Install Windows Server 2022 on bare metal
1. Booted each workstation with **F12**, chose the USB under *UEFI Boot*, and picked the Server 2022 ISO
   from the Ventoy menu.
2. On the newer Dell Pro Tower Plus machines, UEFI USB boot had to be turned on first:
   *BIOS Setup → Boot Configuration → UEFI USB → Load Defaults*.

### 3. Base server configuration (all three servers)
1. **Server Manager → Add Roles and Features →** installed **Active Directory Domain Services**.
2. Disabled the unused second NIC (*Ethernet 2*).
3. Set a static IPv4 address: the server's IP from the table, mask `255.255.255.0`, gateway `44.38.3.1`,
   and the lab DNS servers.
4. Reset the local Administrator password to a strong one.
5. Renamed the servers **G03SRV01**, **G03SRV02** and **G03SRV03**.

### 4. Point the child-domain servers at the root DC (SRV02, SRV03)
- Turned off IPv6 on the NIC and set **Preferred DNS = 44.38.3.2** (G03SRV01), with the lab DNS as
  alternate. The child domains can only find the forest root through DNS.

### 5. Create the forest (G03SRV01)
1. *Promote this server to a domain controller → **Add a new forest***.
2. Root domain: `group03.c24200.cit.lcl`. NetBIOS: `GROUP03`. Set and recorded the DSRM password.
3. Installed and rebooted.

### 6. Add the child domains (G03SRV02 and G03SRV03)
1. *Promote this server to a domain controller → **Add a new domain to an existing forest***.
2. Parent domain: `group03.c24200.cit.lcl`. New domain name: `c242-03-b` on SRV02 and `c242-03-a` on SRV03.
3. Authenticated as `GROUP03\Administrator` (the forest root admin), set a DSRM password, installed and rebooted.

### 7. Remote Desktop
1. *Local Server → Remote Desktop →* allowed connections **only from computers running Remote Desktop
   with Network Level Authentication (NLA)**.
2. Added the root and child domain Administrators as allowed users.
3. In `secpol.msc` → *Local Policies → User Rights Assignment → **Allow log on through Remote Desktop
   Services***, added the same accounts.

### 8. Patching
1. Installed all pending Windows Updates.
2. In `gpedit.msc` → *Computer Configuration → Administrative Templates → Windows Components → Windows
   Update → **Automatic Updates Detection Frequency*** → Enabled, **12 hours**.

### 9. Time synchronization
Kerberos fails if clocks drift more than 5 minutes, so every server syncs to the lab time source:

```powershell
w32tm /config /manualpeerlist:"tick.cit.lcl" /syncfromflags:manual /reliable:YES /update
w32tm /resync
```

Then set the time zone to *Indiana (East)*.

## Result
One forest with three domains and three domain controllers, reachable over NLA-protected RDP, patched,
and time-synced. This is the foundation every later lab builds on.

## Security takeaways
- **NLA on RDP** makes users authenticate before a session is created, which shrinks the pre-auth attack surface.
- **Explicit "log on through RDS" rights** instead of leaving RDP open to every account.
- **Time sync is a security control.** Kerberos and log correlation both depend on it.
