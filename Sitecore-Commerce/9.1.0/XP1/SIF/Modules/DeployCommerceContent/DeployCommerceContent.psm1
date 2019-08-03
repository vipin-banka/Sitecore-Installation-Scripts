
Function Invoke-DeployCommerceContentTask {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[Parameter(Mandatory=$true)]
		[string]$ServicesContentPath,
		[Parameter(Mandatory=$true)]
		[string]$PhysicalPath,        
		[Parameter(Mandatory=$true)]
		[string]$UserName,
		[Parameter(Mandatory=$true)]
		[string]$SitecoreIdentityServerUrl, 
		[Parameter(Mandatory=$false)]
		[psobject[]]$BraintreeAccount = @(),        
		[Parameter(Mandatory=$false)]
		[string]$CommerceSearchProvider,				
		[Parameter(Mandatory=$false)]
		[string]$CommerceServicesDbServer,
		[Parameter(Mandatory=$false)]
		[string]$CommerceServicesDbName,
		[Parameter(Mandatory=$false)]
		[string]$CommerceServicesGlobalDbName,
		[Parameter(Mandatory=$false)]
		[string]$SiteHostHeaderName,
		[Parameter(Mandatory=$false)]
		[string]$CommerceServicesHostPostfix,
		[Parameter(Mandatory=$false)]
		[string]$CommerceAuthoringServicesPort,
		[Parameter(Mandatory=$false)]
		[string]$SitecoreBizFxPort,
		[Parameter(Mandatory=$false)]
		[string]$SolrUrl,
		[Parameter(Mandatory=$false)]
		[string]$SearchIndexPrefix,	
		[Parameter(Mandatory=$false)]
		[string]$EnvironmentsPrefix,
		[Parameter(Mandatory=$false)]
		[string]$EngineCertificateThumbprint,
		[Parameter(Mandatory=$false)]
		[string]$AzureSearchServiceName,		
		[Parameter(Mandatory=$false)]
		[string]$AzureSearchAdminKey,		
		[Parameter(Mandatory=$false)]
		[string]$AzureSearchQueryKey
	)

	try {       
		switch ($Name) {
			{($_ -match "CommerceOps")} {                    
				Write-Host 
				$global:opsServicePath = "$PhysicalPath\*"
				$commerceServicesItem =  Get-Item $ServicesContentPath | select-object -first 1

				if (Test-Path $commerceServicesItem -PathType Leaf) {
					# Assume path to zip file passed in, extract zip to $PhysicalPath
					#Extracting the CommerceServices zip file Commerce Shops Services
					Write-Host "Extracting CommerceServices from $commerceServicesItem to $PhysicalPath" -ForegroundColor Yellow ;
					Expand-Archive $commerceServicesItem -DestinationPath $PhysicalPath -Force
					Write-Host "CommerceOps Services extraction completed" -ForegroundColor Green ;	
				}
				else {
					# Assume path is to a published Commerce Engine folder. Copy the contents of the folder to the $PhysicalPath
					Write-Host "Copying the contents of CommerceServices from $commerceServicesItem to $PhysicalPath" -ForegroundColor Yellow ;
					Get-ChildItem $ServicesContentPath | Copy-item -Destination $PhysicalPath -Container -Recurse
					Write-Host "CommerceOps Services copy completed" -ForegroundColor Green ;	
				}               			

				$commerceServicesLogDir = $(Join-Path -Path $PhysicalPath -ChildPath "wwwroot\logs")                
				if(-not (Test-Path -Path $commerceServicesLogDir)) {                      
					Write-Host "Creating Commerce Services logs directory at: $commerceServicesLogDir"
					New-Item -Path $PhysicalPath -Name "wwwroot\logs" -ItemType "directory"
				}

				Write-Host "Granting full access to $UserName to logs directory: $commerceServicesLogDir"
				GrantFullReadWriteAccessToFile -Path $commerceServicesLogDir  -UserName "$($UserName)"							

				# Set the proper environment name                
				$pathToJson  = $(Join-Path -Path $PhysicalPath -ChildPath "wwwroot\config.json")
				$originalJson = Get-Content $pathToJson -Raw  | ConvertFrom-Json										
				
				Write-Host "Applying certificate: $($EngineCertificateThumbprint)" -ForegroundColor Green
				$originalJson.Certificates.Certificates[0].Thumbprint = $EngineCertificateThumbprint
				$originalJson.AppSettings.CommerceServicesHostPostfix = $CommerceServicesHostPostfix
				$originalJson.AppSettings.SitecoreIdentityServerUrl = $SitecoreIdentityServerUrl

				$originalJson.AppSettings.EnvironmentName = "$($EnvironmentsPrefix)Authoring"
				$allowedOrigins = @("https://localhost:$SitecoreBizFxPort", "https://$SiteHostHeaderName")
				if ($CommerceServicesHostPostfix){
					$allowedOrigins += "https://bizfx.$CommerceServicesHostPostfix"
				}
				$originalJson.AppSettings.AllowedOrigins = $allowedOrigins 
				
				$originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToJson

				#Replace database name in Global.json
				$pathToGlobalJson  = $(Join-Path -Path $PhysicalPath -ChildPath "wwwroot\bootstrap\Global.json")
				$originalJson = Get-Content $pathToGlobalJson -Raw  | ConvertFrom-Json
				foreach ($p in $originalJson.Policies.'$values') {
					if ($p.'$type' -eq 'Sitecore.Commerce.Plugin.SQL.EntityStoreSqlPolicy, Sitecore.Commerce.Plugin.SQL') {						
						$oldServer = $p.Server
						$oldDatabase = $p.Database
						$p.Server = $CommerceServicesDbServer
						$p.Database = $CommerceServicesGlobalDbName
						Write-Host "Replacing in EntityStoreSqlPolicy $oldServer with $CommerceServicesDbServer and $oldDatabase with $CommerceServicesGlobalDbName"
					} elseif ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Management.SitecoreConnectionPolicy, Sitecore.Commerce.Plugin.Management') {
						if ($SiteHostHeaderName -ne "sxa.storefront.com") {
							$p.Host = $SiteHostHeaderName	
							Write-Host "Replacing in SitecoreConnectionPolicy 'sxa.storefront.com' with $SiteHostHeaderName"
						}
					}
				}
				$originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToGlobalJson
				
				$pathToEnvironmentFiles = $(Join-Path -Path $PhysicalPath -ChildPath "wwwroot\data\Environments")

				# if setting up Azure search provider we need to rename the azure and solr files
				if ($CommerceSearchProvider -eq 'AZURE') {

					#rename the azure file from .disabled and disable the Solr policy file
					$AzurePolicyFile = Get-ChildItem "$pathToEnvironmentFiles\PlugIn.Search.Azure.PolicySet*.disabled"
					$SolrPolicyFile = Get-ChildItem "$pathToEnvironmentFiles\PlugIn.Search.Solr.PolicySet*.json"
					$newName = $AzurePolicyFile.FullName -replace ".disabled",''
					RenameMessage $($AzurePolicyFile.FullName) $($newName);
					Rename-Item $AzurePolicyFile -NewName $newName -f;
					$newName = $SolrPolicyFile.FullName -replace ".json",'.json.disabled'
					RenameMessage $($SolrPolicyFile.FullName) $($newName);
					Rename-Item $SolrPolicyFile -NewName $newName -f;
					Write-Host "Renaming search provider policy sets to enable Azure search"
				}

				#Replace database name in environment files
				$Writejson = $false
				$environmentFiles = Get-ChildItem $pathToEnvironmentFiles -Filter *.json
				foreach ($jsonFile in $environmentFiles) {
					$json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
					foreach ($p in $json.Policies.'$values') {
						if ($p.'$type' -eq 'Sitecore.Commerce.Plugin.SQL.EntityStoreSqlPolicy, Sitecore.Commerce.Plugin.SQL') {
							$oldServer = $p.Server
							$oldDatabase = $p.Database;
							$Writejson = $true
							$p.Server = $CommerceServicesDbServer
							$p.Database =  $CommerceServicesDbName
							Write-Host "Replacing in EntityStoreSqlPolicy $oldServer with $CommerceServicesDbServer and $oldDatabase with $CommerceServicesDbName"
						} elseif ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Management.SitecoreConnectionPolicy, Sitecore.Commerce.Plugin.Management') {
							if ($SiteHostHeaderName -ne "sxa.storefront.com") {
								$oldHost = $p.Host;
								$Writejson = $true
								$p.Host =  $SiteHostHeaderName
								Write-Host "Replacing SiteHostHeaderName $oldHost with $SiteHostHeaderName"
							}
						} elseif ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Search.Solr.SolrSearchPolicy, Sitecore.Commerce.Plugin.Search.Solr') {
							$p.SolrUrl = $SolrUrl;
							$Writejson = $true;
							Write-Host "Replacing Solr Url"
						} elseif ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Search.Azure.AzureSearchPolicy, Sitecore.Commerce.Plugin.Search.Azure') {
							$p.SearchServiceName = $AzureSearchServiceName;
							$p.SearchServiceAdminApiKey = $AzureSearchAdminKey;
							$p.SearchServiceQueryApiKey = $AzureSearchQueryKey;
							$Writejson = $true;
							Write-Host "Replacing Azure service information"
						} elseif ($p.'$type' -eq 'Plugin.Sample.Payments.Braintree.BraintreeClientPolicy, Plugin.Sample.Payments.Braintree') {
							$p.MerchantId = $BraintreeAccount.MerchantId;
							$p.PublicKey = $BraintreeAccount.PublicKey;
							$p.PrivateKey = $BraintreeAccount.PrivateKey;
							$Writejson = $true;
							Write-Host "Inserting Braintree account"
						} elseif ($p.'$type' -eq 'Sitecore.Commerce.Core.PolicySetPolicy, Sitecore.Commerce.Core' -And $p.'PolicySetId' -eq 'Entity-PolicySet-SolrSearchPolicySet') {
							if ($CommerceSearchProvider -eq 'AZURE') {
								$p.'PolicySetId' = 'Entity-PolicySet-AzureSearchPolicySet';
								$Writejson = $true
							}
						} elseif ($p.'$type' -eq 'Sitecore.Commerce.Plugin.BusinessUsers.EnvironmentBusinessToolsPolicy,Sitecore.Commerce.Plugin.BusinessUsers') {
						    if ($CommerceServicesHostPostfix) {
								$p.ServiceUrl = "https://commerceauthoring.$CommerceServicesHostPostfix";							
							} else {
								$p.ServiceUrl = $p.ServiceUrl -replace "5000", $CommerceAuthoringServicesPort
							}
							$Writejson = $true;
							Write-Host "Updating ServiceUrl"
						}
					}
					if ($Writejson) {
						$json = ConvertTo-Json $json -Depth 100
						Set-Content $jsonFile.FullName -Value $json -Encoding UTF8
						$Writejson = $false
					}
				}
								
				if ([string]::IsNullOrEmpty($SearchIndexPrefix) -eq $false) {
					#modify the search policy set
					$jsonFile = Get-ChildItem "$pathToEnvironmentFiles\PlugIn.Search.PolicySet*.json"
					$json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
					$indexes = @()
					# Generically update the different search scope policies so it will be updated for any index that exists or is created in the future
					Foreach ($p in $json.Policies.'$values') {
						if ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Search.SearchViewPolicy, Sitecore.Commerce.Plugin.Search') {
							$oldSearchScopeName = $p.SearchScopeName
							$searchScopeName = "$SearchIndexPrefix$oldSearchScopeName"
							$p.SearchScopeName = $searchScopeName;
							$Writejson = $true;

							Write-Host "Replacing SearchViewPolicy SearchScopeName $oldSearchScopeName with $searchScopeName"

							# Use this to figure out what indexes will exist
							$indexes += $searchScopeName
						}

						if ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Search.SearchScopePolicy, Sitecore.Commerce.Plugin.Search') 
						{
							$oldName = $p.Name
							$name = "$SearchIndexPrefix$oldName"
							$p.Name = $name;
							$Writejson = $true;

							Write-Host "Replacing SearchScopePolicy Name $oldName with $name"
						}

						if ($p.'$type' -eq 'Sitecore.Commerce.Plugin.Search.IndexablePolicy, Sitecore.Commerce.Plugin.Search') 
						{
							$oldSearchScopeName = $p.SearchScopeName
							$searchScopeName = "$SearchIndexPrefix$oldSearchScopeName"
							$p.SearchScopeName = $searchScopeName;
							$Writejson = $true;

							Write-Host "Replacing IndexablePolicy SearchScopeName $oldSearchScopeName with $searchScopeName"
						}
					}
					
					if ($Writejson) {
						$json = ConvertTo-Json $json -Depth 100
						Set-Content $jsonFile.FullName -Value $json -Encoding UTF8
						$Writejson = $false
					}
				}
			}
			{($_ -match "CommerceShops") -or ($_ -match "CommerceAuthoring") -or ($_ -match "CommerceMinions")}  {
				# Copy the the CommerceServices files to the $Name Services
				Write-Host "Copying Commerce Services from $global:opsServicePath to $PhysicalPath" -ForegroundColor Yellow ;
				Copy-Item -Path $global:opsServicePath -Destination $PhysicalPath -Force -Recurse
				Write-Host "$($_) Services extraction completed" -ForegroundColor Green ;

				$commerceServicesLogDir = $(Join-Path -Path $PhysicalPath -ChildPath "wwwroot\logs")
				if(-not (Test-Path -Path $commerceServicesLogDir)) {                      
					Write-Host "Creating Commerce Services logs directory at: $commerceServicesLogDir"
					New-Item -Path $PhysicalPath -Name "wwwroot\logs" -ItemType "directory"
				}
				
				Write-Host "Granting full access to $UserName to logs directory: $commerceServicesLogDir"
				GrantFullReadWriteAccessToFile -Path $commerceServicesLogDir  -UserName "$($UserName)"

				# Set the proper environment name
				$pathToJson  = $(Join-Path -Path $PhysicalPath -ChildPath "wwwroot\config.json")
				$originalJson = Get-Content $pathToJson -Raw | ConvertFrom-Json
				
				$environment = "$($EnvironmentsPrefix)Shops"
				if ($Name -match "CommerceAuthoring"){
					$environment = "$($EnvironmentsPrefix)Authoring"
				}elseif ($Name -match "CommerceMinions"){
					$environment = "$($EnvironmentsPrefix)Minions"
				}		
				$originalJson.AppSettings.EnvironmentName = $environment
				$originalJson.AppSettings.SitecoreIdentityServerUrl = $SitecoreIdentityServerUrl
				$originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToJson
			}     
			{($_ -match "BizFx")} {
				Write-Host
				# Copying the BizFx content
				$commerceServicesItem = Get-Item $ServicesContentPath | select-object -first 1
				if (Test-Path $commerceServicesItem -PathType Leaf) {
					# Assume path to zip file passed in, extract zip to $PhysicalPath
					#Extracting the BizFx zip file 
					Write-Host "Extracting BizFx from $commerceServicesItem to $PhysicalPath" -ForegroundColor Yellow ;
					Expand-Archive $commerceServicesItem -DestinationPath $PhysicalPath -Force
					Write-Host "SitecoreBizFx extraction completed" -ForegroundColor Green ;
				}
				else {
					# Assume path is to a published BizFx folder. Copy the contents of the folder to the $PhysicalPath
				   Write-Host "Copying the BizFx content $ServicesContentPath to $PhysicalPath" -ForegroundColor Yellow ;
				   Get-ChildItem $ServicesContentPath | Copy-item -Destination $PhysicalPath -Container -Recurse
				   Write-Host "SitecoreBizFx copy completed" -ForegroundColor Green ;
				}
				
				$pathToJson  = $(Join-Path -Path $PhysicalPath -ChildPath "assets\config.json")
				$originalJson = Get-Content $pathToJson -Raw  | ConvertFrom-Json
				if ($CommerceServicesHostPostfix){
					$originalJson.BizFxUri = "https://bizfx.$CommerceServicesHostPostfix"
					$originalJson.EngineUri = "https://commerceauthoring.$CommerceServicesHostPostfix"
				} else {
					$originalJson.BizFxUri = $originalJson.BizFxUri -replace "4200", $SitecoreBizFxPort  
					$originalJson.EngineUri = $originalJson.EngineUri -replace "5000", $CommerceAuthoringServicesPort
				}
				$originalJson.IdentityServerUri = $SitecoreIdentityServerUrl               
				$originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToJson                			
			}			
			default { Write-Host "Create content failed for $($_). Name $($_) is unknown" }
		}
	}
	catch {
		Write-Error $_
	}
}


Function Invoke-CreatePerformanceCountersTask {   

	try {
		$countersVersion = "1.0.2"
		$ccdTypeName = "System.Diagnostics.CounterCreationData"       
		$perfCounterCategoryName = "SitecoreCommerceEngine-$countersVersion"
		$perfCounterInformation = "Performance Counters for Sitecore Commerce Engine"
		$commandCountersName = "SitecoreCommerceCommands-$countersVersion"
		$metricsCountersName = "SitecoreCommerceMetrics-$countersVersion"
		$listCountersName = "SitecoreCommerceLists-$countersVersion"
		$counterCollectionName = "SitecoreCommerceCounters-$countersVersion"
		[array]$allCounters = $commandCountersName,$metricsCountersName,$listCountersName,$counterCollectionName

		Write-Host "Attempting to delete existing Sitecore Commmerce Engine performance counters"

		# delete all counters
		foreach($counter in $allCounters)
		{
			$categoryExists = [System.Diagnostics.PerformanceCounterCategory]::Exists($counter)
			If ($categoryExists)
			{
				Write-Host "Deleting performance counters $counter" -ForegroundColor Green
				[System.Diagnostics.PerformanceCounterCategory]::Delete($counter); 
			}
			Else
			{
				Write-Warning "$counter does not exist, no need to delete"
			}
		}

		Write-Host "`nAttempting to create Sitecore Commmerce Engine performance counters"

		# command counters
		Write-Host "`nCreating $commandCountersName performance counters" -ForegroundColor Green
		$CounterCommandCollection = New-Object System.Diagnostics.CounterCreationDataCollection
		$CounterCommandCollection.Add( (New-Object $ccdTypeName "CommandsRun", "Number of times a Command has been run", NumberOfItems32) )
		$CounterCommandCollection.Add( (New-Object $ccdTypeName "CommandRun", "Command Process Time (ms)", NumberOfItems32) )
		$CounterCommandCollection.Add( (New-Object $ccdTypeName "CommandRunAverage", "Average of time (ms) for a Command to Process", AverageCount64) )
		$CounterCommandCollection.Add( (New-Object $ccdTypeName "CommandRunAverageBase", "Average of time (ms) for a Command to Process Base", AverageBase) )
		[System.Diagnostics.PerformanceCounterCategory]::Create($commandCountersName, $perfCounterInformation, [Diagnostics.PerformanceCounterCategoryType]::MultiInstance, $CounterCommandCollection) | out-null

		# metrics counters
		Write-Host "`nCreating $metricsCountersName performance counters" -ForegroundColor Green
		$CounterMetricCollection = New-Object System.Diagnostics.CounterCreationDataCollection
		$CounterMetricCollection.Add( (New-Object $ccdTypeName "MetricCount", "Count of Metrics", NumberOfItems32) )
		$CounterMetricCollection.Add( (New-Object $ccdTypeName "MetricAverage", "Average of time (ms) for a Metric", AverageCount64) )
		$CounterMetricCollection.Add( (New-Object $ccdTypeName "MetricAverageBase", "Average of time (ms) for a Metric Base", AverageBase) )
		[System.Diagnostics.PerformanceCounterCategory]::Create($metricsCountersName, $perfCounterInformation, [Diagnostics.PerformanceCounterCategoryType]::MultiInstance, $CounterMetricCollection) | out-null

		# list counters
		Write-Host "`nCreating $listCountersName performance counters" -ForegroundColor Green
		$ListCounterCollection = New-Object System.Diagnostics.CounterCreationDataCollection
		$ListCounterCollection.Add( (New-Object $ccdTypeName "ListCount", "Count of Items in the CommerceList", NumberOfItems32) )
		[System.Diagnostics.PerformanceCounterCategory]::Create($listCountersName, $perfCounterInformation, [Diagnostics.PerformanceCounterCategoryType]::MultiInstance, $ListCounterCollection) | out-null

		# counter collection
		Write-Host "`nCreating $counterCollectionName performance counters" -ForegroundColor Green
		$CounterCollection = New-Object System.Diagnostics.CounterCreationDataCollection
		$CounterCollection.Add( (New-Object $ccdTypeName "ListItemProcess", "Average of time (ms) for List Item to Process", AverageCount64) )
		$CounterCollection.Add( (New-Object $ccdTypeName "ListItemProcessBase", "Average of time (ms) for a List Item to Process Base", AverageBase) )
		[System.Diagnostics.PerformanceCounterCategory]::Create($counterCollectionName, $perfCounterInformation, [Diagnostics.PerformanceCounterCategoryType]::MultiInstance, $CounterCollection) | out-null          
	}
	catch {
		Write-Error $_
	}
}

Register-SitecoreInstallExtension -Command Invoke-DeployCommerceContentTask -As DeployCommerceContent -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-CreatePerformanceCountersTask -As CreatePerformanceCounters -Type Task -Force

function RenameMessage([string] $oldFile, [string] $newFile){
	Write-Host "Renaming " -nonewline;
	Write-Host "$($oldFile) " -nonewline -ForegroundColor Yellow;
	Write-Host "to " -nonewline;
	Write-Host "$($newFile)" -ForegroundColor Green;
}

function GrantFullReadWriteAccessToFile 
{

PARAM
  (
	[String]$Path=$(throw 'Parameter -Path is missing!'),
	[String]$UserName=$(throw 'Parameter -UserName is missing!')
  )
  Trap
  {
	Write-Host "Error: $($_.Exception.GetType().FullName)" -ForegroundColor Red ; 
	Write-Host $_.Exception.Message; 
	Write-Host $_.Exception.StackTrack;
	break;
  }
  
  $colRights = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [System.Security.AccessControl.FileSystemRights]::Modify;
  #$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit;
  #$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None;
  $objType =[System.Security.AccessControl.AccessControlType]::Allow;
  
  $Acl = (Get-Item $Path).GetAccessControl("Access");
  $Ar = New-Object system.security.accesscontrol.filesystemaccessrule($UserName, $colRights, $objType);

  for ($i=1; $i -lt 30; $i++)
  {
	  try
	  {
		Write-Host "Attempt $i to set permissions GrantFullReadWriteAccessToFile"
		$Acl.SetAccessRule($Ar);
		Set-Acl $path $Acl;
		break;
	  }
	  catch
	  {
		Write-Host "Attempt to set permissions failed. Error: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow ; 
		Write-Host $_.Exception.Message; 
		Write-Host $_.Exception.StackTrack;
	
		Write-Host "Retrying command in 10 seconds" -ForegroundColor Yellow ;

		Start-Sleep -Seconds 10
	  }
  }
}
# SIG # Begin signature block
# MIINGQYJKoZIhvcNAQcCoIINCjCCDQYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1/nRrqGEGNfYOz/dtKUTLFKk
# K96gggpjMIIFKzCCBBOgAwIBAgIQB6Zc7QsNL9EyTYMCYZHvVTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE3MDgyMzAwMDAwMFoXDTIwMDkz
# MDEyMDAwMFowaDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAmNhMRIwEAYDVQQHEwlT
# YXVzYWxpdG8xGzAZBgNVBAoTElNpdGVjb3JlIFVTQSwgSW5jLjEbMBkGA1UEAxMS
# U2l0ZWNvcmUgVVNBLCBJbmMuMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEAuz2f4Iboa0P6f9AoOwUa2I8O2TMfBzQWphJtBJfrHnT1mHgABa4w0qRAsWI7
# yvPzTkvXZLQt+Vy9k0RDDiZO+OpmaomvoPjUAzxGg4zTxv4k9IFrDngmvXVHCFLZ
# wUNIQSrLkW2rt5+8NbiIK9839vb3PTYQqM9ZtrgTSLiwZZCoLl8ID7eK84+uvtfC
# Vd8ci0CaEt2QAPJOhZ2ZbTQfuBwdCyqT5hfD5gJuX4cBs+iRUynvhwgUbbsDhBEU
# ndRDe0xiosXM0l/BSTM/OHXDnwC8Y04+kVBeUzUkCw9qQAoGFpfDDNJRLQ/9Xon+
# 0yjB6mgPrJv8ia5ShLTq/N+gbwIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5
# eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYEFC4etEljgTp1PU0hatHNrFpjHbux
# MA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8EcDBu
# MDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNz
# LWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNz
# dXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggrBgEF
# BQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEwgYQG
# CCsGAQUFBwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tME4GCCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRTSEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIw
# ADANBgkqhkiG9w0BAQsFAAOCAQEAaM6SYQXbGs9fRPX2mv8La57LFK3isWVZGEPj
# VYlnsiJnOahGXAz8t0IH+99ZFT52LsIuUtFPqsoOadQjZ/1rL5ybHcPGjtJbHmnb
# vDxArh49WecOJouaxjavkFWEgQdrwYeT7Oa17onwRRfGJ1MgXNirlgTgqujE0TdR
# 9rFOS7TlHEJGnL/IcqJvAxxEW3d5iAZFfH5rQJr8BWDgrF3QRzksEFL37Odxskq5
# yGIlk9MueplWD8A4+4fz3VjuYSLmZup+aISJy4oNcHolQydueK/tqX8skU/tNiVV
# cchxTAi8AgErOL4G4mczA5bZqEwx8/YFC8bvwnwRjNMGjA7t3DCCBTAwggQYoAMC
# AQICEAQJGBtf1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEz
# MTAyMjEyMDAwMFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8G
# A1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP
# 0PtFmbE620T1f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6
# funRZ9PG+yknx9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQt
# oaPpiCwgla4cSocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ry
# CuRXu0q16XTmK/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKW
# wfIPEvTFjg/BougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9EC
# AwEAAaOCAc0wggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGG
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0
# MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYw
# OAYKYIZIAYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2Vy
# dC5jb20vQ1BTMAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32
# ZXUOWDAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0B
# AQsFAAOCAQEAPuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v9
# 7yrfIFU3sOH20ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZO
# XP+QsRsHDpEV+7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+b
# p1wgXNlxsQyPu6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd
# 6fp0ZGuy62ZD2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92Ju
# oVP6EpQYhS6SkepobEQysmah5xikmmRR7zGCAiAwggIcAgEBMIGGMHIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2Rl
# IFNpZ25pbmcgQ0ECEAemXO0LDS/RMk2DAmGR71UwCQYFKw4DAhoFAKBwMBAGCisG
# AQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQSXcU63DuTQ3+O
# l0lGeEbwZeKxWjANBgkqhkiG9w0BAQEFAASCAQBr6zgp7K9PXs8/yAE2QDgLZU6L
# YtF3ONfiFMihMir+6KlFm6hG+/xTnIXnNqaKnDeRprdle6oWcdY2PeeFkMDHsm4z
# ND4+5lEHVG0LrfYbyrkrL9+zfRN5TM+Dy8gsZlx2wiufqhzJjFXeBB36sO0PUhaJ
# TpscSCIWTSG1THDusC/fzvITEcK/JVZJb3/Cr3R3Lvtag6th4SGDRiiB+qM8Hxt1
# SE8VlotmUoCjJ1mbhcnMGZp1ambklc7msbKmbMZ5IxRFHQ5Bjq7dvjC40rC5I999
# FkI5A492v32hzVpZNBR+7XeIfiI13Wquh8G8JxfiTJGUYQ920LiNjRC5Kfc3
# SIG # End signature block
