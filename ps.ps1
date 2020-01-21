# For each item in source DIR,
# Copy to EDI processing server
# and if successful, move to move-to folder
# (recording any errors to log)
# Args: 0. Source DIR, 1. EDI processing server DIR, 2. move-to DIR, 3. log file (optional)
#
# Created June 2019 by Liam Lutsch and Matt Brown

try {
	# Check that we were given the correct number of arguments, and assign them to descriptive variables
	if ($args.Count -ne 4) { throw "Not enough arguments passed to FileCopyThenmove-to.ps1" }
	$source=$args[0]
	$copyDest=$args[1]
	$moveDest=$args[2]
	$logFile=$args[3]
	# Check that source, copyDest and moveDest directories are reachable.
	if (!(Test-Path $source))	{ throw "Failed to find source folder "+$source }
	if (!(Test-Path $copyDest))	{ throw "Failed to find copy-to folder "+$copyDest }
	if (!(Test-Path $moveDest))	{ throw "Failed to find move-to folder "+$moveDest }
	# No checking for log file because if it can't be found then we can't log the fact that it can't be found.
	
	# We copy-then-move files one-by-one so that if there's a problem, there won't ever be a question as to
	# where the file is / what its status is. i.e. in a mid-process failure, which ones succeeded and which ones failed?
	$allFiles = Get-ChildItem $source
	if ($allFiles.Count -eq 0)	{ exit } # If we want to log "no files found", add it in an else statement here.
	foreach ($file in $allFiles){
		#Check that file is accessible for read-write
		try {
			$Stream = $file.open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) 
			$Stream.Close()
		} catch { throw "File is locked: "+$file }
		try { Copy-Item -Path $file.fullname -Destination $copyDest -ErrorAction stop }
		catch { throw "Failed to copy file "+$file+" to copy-to folder "+$copyDest }
		try { Move-Item -Path $file.fullname -Destination $moveDest -ErrorAction stop }
		catch { throw "Failed to move file "+$file+" to move-to folder "+$moveDest }
		# Process worked. If we desire to log successes, add it here.
	}
} catch {
	# If not enough values are passed in the logFile path will be set as null
	if ($null -ne $logFile -And (Test-Path $logFile)) {
		Add-Content $logFile Get-Date": Error: "$_".
"
	}
	else { Write-Error "Log file path does not exist, failed to write to log" }
}