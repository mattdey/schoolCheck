#!/bin/bash 
#
#/usr/bin/curl -s http://www.adoptalab.org/show_story.php?TYPE=ALL | /usr/bin/md5sum - > /tmp/mdey.foo 
#/usr/bin/curl -s http://www.adoptalab.org/show_story.php?TYPE=ALL | /usr/bin/md5sum -c /tmp/mdey.foo  
#links -dump -width 160 'http://www.news12.com/school_closings.jsp?regionId=3&flag=0' | egrep '(Stamford School District|Greenwich School District|Building|King |Fairfield School)'


#PAGE="http://www.news12.com/school_closings.jsp?regionId=3&flag=0" 
PAGE="http://closings.news12.com/school_closings.jsp?region=CT"
GREP_BIN=/bin/egrep
GREP_STRING='(Darien School|Stamford School District|Greenwich School District|Building Blocks|King |Fairfield School)'
ALERT_TITLE="School Closings page Updated"
CKSUMFILE=/var/admin/schoolCheck.md5
#ALERT_EMAIL_ADDRS=matt.dey@gmail.com,russ06902@yahoo.com,mdey@factset.com
ALERT_EMAIL_ADDRS=matt.dey@gmail.com
ALERT_PAGE_ADDRS=mattdey@txt.att.net,2032495072@vtext.com
ALLOW_PAGE=0
THROTTLE_MIN=15
THROTTLE_SEC=$(($THROTTLE_MIN * 60)) 
#THROTTLE_SEC=1
INIT_RUN=0
FORCE_SEND_EMAIL=0

function processArguments {
	for arg in "$@" 
	do
		case $arg in
			-i)	rm $CKSUMFILE
				INIT_RUN=1
			;;
			-s)	FORCE_SEND_EMAIL=1
			;;
		esac
	done
}

function alert {
	sendEmail
	if [ "$ALLOW_PAGE" = 1 ]
	then 
		sendPage
	fi
}

function sendEmail {
	count=`/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" | /usr/bin/head -50 | wc -l`
	if (( count > 0 ))
	then 
#		/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" | /usr/bin/head -50 | /usr/bin/mail -s "$ALERT_TITLE" $ALERT_EMAIL_ADDRS -- -F "Matt Dey" -f matt.dey@gmail.com
		/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" | /usr/bin/head -50 | sed 's/^[ \t]\+//g' | sed 's/ [ \t]\+/,/g' | column -s , -t | /usr/bin/mail -s "$ALERT_TITLE" $ALERT_EMAIL_ADDRS -- -F "Matt Dey" -f matt.dey@gmail.com
	fi
}

function sendPage {
	echo " " | /usr/bin/mail -s "$ALERT_TITLE" $ALERT_PAGE_ADDRS -- -F "Matt Dey" -f matt.dey@gmail.com
}

function updateCheckSum {
	/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" | /usr/bin/md5sum - > $CKSUMFILE
}

function checkForCheckSumFile {
	if [ ! -s $CKSUMFILE ]
	then
        	updateCheckSum
	fi
}

function fileThrottled {
	# File to Check time of
	throttleFile=$1
	# Delay to check for
	throttleDelay=$2

	currTime=`/bin/date +%s`
	fileTime=`/usr/bin/stat -c %Y $throttleFile`
	timeDiff=$((currTime-fileTime))

	if [ "$INIT_RUN" = 1 ]
	then
		echo 0
		return 0
	fi

	if (( $timeDiff > $throttleDelay )) 
	then
		echo 0
		return 0
	else
		echo 1
		return 1
	fi
}

function checkAndAlert {
	/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" 
	/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" | /usr/bin/md5sum --status -c $CKSUMFILE
	UPDATED=$?
	if [ "$UPDATED" = 1 ]
	then
		# echo "Alert!"
		alert
		# Update check sum
		/usr/bin/links -dump -width 160 $PAGE | $GREP_BIN "$GREP_STRING" | /usr/bin/md5sum - > $CKSUMFILE
		return 1
	elif [ "$FORCE_SEND_EMAIL" = 1 ]
	then
		sendEmail
		# echo "nope!"
	fi

}

processArguments $@
checkForCheckSumFile
throttled=`fileThrottled $CKSUMFILE $THROTTLE_SEC`
if [ $throttled -eq 0 ]
then
	checkAndAlert
fi
