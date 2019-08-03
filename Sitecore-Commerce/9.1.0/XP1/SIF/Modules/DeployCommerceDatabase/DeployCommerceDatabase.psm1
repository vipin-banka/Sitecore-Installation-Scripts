
function Invoke-DeployCommerceDatabaseTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommerceServicesDbServer,
        [Parameter(Mandatory=$true)]
        [string]$CommerceServicesDbName,
        [Parameter(Mandatory=$true)]
        [string]$CommerceServicesGlobalDbName,
        [Parameter(Mandatory=$true)]
        [string]$CommerceEngineDacPac,
        [Parameter(Mandatory=$true)]
        [string]$UserName
    )

    #************************************************************************
    #***** DEPLOY DATABASE DACPACS ****
    #************************************************************************
    #Drop the CommerceServices databases if they exist
    Write-Host "Deleting existing CommerceServices databases...";
    Add-SQLPSSnapin;
    DropSQLDatabase $CommerceServicesDbName
    DropSQLDatabase $CommerceServicesGlobalDbName

    Write-Host "Creating CommerceServices databases...";
    $connectionString = "Server=" + $CommerceServicesDbServer + ";Trusted_Connection=Yes;"

    #deploy using the dacpac
    try {
        deploydacpac $CommerceEngineDacPac $connectionString $CommerceServicesGlobalDbName
        deploydacpac $CommerceEngineDacPac $connectionString $CommerceServicesDbName
        write-host "adding roles to commerceservices databases...";
        AddSqlUserToRole $CommerceServicesDbServer $CommerceServicesGlobalDbName $UserName "db_owner"
        AddSqlUserToRole $CommerceServicesDbServer $CommerceServicesDbName $UserName "db_owner"
    }
    catch {
        Write-Host $_.Exception
        Write-Error $_ -ErrorAction Continue
        $dacpacError = $TRUE
    }
}

function Invoke-AddCommerceUserToCoreDatabaseTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SitecoreDbServer,
        [Parameter(Mandatory=$true)]
        [string]$SitecoreCoreDbName,
        [Parameter(Mandatory=$true)]
        [string]$UserName
    )

    #************************************************************************
    #***** Grant Sitecore Core database permissions to Commerce User     ****
    #************************************************************************

    try {
        AddSqlUserToRole $SitecoreDbServer $SitecoreCoreDbName $UserName "db_owner"
    }
    catch {
        Write-Error $_ -ErrorAction Continue
    }
}

function Add-SQLPSSnapin
{
    #
    # Add the SQL Server Provider.
    #

    $ErrorActionPreference = "Stop";

    $shellIds = Get-ChildItem HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds;

    if(Test-Path -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps") {
        $sqlpsreg = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps"
    }
    elseif(Test-Path -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps110") {
        try{
            if((Get-PSSnapin -Registered |? { $_.Name -ieq "SqlServerCmdletSnapin110"}).Count -eq 0) {

                Write-Host "Registering the SQL Server 2012 Powershell Snapin";

                if(Test-Path -Path $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe;
                }
                elseif (Test-Path -Path $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe;
                }
                else {
                    throw "InstallUtil wasn't found!";
                }

                if(Test-Path -Path "$env:ProgramFiles\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "$env:ProgramFiles\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "$env:ProgramFiles\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }
                elseif(Test-Path -Path "${env:ProgramFiles(x86)}\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }

                Add-PSSnapin SQLServer*110;
                Write-Host "Sql Server 2012 Powershell Snapin registered successfully.";
            }
        }catch{}

        $sqlpsreg = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps110";
    }
    elseif(Test-Path -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps120") {
        try{
            if((Get-PSSnapin -Registered |? { $_.Name -ieq "SqlServerCmdletSnapin120"}).Count -eq 0) {

                Write-Host "Registering the SQL Server 2014 Powershell Snapin";

                if(Test-Path -Path $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe;
                }
                elseif (Test-Path -Path $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe;
                }
                else {
                    throw "InstallUtil wasn't found!";
                }

                if(Test-Path -Path "$env:ProgramFiles\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "$env:ProgramFiles\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "$env:ProgramFiles\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }
                elseif(Test-Path -Path "${env:ProgramFiles(x86)}\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }

                Add-PSSnapin SQLServer*120;
                Write-Host "Sql Server 2014 Powershell Snapin registered successfully.";
            }
        }catch{}

        $sqlpsreg = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps120";
    }
    elseif(Test-Path -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps130") {
        try{
            if((Get-PSSnapin -Registered |? { $_.Name -ieq "SqlServerCmdletSnapin130"}).Count -eq 0) {

                Write-Host "Registering the SQL Server 2016 Powershell Snapin";

                if(Test-Path -Path $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe;
                }
                elseif (Test-Path -Path $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe;
                }
                else {
                    throw "InstallUtil wasn't found!";
                }

                if(Test-Path -Path "$env:ProgramFiles\Microsoft SQL Server\130\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "$env:ProgramFiles\Microsoft SQL Server\130\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "$env:ProgramFiles\Microsoft SQL Server\130\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }
                elseif(Test-Path -Path "${env:ProgramFiles(x86)}\Microsoft SQL Server\130\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\130\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\130\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }

                Add-PSSnapin SQLServer*130;
                Write-Host "Sql Server 2016 Powershell Snapin registered successfully.";
            }
        }catch{}

        $sqlpsreg = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps130";
    }
    elseif(Test-Path -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps140") { 
        try{
            if((Get-PSSnapin -Registered |? { $_.Name -ieq "SqlServerCmdletSnapin140"}).Count -eq 0) {
                Write-Host "Registering the SQL Server 2017 Powershell Snapin";
                if(Test-Path -Path $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe;
                }
                elseif (Test-Path -Path $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe) {
                    Set-Alias installutil $env:windir\Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe;
                }
                else {
                    throw "InstallUtil wasn't found!";
                }
                if(Test-Path -Path "$env:ProgramFiles\Microsoft SQL Server\140\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "$env:ProgramFiles\Microsoft SQL Server\140\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "$env:ProgramFiles\Microsoft SQL Server\140\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll";
                }
                elseif(Test-Path -Path "${env:ProgramFiles(x86)}\Microsoft SQL Server\140\Tools\PowerShell\Modules\SQLPS\") {
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\140\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSProvider.dll";
                    installutil "${env:ProgramFiles(x86)}\Microsoft SQL Server\140\Tools\PowerShell\Modules\SQLPS\Microsoft.SqlServer.Management.PSSnapins.dll"; 
                }

                Add-PSSnapin SQLServer*140;
                Write-Host "Sql Server 2017 Powershell Snapin registered successfully.";
            }
        }catch{}
        $sqlpsreg = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps140";
    }
    else {
        throw "SQL Server Provider for Windows PowerShell is not installed."
    }

    $item = Get-ItemProperty $sqlpsreg
    $sqlpsPath = [System.IO.Path]::GetDirectoryName($item.Path)

    #
    # Set mandatory variables for the SQL Server provider
    #
    Set-Variable -scope Global -name SqlServerMaximumChildItems -Value 0
    Set-Variable -scope Global -name SqlServerConnectionTimeout -Value 30
    Set-Variable -scope Global -name SqlServerIncludeSystemObjects -Value $false
    Set-Variable -scope Global -name SqlServerMaximumTabCompletion -Value 1000

    #
    # Load the snapins, type data, format data
    #
    Push-Location

    cd $sqlpsPath

    if (Get-PSSnapin -Registered | where {$_.name -eq 'SqlServerProviderSnapin100'})
    {
        if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerProviderSnapin100'}))
        {
            Add-PSSnapin SqlServerProviderSnapin100;
        }

        if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerCmdletSnapin100'}))
        {
            Add-PSSnapin SqlServerCmdletSnapin100;
        }

        Write-Host "Using the SQL Server 2008 Powershell Snapin.";

       Update-TypeData -PrependPath SQLProvider.Types.ps1xml -ErrorAction SilentlyContinue
       Update-FormatData -prependpath SQLProvider.Format.ps1xml -ErrorAction SilentlyContinue
    }
    else #Sql Server 2012 or 2014 module should be registered now.  Note, we'll only use it if the earlier version isn't installed.
    {
        if (!(Get-Module -ListAvailable -Name SqlServer))
        {
            Write-Host "Using the SQL Server 2012 or 2014 Powershell Module.";

            if( !(Get-Module | where {$_.name -eq 'sqlps'}))
            {
                Import-Module 'sqlps' -DisableNameChecking;
            }
            cd $sqlpsPath;
            cd ..\PowerShell\Modules\SQLPS;
        }

        Update-TypeData -PrependPath SQLProvider.Types.ps1xml -ErrorAction SilentlyContinue
        Update-FormatData -prependpath SQLProvider.Format.ps1xml -ErrorAction SilentlyContinue
    }

    Pop-Location
}

function DropSQLDatabase
{
    param
    (
        [String]$dbName=$(throw 'Parameter -dbName is missing!')
    )

    try
    {
        $server = new-object ("Microsoft.SqlServer.Management.Smo.Server")
        if($server.Databases.Contains($dbName))
        {
            Write-Host "Attemping to delete database $dbName" -ForegroundColor Green -NoNewline
            Invoke-Sqlcmd -Query "USE [master]; ALTER DATABASE [$($dbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$($dbName)]"
            Write-Host "    DELETED" -ForegroundColor DarkGreen
        }
        else
        {
            Write-Warning "$dbName does not exist, cannot delete"
        }
    }
    catch
    {
	    Write-Host $_.Exception.Message
        Write-Host "    Unable to delete database $dbName" -ForegroundColor Red
    }
}

function AddSqlUserToRole
{
    param
    (
        [String]$dbServer=$(throw 'Parameter -dbServer is missing!'),
        [String]$dbName=$(throw 'Parameter -dbName is missing!'),
        [String]$userName=$(throw 'Parameter -userName is missing!'),
        [String]$role=$(throw 'Parameter -role is missing!')
    )
    Write-Host "Attempting to add the user $userName to database $dbName as role $role" -ForegroundColor Green -NoNewline

    try
    {
        Invoke-Sqlcmd -ServerInstance $dbServer -Query "IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE name = '$($userName)') BEGIN CREATE LOGIN [$($userName)] FROM WINDOWS WITH DEFAULT_DATABASE=[$($dbName)], DEFAULT_LANGUAGE=[us_english] END"
        Invoke-Sqlcmd -ServerInstance $dbServer -Query "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$($userName)') BEGIN USE [$($dbName)] CREATE USER [$($userName)] FOR LOGIN [$($userName)] END"
        Invoke-Sqlcmd -ServerInstance $dbServer -Query "USE [$($dbName)] EXEC sp_addrolemember '$($role)', '$($userName)'"
        Write-Host "     Added" -ForegroundColor DarkGreen
    }
    catch
    {
        Write-Host ""
        Write-Host "Error: Unable to add user $userName`nDetails: $_" -ForegroundColor Red
    }
}

function GetSqlDacVersion
{
    # load in DAC DLL (requires config file to support .NET 4.0)
    # change file location for a 32-bit OS
    # param out the base path of SQL Server
    $sqlServerVersions = @("140", "130", "120", "110");
    $sqlCurrentVersion = ""
    $baseSQLServerPath = "C:\Program Files (x86)\Microsoft SQL Server\{0}\DAC\bin\Microsoft.SqlServer.Dac.dll";

    foreach($sqlServerVersion in $sqlServerVersions)
    {
        $fullPath = $baseSQLServerPath -f $sqlServerVersion;

        if(Test-Path -Path $fullPath)
        {
            Write-Host "Using SQL Server $($sqlServerVersion) to import DACPAC";
            #add-type -path $fullPath;
            $sqlCurrentVersion = $sqlServerVersion
            break;
        }
    }

    return $sqlCurrentVersion
}


#************************************************************************
#**** DACPAC DEPLOY FUNCTION ****
#************************************************************************

function DeployDacpac
(
    [Parameter(Mandatory=$true)][string]$dacpac,
    [Parameter(Mandatory=$true)]$connStr,
    [Parameter(Mandatory=$true)]$databaseName
)
{
    Write-Host "Importing DACPAC $($dacpac)"

    # load in DAC DLL (requires config file to support .NET 4.0)
    # change file location for a 32-bit OS
    # param out the base path of SQL Server
    $sqlServerVersions = @("140", "130", "120", "110");
    $sqlCurrentVersion = ""
    $baseSQLServerPath = "C:\Program Files (x86)\Microsoft SQL Server\{0}\DAC\bin\Microsoft.SqlServer.Dac.dll";

    foreach($sqlServerVersion in $sqlServerVersions)
    {
        $fullPath = $baseSQLServerPath -f $sqlServerVersion;

        if(Test-Path -Path $fullPath)
        {
            Write-Host "Using SQL Server $($sqlServerVersion) to import DACPAC";
            add-type -path $fullPath;
            $sqlCurrentVersion = $sqlServerVersion
            break;
        }
    }

    if($sqlCurrentVersion -match "110")
    {
        Write-Error "Cannot deploy this dacpac with the version Sql 2012, please upgrade your version or use the sql script located in the same location as the dacpac"
        return;
    }

    # make DacServices object, needs a connection string
    $d = new-object Microsoft.SqlServer.Dac.DacServices $connStr;

    # register events, if you want 'em
    register-objectevent -in $d -eventname Message -source "msg" -action { out-host -in $Event.SourceArgs[1].Message.Message }

    # Load dacpac from file & deploy to database named $databaseName
     $dp = [Microsoft.SqlServer.Dac.DacPackage]::Load($dacpac)
     $d.deploy($dp, $databaseName, $TRUE);

    # clean up event
    unregister-event -source "msg";
}

Register-SitecoreInstallExtension -Command Invoke-DeployCommerceDatabaseTask -As DeployCommerceDatabase -Type Task -Force

Register-SitecoreInstallExtension -Command Invoke-AddCommerceUserToCoreDatabaseTask -As AddCommerceUserToCoreDatabase -Type Task -Force
# SIG # Begin signature block
# MIINGQYJKoZIhvcNAQcCoIINCjCCDQYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmUPgj/GJpY9v2K1Ay4CSvuSv
# vbWgggpjMIIFKzCCBBOgAwIBAgIQB6Zc7QsNL9EyTYMCYZHvVTANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRdiJv04pW12gcs
# I88X0/fBWqqcnTANBgkqhkiG9w0BAQEFAASCAQBQuHDV0rK6UP8O6bYyWYKZhMjs
# b2EKaLvKsnHtFqm7+JExPm8IiF4kCdHqJZa3q+0pZa3I7Z6Xrt646F9x0xAHApUn
# IfWR5jH8C65Hg8k5i1jgBd0SLIrSha3GUpbrRk8OGP2Rtv5exi9NtJE/O2yaJr1G
# dCeYznANRLfnVDsV6sYxHWCMl8bzBvoY7PAOl5mngjcr1qoLBcjk3cBhRrKl4wOQ
# esYH1ZxIDBG28Zhjy7wSjsOHQFK0/hRTK9H0JxFqdZ7HewJTXXRWWjZrE9t5rex0
# ad7gTKhBulopEBJia+Cyc+FiSN1g2F761mJjCZ/pPSuLV8oqFaykBaDbESUp
# SIG # End signature block
