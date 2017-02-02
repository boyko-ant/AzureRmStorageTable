<#
.SYNOPSIS
	AzureRmStorageTableCoreHelper.psm1 - PowerShell Module that contains all functions related to manipulating Azure Storage Table rows/entities.
.DESCRIPTION
  	AzureRmStorageTableCoreHelper.psm1 - PowerShell Module that contains all functions related to manipulating Azure Storage Table rows/entities.
.NOTES
	Make sure the latest Azure PowerShell module is installed since we have a dependency on Microsoft.WindowsAzure.Storage.dll and 
    Microsoft.WindowsAzure.Commands.Common.Storage.dll.

	If running this module from Azure Automation, please make sure you follow these steps in order to execute it from that environment:
	
	1) After installing the latest version of Azure PowerShell module, copy the following DLLs from
	   C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager\AzureRM.Storage
	   to a folder with the source files of this module:
	
		- Microsoft.Azure.Common.dll
		- Microsoft.Data.Edm.dll
		- Microsoft.Data.OData.dll
		- Microsoft.Data.Services.Client.dll
		- Microsoft.WindowsAzure.Commands.Common.Storage.dll
		- Microsoft.WindowsAzure.Commands.Storage.dll
		- Microsoft.WindowsAzure.Storage.dll
		- System.Spatial.dll

	2) Compress all files (including the PSM1 and PSD1 from this module) into a file called AzureRmStorageTable.zip

	3) At your Azure Automation account, open "Assets" and click on "Modules"

	4) Click "Browse gallery" and install the following modules in this order (please give some wait until functions get extracted between modules):
		1) AzureRM.profile
		2) Azure.Storage
		3) AzureRM.Storage

	5) Back at the Modules blade, click "Add a module" and select your ZIP file with the required DLLs plus the AzureRmStorageTable module files

#>

#Checking if module is being executed in Azure Automation environment
$runbookServerPath = "C:\modules\user"
if (Test-Path -Path ($runbookServerPath))
{
	#Load dlls from runbook server
	#Load dlls from runbook server
	
	$dlls = Get-ChildItem -Path (join-path $PSScriptRoot "*.dll")
	foreach ($dll in $dlls)
	{
		[System.Reflection.Assembly]::LoadFrom($dll.fullname)		
	}
}
else
{
	# Excution is in a regular VM

	#---------------------------------------------------------------
	# Loading Microsoft.WindowsAzure.StorageClient.dll fron .NET SDK
	#---------------------------------------------------------------
	$dllName = "Microsoft.WindowsAzure.Storage.dll"
	$localPathToStorageDll = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager\AzureRM.Storage\$dllName"

	if (Test-Path -Path $localPathToStorageDll)
	{
		[System.Reflection.Assembly]::LoadFrom($localPathToStorageDll)
	}
	elseif (Test-Path -Path $(".\$dllName"))
	{
		# Load dll from same folder as script
		[System.Reflection.Assembly]::LoadFrom(".\$dllName")
	}
	else
	{
		throw "Azure PowerShell module must be installed in order to expose $dllName file."		
	}

	#---------------------------------------------------------------------------------------
	# Loading Microsoft.WindowsAzure.Commands.Common.Storage.dll for Azure PowerShell module
	#---------------------------------------------------------------------------------------
	$dllName = "Microsoft.WindowsAzure.Commands.Common.Storage.dll"
	$pathToCommonStorageDll = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager\AzureRM.Storage\$dllName"
	$runbookServerPathToCommonStorageDll = "C:\modules\Global\Azure\Azure.Storage\$dllName"

	if (Test-Path -Path $pathToCommonStorageDll)
	{
		[System.Reflection.Assembly]::LoadFrom($pathToCommonStorageDll)
	}
	elseif (Test-Path -Path $(".\$dllName"))
	{
		# Load dll from same folder as script
		[System.Reflection.Assembly]::LoadFrom(".\$dllName")
	}
	else
	{
		throw "Azure PowerShell module must be installed in order to expose $dllName file."	
	}	
}


function Add-StorageTableRow
{
	<#
	.SYNOPSIS
		Adds a row/entity to a specified table
	.DESCRIPTION
		Adds a row/entity to a specified table
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable where the entity will be added
	.PARAMETER PartitionKey
		Identifies the table partition
	.PARAMETER RowKey
		Identifies a row within a partition
	.PARAMETER Property
		Hashtable with the columns that will be part of the entity. e.g. @{"firstName"="Paulo";"lastName"="Marques"}
	.EXAMPLE
		# Adding a row
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext
		Add-StorageTableRow -table $table -partitionKey $partitionKey -rowKey ([guid]::NewGuid().tostring()) -property @{"firstName"="Paulo";"lastName"="Costa";"role"="presenter"}
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table,
		#[Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable]$table,
		
		[Parameter(Mandatory=$true)]
        [String]$partitionKey,

		[Parameter(Mandatory=$true)]
        [String]$rowKey,

		[Parameter(Mandatory=$true)]
        [hashtable]$property
	)
	
	# Creates the table entity with mandatory partitionKey and rowKey arguments
    $entity = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity -ArgumentList $partitionKey, $rowKey

    # Adding the additional columns to the table entity

	foreach ($prop in $property.Keys)
	{
		$entity.Properties.Add($prop, $property.Item($prop))
	}
    
    # Adding the dynamic table entity to the table
	return ($table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity)))
}

function Get-PSObjectFromEntity
{
	# Internal function
	# Converts entities output from the ExecuteQuery method of table into an array of PowerShell Objects

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$entityList
	)

	$returnObjects = @()

	if (-not [string]::IsNullOrEmpty($entityList))
	{
		foreach ($entity in $entityList)
		{
			$entityNewObj = New-Object -TypeName psobject
			$entity.Properties.Keys | % {Add-Member -InputObject $entityNewObj -Name $_ -Value $entity.Properties[$_].PropertyAsObject -MemberType NoteProperty}

			# Adding PartitionKey and RowKey to Object
			Add-Member -InputObject $entityNewObj -Name "PartitionKey" -Value $entity.PartitionKey -MemberType NoteProperty
			Add-Member -InputObject $entityNewObj -Name "RowKey" -Value $entity.RowKey -MemberType NoteProperty

			$returnObjects += $entityNewObj
		}
	}

	return $returnObjects

}

function Get-AzureStorageTableRowAll
{
	<#
	.SYNOPSIS
		Returns all rows/entities from a storage table - no filtering
	.DESCRIPTION
		Returns all rows/entities from a storage table - no filtering
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable to retrieve entities
	.EXAMPLE
		# Getting all rows
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext
		Get-AzureStorageTableRowAll -table $table
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table
	)

	# No filtering
	$tableQuery = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.TableQuery

	$result = $table.CloudTable.ExecuteQuery($tableQuery)

	if (-not [string]::IsNullOrEmpty($result))
	{
		return (Get-PSObjectFromEntity -entityList $result)
	}
}

function Get-AzureStorageTableRowByPartitionKey
{
	<#
	.SYNOPSIS
		Returns one or more rows/entities based on Partition Key
	.DESCRIPTION
		Returns one or more rows/entities based on Partition Key
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable to retrieve entities
	.PARAMETER PartitionKey
		Identifies the table partition
	.EXAMPLE
		# Getting rows by partition Key
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext
		Get-AzureStorageTableRowByPartitionKey -table $table -partitionKey $newPartitionKey
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table,

		[Parameter(Mandatory=$true)]
		[string]$partitionKey
	)
	
	# Filtering by Partition Key

	$tableQuery = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.TableQuery

	[string]$filter = `
		[Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("PartitionKey",`
		[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,$partitionKey)

	$tableQuery.FilterString = $filter

	$result = $table.CloudTable.ExecuteQuery($tableQuery)

	if (-not [string]::IsNullOrEmpty($result))
	{
		return (Get-PSObjectFromEntity -entityList $result)
	}
}

function Get-AzureStorageTableRowByColumnName
{
	<#
	.SYNOPSIS
		Returns one or more rows/entities based on a specified column and its value
	.DESCRIPTION
		Returns one or more rows/entities based on a specified column and its value
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable to retrieve entities
	.PARAMETER ColumnName
		Column name to compare the value to
	.PARAMETER Value
		Value that will be looked for in the defined column
	.PARAMETER Operator
		Supported comparison operator. Valid values are "Equal","GreaterThan","GreaterThanOrEqual","LessThan" ,"LessThanOrEqual" ,"NotEqual"
	.EXAMPLE
		# Getting row by firstname
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext
		Get-AzureStorageTableRowByColumnName -table $table -columnName "firstName" -value "Paulo" -operator Equal
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table,

		[Parameter(Mandatory=$true)]
		[string]$columnName,

		[Parameter(Mandatory=$true)]
		[string]$value,

		[Parameter(Mandatory=$true)]
		[validateSet("Equal","GreaterThan","GreaterThanOrEqual","LessThan" ,"LessThanOrEqual" ,"NotEqual")]
		[string]$operator
	)
	
	# Filtering by Partition Key

	$tableQuery = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.TableQuery

	[string]$filter = `
		[Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition($columnName,[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::$operator,$value)

	$tableQuery.FilterString = $filter

	$result = $table.CloudTable.ExecuteQuery($tableQuery)

	if (-not [string]::IsNullOrEmpty($result))
	{
		return (Get-PSObjectFromEntity -entityList $result)
	}
}

function Get-AzureStorageTableRowByCustomFilter
{
	<#
	.SYNOPSIS
		Returns one or more rows/entities based on custom filter.
	.DESCRIPTION
		Returns one or more rows/entities based on custom filter. This custom filter can be
		built using the Microsoft.WindowsAzure.Storage.Table.TableQuery class or direct text.
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable to retrieve entities
	.PARAMETER customFilter
		Custom filter string.
	.EXAMPLE
		# Getting row by firstname by using the class Microsoft.WindowsAzure.Storage.Table.TableQuery
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext
		Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $finalFilter
	.EXAMPLE
		# Getting row by firstname by using text filter directly (oData filter format)
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext
		Get-AzureStorageTableRowByCustomFilter -table $table -customFilter "(firstName eq 'User1') and (lastName eq 'LastName1')"
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table,

		[Parameter(Mandatory=$true)]
		[string]$customFilter
	)
	
	# Filtering by Partition Key

	$tableQuery = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.TableQuery

	$tableQuery.FilterString = $customFilter

	$result = $table.CloudTable.ExecuteQuery($tableQuery)

	if (-not [string]::IsNullOrEmpty($result))
	{
		return (Get-PSObjectFromEntity -entityList $result)
	}
}

function Update-AzureStorageTableRow
{
	<#
	.SYNOPSIS
		Updates a table entity
	.DESCRIPTION
		Updates a table entity. To work with this cmdlet, you need first retrieve an entity with one of the Get-AzureStorageTableRow cmdlets available
		and store in an object, change the necessary properties and then perform the update passing this modified entity back, through Pipeline or as argument.
		Notice that this cmdlet accepts only one entity per execution. 
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable where the entity exists
	.PARAMETER Entity
		The entity/row with new values to perform the update.
	.EXAMPLE
		# Updating an entity
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext	
		[string]$filter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("firstName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"User1")
		$person = Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $filter
		$person.lastName = "New Last Name"
		$person | Update-AzureStorageTableRow -table $table
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table,

		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		$entity
	)
    
    # Only one entity at a time can be updated
    $updatedEntityList = @()
    $updatedEntityList += $entity

    if ($updatedEntityList.Count -gt 1)
    {
        throw "Update operation can happen on only one entity at a time, not in a list/array of entities."
    }

	# Getting original entity
	[string]$partitionFilter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("PartitionKey",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal, $updatedEntityList[0].PartitionKey)
	[string]$rowFilter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("RowKey",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal, $updatedEntityList[0].RowKey)
	
	[string]$finalFilter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::CombineFilters($partitionFilter,"and",$rowFilter)

	$currentEntity = Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $finalFilter

	$updatedEntity = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity -ArgumentList $currentEntity.PartitionKey, $currentEntity.RowKey

	# Iterating over PS Object properties to add to the updated entity 
	foreach ($prop in $entity.psobject.Properties)
	{
		if (($prop.name -ne "PartitionKey") -or ($prop.name -ne "RowKey"))
		{
			$updatedEntity.Properties.Add($prop.name, $prop.Value)
		}
	}

	$updatedEntity.ETag = "*"

    # Updating the dynamic table entity to the table
	return ($table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Replace($updatedEntity)))
}

function Remove-AzureStorageTableRow
{
	<#
	.SYNOPSIS
		Remove-AzureStorageTableRow - Removes a specified table row
	.DESCRIPTION
		Remove-AzureStorageTableRow - Removes a specified table row. It accepts multiple deletions through the Pipeline when passing entities returned from the Get-AzureStorageTableRow
		available cmdlets. It also can delete a row/entity using Partition and Row Key properties directly.   
	.PARAMETER Table
		Table object of type Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageTable where the entity exists
	.PARAMETER Entity (ParameterSetName=byEntityPSObjectObject)
		The entity/row with new values to perform the deletion.
	.PARAMETER PartitionKey (ParameterSetName=byPartitionandRowKeys)
		Partition key where the entity belongs to.
	.PARAMETER RowKey (ParameterSetName=byPartitionandRowKeys)
		Row key that uniquely identifies the entity within the partition.		 
	.EXAMPLE
		# Deleting an entry by entity PS Object
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext	
		[string]$filter1 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("firstName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"Paulo")
		[string]$filter2 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("lastName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"Marques")
		[string]$finalFilter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::CombineFilters($filter1,"and",$filter2)
		$personToDelete = Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $finalFilter
		$personToDelete | Remove-AzureStorageTableRow -table $table
	.EXAMPLE
		# Deleting an entry by using partitionkey and row key directly
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext	
		Remove-AzureStorageTableRow -table $table -partitionKey "TableEntityDemoFullList" -rowKey "399b58af-4f26-48b4-9b40-e28a8b03e867"
	.EXAMPLE
		# Deleting everything
		$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
		$table = Get-AzureStorageTable -Name $tableName -Context $saContext	
		Get-AzureStorageTableRowAll -table $table | Remove-AzureStorageTableRow -table $table
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$table,

		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ParameterSetName="byEntityPSObjectObject")]
		$entity,

		[Parameter(Mandatory=$true,ParameterSetName="byPartitionandRowKeys")]
		[string]$partitionKey,

		[Parameter(Mandatory=$true,ParameterSetName="byPartitionandRowKeys")]
		[string]$rowKey
	)

	begin
	{
		$updatedEntityList = @()
		$updatedEntityList += $entity

		if ($updatedEntityList.Count -gt 1)
		{
			throw "Delete operation cannot happen on an array of entities, altough you can pipe multiple items."
		}

		$results = @()
	}
	
	process
	{
		if ($PSCmdlet.ParameterSetName -eq "byEntityPSObjectObject")
		{
			$partitionKey = $entity.PartitionKey
			$rowKey = $entity.RowKey
		}

		$entityToDelete = ($table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Retrieve($partitionKey,$rowKey))).Result

		if ($entityToDelete -ne $null)
		{
			$results += $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Delete($entityToDelete))
		}
	}
	
	end
	{
		return ,$results
	}
}
