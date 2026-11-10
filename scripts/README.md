# Scripts

| File | Lab | Purpose |
| --- | --- | --- |
| `deleteBackup.cmd` | 4 | 7-day retention on the TrueNAS backup share (`forfiles /d -7`) |
| `renameBackup.cmd` | 4 | Timestamps each backup set so it isn't overwritten |
| `fsmo-transfer.ps1` | 3, 4 | FSMO role moves plus replication checks |
| `iis-firewall.ps1` | 4, 5 | IIS port rules and WinRM setup for WAC |

The batch scripts are cleaned-up versions of the ones in the lab report. Smart quotes were converted to
plain quotes, and a typo in the timestamp format was fixed.
