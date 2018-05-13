#!/usr/bin/php
<?php

	class NagiosWarning  extends Exception {}
	class NagiosCritical extends Exception {}
	class NagiosOK       extends Exception {}
	class NagiosUnknown  extends Exception {}

	try {
		$hour = date("H");
		$check_hour = (int)$argv[1];

                if( $hour > $check_hour && $hour < $check_hour+2 )
                        throw new NagiosCritical('TEST CRITICAL MESSAGE - System is working correctly.');
		else if( $hour >= (int)$argv[1] && $hour < (((int)$argv[1])+1) )
			throw new NagiosWarning('TEST WARNING MESSAGE - System is working correctly.');
		else 
			throw new NagiosOK('TEST SYSTEM - System reset.');
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

