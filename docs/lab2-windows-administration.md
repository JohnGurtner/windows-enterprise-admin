# Lab 2: Microsoft Windows Administration

**Goal:** Turn the empty forest from Lab 1 into a working company directory for WoodRock: departments,
users, a least-privilege group design, file permissions, user-environment GPOs and a shared printer,
tested from a domain-joined Windows 11 client.

[← Back to overview](../README.md)

## Business scenario

| Domain | Server | Departments (one OU each) |
| --- | --- | --- |
| `group03.c24200.cit.lcl` | G03SRV01 | Accounting, Human Resources, Executive |
| `c242-03-b.group03.c24200.cit.lcl` | G03SRV02 | Warehouse, Shipping, Marketing |
| `c242-03-a.group03.c24200.cit.lcl` | G03SRV03 | Outside Sales, Inside Sales, Account Management |

## Procedure

### 1. Organizational Units
*Active Directory Users and Computers → right-click the domain → New → Organizational Unit*, one per
department, on all three domains.

### 2. Security groups using the AGDLP model
Each department OU got three groups:

| Group | Scope | Purpose |
| --- | --- | --- |
| `<Dept>_READ_DL` | Domain Local | Granted **read** on the department folder |
| `<Dept>_MOD_DL` | Domain Local | Granted **modify/write** on the department folder |
| `<Dept>_MANAGER_G` | Global | Managers. **Nested into both DL groups** so they inherit read and write |

Only the Domain Local groups ever appear on ACLs. People go into groups, never directly onto resources.
That keeps permission changes to a group-membership edit.

### 3. Users
Created **18 users per domain** (two in each security group) under the matching OU, then added them to
the groups through *Properties → Members → Add*.

### 4. Password policy
*Group Policy Management → Default Domain Policy → Edit → Computer Configuration → Policies → Windows
Settings → Security Settings → Account Policies → Password Policy*

- **Minimum password length: 8**
- Set the Default Domain Policy link to **Enforced** so a lower-level GPO can't override it.

### 5. Department file shares with NTFS permissions
1. *Disk Management →* created a new simple volume (D:) on the 1 TB disk.
2. Created one folder per department.
3. For each folder: *Properties → Security → Advanced → **Disable inheritance → Convert inherited
   permissions into explicit permissions***.
4. Removed every entry except Administrators and SYSTEM.
5. Added `<Dept>_READ_DL` with **Read** and `<Dept>_MOD_DL` with **Modify/Write**.

### 6. Test client
1. Installed VMware Workstation 17.6 on each server and built a Windows 11 VM (`G03S1WIN11`,
   `G03S2WIN11`, `G03S3WIN11`) with an encrypted VM disk.
2. Pointed the VM's preferred DNS at its domain controller, gave it a static IP, and joined it to the
   domain with `sysdm.cpl`.

### 7. Group Policy Objects
Each GPO was created in *Group Policy Management*, linked to the domain, and checked from the Windows 11 client.

| GPO | Setting path | Value |
| --- | --- | --- |
| **Disable Regedit** | User Config → Policies → Admin Templates → System → *Prevent access to registry editing tools* | **Enabled** |
| **Business Case** | Computer Config → Windows Settings → Security Settings → Local Policies → Security Options → *Interactive logon: Machine inactivity limit* | **600 seconds** (auto-lock after 10 minutes) |
| **Redirected Folders** | User Config → Policies → Windows Settings → Folder Redirection (Desktop, Documents…) | Basic, redirect everyone to `\\<server>\RedirectedFolders` |
| **Roaming Profiles** | Computer Config → Admin Templates → System → User Profiles → *Set roaming profile path for all users logging onto this computer* | `\\<server>\Profiles$\%USERNAME%` |
| **printers** | User Config → Preferences → Control Panel Settings → Printers | Shared printer `k238`, with **item-level targeting** to the department DL groups |

### 8. Storage for redirection and profiles
1. Created `RedirectedFolders` and a **hidden** share `Profiles$`. The `$` keeps it out of network browsing.
2. Share permissions: removed *Everyone* and added the department DL groups. NTFS permissions were
   trimmed the same way as in step 5.
3. **Disk quotas** on the volume: *Enable quota management*, **deny disk space to users exceeding the
   limit**, with a 1 GB limit and a 900 MB warning.

### 9. Print server
1. *Add Roles and Features →* **Print and Document Services**.
2. Added the lab HP LaserJet by IP as an IPP printer and shared it as `k238`.
3. Deployed it with the `printers` GPO above, so only targeted departments get it.

### 10. Activation
Activated Windows Server against the university KMS host with `slmgr.vbs /skms`, `/ipk` and `/ato`.

## Verification
Signed into the domain-joined Windows 11 VM as department users to test the GPOs: whether `regedit`
was blocked, and whether redirected and profile folders were created on the server. Problems 2 and 3
below came out of this testing.

## Problems and fixes

**1. OUs created in the wrong place couldn't be deleted.**
All the OUs had accidentally been nested under one parent, and deleting them failed with
*"protected from accidental deletion."* The checkbox to turn that off wasn't visible.
**Fix:** *View → **Advanced Features*** in ADUC shows the **Object** tab, where *Protect object from
accidental deletion* can be unchecked. Then the OUs were rebuilt correctly.

**2. The Disable Regedit GPO didn't block Regedit.**
The GPO was linked and enforced, but users could still open `regedit`.
**Fix:** The setting itself was *Disabled* instead of *Enabled*. In this policy, "Disabled" means
"don't prevent access." Lesson: read what each policy state means, not just whether the GPO is linked.

**3. Folder redirection didn't create user folders.**
The GPO was correct, but no folders appeared on logon.
**Fix:** The folder wasn't actually shared, and share permissions were missing for the user groups.
Enabling *Advanced Sharing → Share this folder* and granting the groups the right share permissions fixed it.
Folder redirection needs **both** share and NTFS permissions.

## Security takeaways
- AGDLP makes access auditable. To see who can modify Accounting, look at one group.
- Removing inherited ACEs keeps broad groups like *Users* off sensitive folders.
- Blocking registry tools, auto-locking sessions, quotas and hidden shares are everyday hardening GPOs.
