## ------------------------------------------------------------- ##
##						SQL Backup - Connect String
## ------------------------------------------------------------- ##
## 				Created by: Steven McManus
##							2015/10/13
##			this Powershell Script was modified from the existing script used for Update.ps1
##			used on the Database Upgrades
## 	
##			This script will do a backup using the standard SQL connect string. 
## --------------------------------------------------------------##

	$BackupDirectory = $OctopusParameters['DBPath']
	$ConnectionString = $OctopusParameters['ConnectString']
	$Backup = $OctopusParameters['BackRest']
	$TimeOut = $OctopusParameters['ConnectionTimeOut']
	$KevUser = $OctopusParameters['SqlMasterUser']
	$KevPass = $OctopusParameters['SqlMasterPass']
	
if($connectionString -eq "")
{
    Write-Host 'Usage:
        -connectionString "[connectionString]"
        -csFromFile "[FilePath]"
        -csXPath [xPath to connection string] - default is ''/connectionStrings/add[@name="SCRDB"]/@connectionString''
        -applyScripts - to apply scripts, otherwise it will list scripts to be applied only
        -filter ""[conditions]"" conditions used to get script to execute, default is "$executedScripts -notcontains $f.Name -and $f.Major -ge 4"
        -insertExecuted - insert executed record for script, even if no script has beed executed
        
        It may be required to install Sql server snapin, check this out http://jasonq.com/index.php/2012/03/3-things-to-do-if-invoke-sqlcmd-is-not-recognized-in-windows-powershell/
    '
    return
}
invoke-expression "function filter-function(`$f) {return $filter}"

function extractValues($string, $values){
    return ($values | %{ $string -match "$_=([^;]+)" | Out-Null; $matches} | %{$_[1]})
}

Write-Host "Using $connectionString"
($serverName, $dbName, $user, $pass) = extractValues $connectionString @("Data Source", "Initial Catalog", "User ID", "Password")

Write-Host "dbname: $dbname   servername: $servername   user: $user    pass: $pass"

# http://jasonq.com/index.php/2012/03/3-things-to-do-if-invoke-sqlcmd-is-not-recognized-in-windows-powershell/
Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

function CreateDB ($dbNam){
	
	$SrvName='localhost'
	try {
		Import-Module SQLPS -DisableNameChecking
		
		Write-Host "Database Create: Starting - $dbNam"

		#create SMO handle to your database
		$DBObject = CheckDBExists($dbNam)
		#check database exists on server
		if ($DBObject -eq $TRUE) {
			write-host "Database Create: Database Exists- No Action Taken."
		}
		else {
			#Your SQL Server Instance Name
			$inn=Get-ChildItem env:computername
			$iname=$inn.value
write-host "Before SMO. Databasse ($DBNam,$iname)"
			$Srvr = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SrvName
			#### Access the SQL-Server with SQL-Server credentials in mixed mode authentications
			$Srvr.ConnectionContext.LoginSecure = $false 
			$Srvr.ConnectionContext.Login = $kevuser 
			$Srvr.ConnectionContext.Password = $kevpass

			$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($Srvr, $DBNam)
write-host "Create SMO object"
			$db.Create() 
			
Write-host "After Create DB"
			#Confirm, list databases in your current instance
			$Srvr.Databases | Select Name, Status, Owner, CreateDate

			Write-Host "Database Create: Database Creation Finished !"
		}
		# Close & Clear all objects.
	}
	catch {
		write-host “Caught an exception:” -ForegroundColor Red
		write-host “Exception Type: $($_.Exception.GetType().FullName)” -ForegroundColor Red
		write-host “Exception Message: $($_.Exception.Message)” -ForegroundColor Red
		exit 106
	}
}

function extractValues($string, $values){
    return ($values | %{ $string -match "$_=([^;]+)" | Out-Null; $matches} | %{$_[1]})
}

Function CheckDBExists ($DBN){

	$sqlServer = 'localhost'
	$exists = $FALSE
	try {
		# we set this to null so that nothing is displayed
		[System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO') | Out-Null
		# Get reference to database instance
		$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $sqlServer
		#### Access the SQL-Server with SQL-Server credentials in mixed mode authentications
		$server.ConnectionContext.LoginSecure = $false 
		$server.ConnectionContext.Login = $kevuser 
		$server.ConnectionContext.Password = $kevpass

		foreach($db in $server.databases)	{  
			$dbna = $db.name 
			if ($dbna -eq $DBN) {
				$exists = $TRUE
			}
		}
	}
	catch {
		write-host “Caught an exception:” -ForegroundColor Red
		write-host “Exception Type: $($_.Exception.GetType().FullName)” -ForegroundColor Red
		write-host “Exception Message: $($_.Exception.Message)” -ForegroundColor Red
		exit 130
	}
	return $exists
}	

Function Add-UserToRole ([string] $server, [String] $Database , [string]$User, [string]$Role){
try { 
[System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO') | out-null
    $Svr = new-object ("Microsoft.SqlServer.Management.Smo.Server") $server
	$Svr.ConnectionContext.LoginSecure = $false 
	$Svr.ConnectionContext.Login = $kevuser 
	$Svr.ConnectionContext.Password = $kevpass
	
    #Check Database Name entered correctly
    $db = $svr.Databases[$Database]
        if($db -eq $null)
            {
            Write-Host " $Database is not a valid database on $Server"
            Write-Host " Databases on $Server are :"
            $svr.Databases|select name
            break
            }
    #Check Role exists on Database
            $Rol = $db.Roles[$Role]
        if($Rol -eq $null)
            {
            Write-Host " $Role is not a valid Role on $Database on $Server  "
            Write-Host " Roles on $Database are:"
            $db.roles|select name
            break
            }
        if(!($svr.Logins.Contains($User)))
            {
            Write-Host "$User not a login on $server create it first"
            break
            }
        if (!($db.Users.name.Contains($User)))
            {
            # Add user to database

            $usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') ($db, $User)
            $usr.Login = $User
            $usr.Create()

            #Add User to the Role
            $Rol = $db.Roles[$Role]
            $Rol.AddMember($User)
            Write-Host "$User was not a login on $Database on $server"
            Write-Host "$User added to $Database on $Server and $Role Role"
            }
            else
            {
             #Add User to the Role
            $Rol = $db.Roles[$Role]
            $Rol.AddMember($User)
            Write-Host "$User added to $Role Role in $Database on $Server "
            }
    }
    catch {
	write-host “Caught an exception:” -ForegroundColor Red
	write-host “Exception Type: $($_.Exception.GetType().FullName)” -ForegroundColor Red
	write-host “Exception Message: $($_.Exception.Message)” -ForegroundColor Red
	exit 
    }
}

		
Function LoginCreate ( $servern, $DBase , $logi, $passw){

	Write-Host "Create Login: Starting - $logi"
#First Create login --------------------
	#import SQL Server module
	Import-Module SQLPS -DisableNameChecking
	 
	#your SQL Server Instance Name
	Write-host "kevuser: $kevuser -- kevpass:$kevpass"
	try {
		$Server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $servern
		#### Access the SQL-Server with SQL-Server credentials in mixed mode authentications
		$server.ConnectionContext.LoginSecure = $false 
		$server.ConnectionContext.Login = $kevuser 
		$server.ConnectionContext.Password = $kevpass
		if ($Server.logins.Contains($logi)){
			write-host "Create Login: ($logi) Exists on Server - no action taken"
		}
		else {
			Write-Host "--Starting LoginCreate--"
			$usr =  New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $server, $logi
			$usr.LoginType = 'SqlLogin'
			$usr.PasswordExpirationEnabled = $false
			$usr.PasswordPolicyEnforced = $false
			$usr.Create($passw)
			Write-Host "Create Login: Login ($logi) Created on Server"
		}
#-------------------create login end

		# Load the SMO assembly
		# [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO') | out-null

		# Connect to the instance using SMO
		#	$s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Server


		$log = $Server.Logins.name -contains $logi
		if (!($log)) {
			write-output "Create Login: $logi- has not been created correctly."
			break;
		}


		# Cycle through the databases
		foreach ($db in $Server.Databases) {
			$dbna = $db.name
			if ($dbna -eq $DBName) {
				$dbname = $dbna
				$logname = $logi
				# Check to see if the login is a user in this database
				$usrtest = ($db.Users.name -contains $logname)

				if (!($usrtest)) {
					# Not present, so add it
					$usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') $db, $logname
					$usr.Login = $logname
					$usr.Create()
					Write-Host "Create Login: User $logi Created"
					$Rslt = Add-UserToRole	$servername $dbName $logi 'db_owner'
				}
				
				$cstring = "Data Source=$serverName;Initial Catalog=$dbName;Persist Security Info=True;User ID=$kevuser;Password=$kevpass;MultipleActiveResultSets=True"
				$cn1 = New-Object System.Data.SqlClient.SqlConnection($cstring);
				$cn1.Open()

				$q1 = "EXEC sp_change_users_login 'Auto_Fix', '$logname'"
				$cmd1 = new-object "System.Data.SqlClient.SqlCommand" ($q1, $cn1)
				$cmd1.ExecuteNonQuery() | out-null
			$cn1.Close()
			Write-Host "Create Login: User $logi Orphaned User Fixed"
				

				# Check to see if the user is a member of the db_owner role
			}
		}
	}
	catch {
	write-host “Caught an exception:” -ForegroundColor Red
	write-host “Exception Type: $($_.Exception.GetType().FullName)”  -ForegroundColor Red
	write-host “Exception Message: $($_.Exception.Message)” -ForegroundColor Red
	exit 222
	}
}	



try {
    
    if ($backup -eq "b"){
	    $scriptInfo = $args[0]
		$conn = New-Object System.Data.SqlClient.SqlConnection($connectionString)
		$conn.Open()
		$Query = "BACKUP DATABASE  $dbname  TO DISK='$BackupDirectory\Backup\$dbName.bak' WITH INIT"
		Write-Host "Proceeding with {"$Query"}"
		$backrest = $conn.CreateCommand()
		$backrest.CommandText = $Query
		$backrest.CommandTimeout = $TimeOut
		$backrest.ExecuteNonQuery() #| Out-Null
		$conn.close()
	}
	if ($backup -eq "r"){
		
		Try {
			CreateDB($dbName)
		}
		catch {
			Write-Error "Failed to Create DB ($dbname) on $sqlServer"
		}
		LoginCreate 'localhost'  $dbname  $user  $pass
		# Restore Database
		
		Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
		Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
		$Svr = new-object ("Microsoft.SqlServer.Management.Smo.Server") $ServerName
		$Svr.ConnectionContext.LoginSecure = $false 
		$Svr.ConnectionContext.Login = $kevuser 
		$Svr.ConnectionContext.Password = $kevpass
		$svr.KillAllProcesses("$dbname")
		
		$rst = new-object Microsoft.SqlServer.Management.Smo.Restore -Property @{
		   Action = 'database'
		   Database = $DBName
		   ReplaceDatabase = $true
		   NoRecovery = $false
		   PercentCompleteNotification = 10
		}
		Write-Host "Database Restore: Starting - $dbName"

			
			$pass = ConvertTo-SecureString "$kevpass" -AsPlainText -Force
			$svr.KillAllProcesses("$dbname")
			$mycreds = New-Object System.Management.Automation.PSCredential ($Kevuser, $Pass) 
			  
			Restore-SqlDatabase -Database $dbName -ServerInstance "localhost" -Backupfile "$BackupDirectory\Backup\$dbName.bak"  -Credential $mycreds -ReplaceDatabase -RestoreAction  "Database"
			
		Write-Host "Database Restore: Restored - $dbName"

		LoginCreate 'localhost' $dbname $user $pass
	}
	
		if($err -ne $null){
			throw $err
		}
       
        Write-Host " Done"

}
catch {
		write-host “Caught an exception:” -ForegroundColor Red
		write-host “Exception Type: $($_.Exception.GetType().FullName)” -ForegroundColor Red
		write-host “Exception Message: $($_.Exception.Message)” -ForegroundColor Red
		write-host “Exception Detail: $($error[0]|format-list -force)” -ForegroundColor Red

		exit 130
}
finally{
	echo "Completed."
}	return $exists
	

