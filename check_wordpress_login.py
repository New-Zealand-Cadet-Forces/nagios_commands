#!/usr/bin/python

#    Written by Phil Tanner, May 2018
#    Based heavily on these scripts:
#    https://github.com/geekpete/nagiosplugins/blob/master/check_gmailunread.py
#    http://yuji.wordpress.com/2011/06/22/python-imaplib-imap-example-with-gmail/

### Define required nagios script settings.

import mechanize
import cookielib
import datetime
import re
import os
import sys
import getopt

# define script name.
scriptName=sys.argv[0]

# define script version.
scriptVersion = "v0.1.1"

# Nagios plugin exit codes
STATE_OK       = 0
STATE_WARNING  = 1
STATE_CRITICAL = 2
STATE_UNKNOWN  = 3

# Default variable values
username = ""
password = ""
successstring = ""
host = ""
url = "/wp-login.php"
usehttps = False
wp_loginform = "loginform"
wp_field_username = "log"
wp_field_password = "pwd"
debug = False

# Define how we should be used
class Usage(Exception):
    def __init__(self, err):
        self.msg = err

def usage():
    print "Usage: "+scriptName+" -H hostname [-U login_page_url] -u username -p password "
    print "              -s Expected_string_on_success"
    print "       "+scriptName+" -h for detailed help"
    print "       "+scriptName+" -V for version information"

def detailedUsage():
    print "Nagios plugin to check successful login to a WordPress site (version " + scriptVersion +")"
    print
    usage()
    print
    print "Options:"
    print "  -h --help"
    print "     Print this help message."
    print "  -v --version"
    print "     Print version information then exit."
    print "  -H"
    print "     Hostname for the WordPress website."
    print "  -U"
    print "     URL for the login page (defaults to /wp-login.php)."
    print "  -u username"
    print "     User name of the WordPress account."
    print "  -p password"
    print "     Password of the WordPress account."
    print "  -s Expected_String_on_Success"
    print "     The text you expect to see on a successful login on the page."
    print "  -S --secure"
    print "     Use SSL (run the test against https:// instead of http://)"
    print "  -f --formname"
    print "     HTML argument for name of login form on WordPress login page"
    print "     (defaults to '" + wp_loginform + "')"
    print "  --userinput"
    print "     HTML argument for name of username field on WordPress login page"
    print "     (defaults to '" + wp_field_username + "')"
    print "  --passwordinput"
    print "     HTML argument for name of password field on WordPress login page"
    print "     (defaults to '" + wp_field_password + "')"
    print "  --debug"
    print "     Include debugging information"
    print

# Parse the command line switches and arguments
try:
    try:
        opts, args = getopt.getopt(sys.argv[1:], "u:H:p:s:f:vhS", ["formname=","userinput=","passwordinput=","debug","help","secure"])
    except getopt.GetoptError, err:
        # print help information and exit:
        raise Usage(err)
except Usage, err:
    print >>sys.stderr, err.msg
    usage()
    sys.exit(STATE_UNKNOWN)

# Gather values for our variables from given parameter switches
for o, a in opts:
        if o == "-u":
            username = a
	elif o == "-H":
	    host = a
	elif o == "-U":
	    url = a
        elif o == "-p":
            password = a
        elif o == "-s":
            successstring = a
	elif o in ("--secure","-S"):
	    usehttps = True
	elif o in ("-f","--formname"):
	    wp_loginform = a
	elif o == "--userinput":
	    wp_field_username = a
	elif o == "--passwordinput":
	    wp_field_password = a
	elif o == "--debug":
	    debug = True
        elif o in ("-V","-v","--version"):
            print scriptName + " " + scriptVersion
            sys.exit()
        elif o in ("-h", "--help"):
            detailedUsage()
            sys.exit()
        else:
            assert False, "unhandled option"

# Check to see if arguments have been specified, throw an error if not.
if username=="":
	print "Error: no username specified."
	usage()
	sys.exit(STATE_UNKNOWN)
elif password=="":
        print "Error: no password specified."
        usage()
        sys.exit(STATE_UNKNOWN)
elif successstring=="":
        print "Error: no success string specified."
        usage()
        sys.exit(STATE_UNKNOWN)
elif host=="":
	print "Error: no host specified."
	usage()
	sys.exit(STATE_UNKNOWN)
elif wp_loginform=="":
	print "Error: No form name specified."
	usage()
	sys.exit(STATE_UNKNOWN)
elif wp_field_username=="":
        print "Error: No username input field name specified."
        usage()
        sys.exit(STATE_UNKNOWN)
elif wp_field_password=="":
        print "Error: No password input field name specified."
        usage()
        sys.exit(STATE_UNKNOWN)
elif url=="":
	print "Error: no login URL specified."
	usage()
	sys.exit(STATE_UNKNOWN)

###############################################################
# Right - now we've parsed and passed everything, do our stuff
###############################################################

# Create a Browser object
br = mechanize.Browser()

# Create a Cookie Jar to hold our cookies (so we can login)
cj = cookielib.LWPCookieJar()
br.set_cookiejar(cj)

# Browser options
br.set_handle_equiv(True)
#br.set_handle_gzip(True)
br.set_handle_redirect(True)
br.set_handle_referer(True)
br.set_handle_robots(False)

# Follows refresh 0 but not hangs on refresh > 0
br.set_handle_refresh(mechanize._http.HTTPRefreshProcessor(), max_time=1)

if debug:
	br.set_debug_http(True)
	br.set_debug_redirects(True)
	br.set_debug_responses(True)

# User-Agent (be clear about who we are, and what we're doing for target server logs)
br.addheaders = [('User-agent', 'Phil Tanner\'s Nagios WordPress login script, version '+scriptVersion)]

try:
    loginurl = 'https://' + host + url if usehttps else 'http://' + host + url
    # Not handling basic auth yet - left for future enhancements
    ## HTTP Authentication:
    #br.add_password(loginurl, basicauth_user, basicauth_pwd)
    r = br.open(loginurl)
except mechanize.URLError, err:
    print "CRITICAL - Unable to open URL " + loginurl
    sys.exit(STATE_CRITICAL)

# Attempt to carry out a login
try:
    # Grab our login form
    br.select_form(name=wp_loginform)
except mechanize._mechanize.FormNotFoundError, err:
    print "CRITICAL - Cannot find login form name '"+ wp_loginform + "'"
    sys.exit(STATE_CRITICAL)

try:
    br.form[wp_field_username]=username
except mechanize._form.ControlNotFoundError, err:
    print "CRITICAL - Cannot find user field form name '"+ wp_field_username + "'"
    sys.exit(STATE_CRITICAL)

try:    
    br.form[wp_field_password]=password
except mechanize._form.ControlNotFoundError, err:
    print "CRITICAL - Cannot find password field form name '"+ wp_field_password + "'"
    sys.exit(STATE_CRITICAL)

# Assign the form submission to a variable. This allows us to inspect HTTP Status codes etc (result.code==200)
result = br.submit()


# See what the server sent us back
html = br.response().read()

# Now check if what we wanted was in the response
if successstring in html:
    print "OK - Login appears successful"
    sys.exit(STATE_OK)
else:
    print "CRITICAL - Expected string not found in response - unsuccessful login?"
    sys.exit(STATE_CRITICAL)

# We shouldn't get here. But in case we do - exit cleanly
print "UNKNOWN - Reached the end of the script somehow?"
sys.exit(STATE_UNKNOWN)

