# FSMO role transfers used during the WoodRock migration.
# The account running these needs Schema Admins + Enterprise Admins for forest-wide roles.

# Lab 3: move forest-wide roles from the physical DC to the new VM
$Server = Get-ADDomainController -Identity "G03SRV01VM.group03.c24200.cit.lcl"
Move-ADDirectoryServerOperationMasterRole -Identity $Server `
    -OperationMasterRole SchemaMaster, DomainNamingMaster

# Lab 4: spread roles out to G03SRV05 for redundancy
$Server = Get-ADDomainController -Identity "G03SRV05.group03.c24200.cit.lcl"
Move-ADDirectoryServerOperationMasterRole -Identity $Server -OperationMasterRole DomainNamingMaster

# Verify replication after every change
repadmin /replsummary
repadmin /showrepl
