# Lab 4: open the non-standard IIS ports for PrivateSite (8080) and SpecSite (8081) on G03SRV06
New-NetFirewallRule -DisplayName "Allow HTTP 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTP 8081" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow

# Lab 5: WinRM for Windows Admin Center
Enable-PSRemoting -Force
# Cross-subnet host (G03SRV04). In production, scope -RemoteAddress to the management subnet instead of Any.
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -RemoteAddress Any
