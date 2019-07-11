
##  *** 
##  *** 
##  *** 
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


Write-Host "Preparing Parameters"

$PathToWinScp = $OctopusParameters['PathToWinScp']
$FtpHost = $OctopusParameters['FtpHost']
$ftpPort = $OctopusParameters['FtpPort']
$ftpProtocol = $OctopusParameters['FtpProtocol']
$FtpUsername = $OctopusParameters['FtpUsername']
$FtpPassword = $OctopusParameters['FtpPassword']
$FtpRemoteDirectory = $OctopusParameters['FtpRemoteDirectory']
$FileName =  $OctopusParameters['FileName']
$FileAge = $OctopusParameters['FileName']

Write-Host "Parameters were loaded"
Write-Host "FileName: "$FileName
Write-Host "Fle Age:"$FileAge


 # Load WinSCP .NET assembly
    Add-Type -Path "$PathToWinScp\WinSCPnet.dll"
	Write-Host "Added .NET WinSCP assembly"

		# Connect


	# Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::$FtpProtocol
        HostName = $FtpHost
        PortNumber = $FtpPort
        UserName = $FtpUsername
        Password = $FtpPassword
        SshHostKeyFingerprint = $FTPSSHFingerprint
    }
 
    $session = New-Object WinSCP.Session
    
    Try
    {

        $session.Open($sessionOptions)

        $list = $session.ListDirectory($FtpRemoteDirectory)
        if ($FileName -match '[*]')
        {
            $wildc = $FileName  -replace '[*]',''
            Write-Host "Matched WildCard!"
        }
        else 
        {
            $wildc = $FileName
        }

        if ($list.count -gt 0)
           {
                foreach ($fileInfo in $List.Files)
                    {
                        if ($fileInfo.name -match $wildc -and $fileInfo.LastWriteTime -lt [DateTime]::Now.AddDays($FileAge))
                        {                            Write-Host ("{0} with size {1}, permissions {2} and last modification at {3}" -f 
                            $fileInfo.Name, $fileInfo.Length, $fileInfo.FilePermissions, $fileInfo.LastWriteTime);
                            $removename=(-join ($FtpRemoteDirectory,$fileinfo.Name)) ;
                            Write-Host $removename ;
                                
                            $removalResult = $session.RemoveFiles($session.EscapeFileMask($removename))
 
                            if ($removalResult.IsSuccess)
                            {
                                Write-Host ("Removing of file {0} succeeded" -f
                                    $fileinfo.FileName)
                            }
                            else
                            {
                                Write-Host ("Removing of file {0} failed" -f
                                    $fileinfo.FileName)
                            }
                        }
                    }
           }
        else 
        {
            Write-Host ("No files matching {0} found")
        }
    }

    Catch  [Exception]
    {
        Write-Host ("Error: {0}" -f $_.Exception.Message)
        exit 1
    }
         
    Finally
    {
        # Disconnect, clean up
        $session.Dispose()
    }
