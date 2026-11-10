# Lab 4: Enterprise Windows Server Administration

**Goal:** Grow WoodRock's virtualized environment into a multi-site enterprise. This lab connects
Nutanix to Active Directory, adds network storage with automated backups, builds a second AD site,
spreads out the FSMO roles, delegates Nutanix access by department, and publishes three web sites with
different levels of access control.

[← Back to overview](../README.md)

## Procedure

### 1. Connect Prism Central to Active Directory (LDAP)
1. On both domain controllers (`G03SRV01VM`, `G03SRV03VM`), created a GPO under *Security Settings →
   Local Policies → Security Options* that set the LDAP signing and channel-binding policies so Prism
   Central could bind (channel binding *When supported*, client signing *Negotiate signing*, client
   encryption *Negotiate sealing*).
2. In Prism Central → *Authentication → Directory List*, added both domains:

| Name | Domain | Directory URL |
| --- | --- | --- |
| `G03SRV01LDAP` | `group03.c24200.cit.lcl` | `ldap://44.38.3.31:389` |
| `G03SRV03LDAP` | `c242-03-a.group03.c24200.cit.lcl` | `ldap://44.38.3.20:389` |

> **Real-world note:** Relaxing LDAP signing to allow plain `ldap://389` was a lab shortcut. In
> production, this integration should use **LDAPS (636)** with signing required, so directory
> credentials never cross the network in cleartext.

### 2. TrueNAS network storage
1. Uploaded the TrueNAS 13.0-U6.2 ISO to Prism Central and deployed **G03TRUENAS** (2 cores, 8 GB RAM,
   32 GB boot disk, plus two 250 GB data disks).
2. From the TrueNAS console: static IP **44.38.3.50/24**, DNS domain `group03.c24200.cit.lcl`, and
   nameserver `44.38.3.31` (the DC).
3. In the web UI: **joined TrueNAS to Active Directory**, then created storage pool **Group03NAS** from the
   two data disks.
4. Created two datasets with SMB shares:

| Dataset | Path | ACL |
| --- | --- | --- |
| `BackupSet03` | `/mnt/G03NAS/BackupSet03` | **RESTRICTED** preset: only authorized admins can read or write backups |
| `GeneralSet03` | `/mnt/G03NAS/GeneralSet03` | Shared company data for domain users |

### 3. Automated backups with retention
1. On G03SRV01VM:
   ```powershell
   Install-WindowsFeature Windows-Server-Backup
   ```
2. Set up a scheduled backup of **System State** (which includes the AD database) and user data to
   `\\44.38.3.50\BackupSet03`.
3. Wrote two batch scripts ([`scripts/`](../scripts/)):
   - `renameBackup.cmd` adds a timestamp to each new backup folder so the old one isn't overwritten.
   - `deleteBackup.cmd` maps the share and deletes backup folders **older than 7 days** with `forfiles`.
4. Scheduled both in **Task Scheduler** (`delBackup` daily at 6:30 AM, plus `renameBackup`) under the
   task folder `mainScripts`.

### 4. A second site
1. In Prism Central, created subnet **LAN1903** (VLAN 1903, `44.38.103.0/24`, gateway `.1`, DNS `44.38.3.31`).
2. Deployed **G03SRV04** at `44.38.103.2`, joined it to the parent domain, and promoted it to a DC.
3. In *Active Directory Sites and Services*, created site **GROUP03SITE** and associated subnet
   `44.38.103.0/24` with it. AD uses this to send clients in that subnet to their local DC and to
   manage replication between sites.
4. Deployed **G03S2WIN11** (`44.38.103.3`) as the site-2 client.

### 5. Spreading out the FSMO roles
1. Deployed **G03SRV05** (`44.38.3.67`) and promoted it to a DC.
2. Moved the **RID Master**, **Infrastructure Master** and **Domain Naming Master** roles off G03SRV01VM, so
   losing one DC doesn't take every role with it:

```powershell
$Server = Get-ADDomainController -Identity "G03SRV05.group03.c24200.cit.lcl"
Move-ADDirectoryServerOperationMasterRole -Identity $Server -OperationMasterRole DomainNamingMaster
repadmin /replsummary; repadmin /showrepl
```

### 6. Role-based access in Nutanix
Gave each department access to only the VMs it should manage:

1. **Categories** to tag VMs: `Windows11:WIN11` and `WindowsServer2025:SRV`.
2. **Custom roles:** `VirtualOperator` (based on *Virtual Machine Operator*: power and console only)
   and `VirtualCreate` (based on *Virtual Machine Admin*).
3. **Projects:** `Windows11VMConfigure`, `WindowsServer2025Configure` and `NewVMCreate`.
4. **Authorization policies** linking AD groups to roles and scopes:

| Policy | AD groups | Role | Scope |
| --- | --- | --- | --- |
| HR | `HR_Mod_DL`, `HR_Read_DL` | VirtualOperator | Windows Server 2025 VMs |
| Executive | `Exec_Mod_DL`, `Exec_Read_DL` | VirtualOperator | Windows 11 VMs |
| Accounting | `ACCG_Mod_DL`, `ACCG_Read_DL` | VirtualCreate | New-VM project, all clusters |
| Administrator | `Administrators` | Full | Cluster G03NUTXSRV02 |

The same AD groups that control file access in Lab 2 now control hypervisor access as well. That gives
one source of truth for permissions.

### 7. Three web sites with tiered access (IIS)
Deployed **G03SRV06** (`44.38.3.55`), joined it to the domain, and installed **Web Server (IIS)**.

| Site | Path | Port | Who can reach it |
| --- | --- | --- | --- |
| `PublicSite` | `C:\inetpub\wwwroot\Public` | 80 | Anyone |
| `PrivateSite` | `C:\inetpub\wwwroot\Private` | 8080 | **Domain Users**: Anonymous auth disabled, Windows Authentication enabled, authorization rule for Domain Users |
| `SpecSite` | `C:\inetpub\wwwroot\SiteSpec` | 8081 | **Site Users** group *and* clients from `44.38.3.0/24`. Unlisted clients are **denied** by *IP Address and Domain Restrictions* |

Opened the non-standard ports in Windows Defender Firewall:

```powershell
New-NetFirewallRule -DisplayName "Allow HTTP 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTP 8081" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow
```

## Verification
- `repadmin /replsummary` and `repadmin /showrepl` after each DC promotion and role transfer, to
  confirm replication across both sites.
- Loaded each IIS site to check its access rule. The private sites failing to load is how Problem 2
  below was found.

## Problems and fixes

**1. Windows Server Backup couldn't reach `\\44.38.3.50\BackupSet03`.**
**Fix:** DNS was misconfigured on TrueNAS and on the DC. With name resolution fixed on both, they could
find each other and authenticate over SMB.

**2. The private IIS sites wouldn't load for anyone.**
Authentication and authorization rules were checked first.
**Fix:** The ports were blocked. Windows Firewall only allows 80/443 for IIS by default, so the inbound
rules for 8080/8081 above were needed.

**3. Moving FSMO roles to G03SRV05 failed.**
**Fix:** The admin account lacked the forest-level group membership the **Domain Naming Master** role
requires. After adding it, the transfer worked.

## Security takeaways
- **Defense in depth on the web tier:** authentication, authorization rules, IP restrictions and host
  firewall rules each block access on their own.
- **Backups:** a restricted ACL on the backup share, System State coverage, and automatic retention.
- **One identity source** (AD groups) drives file, hypervisor and web authorization.
- Lab convenience settings (plain LDAP) are written down as risks, not hidden.
