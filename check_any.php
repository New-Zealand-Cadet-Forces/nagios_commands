#!/usr/bin/php
<?php
/*
        Sebastián Gómez (tiochan@gmail.com)
        UPCnet - Politechnical University of Catalonya - Spain
 */

	$PHP_SELF=$argv[0];
	$output_link=0;
	
	// $dir=dirname($PHP_SELF);

	function nagios_bridge_start() {
		global $PHP_SELF;
		global $output_link;
		// What do you need to do at start?
		// Open a file, a database connection
		
		// I'll write the output to a file
		$output_file="/var/log/nagios3/activity.log";
		
		if(!($output_link=fopen($output_file,"a"))) {
			echo "$PHP_SELF: Sorry, I couln't open the output file $output_file.";
			exit(3);
		}
	}
	
	function nagios_bridge_register($msg) {
		global $output_link;
		// And how must you register any event?
		
		// I'll write everything to the file...
		if(!fwrite($output_link, $msg)) {
		}
	}
	
	
	function nagios_bridge_end() {
		global $output_link;
		// What do you need to close?
		fwrite($output_link, "--------------------------------------\n");
		fclose($output_link);
	}
	
	//////////////////////////////////////////////////////////////////////////////////
	// M A I N
		
	// argv[0]= own script
	// argv[1]= command to execute
	// argv[>1]= parameters to command

	// At least the command name!
	if($argc < 2) {
		exit(3);
	}
	
	// $command= $dir . "/" . $argv[1];
	$command= $argv[1];
	
	$parameters="";
	for($i=2; $i<$argc; $i++) {
		$parameters.= " " . $argv[$i];
	}
	$command_line= "$command $parameters";
	
	$now=date("Y-m-d H:i:s");
	
	nagios_bridge_start();
	
	if(!exec($command_line, &$command_output, &$command_status)) {
		echo "Sorry: Error executing command: $command_line.";
		nagios_bridge_end();
		exit(3);
	}
	
	$ret= "";
	for($i=0; $i < count($command_output); $i++) {
		$ret.= $command_output[$i] . "\n";
	}
	
	echo $ret;
	
	nagios_bridge_register("DATE: $now\n");
	nagios_bridge_register("COMMAND: $command_line\n");
	nagios_bridge_register("RETURNED: $command_status\n");
	nagios_bridge_register("$ret\n");
	
	nagios_bridge_end();
	exit($command_status);
?>
