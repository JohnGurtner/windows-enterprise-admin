# Windows Enterprise Administration

> A full semester building and running a multi-server Windows Server enterprise for a fictional
> company (WoodRock) — Active Directory, Group Policy, virtualization, file services, patching, and
> web hosting across a team of three.

*CNIT 242 — Enterprise System Administration (Labs 1–5), Group 3.*

## Summary

Progressively stood up and administered a real multi-domain Windows environment: a parent domain
plus child domains, multiple domain controllers, a Nutanix virtualization layer, network file
services, centralized patching, and locked-down IIS sites. Every control has a security angle —
least-privilege groups, GPO enforcement, access-controlled shares, IP restrictions, and a firewall.

## Environment

- Windows Server 2022/2025, Windows 11 clients
- Active Directory forest: `group03.c24200.cit.lcl` + child domains
- Nutanix AHV / Community Edition + Prism Central
- TrueNAS, IIS, WSUS, DFS, Windows Admin Center

## What I built (by lab)

| Lab | Focus | Security-relevant work |
| --- | --- | --- |
| 1 — Windows Infrastructure | AD DS install, new forest, static IP/DNS | Domain foundation, server naming, admin password reset |
| 2 — Windows Administration | OUs, Domain Local + Global groups, GPOs | Group **nesting** for least privilege, password policy, disk quotas, folder redirection, `regedit` lockdown GPO |
| 3 — Enterprise Virtualization | Nutanix AHV/CE, Prism Central, templates | DC demotion/promotion, FSMO transfer, live migration, VM templates with Sysprep |
| 4 — Windows Server Admin | TrueNAS SMB shares, backups, IIS | **SMB ACLs**, scheduled backup scripts, public/private/site-specific IIS sites, **IP restrictions**, host firewall, per-dept authorization policies |
| 5 — Windows Server Admin II | WSUS, DFS, print mgmt, WAC | Centralized **patching (WSUS)**, replicated DFS namespaces, print permissions/priorities, PowerShell remoting, remote mgmt via WAC |

## Why it's in a security portfolio

Defenders have to understand the enterprise they're protecting. This is the Windows/AD side of that:
how domains, GPOs, and shares actually enforce access, where patching and backups fit, and how a real
multi-server environment is segmented and administered.

## Screenshots

See [`screenshots/`](screenshots/) for AD/OU structure, GPOs, the Nutanix cluster, TrueNAS shares,
IIS site restrictions, and WSUS/DFS configuration.

## Skills demonstrated

Active Directory · Group Policy · least-privilege group design · Nutanix virtualization · FSMO roles ·
SMB/ACLs · WSUS patching · DFS replication · IIS access control · PowerShell remoting
