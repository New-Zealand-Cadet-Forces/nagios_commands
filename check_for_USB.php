<?php

	class NagiosWarning  extends Exception {}
	class NagiosCritical extends Exception {}
	class NagiosOK       extends Exception {}
	class NagiosUnknown  extends Exception {}

	try {
		exec( "ps ax |grep lsusb", $output );
//		$linecount = explode("\n", $output );
		if( count($output) > 4 )
			throw new NagiosCritical('Too many `lsusb` processes running already, quitting');
		exec( "lsusb | grep ".$argv[1], $output, $returnvar );
		if( strpos( implode("\n", $output), $argv[1] ) === false )
			throw new NagiosCritical('Cannot find USB device "'.$argv[1].'".');
		else 
			throw new NagiosOK('Found USB Device "'.$argv[1].'".');
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

