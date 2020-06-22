# Author: Peter Finn
# Github: peter2233finn
# Contact: peter123finn@gmail.com
file="$HOME/.cache/episodeLog"

# Get all arguements passed in a string. Will be used in getops for validation of other arguements
cmdArg="$*"

if [ ! -f "$file" ]; then
	echo "Chould not file the stoarage file. in \"$file\". Creating it now"
	touch "$file"
fi

# This is the usage dialog.
function usage(){
  printf "Usage:\n\
   a Add a series\n\
   q the name of the series you want to update\n\n\
   e is the episode to update the series to\n\
   i increment the episode by one (you wantched an episode)\n\n\
   p is too print all series\n\
   f is to find an episode (simular to print)\n\
   s sets the season\n\
   r remove a series\n\
   R remove all series\n"
}

# This prints out all series and episodes on a table dialog
function printAll(){
	# Check if there are any results to show
	if (( $(wc -l < "$file") > 0 ))
	then
		cat "$file" | awk 'BEGIN {FS=";"} {print ""$3"||Season: "$1"||  Episode: "$2}'| sort | column -t -s'||'
	else
		echo "No series to show"
	fi
}

# Search for a series. This uses grep -i to remove case sensitivity.
function search(){
	result=$(printAll | grep -m 1 -i "$*")

	# Check if any results are found
	if [[ "$result" != "" ]] ; then
		# Printing out the results:
		# 1. find relivant results using grep
		# 2. Seperate the fields using || and label them
		# 3. format them using column using the seperator '||'
		grep -i "$*" "$file" | awk 'BEGIN {FS=";"} {print ""$3"||  Season: "$1"||Episode: "$2}'|column -t -s'||'
	else
		echo "No results found. Try -p to print all series"
	fi
}

# Function to check if a series exists.
# If it does it will return the series name. This is case sensitive
function existsCheck(){
	cat "$file" | awk 'BEGIN {FS=";"} {print $3}' | grep -m 1 -x "$*"
}

# Gets the current episode from a series. Takes the series name and returns the current episode from a series.
function getFileLine(){
	# Finds the line number first by finding the series name
	lineNum=$(cat "$file" | awk 'BEGIN  {FS=";"} {print $3}' | grep -n -m 1 -x "$*"  | cut -f1 -d:)
	# Check if the line number exists. It will cause a run time error if it doesnt.
	# Checks if the line exists
	if (( $lineNum )) ; then
		awk "NR==$lineNum" "$file"
	fi
}

function addEpisode(){

	# make sure it doesnt exist
	alreadyExists=$(existsCheck $*)
	if [[ "$alreadyExists" == "" ]] ; then
	 	# Add the series
		echo "Added series \"$*\"."
		echo "0;0;$*" >> "$file"
	else
 		# Series already exists.
		echo "It appears that this series is already saved."
	fi
}

# Remove one series.
function removeSeries(){
	fullLine=$(getFileLine "$*")
	# Make sure the series exists.
	if [ "$(existsCheck "$*")" != "" ] ; then
		sed -i "/^$fullLine$/d" "$file"
		echo "Episode \"$*\" has been removed."
	else
		echo "Error: Series not found."
	fi
}

# Remove all series
function removeAll(){
	# Verify with the user if they want to delete all series.
	echo "Are you sure? [Y/N]"
	read verify
	if [ "$verify" == "y" ] || [ "$verify" == "Y" ] ; then
		# Delete all series
		printf "" > "$file"
		echo "All series removed."
	else
		# Abort and make no changes
		echo "Aborting"
	fi
}

# Set either the season or episode.
# takes the varables: "int to update too" "s/e for season or episode" "series name"
# If no series are found, then prompt user if they want to create it.
function setEpisode(){
	# Get the series name and current episode (if it exists)
  	series="${@:3}"

	# Type is what is to be changed episode or season. it will be s or e
	type="$2"

	# get either the current series or episode
	orgLine=$(getFileLine $series)
	currentSeason=$(echo $orgLine | awk 'BEGIN {FS=";"} {print $1}')
	currentEpisode=$(echo $orgLine | awk 'BEGIN {FS=";"} {print $2}')

	# By default, these will both be the origional status in the file
	# When they are processed they will be changed accordingly
	newSeason=$currentSeason
	newEpisode=$currentEpisode

	# Checks if it is a season or episode being updated
	# using the "type" varible
	if [ "$type" == "e" ] ; then
  		# +1 will be used if -i is used in the cli. This will add one to the current episode.
		if [ "$1" == "+1" ] ; then
			newEpisode=$(($currentEpisode+1))
		else
			newEpisode=$1
		fi

		# Check if the used entered a valid number. If not than exit on error
		if ! [[ "$newEpisode" =~ ^[0-9]+$ ]] ; then
			echo "For -e you must use a number as this sets the episode number"; exit 1
		fi

	elif [ "$type" == "s" ] ; then
		newSeason=$1

		# Check if the used entered a valid number. If not than exit on error
		if ! [[ "$newSeason" =~ ^[0-9]+$ ]] ; then
			echo "For -s you must use a number as this sets the episode number"; exit 1
		fi
	fi

	# Check if the series actually exists.
	# If it doesnt than promot for creation
	if [ "$(existsCheck $series)" != "" ] ; then
	# The series is in the file.

		# The status will be changed using sed
		# newFileStatus is the updated version
		newFileStatus="$newSeason;$newEpisode;$series"

		# Make the changes to the file
		sed -i "s/^$orgLine$/$newFileStatus/g" "$file"

		# Print message
		if [ "$type" == "e" ] ; then
			echo "Updated \"$series\" from episode $currentEpisode to $newEpisode"
		elif [ "$type" == "s" ] ; then
			echo "Updated \"$series\" from season $currentSeason to $newSeason"
		fi


	else
	# The series isn't in the file. Ask user if they want to create it.
		echo "The series appears not to be saved. Do you want to add it now? [Y/N]"
		read doAdd
		if [ "$doAdd" == "Y" ] || [ "$doAdd" == "y" ] ; then
			# The default episode number is 0.
			addEpisode "$series"
			# Set the episode number.
			setEpisode $newEpisode "$type" "$series"
		else
			# The user did not select y on the prompt.
			echo "Exiting"
		fi
	fi
}


# Null fonction which does nothing
function null() { printf "";}

# Makes sure the -q flag is active
function eOptCheck(){
	if [[ "$*" != *"-q"* ]] ; then
		echo "Error: -q is needed for this option. -q is for querying the series"
		exit 1
	fi
}

# Handle -q independantly as it must be processed first
# Couldnt find a better way to handle the getops.
# -q must be processed first so two getops are executed.
# If anyone has a batter way to do this, please let me know :)

function parseArgs() {
for i in $@ ; do
	if [[ "$i" == "-"[a-zA-Z] ]] ; then
		start="0"
	fi
	if [ "$start" == "1" ] ; then
		args+="$i "
	fi

	if [[ "$i" == "$1" ]] ; then
		start="1"
	fi
done
echo "$args" | xargs
}

episode=$(parseArgs "-q" "$*")
searchArgs=$(parseArgs "-f" "$*")
removeArgs=$(parseArgs "-r" "$*")
addArgs=$(parseArgs "-a" "$*")
# Getops to make main selection.

optStr="f:q:a:e:s:hpr:Ri"
while getopts "$optStr" option > /dev/null 2>&1; do
	case "${option}"
	in
		# Doesnt do anything but OPTINT must be set for multaple arguements under -q.
		q) null;;
		a) addEpisode "$addArgs";;

		# eOptCheck function makes sure -q option is present as it wont know what series to update without it
		e) eOptCheck "$cmdArg";setEpisode "${OPTARG}" "e" "$episode";;
		s) eOptCheck "$cmdArg";setEpisode "${OPTARG}" "s" "$episode";;
		h) usage;;
		f) echo $searchArgs;search "$searchArgs";;
		r) removeSeries "$removeArgs";;
		i) eOptCheck "$cmdArg";setEpisode "+1" "e" "$episode";;
		R) removeAll;;
		p) printAll;;
		q) null;;
	esac
done
