#ref: http://purple-screen.com/?p=440
#ref: https://gallery.technet.microsoft.com/scriptcenter/31db73b4-746c-4d33-a0aa-7a79006317e6
[CmdletBinding()]
param (
	#Test Mode will not remove any files, does a what-if
    [switch] $TestMode = $true,
	#Log folder location
	[parameter(Mandatory=$true)]
    [alias("source")]  
	[string]$Folder,
	# Archive Storage Location - Use this variable to specify a single location 
	# to save all archives. 
    [parameter(Mandatory=$true)]
    [alias("Target")]
    [string] $ArchiveStorage,
	# Short name to begin the filename of the .zip archive 
	[parameter(Mandatory=$true)]
	[alias("ArchiveName")]
	[string]$ArchiveFileName,
	# Extension of files to archive. 
	[parameter(Mandatory=$true)]
    [alias("extn")]
	[string]$FileExtension,

    # Archive Date Grouping - Specify how to group the archives 
	# month -> Archive all past daily files to monthly archive files
	# day ->   Archive all past log files to daily archive logs
    [parameter(Mandatory=$true)]
	[ValidateSet('hour','day','month')]
	[string]$ArchiveGrouping,
	

	# Naming pattern of files to archive. 
    [alias("match")]
	[alias("filter")]
	$FileNamePattern = "",
 
    # If you would like to automatically remove the archives that this script creates,  
    # set the following to true and then define how old the archives should be (in days)
    # Note: This option only deletes .zip files 
	[switch] $RemoveOldArchives,
    [int] $RemoveArchivesDaysOld = 7,
	#Whether to ignore files modified in current period (hour/day or month)
	[switch]$SkipCurrentPeriod
)
begin{
	$startTime = Get-Date
	# Extension of archive files. 
	$ArchiveExtension = ".zip" 
	# Get today's date 
	$CurrentDate = Get-Date 
	echo $startTime
	echo "Starting Archiving script"
	echo "-------------------------------------------------------------------------------------------------------------------------"
	echo "The script was started $($startTime.ToString('yyyy-MM-ddTHH:mm:ss'))"
	echo "Archiving files from $Folder, all files matching $FileNamePattern with extension $FileExtension"
	echo "Storing archives to $ArchiveStorage, any archives older than $RemoveArchivesDaysOld days will be removed"
	echo "-------------------------------------------------------------------------------------------------------------------------"
	echo "Scanning for files..."
	#Tests if a file is in use, and locked
	function Test-FileLocked {
		param ([parameter(Mandatory=$true)][string]$Path)
		if($Path -eq $null){
			return false;
		}
		try {
			if ((Test-Path -Path $Path -ErrorAction SilentlyContinue) -eq $false){
				return $false
			}
		}
		catch {
		#can't even test path means the file is locked or we don't have access to that file
		return $true
		}
			try {
				$oFile = New-Object System.IO.FileInfo $Path
				$oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
				if ($oStream){
					$oStream.Close()
				}
				$false
			}
			 catch {
				# file is locked by a process.
				return $true
			 }
	}
	#Creates a zip file from a set of files passed.
	#If the file is already present it will be updated
	#If any files inside zip are already present they will be replaced
	#add .Net 4.5 compression assembly
	Add-Type -As System.IO.Compression.FileSystem
	function CreateArchiveFile {
		Param (
			[Parameter(Mandatory=$true)]
			[string[]] $FilesList,
			[Parameter(Mandatory=$true)]
			[string] $ZipFilePath
		)
		Begin {
			$Compression = 'Optimal'
			$ProcessedFiles = @()
			if (-not (Split-Path $ZipFilePath)) { $ZipFilePath = Join-Path $Pwd $ZipFilePath }
			if (Test-Path $ZipFilePath) {
				if ((Test-FileLocked  $ZipFilePath) -eq $true){
					Write-Error "$ZipFilePath is Locked by another process!! Can't continue!"
					return -1;
				}
				Write-Verbose 'Appending to the destination file'
				$Archive = [System.IO.Compression.ZipFile]::Open($ZipFilePath,'Update')           
			} else {
				Write-Verbose 'Creating the destination file'
				$Archive = [System.IO.Compression.ZipFile]::Open($ZipFilePath,'Create')
			}
		}
		Process {
			foreach ($File in $FilesList) {
				try {
					$EntryName = Split-Path $File -Leaf
					$Entry = $Archive.Entries | ? FullName -eq $EntryName
					if ($Entry) {
						Write-Verbose "Removing $EntryName from the archive"
						$Entry.Delete()
					}
					$locked = Test-FileLocked  $File
					if(!$locked){
						$Verbose = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,$File,$EntryName,$Compression)
						$ProcessedFiles += $Verbose.Name
					}
				} 
				catch {
					Write-Error $_
					$Archive.Dispose()
					Pop-Location
					return -1
				}
			}
		}
		End {
			$Archive.Dispose()
			return $ProcessedFiles
		}
	}
	
	# Set the dates needed for archiving by month or day,  
	# depending on what was set above for $ArchiveGrouping 
	Switch($ArchiveGrouping) { 
		"month" { 
			$ArchiveGroupingString = "{0:yyyy}{0:MM}" 
			if($SkipCurrentPeriod){
				$ArchiveDate = $CurrentDate.AddMonths(-1).ToString("yyyyMM")
			}else{
				$ArchiveDate = $CurrentDate.ToString("yyyyMM") 
			}
		} 
		"day" { 
			$ArchiveGroupingString = "{0:yyyy}{0:MM}{0:dd}" 
			if($SkipCurrentPeriod){
				$ArchiveDate = $CurrentDate.AddDays(-1).ToString("yyyyMMdd") 
			}else{
				$ArchiveDate = $CurrentDate.ToString("yyyyMMdd") 
			}
		} 
		"hour" { 
			$ArchiveGroupingString = "{0:yyyy}{0:MM}{0:dd}{0:hh}" 
			if($SkipCurrentPeriod){
				$ArchiveDate = $CurrentDate.AddHours(-1).ToString("yyyyMMddHH") 
			}else{
				$ArchiveDate = $CurrentDate.ToString("yyyyMMddHH") 
			}
		} 
		Default { 
			echo "Invalid Archive Grouping selected. You selected '$ArchiveGrouping'. Valid options are month and day."                 
			Exit 
		} 
	} 
	# Set the date for old archive file removal if that was specified above 
	if ($RemoveOldArchives) {
		[DateTime]$OldArchiveRemovalDate = $CurrentDate.AddDays(-$RemoveArchivesDaysOld) 
	} 
	# Test the path to the archive storage location if it has been set 
	if ($ArchiveStorage  -and ($ArchiveStorage  -ne "") -and !(Test-Path $ArchiveStorage -pathType container )) {  
		New-Item $ArchiveStorage -Force -itemtype directory | Out-Null 
	} 
	# Test the path to the log storage location if it has been set 
	if ($Folder ) {  
		if (!(Test-Path $Folder ) -and ($Folder  -ne "")) {  
			echo "Error: The specified archive storage location does not exist at $Folder .  
			Please check the folder and try again." 
			Exit 
		} 
	}
}
process{
	$TargetFiles = New-Object Collections.Generic.List[String]
	dir $Folder | where {  
		!$_.PSIsContainer `
		-and $_.extension -eq $FileExtension `
		-and $ArchiveGroupingString -f $_.LastWriteTime -le $ArchiveDate `
		-and $_.fullname -match $FileNamePattern
	} | group {  
		$ArchiveGroupingString -f $_.LastWriteTime  
	} | foreach { 
		$FilesFound = $true 
		$null = $TargetFiles.Clear()
		# Generate the list of files to compress 
		$_.group | foreach {$TargetFiles.Add($_.fullname)}
		# Create the full path of the archive file to be created 
		$ZipFileName = $ArchiveStorage +"\"+$ArchiveFileName+$_.name+$ArchiveExtension
		echo "Found $($TargetFiles.Count) files in group $($_.name)  --> $ZipFileName"
		$ArchivedFiles = CreateArchiveFile $TargetFiles.ToArray() $ZipFileName
		if($ArchivedFiles.Count -gt 0) {
			if($ArchivedFiles.Count -ne $TargetFiles.Count){
				# Creating the archive failed 
				echo "$($TargetFiles.Count) of $($ArchivedFiles.Count) files added to archive $ZipFileName" 
			}
			foreach ($File in $ArchivedFiles){
				$File=Join-Path $Folder $File
				#supress printing True to screen
				$null = $TargetFiles.Remove($File)
				#echo "Archived : $File  --> $ZipFileName"
				if($TestMode) { 
					# Show what files would be deleted 
					Remove-Item -Path $File -WhatIf 
				} else { 
					# Delete the original files 
					Remove-Item -Path $File
				} 
			}
			foreach($file in $TargetFiles) {
				echo "Failed: $file"
			}
		} else {
			# Creating the archive failed 
			echo "There was an error creating the archive $ZipFileName"
			foreach($file in $TargetFiles) {
				echo "Failed: $file"
			}
			exit -1
		}
	}
	# If the option to remove old archives is set to $true in the settings section, do so 
	if ($RemoveOldArchives) { 
		# Grab all files that aren't folders, last write time older than specified above, with a .zip extension         
		dir $ArchiveStorage | where {!$_.PSIsContainer} | where {$_.LastWriteTime -lt $OldArchiveRemovalDate -and $_.extension -eq ".zip" } | foreach {  
		if($TestMode) { 
			Remove-Item "$ArchiveStorage\$_" -WhatIf 
		} 
		else { 
			Remove-Item "$ArchiveStorage\$_" 
		} 
		$FileLastWriteTime = $_.LastWriteTime 
		echo "Old archive file removed`nPath/Name: $ArchiveStorage\$_ `nDate: $FileLastWriteTime `n`n" 
		} 
	}
}
	
end{
	$endTime = Get-Date
	echo "-------------------------------------------------------------------------------------------------------------------------"
	echo "The script completed $($endTime.ToString('yyyy-MM-ddTHH:mm:ss'))"
	echo "-------------------------------------------------------------------------------------------------------------------------"
}