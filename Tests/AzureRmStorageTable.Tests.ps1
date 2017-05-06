Import-Module .\AzureRmStorageTable.psd1 -Force

$choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Y","&N")
$useEmulator = $Host.UI.PromptForChoice("Use local Azure Storage Emulator?", "", $choices, 0)
$useEmulator = $useEmulator -eq 0

$uniqueString = Get-Date -UFormat "PsTest%Y%m%dT%H%M%S"

Describe "AzureRmStorageTable" {
    BeforeAll {
        if ($useEmulator) {
            $context = New-AzureStorageContext -Local
        } else {
            $subscriptionName = Read-Host "Enter Azure Subscription name"                
            $locationName = Read-Host "Enter Azure Location name"

            Write-Host -for DarkGreen "Login to Azure"
            Login-AzureRmAccount
            Select-AzureRmSubscription -SubscriptionName $subscriptionName

            Write-Host -for DarkGreen "Creating resource group $($uniqueString)"
            New-AzureRmResourceGroup -Name $uniqueString -Location $locationName

            Write-Host -for DarkGreen "Creating storage account $($uniqueString.ToLower())"
            New-AzureRmStorageAccount -ResourceGroupName $uniqueString -Name $uniqueString.ToLower() -Location $locationName -SkuName Standard_LRS

            $storage = Get-AzureRmStorageAccount -ResourceGroupName $uniqueString -Name $uniqueString
            $context = $storage.Context
        }

        Write-Host -for DarkGreen "Creating table $($uniqueString)"
        $table = New-AzureStorageTable -Name $uniqueString -Context $context
    }

    Context "Add-StorageTableRow" {
        It "Can add entity" {
            $expectedPK = "pk"
            $expectedRK = "rk"

            Add-StorageTableRow -table $table `
                -partitionKey $expectedPK `
                -rowKey $expectedRK `
                -property @{}

            $entity = Get-AzureStorageTableRowAll -table $table

            $entity.PartitionKey | Should be $expectedPK
            $entity.RowKey | Should be $expectedRK
        }

        It "Can add entity with empty partition key" {
            $expectedPK = ""
            $expectedRK = "rk"

            Add-StorageTableRow -table $table `
                -partitionKey $expectedPK `
                -rowKey $expectedRK `
                -property @{}

            $entity = Get-AzureStorageTableRowByPartitionKey -table $table `
                -partitionKey $expectedPK

            $entity.PartitionKey | Should be $expectedPK
            $entity.RowKey | Should be $expectedRK
        }

        It "Can add entity with empty row key" {
            $expectedPK = "pk"
            $expectedRK = ""

            Add-StorageTableRow -table $table `
                -partitionKey $expectedPK `
                -rowKey $expectedRK `
                -property @{}

            $entity = Get-AzureStorageTableRowByColumnName -table $table `
                -columnName "RowKey" -value $expectedRK -operator Equal

            $entity.PartitionKey | Should be $expectedPK
            $entity.RowKey | Should be $expectedRK
        }

        It "Can add entity with empty partition and row keys" {
            $expectedPK = ""
            $expectedRK = ""

            Add-StorageTableRow -table $table `
                -partitionKey $expectedPK `
                -rowKey $expectedRK `
                -property @{}

            $entity = Get-AzureStorageTableRowByCustomFilter -table $table `
                -customFilter "(PartitionKey eq '$($expectedPK)') and (RowKey eq '$($expectedRK)')"

            $entity.PartitionKey | Should be $expectedPK
            $entity.RowKey | Should be $expectedRK
        }
    }

    AfterAll { 
        Write-Host -for DarkGreen "Cleanup in process"

        if ($useEmulator) {
            Remove-AzureStorageTable -Context $context -Name $uniqueString -Force
        } else {
            Remove-AzureRmResourceGroup -Name $uniqueString -Force
        }

        Write-Host -for DarkGreen "Done"
    }
}