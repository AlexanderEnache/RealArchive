
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


# Archive Files
Add-Type -assembly 'system.io.compression.filesystem'

	function archive{

		$source = "\\sql-dev-2016\dev\coop\folder1"
		$dest = "\\sql-dev-2016\dev\coop"
		$files = Get-ChildItem -Path $source -Recurse -Exclude Archive -Include '*.txt','*.csv','*.log'


	foreach ($file in $files){	
		$folder = $file.directoryname | Split-Path -Leaf

# Create zip
	If (!(Test-Path $dest$folder.zip))
	{New-Item $dest$folder.zip -ItemType file}
	else 
	Write-Error "zip folder cannot be created"

# Add files to zip
$zip = [io.compression.zipfile]::Open("$dest$folder.zip",'Update')
[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$file.name)
$zip.dispose()
}
}




LOG ROTATE

function RotateLog {
$log ="\\sql-dev-2016\dev\coop" 
$target = Get-ChildItem $log -Filter "*.txt"
$threshold = 30
$datetime = Get-Date -uformat "%Y-%m-%d-%H%M"
$target | ForEach-Object {
    if ($_.Length -ge $threshold) { 
        Write-Host "file named $($_.name) is bigger than $threshold KB"
        $newname = "$($_.BaseName)_${datetime}.log_old"
        Rename-Item $_.fullname $newname
        Write-Host "Done rotating file" 
    }
    else{
         Write-Host "file named $($_.name) is not bigger than $threshold KB"
    }
    Write-Host " "
}
} 