
Function Invoke-UpdateShopsHostnameTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EngineConnectIncludeDir,
        [Parameter(Mandatory = $true)]
        [string]$CommerceServicesHostPostfix                   
    )      

    $pathToConfig = $(Join-Path -Path $EngineConnectIncludeDir -ChildPath "\Sitecore.Commerce.Engine.Connect.config") 
    $xml = [xml](Get-Content $pathToConfig)

    $node = $xml.configuration.sitecore.commerceEngineConfiguration
    $node.shopsServiceUrl = $node.shopsServiceUrl -replace "localhost:5000", "commerceauthoring.$CommerceServicesHostPostfix"
    $node.commerceOpsServiceUrl = $node.commerceOpsServiceUrl -replace "localhost:5000", "commerceauthoring.$CommerceServicesHostPostfix"
    $xml.Save($pathToConfig)      
}

Function Invoke-UpdateShopsPortTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EngineConnectIncludeDir,
        [Parameter(Mandatory = $true)]
        [string]$CommerceAuthoringServicesPort                  
    )      
    $pathToConfig = $(Join-Path -Path $EngineConnectIncludeDir -ChildPath "\Sitecore.Commerce.Engine.Connect.config") 
    $xml = [xml](Get-Content $pathToConfig)
    $node = $xml.configuration.sitecore.commerceEngineConfiguration
    $node.shopsServiceUrl = $node.shopsServiceUrl -replace "5000", $CommerceAuthoringServicesPort
    $node.commerceOpsServiceUrl = $node.commerceOpsServiceUrl -replace "5000", $CommerceAuthoringServicesPort
    $xml.Save($pathToConfig)      
}

Function Invoke-ApplyCertificateTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EngineConnectIncludeDir,
        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint,
        [Parameter(Mandatory = $true)]
        [string[]]$CommerceServicesPathCollection
    )      

    Write-Host "Applying certificate: $($CertificateThumbprint)" -ForegroundColor Green

    $pathToConfig = $(Join-Path -Path $EngineConnectIncludeDir -ChildPath "\Sitecore.Commerce.Engine.Connect.config") 
    $xml = [xml](Get-Content $pathToConfig)
    $node = $xml.configuration.sitecore.commerceEngineConfiguration
    $node.certificateThumbprint = $CertificateThumbprint
    $xml.Save($pathToConfig)  

    foreach ($path in $CommerceServicesPathCollection) {
        $pathToJson = $(Join-Path -Path $path -ChildPath "wwwroot\config.json") 
        $originalJson = Get-Content $pathToJson -Raw | ConvertFrom-Json
        $certificateNode = $originalJson.Certificates.Certificates[0]
        $certificateNode.Thumbprint = $CertificateThumbprint      
        $originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToJson
    } 
}

Function Invoke-GetIdServerTokenTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject[]]$SitecoreAdminAccount,
        [Parameter(Mandatory = $true)]
        [string]$UrlIdentityServerGetToken        
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", 'application/x-www-form-urlencoded')
    $headers.Add("Accept", 'application/json')

    $body = @{
        password   = $SitecoreAdminAccount.password
        grant_type = 'password'
        username   = $SitecoreAdminAccount.userName
        client_id  = 'postman-api'
        scope      = 'openid EngineAPI postman_api'
    }

    Write-Host "Get Token From Sitecore.IdentityServer" -ForegroundColor Green
    $response = Invoke-RestMethod $UrlIdentityServerGetToken -Method Post -Body $body -Headers $headers

    $global:sitecoreIdToken = "Bearer {0}" -f $response.access_token
}

Function Invoke-BootStrapCommerceServicesTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UrlCommerceShopsServicesBootstrap        
    )
    Write-Host "BootStrapping Commerce Services: $($urlCommerceShopsServicesBootstrap)" -ForegroundColor Yellow
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $global:sitecoreIdToken)
    Invoke-RestMethod $UrlCommerceShopsServicesBootstrap -TimeoutSec 1200 -Method PUT -Headers $headers
    Write-Host "Commerce Services BootStrapping completed" -ForegroundColor Green
}

Function Invoke-InitializeCommerceServicesTask {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true)]
        [string]$UrlInitializeEnvironment,
        [Parameter(Mandatory = $true)]
        [string]$UrlCheckCommandStatus,
        [Parameter(Mandatory = $true)]
        [string[]]$Environments)

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $global:sitecoreIdToken);

    foreach ($env in $Environments) {
        Write-Host "Initializing $($env) ..." -ForegroundColor Yellow

        $initializeUrl = $UrlInitializeEnvironment

        $payload = @{
            "environment"=$env;
        }

        $result = Invoke-RestMethod $initializeUrl -TimeoutSec 1200 -Method POST -Body ($payload|ConvertTo-Json) -Headers $headers -ContentType "application/json"
        $checkUrl = $UrlCheckCommandStatus -replace "taskIdValue", $result.TaskId

        $sw = [system.diagnostics.stopwatch]::StartNew()
        $tp = New-TimeSpan -Minute 10
        do {
            Start-Sleep -s 30
            Write-Host "Checking if $($checkUrl) has completed ..." -ForegroundColor White
            $result = Invoke-RestMethod $checkUrl -TimeoutSec 1200 -Method Get -Headers $headers -ContentType "application/json"

            if ($result.ResponseCode -ne "Ok") {
                $(throw Write-Host "Initialize environment $($env) failed, please check Engine service logs for more info." -Foregroundcolor Red)
            }
        } while ($result.Status -ne "RanToCompletion" -and $sw.Elapsed -le $tp)

        Write-Host "Initialization for $($env) completed ..." -ForegroundColor Green
    }

    Write-Host "Initialization completed ..." -ForegroundColor Green 
}

Function Invoke-EnableCsrfValidationTask {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true)]
        [string[]]$CommerceServicesPathCollection
    )

    foreach ($path in $CommerceServicesPathCollection) {
        $pathToJson = $(Join-Path -Path $path -ChildPath "wwwroot\config.json")
        $originalJson = Get-Content $pathToJson -Raw  | ConvertFrom-Json
        $originalJson.AppSettings.AntiForgeryEnabled = $true
        $originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToJson
    }
}

Function Invoke-DisableCsrfValidationTask {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true)]
        [string[]]$CommerceServicesPathCollection
    )
    foreach ($path in $CommerceServicesPathCollection) {
        $pathToJson = $(Join-Path -Path $path -ChildPath "wwwroot\config.json")
        $originalJson = Get-Content $pathToJson -Raw  | ConvertFrom-Json
        $originalJson.AppSettings.AntiForgeryEnabled = $false
        $originalJson | ConvertTo-Json -Depth 100 -Compress | set-content $pathToJson
    }
}

Function Invoke-EnsureSyncDefaultContentPathsTask {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true)]
        [string]$UrlEnsureSyncDefaultContentPaths,
        [Parameter(Mandatory = $true)]
        [string]$UrlCheckCommandStatus,
        [Parameter(Mandatory = $true)]
        [string[]]$Environments)

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $global:sitecoreIdToken);
   
    foreach ($env in $Environments) {
        Write-Host "Ensure/Sync default content paths for: $($env)" -ForegroundColor Yellow 

        $ensureUrl = $UrlEnsureSyncDefaultContentPaths -replace "envNameValue", $env
        $result = Invoke-RestMethod $ensureUrl -TimeoutSec 1200 -Method PUT -Headers $headers  -ContentType "application/json" 
        $checkUrl = $UrlCheckCommandStatus -replace "taskIdValue", $result.TaskId

        $sw = [system.diagnostics.stopwatch]::StartNew()
        $tp = New-TimeSpan -Minute 10
        do {
            Start-Sleep -s 30
            Write-Host "Checking if $($checkUrl) has completed ..." -ForegroundColor White
            $result = Invoke-RestMethod $checkUrl -TimeoutSec 1200 -Method Get -Headers $headers -ContentType "application/json"

            if ($result.ResponseCode -ne "Ok") {
                $(throw Write-Host "Ensure/Sync default content paths for environment $($env) failed, please check Engine service logs for more info." -Foregroundcolor Red)
            }
            
        } while ($result.Status -ne "RanToCompletion" -and $sw.Elapsed -le $tp)

        Write-Host "Ensure/Sync default content paths for $($env) completed ..." -ForegroundColor Green
    }

    Write-Host "Ensure/Sync default content paths completed ..." -ForegroundColor Green
}

Register-SitecoreInstallExtension -Command Invoke-UpdateShopsHostnameTask -As UpdateShopsHostname -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-UpdateShopsPortTask -As UpdateShopsPort -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-ApplyCertificateTask -As ApplyCertificate -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-GetIdServerTokenTask -As GetIdServerToken -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-BootStrapCommerceServicesTask -As BootStrapCommerceServices -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-InitializeCommerceServicesTask -As InitializeCommerceServices -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-EnableCsrfValidationTask -As EnableCsrfValidation -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-DisableCsrfValidationTask -As DisableCsrfValidation -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-EnsureSyncDefaultContentPathsTask -As EnsureSyncDefaultContentPaths -Type Task -Force
# SIG # Begin signature block
# MIINGQYJKoZIhvcNAQcCoIINCjCCDQYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJOI9P7jicTBcPxRQOnzVezDY
# oQugggpjMIIFKzCCBBOgAwIBAgIQB6Zc7QsNL9EyTYMCYZHvVTANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTtHeeXh6fR+k1S
# MoDpIiRPu4uRfTANBgkqhkiG9w0BAQEFAASCAQAxppc24JVwVQmoWQj+qXjZ6LfZ
# 8X1bMG8F1qX3SJOKiyrzwjVlFfCntWle65sKPDV1N5HkQsRQgnDPT7QAjhmGQanv
# suC8hVmZxvYYSk8dLUktMANfdMQaSTCBiDGE2zdkR1Hr/kY29n8BEJZpPy/Fo44B
# cfMjuQfuXf/WwDjfyRK+MEhO55xLsWuP+pFEbZQEpuUeM0Nh1KyAY1dMOZTeE6I7
# DMpoddgzDJXBG/wK3sYM47qucYNus/1cEz8K9VZwpgcnfTFC/X+PiJzPQeZ3n/Vv
# 6N5sUlIgDMWJlEmD/SOkvJBq9LH4rEmcWyFDTJFDijqdIxMCBh/2pFb4U1l1
# SIG # End signature block
