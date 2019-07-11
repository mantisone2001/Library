Try {
    $source = $OctopusParameters['Src']
    $target = $OctopusParameters['Dst']

    Add-Type -assembly “system.io.compression.filesystem”

	if (test-path $target) {
		remove-item -path $target -Force -Recurse
	}
	$trgt = split-path $target
    [io.compression.zipfile]::ExtractToDirectory($source, $trgt)
	
}
catch {
	write-host “Caught an exception:” -ForegroundColor Red
	write-host “Exception Type: $($_.Exception.GetType().FullName)” -ForegroundColor Red
	write-host “Exception Message: $($_.Exception.Message)” -ForegroundColor Red
	exit 45
}