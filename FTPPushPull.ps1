
##  *** 
##  ***    FTP Transfer routine Created by Steven McManus
##  *** 
##  *** 	This routine was developed for upload  and download
##  *** 	any file for Octopus. 
##  *** 
##  ***  	By Steven McManus  2016.07.18
##  *** 
##  *** Functions
function ValidCheck([string]$foo, [string[]]$validInput, $parameterName) {
    if (! $parameterName -contains "Password") { 
        Write-Host "${parameterName}: $foo" 
    }
    if (! $foo) {
        throw "No value was set for $parameterName, and it cannot be empty"
    }
}
function Validate-Parameter([string]$foo, [string[]]$validInput, $parameterName) {
    if (! $parameterName -contains "Password") 
    { 
        Write-Host "${parameterName}: $foo" 
    }
    if (! $foo) {
        throw "No value was set for $parameterName, and it cannot be empty"
    }
}

Function FriendlyErr ($thisError) {
    [string] $Return = $thisError.Exception
    $Return += "`r`n"
    $Return += "At line:" + $thisError.InvocationInfo.ScriptLineNumber
    $Return += " char:" + $thisError.InvocationInfo.OffsetInLine
    $Return += " For: " + $thisError.InvocationInfo.Line
    Return $Return
}

function FileTransferProgress
{
    param($e)
 
    # New line for every new file
    if (($script:lastFileName -ne $Null) -and
        ($script:lastFileName -ne $e.FileName))
    {
        Write-Host
    }
 
    # Print transfer progress
    Write-Host -NoNewline ("`r{0} ({1:P0})" -f $e.FileName, $e.FileProgress)
 
    # Remember a name of the last file reported
    $script:lastFileName = $e.FileName
}

Write-Host "Preparing Parameters"

$PathToWinScp = $OctopusParameters['PathToWinScp']
$FtpHost = $OctopusParameters['FtpHost']
$FtpProtocol = $OctopusParameters['FtpProtocol']
$FtpPort = $OctopusParameters['FtpPort']
$FtpUsername = $OctopusParameters['FtpUsername']
$FtpPassword = $OctopusParameters['FtpPassword']
$FtpSSHFingerprint = $OctopusParameters['FtpSSHFingerprint']
$FtpRemoteDirectory = $OctopusParameters['FtpRemoteDirectory']
$FileName =  $OctopusParameters['FileName']
$FTPExt =  $OctopusParameters['FTPExt']
$LocalFilePath = $OctopusParameters['LocalFilePath']
$PushOrPull = $OctopusParameters['PushOrPull']
$Remove = $OctopusParameters['Remove']
$UseCustom = $OctopusParameters['UseCustom']
$connectionString = $OctopusParameters['SCRDB']
$OverWrite = $OctopusParameters['OverWrite']
$CID = $OctopusParameters['Octopus.Action.Package.CustomInstallationDirectory']

Write-Host "Parameters were loaded"

function extractValues ($string, $values){
    return ($values | %{ $string -match "$_=([^;]+)" | Out-Null; $matches} | %{$_[1]})
}

Write-Host "Using $connectionString"
	try {
	# Load WinSCP .NET assembly
	Add-Type -Path "$PathToWinScp\WinSCPnet.dll"
	Write-Host "Added .NET WinSCP assembly"

	Validate-Parameter $PathToWinScp -parameterName "Path to WinSCP .NET Assembly"
	Validate-Parameter $FtpHost -parameterName "Host"
	Validate-Parameter $FtpPort -parameterName "Port"
	Validate-Parameter $FtpUsername -parameterName "Username"
	Validate-Parameter $FtpPassword -parameterName "Password"
	Validate-Parameter $FtpSSHFingerprint -parameterName "FTP SSH Fingerprint"
	Validate-Parameter $FtpRemoteDirectory -parameterName "Remote directory"
	Validate-Parameter $FileName -parameterName "Filename"
	Validate-Parameter $FTPExt -parameterName "File Extension"
	Validate-Parameter $LocalFilePath -parameterName "Local fileing system path."
	Validate-Parameter $PushOrPull -parameterName "Push to or Pull from the FTP Server"
	Validate-Parameter $OverWrite -parameterName "Overwrite File on Destination"
	Validate-Parameter $UseCustom -parameterName "Source for FileName"
	Write-Host "Parameters were Validated"
	Write-host "Remove:" $Remove

	write-host ("FtpProtocol:$FtpProtocol")
	write-host ("FtpHost:$FtpHost")
	write-host ("FtpPort:$FtpPort")
	write-host ("FtpUsername:$FtpUsername")
	write-host ("FtpPassword:$FtpPassword")
	write-host ("FtpSSHFingerprint:$FtpSSHFingerprint")

	$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
		Protocol = [WinSCP.Protocol]::$FtpProtocol
		HostName = $FtpHost
		PortNumber = $FtpPort
		UserName = $FtpUsername
		Password = $FtpPassword
		SshHostKeyFingerprint = $FtpSSHFingerprint
		}
	 
		$session = New-Object WinSCP.Session
	 
		Write-host "All Values Loaded. Now Executing."
		
		try
		{
			if ($UseCustom -eq "Custom") {
				($serverName, $dbName, $user, $pass) = extractValues $connectionString @("Data Source", "Initial Catalog", "User ID", "Password")
				$FileName = $dbName.trim()
			}

			Write-Host ("Connecting to FTP:$FtpHost ")
			Write-Host ("$PushOrPull $FileName ")
			Write-Host (" from/to Location: $LocalFilePath")
			
			# Connect
			$session.Open($sessionOptions)

			if ($FTPExt -eq 'zip') {
				$fname =  (($LocalFilePath.Split('\')[-1]).trim())
				$remotefile =  "$FtpRemoteDirectory$fname.$FTPExt"
				$localfile = "$LocalFilePath.$FTPExt"
			}
			else {
				$localfile = join-path $LocalFilePath "$FileName.$FTPExt"
				$remotefile = "$FtpRemoteDirectory$Filename.$FTPExt"
			}
			Write-Host ("local: $localfile / Remote: $remotefile")
			
			if ($PushOrPull -eq "Push") { 
				if (Test-path $localFile) {
					if ($session.FileExists($remotefile)) {
						if ($OverWrite) {
							Write-Host ("Deleting Remote file(Overwrite Enabled) ... $remotefile  on $FtpHost" )
							$session.RemoveFiles("$remotefile")
							Write-Host ("Uploading ... $remotefile  to $FtpHost" )
							$session.PutFiles("$LocalFile", "$RemoteFile").Check() 
						}
						else {
							 throw "Destination File $RemoteFile exists and Overwrite Not Enabled."
						}
					}
					else {
						Write-Host ("Uploading ... $remotefile  to $FtpHost" )
						$session.PutFiles("$LocalFile", "$RemoteFile").Check() 
					
					}
					if ($Remove) {
						remove-item $localFile
					}
				}
				else { 
					throw "Source File $localFile doesn't exist"
				}
				
					
			}
			if ($PushOrPull -eq "Pull")
				{
				if ($session.Fileexists("$RemoteFile")) {
					if (Test-path "$localFile") {
						if ($Overwrite) {
							Write-Host ("Deleting Local file(Overwrite Enabled) ... $localFile" )
							Remove-Item -Path  "$localFile" -Force
							Write-Host ("Downloading  ... $remotefile from $FtpHost ")
							$session.GetFiles("$RemoteFile", "$localFile" ).Check()
						}
						else {
							throw "Destination File $localFile exists and Overwrite Not Enabled."
						}
					}
					else { 
						Write-Host ("Downloading  ... $remotefile from $FtpHost ")
						$session.GetFiles("$RemoteFile", "$localFile" ).Check()
					}
					if ($remove) {
						$session.RemoveFiles("$remotefile")
					}
				}
				else {
					throw "Source File $RemoteFile doesn't exist"
				}
			}
			
		}
		
		finally
		{
			# Disconnect, clean up
			$session.Dispose()
		}
	 
		exit 0
	}
	catch [Exception] {
		Write-Host ("Error: {0}" -f $_.Exception.Message)
			exit 1
	}