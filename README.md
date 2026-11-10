# Windows Enterprise Administration

> A full semester building and running a multi-site Windows Server enterprise for a fictional wood
> company, **WoodRock**. The work covers Active Directory, Group Policy, Nutanix virtualization,
> TrueNAS storage, backups, IIS, WSUS, DFS, print services and remote management, built by a team of three.

*CNIT 242 (Enterprise System Administration), Labs 1–5, Group 3.*

## What this repo contains

Each lab has its own write-up in [`docs/`](docs/) with the **full procedure**: what was built, the
exact settings and commands used, how it was verified, and what broke along the way and how we fixed it.

| Lab | Write-up | What gets built |
| --- | --- | --- |
| 1 | [Windows Infrastructure](docs/lab1-windows-infrastructure.md) | Bare-metal Windows Server installs, a new AD forest, two child domains, RDP, patching and time sync |
| 2 | [Windows Administration](docs/lab2-windows-administration.md) | OUs, AGDLP security groups, NTFS permissions, GPOs, folder redirection, roaming profiles, quotas, print server |
| 3 | [Enterprise Virtualization](docs/lab3-enterprise-virtualization.md) | Two Nutanix AHV clusters and Prism Central, golden-image templates, P2V migration of every DC, FSMO transfers, live migration |
| 4 | [Windows Server Administration](docs/lab4-windows-server-administration.md) | LDAP integration, TrueNAS SMB storage, scripted backups, a second AD site, Nutanix RBAC, IIS with tiered access control |
| 5 | [Windows Server Administration II](docs/lab5-windows-server-administration-2.md) | WSUS patch management, DFS namespaces and replication, print management, PowerShell remoting, Windows Admin Center |

Supporting files:

- [`scripts/`](scripts/): the backup rotation scripts, FSMO transfer commands and firewall rules used in the labs
- [`screenshots/`](screenshots/): configuration evidence from the original reports

## Final environment

```
                         AD forest: group03.c24200.cit.lcl
            ┌───────────────────────────┴────────────────────────────┐
   group03.c24200.cit.lcl (parent)                     c242-03-a.group03.c24200.cit.lcl (child)
   Accounting · HR · Executive                         Outside Sales · Inside Sales · Account Mgmt
   DCs: G03SRV01VM, G03SRV04 (site 2), G03SRV05        DC: G03SRV03VM

 Nutanix cluster G03NUTXSRV01 ─┐                   ┌─ Nutanix cluster G03NUTXSRV02
                               ├── Prism Central ──┤
                                                   
 Site 1  44.38.3.0/24    DCs, TrueNAS (BackupSet03 / GeneralSet03), IIS + WAC (G03SRV06),
                         WSUS (G03SRV07), Windows 11 clients
 Site 2  44.38.103.0/24  VLAN 1903, G03SRV04 (DC + DFS replica), G03S2WIN11
```

| Host | Role | Address |
| --- | --- | --- |
| G03SRV01VM | Parent-domain DC, DNS, file/print, DFS primary, backups | 44.38.3.31 |
| G03SRV03VM | Child-domain (c242-03-a) DC | 44.38.3.20 |
| G03SRV04 | Site-2 DC, DFS replica | 44.38.103.2 |
| G03SRV05 | DC holding the Domain Naming, RID and Infrastructure master roles | 44.38.3.67 |
| G03SRV06 | IIS web server, Windows Admin Center | 44.38.3.55 |
| G03SRV07 | WSUS | 44.38.3.70 |
| G03TRUENAS | SMB storage joined to AD | 44.38.3.50 |
| Prism Central | Nutanix management plane | 44.38.3.12 |

## Highlights

- **Least privilege by design.** Every department uses the AGDLP model: users go into Global groups,
  which are nested into `_READ_DL` and `_MOD_DL` Domain Local groups, and only the DL groups appear on
  folder ACLs and share permissions.
- **Infrastructure migration without downtime to the directory.** Every physical domain controller was
  replaced by a VM. That meant demoting each one, wiping it, rebuilding it as a Nutanix node, and moving
  the FSMO roles with PowerShell first, then checking replication with `repadmin`.
- **Tiered web access.** One IIS server hosts a public site, a domain-authenticated site, and a site
  that also requires on-site IP addresses, each behind its own firewall rule.
- **Operations, not just setup.** The environment includes scheduled backups with retention, WSUS-managed
  patching through GPO, DFS replication across two sites, and remote management over WinRM and WAC.

## Environment & tools

Windows Server 2022/2025 · Windows 11 · Active Directory DS / DNS · Group Policy · Nutanix CE (AHV,
Prism Element, Prism Central) · TrueNAS 13 · Windows Server Backup · IIS · WSUS · DFS-N / DFS-R ·
Print Management · Windows Admin Center · PowerShell · VMware Workstation

## Why it's in a security portfolio

Defenders need to understand the enterprise they're protecting. This is the Windows/AD side of that:
how domains, GPOs and ACLs actually enforce access, where patching and backups fit in, what privileged
groups (Schema/Enterprise Admins) are needed for and why, and how a multi-site environment is segmented
and administered. Several write-ups also point out where a lab shortcut would be a real-world risk.

## Skills demonstrated

Active Directory forest/domain design · AGDLP group strategy · NTFS & share permissions · Group Policy ·
FSMO roles & AD replication · AD Sites and Services · hyperconverged virtualization (Nutanix) · VM
templating with Sysprep · RBAC · SMB storage & ACLs · backup automation · IIS authentication & IP
restrictions · Windows Firewall · WSUS · DFS · PowerShell remoting · troubleshooting
