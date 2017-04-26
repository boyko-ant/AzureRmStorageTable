$destinationFolder="c:\AzureAutomation\source"
$ArchiveFile=(Join-Path "$destinationFolder\..\" "AzureRmStorageTable.zip")
$armFolder=$null
$asmFolder=$null
$azureRmStoragetableFolder="${env:programfiles}\WindowsPowerShell\Modules\AzureRmStorageTable"

if (test-path "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager\AzureRM.Storage")
{
    $armFolder="${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager\AzureRM.Storage"
    $asmFolder="${env:ProgramFiles(x86)}Microsoft SDKs\Azure\PowerShell\StorageAzure.Storage "
}
elseif (test-path "${env:ProgramFiles}\WindowsPowerShell\Modules\AzureRM.Storage")
{
    $armFolder="${env:ProgramFiles}\WindowsPowerShell\Modules\AzureRM.Storage"
    $asmFolder="${env:ProgramFiles}\WindowsPowerShell\Modules\Azure.Storage"
}
else
{
    throw "Required Azure PowerShell modules not installed, install via Install-Module or Web Platform Installer"
}


if (!(Test-Path $destinationFolder))
{
    mkdir $destinationFolder
}

# Files from AzureRm.Storage module
$files=@("Microsoft.Data.Edm.dll",`
         "Microsoft.Data.OData.dll",`
         "Microsoft.Data.Services.Client.dll",`
         "Microsoft.WindowsAzure.Commands.Common.Storage.dll",`
         "Microsoft.WindowsAzure.Storage.dll","System.Spatial.dll")

foreach ($file in $files)
{
	copy (join-path $armFolder $file) $destinationFolder
}

# Files from Azure.storage
$files=@("Microsoft.WindowsAzure.Commands.Storage.dll")
foreach ($file in $files)
{
    copy (join-path $asmFolder $file) $destinationFolder
}

# Files from AzureRm Storage Table module
if (Test-path "${env:programfiles}\WindowsPowerShell\Modules\AzureRmStorageTable")
{
    copy "${env:programfiles}\WindowsPowerShell\Modules\AzureRmStorageTable\*" $destinationFolder
}
else
{
    throw "AzureRm Storage Table module not installed"
}

# Compressing file
if (Test-Path $destinationFolder)
{
    Add-Type -Assembly System.IO.Compression.FileSystem
    Remove-Item -Path $ArchiveFile -ErrorAction SilentlyContinue
    [System.IO.Compression.ZipFile]::CreateFromDirectory($destinationFolder, $ArchiveFile)
}

