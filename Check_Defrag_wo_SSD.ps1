# Define the hostname
$hostname = $args[0]

# Define the limit % of fragmented for Error
$Def_Limit_Error = 20

# Define the limit % of fragmented for Warning
$Def_Limit_Warning = [int]$Def_Limit_Error -5

# Initialize variable for the total number of Defrag (used for the Summary channel)
$PRTG_summary = 0

# Initialize the $SSD_Drive and $Disk_defrag arrays
$SSD_Drive = @()
$Disk_defrag = @()


# Get the physical disks of type SSD on the remote host
$physicalDisks = invoke-command $hostname -scriptblock {Get-PhysicalDisk | Where MediaType -eq "SSD" | Select-Object UniqueId}

# Get the partitions on the remote host with their unique ID and Drive Letter
$Partitions = invoke-command $hostname -scriptblock { Get-Partition | Select-Object UniqueId,DriveLetter }

# For each partition, extract its unique ID and check if it is present in the physical disks of type SSD
Foreach ($Partition in $Partitions) {
    $Partition_UniqueId = $Partition.UniqueId | Select-String -Pattern '[A-Z,0-9]{32}$' -AllMatches |% {$_.Matches.Value}
    $Compare = $physicalDisks.UniqueId | Where-Object {$_ -in $Partition_UniqueId } | Select-Object @{Name="DriveLetter";Expression={$Partition.DriveLetter}}
    $DriveLetter = $Compare | Select-Object -ExpandProperty DriveLetter
    $DriveLetter = $DriveLetter+':'

    # If the partition is present on an SSD, add it to the list of SSD drives
    if ($DriveLetter -match '[A-Z]:'){
        $SSD_Drive += $DriveLetter
    }
}

# Get the local disks on the remote host
$Disks = invoke-command $hostname -ScriptBlock {
    Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | Select-Object -ExpandProperty DeviceID }

# For each local disk, check if it is not an SSD (present in the $SSD_Drive list), and add it to the list of disks to defragment if it is not
foreach ($Disk in $Disks){
    if ($Disk -ne $SSD_Drive){
        $Disk_defrag += $Disk.ToString().Replace(":","")
    }
    Else{
    }
}

# For each disk to defragment, get the fragmentation rate with the Optimize-Volume cmdlet and display it
foreach($Disk_to_defrag in $Disk_defrag){ 
    $defragStatus = invoke-command $hostname -ScriptBlock { Optimize-Volume $using:Disk_to_defrag -Analyze -Verbose 4>&1 | Select-String -Pattern "Total fragmented space" }
    $Defrag_Data = $defragStatus.ToString().Split('=')
    $Defrag_Pourcent = $Defrag_Data[1] -replace '%',''

    
    if ([int]$Defrag_Pourcent -ge $Def_Limit_Error){
        
        # Increment $PRTG_Summar
        $PRTG_summary += 1
    }

    # Add the percent of disks fragmentation
    $PRTG_Disk = $Disk_to_defrag + " fragmented"

    $PRTG_Output_Percent += "<result>`n"
    $PRTG_Output_Percent += "<channel>$PRTG_Disk</channel>`n"
    $PRTG_Output_Percent += "<value>$Defrag_Pourcent</value>`n"
    $PRTG_Output_Percent += "<unit>Custom</unit>`n"
    $PRTG_Output_Percent += "<CustomUnit>%</CustomUnit>`n"
    $PRTG_Output_Percent += "<showChart>1</showChart>`n"
    $PRTG_Output_Percent += "<showTable>1</showTable>`n"
    $PRTG_Output_Percent += "<float>0</float>`n"
    $PRTG_Output_Percent += "<LimitMaxWarning>$Def_Limit_Warning</LimitMaxWarning>`n"
    $PRTG_Output_Percent += "<LimitMaxError>$Def_Limit_Error</LimitMaxError>`n"
    $PRTG_Output_Percent += "<LimitMode>1</LimitMode>`n"
    $PRTG_Output_Percent += "</result>`n"  
    
}

# Add the defrag Summary channel
$PRTG_Output += "<result>`n"
$PRTG_Output += "<channel>Defrag summary</channel>`n"
$PRTG_Output += "<value>$PRTG_summary</value>`n"
$PRTG_Output += "<unit>Custom</unit>`n"
$PRTG_Output += "<CustomUnit>Defrag(s) to do</CustomUnit>`n"
$PRTG_Output += "<showChart>1</showChart>`n"
$PRTG_Output += "<showTable>1</showTable>`n"
$PRTG_Output += "<float>0</float>`n"
$PRTG_Output += "<LimitMaxError>0.95</LimitMaxError>`n"
$PRTG_Output += "<LimitMode>1</LimitMode>`n"
$PRTG_Output += "</result>`n"

#Display XML for PRTG
write-host "<prtg>"
Write-host $PRTG_Output
Write-Host $PRTG_Output_Percent
Write-Host "</prtg>"


