<?php

	class NagiosWarning  extends Exception {}
	class NagiosCritical extends Exception {}
	class NagiosOK       extends Exception {}
	class NagiosUnknown  extends Exception {}

	try {
		exec( "cat /tmp/".$argv[1]." |grep ".$argv[2], $output, $returnvar );
		if( strpos( implode("\n", $output), $argv[2] ) === false )
			throw new NagiosCritical('Cannot find visible SSID "'.$argv[2].'" using network device "'.$argv[1].'"');
		else 
			throw new NagiosOK('Found "'.$argv[2].'" using network device "'.$argv[1].'"');
	} catch( NagiosOK $ex ) {
		echo 'OK: '.$ex->getMessage()."\n";
		exit(0);
	} catch( NagiosWarning $ex ) {
		echo 'WARNING: '.$ex->getMessage()."\n";
		exit(1);
	} catch( NagiosCritical $ex ) {
		echo 'CRITICAL: '.$ex->getMessage()."\n";
		exit(2);
	} catch( Exception $ex ) {
		echo 'UNKNOWN: '.$ex->getMessage()."\n";
		exit(3);
	}
?>

