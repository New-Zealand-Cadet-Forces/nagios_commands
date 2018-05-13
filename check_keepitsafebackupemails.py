#!/usr/bin/env python
import imaplib,getopt,sys,datetime,email

#    Written by Phil Tanner, March 2014
#    Based heavily on these scripts:
#    https://github.com/geekpete/nagiosplugins/blob/master/check_gmailunread.py
#    http://yuji.wordpress.com/2011/06/22/python-imaplib-imap-example-with-gmail/

### Define required nagios script settings.

# define script name.
scriptName=sys.argv[0] 

# define script version.
scriptVersion = "v0.1.1"

# Nagios plugin exit codes
STATE_OK       = 0
STATE_WARNING  = 1
STATE_CRITICAL = 2
STATE_UNKNOWN  = 3

# Clear default variable states
gmailUser = ""
gmailPassword = ""
backupSet = ""
checkResult="UNKNOWN"
nagiosState=STATE_UNKNOWN

#####

class Usage(Exception):
    def __init__(self, err):
        self.msg = err

def usage():
    print "Usage: check_keepitsafebackupemails.py -u email_user -p email_password -s backup_set"
    print "       check_keepitsafebackupemails.py -h for detailed help"
    print "       check_keepitsafebackupemails.py -V for version information"

def detailedUsage():
    print "Nagios plugin to check how many unread emails are in a gmail account"
    print 
    usage()
    print 
    print "Options:"
    print "  -h"
    print "     Print this help message."
    print "  -V"
    print "     Print version information then exit."
    print "  -u gmail_user"
    print "     User name of the gmail account."
    print "     For google enterprise accounts use the full email address:"
    print "     eg, your.email@yourcompany.com"
    print "  -p gmail_password "
    print "     Password of the gmail account."
    print "  -s backup_set" 
    print "     The name of the backup set that should be checked, as it"
    print "     appears in the subject line of the email."
    print 

# parse the command line switches and arguments
try:
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hVH:u:p:s:v", ["help", "output="])
    except getopt.GetoptError, err:
        # print help information and exit:
        raise Usage(err)
except Usage, err:
    print >>sys.stderr, err.msg
    usage()
    sys.exit(STATE_UNKNOWN)


# gather values from given parameter switches
for o, a in opts:
        if o == "-u":
            gmailUser = a
        elif o == "-p":
            gmailPassword = a
	elif o == "-s":
	    backupSet = a
        elif o in ("-V","-v","--version"):
            print scriptName + " " + scriptVersion
            usage()
            sys.exit()
        elif o in ("-h", "--help"):
            detailedUsage()
            sys.exit()
        else:
            assert False, "unhandled option"

# Check to see if a host has been specified, throw an error if not.
if gmailUser=="":
    print "Error: no gmail user specified."
    usage()
    sys.exit(STATE_UNKNOWN)
elif gmailPassword=="":
	print "Error: no gmail password specified."
	usage()
	sys.exit(STATE_UNKNOWN)
elif backupSet=="":
	print "Error: no backup set specified."
	usage()
	sys.exit(STATE_UNKNOWN)


# open an SSL imap4 connection to gmail, fail if unsuccessful
try:
    # Open imap4 conection to imap.gmail.com.
	gmailconnection = imaplib.IMAP4_SSL('imap.gmail.com','993')

except Exception:
    print "UNKNOWN: error connecting to imap.gmail.com on tcp port 993"
    sys.exit(STATE_UNKNOWN)

# try to use the gmail login on the newly opened imap connection, fail if unsuccessful
try:
    # log in with gmail account and password
	gmailconnection.login(gmailUser,gmailPassword)

except Exception:
    print "UKNOWN: error authenticating against opened gmail imap connection with provided credentials"
    sys.exit(STATE_UNKNOWN)

# attempt to count the unread emails for this gmail account now that we've logged in
try:
    # log in with gmail account and password
	gmailconnection.select()
	date = (datetime.date.today() - datetime.timedelta(1.5)).strftime("%d-%b-%Y")
	matchingemails = gmailconnection.search(None, '(SENTSINCE {date} HEADER Subject "'.format(date=date)+backupSet+'")')[1][0].split()

	if int(len(matchingemails)) == 0:
	  print "CRITICAL: No emails received in timespan given for backup set "+backupSet
	  sys.exit(STATE_CRITICAL)

	# Grab the contet of the latest matching email.
	latestemail_id = matchingemails[-1]
	rawemail = gmailconnection.fetch(latestemail_id, "(RFC822)")
	rawemail = rawemail[1][0][1]
	email_message = email.message_from_string(rawemail)

	# Ignore embedded GIFS/JPEGS etc, we only want the text
	def walkMsg(msg):
	  for part in msg.walk():
	    if part.get_content_maintype() == "text":
	      yield part.get_payload(decode=1)
	    else:
	      continue

    	# Default to OK, if we find any successes. We'll over-ride later on if there is also a failure
        for part in walkMsg(email_message):
          if 'SUCCESS:' in part:
	    checkResult="OK"
	    nagiosState=STATE_OK

	for part in walkMsg(email_message):
	  if 'ERROR:' in part:
	    checkResult="CRITICAL"
	    nagiosState=STATE_CRITICAL
	  elif 'WARNING:' in part:
	    checkResult="WARNING"
	    nagiosState=STATE_WARNING

except Exception:
    print "UKNOWN: unhandled exception: ", sys.exc_info()
    sys.exit(STATE_UNKNOWN)

# display output of the metrics and any warnings
print "%s: Backup status for %s is %s" % (checkResult, backupSet, checkResult)
sys.exit(nagiosState)

