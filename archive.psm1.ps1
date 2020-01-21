#Archive Files

function archive{
$source = "\\sql-dev-2016\dev\coop\folder1"
$dest = "\\sql-dev-2016\dev\coop"
$files = Get-ChildItem -Path $source -Recurse -Exclude Archive -Include
Add-Type -assembly 'system.io.compression.filesystem'

try 
{

foreach ($file in $files){
$folder = $file.directoryname | Split-Path -Leaf

# Create zip
try{
	If (!(Test-Path $dest$folder.zip)){New-Item $dest$folder.zip -ItemType file}
}
catch { throw "Failed to create zip file"}

# Add files to zip
$rar = [io.compression.zipfile]::Open("$dest$folder.zip",'Update')
[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$file.name)
$zip.dispose()
}
}
Catch
{
Write-Error $_
}
}


