# Lab 5: Enterprise Windows Server Administration, Part II

**Goal:** Add the day-two operations services a real enterprise runs on: centralized patching (WSUS),
replicated file namespaces across both sites (DFS), managed printing, and remote administration
(PowerShell remoting and Windows Admin Center).

[← Back to overview](../README.md)

## Procedure

### 1. WSUS (patch management)
1. Deployed **G03SRV07** from the Server 2025 template (`44.38.3.70`, DNS `44.38.3.31`) with an extra
   **500 GB disk**, and joined it to `group03.c24200.cit.lcl`.
2. *Disk Management*: brought the disk online, initialized it, and made volume **WSUS (F:)** with folder `F:\WSUS`.
3. Installed the **Windows Server Update Services** role with content location `F:\WSUS`, then ran the
   configuration wizard and the first sync with Microsoft Update.
4. Configured WSUS to use SSL:
   ```powershell
   cd "C:\Program Files\Update Services\Tools"
   .\WsusUtil.exe configuressl G03SRV07
   ```
5. Created computer group **WSUS Computers**.
6. On the DC, edited the **Default Domain Policy** under *Computer Config → Admin Templates → Windows
   Components → Windows Update*:
   - *Configure Automatic Updates*: **Enabled**, auto download and schedule the install
   - *Specify intranet Microsoft update service location*: `http://G03SRV07:8530` for both the update
     service and the statistics server

   Domain machines now take patches only from WSUS, on a central schedule, instead of each one going
   to Microsoft Update on its own. *(Recommendation 1 below explains why this should have been its own GPO.)*
7. Applied it with `gpupdate /force`.

### 2. DFS namespaces and replication
1. Installed **DFS Namespaces** and **DFS Replication** on **G03SRV01VM** (site 1) and **G03SRV04** (site 2).
2. Created a **domain-based namespace** `\\group03.c24200.cit.lcl\DFS` hosted on G03SRV01VM.
3. On both servers, created `RedirectedFolders` and `RoamingProfiles` and shared them as **hidden** shares
   (`RedirectedFolders$`, `RoamingProfiles$`).
4. Added namespace folders whose **folder targets** point at the shares on each server.
5. Created replication group **Multipurpose Replication Group**: G03SRV01VM as **primary member** and
   G03SRV04 as replica.
6. Repointed the Lab 2 folder-redirection and roaming-profile GPOs from a single server to the namespace:
   `\\group03.c24200.cit.lcl\DFS\RedirectedFolders$`. User data now survives the loss of either server
   or site.

### 3. Print management
1. Created a dedicated print admin user (`hdoll`) and added it to the built-in **Print Operators** group
   instead of giving it Domain Admin.
2. Installed **Print and Document Services** and the **Internet Printing Client**. Added the HP LaserJet
   `k238` by TCP/IP and **listed it in the directory**.
3. GPO: allowed printer publishing and deployed `k238` as a shared printer to users.
4. Added a second queue, **`k238-duplex`**, for the same physical printer.
5. Showed **pause printing** on both queues.
6. Set printer permissions on each queue and gave Print Operators/Administrators a separate high-priority
   path (**priority 99**), so admin jobs go ahead of user jobs.

### 4. PowerShell remoting
On every VM:
```powershell
Enable-PSRemoting -Force
```
Tested it by managing a service on another DC remotely:
```powershell
Enter-PSSession -ComputerName G03SRV03VM -Credential GROUP03\Administrator
Get-Service -Name Spooler; Stop-Service -Name Spooler
Get-Service -Name Spooler; Start-Service -Name Spooler
Exit-PSSession
```

### 5. Windows Admin Center
1. Installed **WAC** on **G03SRV06** (from `aka.ms/WACDownload`) with a **self-signed certificate**.
2. Browsed to `https://G03SRV06`, signed in as `GROUP03\Administrator`, and added the servers and
   Windows 11 VMs by FQDN (e.g. `G03SRV01VM.group03.c24200.cit.lcl`).

## Problems and fixes

**1. WAC couldn't connect to the Windows 11 VMs or G03SRV04** ("Connection refused" / "WinRM cannot
process the request").
**Fix:** Remoting wasn't actually set up everywhere. `Enable-PSRemoting` created the missing firewall
exceptions on the Windows 11 clients. On **G03SRV04**, which sits in the other subnet, the default
WinRM rule only allows the local subnet, so its scope had to be widened:
```powershell
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -RemoteAddress Any
```
*(In production, scope this to the management subnet rather than `Any`.)*

**2. Windows 11 users got "Windows cannot connect to the printer. Access is denied."**
It worked from servers with Print Operator accounts but not for a standard user.
**Fix:** The queue had no print permission for standard users. In *Print Management → k238 →
Properties → Security*, granted **Print** to the right group.

**3. The WSUS post-install wizard was closed by accident and disappeared.**
**Fix:** It can be reopened from *WSUS console → Update Services → G03SRV07 → Options → **WSUS Server
Configuration Wizard***. Then we finished the upstream source, proxy and first-sync settings.

## Recommendations (from the lab write-up)
1. **One GPO per function, not everything in the Default Domain Policy.** Separate WSUS, printer and
   redirection GPOs, linked to specific OUs, made troubleshooting much easier, and changes can't spill
   into other services.
2. **Check WinRM and firewall rules on every host before rolling out WAC**, especially hosts in other
   subnets or sites.
3. **Always Sysprep a template before cloning.** Duplicate SIDs cause conflicts with identity-dependent
   services like WSUS.

## Security takeaways
- **Patch management is central and enforced by policy**, not left to each machine.
- **Built-in delegated groups** (Print Operators) instead of Domain Admin for routine tasks.
- **Remote-management exposure is a trade-off.** WinRM firewall scope should be as narrow as the
  management design allows.
- DFS replication gives user data **availability** across two sites, which is one leg of the CIA triad.
