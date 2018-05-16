#!/usr/bin/php
<?php
	/*******************************************************\
	*                                                       *
	* Written by Phil Tanner, May 2018                      *
	*                                                       *
	* This script interrogates the SSL certificate returned *
	* on port 443 of a server, and checks how long until it *
	* expires. It does no further assumptions of            *
	* 'correctness'.                                        *
	*                                                       *
	* Caveat exsecutor etc                                  *
	*                                                       *
	\*******************************************************/
	
	$version = "0.0.1";

	class NagiosWarning  extends Exception {}
	class NagiosCritical extends Exception {}
	class NagiosOK       extends Exception {}
	class NagiosUnknown  extends Exception {}

	$days_for_warning  = 90;
	$days_for_critical = 30;

	try {
		// Before we start, lets make sure we have our arguments in order
		if( count( $argv ) == 1 || count( $argv ) > 4 || $argv[1] == "--help" || $argv[1] == "-h" ) {
			display_usage();
			exit(3);
		}
		if( isset( $argv[2] ) ) {
			$days_for_warning = (int)$argv[2];
		}
		if( isset( $argv[3] ) ) {
			$days_for_critical = (int)$argv[3];
		}
		if( $days_for_warning < 1 ) {
			throw new NagiosUnknown('Invalid argument for days warning - must be a number');
		}
		if( $days_for_critical < 1 ) {
			throw new NagiosUnknown('Invalid argument for days critical - must be a number');
		}
		if( $days_for_critical >= $days_for_warning ) {
			throw new NagiosUnknown('Critical days ('.$days_for_critical.') must be larger than warning days ('.$days_for_warning.').');
		}

		// Taken from https://serverfault.com/a/881415
		exec( 'echo | openssl s_client -showcerts -servername '.$argv[1].' -connect '.$argv[1].':443 2>/dev/null | openssl x509 -inform pem -noout -text 2>&1', $output, $returnvar );
var_dump($output);
		// Catch responses without a certificate without wasting any more CPU
		if( $output[0] == "unable to load certificate" ) {
                        throw new NagiosUnknown('Unable to load certificate');
                }

		// Set our initial values to null so we know if we got anything
		$line_for_validity = $line_for_validity_begin = $line_for_validity_end = $start_date = $end_date = null;

		for($i=0; $i < count($output); $i++) {
			if( preg_match( '/^(\s).*(Validity)$/m', $output[$i] ) ) {
				$line_for_validity = $i;
			}
			if( $i == ($line_for_validity+1) && preg_match( '/^\s.*(Not Before: )(.*)$/m', $output[$i], $matches ) ) {
                                $line_for_validity_begin = $i;
				$start_date = strtotime($matches[2]);
                        }
			if( $i == ($line_for_validity_begin+1) && preg_match( '/^\s.*(Not After : )(.*)$/m', $output[$i], $matches ) ) {
                                $line_for_validity_end = $i;
                                $end_date = strtotime($matches[2]);
				// We got all we need, don't waste any more CPU cycles
				break;
                        }
		}
	
		// Check if we found the info in the returned cert information
		if( $line_for_validity === null ) {
			throw new NagiosUnknown('Unable to find Validity information in response');
		}
		if( $line_for_validity_begin === null ) { 
			throw new NagiosUnknown('Unable to find valid start date in returned information');
		}
		if( $line_for_validity_end === null ) {
			throw new NagiosUnknown('Unable to find valid end date in returned information');
		}
		// Check our dates and times
		if( !$start_date ) {
			throw new NagiosUnknown('Unable to convert start date to valid date time');
		}
		if( !$end_date ) {
			throw new NagiosUnknown('Unable to convert end date to valid date time');
		}

		// Now check our dates for our warning/critical values
		if( $start_date > time() ){
                        throw new NagiosCritical('Certificate is not yet valid! Starts on: '.date('c', $end_date));
                } elseif( $end_date - time() < ( $days_for_critical * 60 * 60 * 24 ) ) {
                        throw new NagiosCritical('Certificate expires '.(int)(($end_date - time())/60/60/24).' days (on '.date('c', $end_date).')');
                } elseif( $end_date - time() < ( $days_for_warning * 60 * 60 * 24 ) ) {
			throw new NagiosWarning('Certificate expires in '.(int)(($end_date - time())/60/60/24).' days (on '.date('c', $end_date).')');
		} else {
			throw new NagiosOK('Certificate expires '.(int)(($end_date - time())/60/60/24).' days (on '.date('c', $end_date).')');
		}

		// Something... unusual happened.
		throw new NagiosUnknown('Reached end of script without knowing what to do');

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

	function display_usage() {
		global $argv, $version, $days_for_warning, $days_for_critical;

        	echo "\n$argv[0]\nWritten by Phil Tanner (phil.tanner@gmail.com) Ver: $version\n\n";
                echo "  Usage:\n";
	        echo "    $argv[0] <w> <c>\n\n";
		echo "  Where:\n";
		echo "    <w> = days before expiry to enter warning state\n";
		echo "    <c> = days before expiry to enter critical state\n";
	}
?>

