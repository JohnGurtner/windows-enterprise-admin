# Lab 3: Enterprise Virtualization (Nutanix)

**Goal:** Move WoodRock from physical servers to a **two-cluster Nutanix hyperconverged platform**
without breaking Active Directory. Each physical domain controller was replaced by a VM, the hardware
was rebuilt as a Nutanix node, and both clusters were managed from Prism Central.

[← Back to overview](../README.md)

## The migration plan

The servers were both the hardware *and* the domain controllers, so the order mattered:

```
1. Demote G03SRV02 (c242-03-b)  ─► wipe ─► install Nutanix AHV  ─► cluster G03NUTXSRV02 + Prism Central
2. Build golden templates (Windows Server 2025, Windows 11) on the new cluster
3. Deploy G03SRV03VM ─► promote to DC ─► move FSMO roles ─► demote physical G03SRV03
4. Deploy G03SRV01VM ─► promote to DC ─► move FSMO roles ─► demote physical G03SRV01
5. Wipe G03SRV01 ─► install Nutanix AHV ─► cluster G03NUTXSRV01 ─► register with Prism Central
6. Live-migrate VMs between clusters
```

| Component | Address |
| --- | --- |
| Cluster G03NUTXSRV02: AHV host / CVM | 44.38.3.3 / 44.38.3.10 |
| Cluster G03NUTXSRV01: AHV host / CVM | 44.38.3.2 / 44.38.3.40 |
| Prism Central | 44.38.3.12 (pool .13–.17) |
| G03SRV03VM / G03S3WIN11VM | 44.38.3.20 / .30 |
| G03SRV01VM / G03S1WIN11VM | 44.38.3.31 / .32 |

## Procedure

### 1. Retire the first physical DC (G03SRV02)
1. *Server Manager → Remove Roles → AD DS → Demote*. Checked **Last domain controller in the domain**,
   **Proceed with removal** and **Remove this DNS zone**, because `c242-03-b` was being retired.
2. Booted from USB and deleted all partitions so the disk was clean for the hypervisor.

### 2. Install and create the first Nutanix cluster
1. Booted the Nutanix Community Edition installer. Host IP `44.38.3.3`, CVM IP `44.38.3.10`, gateway `44.38.3.1`.
2. From the AHV host, SSH'd into the Controller VM and created a single-node cluster:

```bash
ssh nutanix@192.168.5.2
cluster -s 44.38.3.10 --redundancy_factor=1 create
ncli cluster edit-params new-name=G03NUTXSRV02
ncli cluster add-to-name-servers servers=44.2.1.44
ncli cluster add-to-ntp-servers servers=tick.cit.lcl
ncli cluster add-to-ntp-servers servers=tock.cit.lcl
```

3. Logged into **Prism Element** at `https://44.38.3.10:9440` and **changed the default admin password
   right away**.

### 3. Prism Central and storage
1. Deployed **Prism Central** from Prism Element: VM IP `44.38.3.12`, iSCSI data services IP `.42`,
   cluster virtual IP `.41`, and a 5-address pool (`.13–.17`).
2. Created a storage container and a VM subnet (VLAN 0, gateway `.1`, lab DNS/NTP).
3. **Disabled IPv6** on the CVM, which Prism Central registration required:

```bash
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
echo -e "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" \
  | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p
manage_ipv6 unconfigure
rolling_restart cvms
```

4. Registered the Prism Element cluster with Prism Central.

### 4. Golden-image templates
Built two templates so every later VM started from the same clean, generalized image:

| Template | vCPU / RAM / Disk | Notes |
| --- | --- | --- |
| `G03WIN2025TEMP` | 2 cores / 8 GB / 250 GB | Secure Boot + **vTPM**, VirtIO drivers, Nutanix Guest Tools, RDP enabled |
| `G03WIN11TEMP` | 4 GB / 60 GB | RDP enabled, Nutanix Guest Tools |

Each one was **generalized with Sysprep** before being snapshotted and turned into a template:

```powershell
cd C:\Windows\System32\Sysprep
.\sysprep /generalize /shutdown /oobe
```

Sysprep resets the machine SID. Cloning without it creates duplicate SIDs, which break domain trust and
services like WSUS (see the Lab 5 recommendations).

### 5. Virtualize the child-domain DC (G03SRV03 → G03SRV03VM)
1. Deployed `G03SRV03VM` from the template: IP `44.38.3.20`, DNS pointing at the existing DC.
2. Joined it to `c242-03-a.group03.c24200.cit.lcl`, installed **AD DS + DNS**, and promoted it to a
   DC in the existing domain.
3. Added the admin account to **Schema Admins** and **Enterprise Admins**, which forest-wide role
   changes require.
4. Moved the FSMO roles to the VM, then checked replication:

```powershell
repadmin /replsummary
repadmin /showrepl
```

5. Deployed a Windows 11 client (`G03S3WIN11VM`, `.30`) from the template and domain-joined it.
6. Demoted and wiped the physical **G03SRV03**, then rebuilt that hardware as a physical Windows 11
   client (`G03WIN11`).

### 6. Virtualize the forest root DC (G03SRV01 → G03SRV01VM)
Same pattern for the most important server in the forest:
1. Deployed `G03SRV01VM` (`44.38.3.31`, plus a 200 GB data disk), joined `group03.c24200.cit.lcl`, and
   promoted it to a DC.
2. Moved the **forest-wide** roles:

```powershell
$Server = Get-ADDomainController -Identity "G03SRV01VM.group03.c24200.cit.lcl"
Move-ADDirectoryServerOperationMasterRole -Identity $Server `
    -OperationMasterRole SchemaMaster, DomainNamingMaster
```

3. Moved the domain-wide roles (PDC Emulator, RID Master, Infrastructure Master) and checked with `repadmin`.
4. Deployed `G03S1WIN11VM` (`.32`) as the parent-domain client.
5. Demoted the physical **G03SRV01**, choosing **Remove DNS delegation**.

### 7. Second cluster and cross-cluster operations
1. Wiped G03SRV01 and installed Nutanix AHV (host `.2`, CVM `.40`). Created cluster **G03NUTXSRV01**
   with the same `ncli` steps, disabled IPv6, and registered it with Prism Central.
2. **Raised the domain functional level** on both remaining domains once the old physical DCs were gone.
3. Created a matching storage container and subnet on the second cluster.
4. **Live-migrated** the Windows 11 VMs between clusters. Memory overcommit had to be **turned off**
   for migration and was turned back on afterward.
5. Updated DNS settings on the migrated VMs and activated Windows/Windows Server against KMS.

## Problems and fixes

**1. The bootable USB didn't show up on the Dell Pro Tower Plus.**
Reformatting the drive and switching between Ventoy and the Windows installer didn't help.
**Fix:** Rebuilt the drive with **Rufus** so it matched the machine's UEFI boot mode. It appeared in
the boot menu and the partitions could be wiped.

**2. IPv6 stayed enabled on Nutanix after running `manage_ipv6 unconfigure` / `disable`.**
Prism Central registration kept failing.
**Fix:** The CVM had to be **rebooted** after the commands before the change took effect. After that,
the cluster registered.

**3. Forest-wide FSMO roles wouldn't move to G03SRV01VM.**
Without the transfer, the physical DC couldn't be demoted.
**Fix:** Schema Master and Domain Naming Master are forest-level roles, so the account needs
**Schema Admins and Enterprise Admins** membership, not just Domain Admins. After adding the account
to those groups, the transfer went through.

## Security takeaways
- **Default credentials get changed right away.** Nutanix ships with a well-known password.
- Schema/Enterprise Admin membership is the highest privilege in AD. Grant it only for the change and
  remove it afterward.
- Sysprep and template hygiene stop duplicated machine identities.
- Demotion is a security step too. Cleanly removing a DC and its DNS records leaves no stale objects behind.
