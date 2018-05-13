#!/usr/bin/php
<?php
	use PHPMailer\PHPMailer\PHPMailer;
	use PHPMailer\PHPMailer\Exception;

	if( count( $argv ) != 7 ) {
		echo $argv[0].": Could not parse arguments\n";
		echo "Usage:\n";
		echo $argv[0]." <smtp username> <smtp password> <to email address> <to email name>\n";
		echo "   <subject> <email body content>\n";
		exit(1);
	}
	$username = $argv[1];
	$password = $argv[2];
	$to_email = $argv[3];
	$to_name  = $argv[4];
	$subject  = $argv[5];
	$bodytext = $argv[6];

	try {
            require 'phpMailer/src/Exception.php';
            require 'phpMailer/src/PHPMailer.php';
            require 'phpMailer/src/SMTP.php';

            $mail = new PHPMailer(true);

	    $mail->SMTPDebug = 0;
	    $mail->isSMTP();
	    $mail->Host = 'smtp.gmail.com';
	    $mail->SMTPAuth = true;
	    $mail->Username = $username;
	    $mail->Password = $password;
	    $mail->SMTPSecure = 'tls';
	    $mail->Port = 587;

	    $mail->addAddress( $to_email, $to_name );
	    $mail->setFrom( $username, 'Nagios');

	    $mail->isHTML(false);
	    $mail->Subject = $subject;
	    $mail->Body    = str_replace('\n',"\n", $bodytext);

	    $mail->send();
	    exit(0);
	} catch (Exception $e) {
	    echo 'Message could not be sent.'."\n";
	    echo 'Mailer Error: ' . $mail->ErrorInfo."\n";
	    print_r($e);
	    exit(1);
	}
