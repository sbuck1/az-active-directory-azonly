$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

#BASIC VARIABLES
    
    $date = $startTime.ToString('yyyy-MM-dd')


#END BASIC VARIABLES

Import-Module Azure -ErrorAction SilentlyContinue
Import-Module C:\Dev\PS_Modules\DS_PowerShell_Function_Library.psm1

#DEPLOYMENT OPTIONS

    $DeploymentName          = "az-active-directory-azonly"
    $templateToDeploy        = "$DeploymentName.json"
    $ConfigFileFolder        = "C:\Dev\!az-configfiles"
    $ConfigFileName          = "$DeploymentName.xml"
    $ConfigFileFullPath      = "$ConfigFileFolder\$ConfigFileName"
    $LogFolder               = "C:\Dev\_Logs\$DeploymentName"
    $LogFileName             = "$date.log"
    $LogFileFullPath         = "$LogFolder\$LogFileName"

    # GITHUB SETTINGS
    $Branch                  = "master"
    $GitAssetLocation           = "https://raw.githubusercontent.com/sbuck1/$DeploymentName/$Branch/"
    $AssetLocation = "C:\dev\az-active-directory-azonly"

#END DEPLOYMENT OPTIONS

#Import Config File

DS_WriteLog "I" "Import the Configuration File" $LogFileFullPath
try {
    [xml]$ConfigFileContent = (Get-Content $ConfigFileFullPath)
    DS_WriteLog "S" "The XML file was imported successfully" $LogFileFullPath 
} catch {
    DS_WriteLog "E" "An error occurred trying to import the XML file(error: $($Error[0]))" $LogFileFullPath
    Exit 1
}


DS_WriteLog "I" "Logging into azure" $LogFileFullPath
try {
    $Username = $ConfigFileContent.Settings.Azure.AzureAdminUserName
    $password = get-content $($ConfigFileContent.Settings.Azure.CredentialFilePath) | convertto-securestring
    $credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username,$password
    
    Add-AzureRmAccount -Credential $credentials
    # select subscription
    Select-AzureRmSubscription -SubscriptionID $ConfigFileContent.settings.azure.SubscriptionID
    DS_WriteLog "S" "Logged into Azure successfully" $LogFileFullPath
} catch {
    DS_WriteLog "E" "An error occurred during login to Azure" $LogFileFullPath
    Exit 1
}


#SET UP AZURE PARAMETERS

$deployparms=@{
    "BaseRGName"                 = $ConfigFileContent.Settings.Azure.BaseResourceGroupName
    "RGName"                     = $ConfigFileContent.Settings.Azure.ResourceGroupName
    "RGLocation"                 = $ConfigFileContent.Settings.Azure.ResourceGroupLocation
    "StorageAccountType"         = $ConfigFileContent.Settings.Azure.StorageAccountType
    "VNetName"                   = $ConfigFileContent.Settings.vNet.Name       
    "VNetAddress"                = $ConfigFileContent.Settings.vNet.Address    
    "SubnetName"                = $ConfigFileContent.Settings.Subnet.Name
    "SubnetNetworkAddress"      = $ConfigFileContent.Settings.Subnet.SubnetAddress
    "DC1Name"                   = $ConfigFileContent.Settings.VMs.DC1.Name
    "DC1IPAddress"              = $ConfigFileContent.Settings.VMs.DC1.IPAddress
    "DC1VMSize"                 = $ConfigFileContent.Settings.VMs.DC1.VMSize
    "DC1VMSKU"                    = $ConfigFileContent.Settings.VMs.DC1.SKU
    "DomainFQDN"                = $ConfigFileContent.Settings.Domain.FQDN
    "DomainNETBIOS"             = $ConfigFileContent.Settings.Domain.NETBIOS
    "LocalAdminUsername"        = $ConfigFileContent.Settings.Credentials.LocalAdmin.Username
    "LocalAdminPassword"        = $ConfigFileContent.Settings.Credentials.LocalAdmin.Password
    "DomainAdminUsername"        = $ConfigFileContent.Settings.Credentials.DomainAdmin.Username
    "DomainAdminPassword"        = $ConfigFileContent.Settings.Credentials.DomainAdmin.Password
    "nestedconfigureazactivedirectoryurl"        = "$($GitAssetLocation)nestedtemplates/configure-az-active-directory-azonly.json"
    "dscconfigureazactivedirectoryurl"        = "$($GitAssetLocation)DSC/ConfigureAZDC-azonly.zip"
}

#Create Variables from the Hashtable
foreach($param in $deployparms.GetEnumerator()){new-variable -name $param.name -value $param.value}

#END SET UP AZURE PARAMETERS


#$TemplateFile = "$($assetLocation)$templateToDeploy" + "?x=5"
$templateFile = "$assetLocation\$templateToDeploy"

try {
    Get-AzureRmResourceGroup -Name $RGName -ErrorAction Stop
    Write-Host "Resource group $RGName exists, updating deployment"
}
catch {
    $RG = New-AzureRmResourceGroup -Name $RGName -Location $RGLocation
    Write-Host "Created new resource group $RGName."
}

$version ++
write-host $TemplateFile
write-host $nestedconfigureazactivedirectoryurl
write-host $dscconfigureazactivedirectoryurl

$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $deployparms -TemplateFile $TemplateFile -Name "$DeploymentName$version"  -Force -Verbose

$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds


write-host "Please create a Virtual Network Gateway and connect to the on Prem Network / And customize the DNS Server within the vnet to your OnPrem DNS Servers"