#!/usr/bin/env bash
#
# CDI - Change Dir Interactive - https://github.com/DavidBevi/cdi
# v2.2.1 (2026-08-03)
#
# SYNOPSIS
# CDI prints the path of the working dir and the list of its subdirs.
# It lets the user CD (with arrow keys), reset the starting dir (R),
# show help (H), and exit (any other key).
#
# START
# The first step is checking if CDI is in Bash and it's sourced.
# - If not CDI prints a brief explanation of error and fix and exits.
# - If it passes the checks CDI enters alt-mode and hides the cursor.
#
# HELP STATE
# Because of its nature CDI doesn't need any argument, therefore if they are
# given CDI will set STATE=HELP and the help page will be displayed.
# Pressing any key sets STATE=NORMAL and resumes the normal execution.
#
# MAIN LOOP
# - If STATE==HELP -> display help screen
# - Clear screen
# - Print title, subtitle, $PWD
# - Check if subdirs-list is cached, (re)build cache when needed
# - If ((subdirs-list < 1))
#   -> then print "no subdirs"
#   -> else build and print subdirs-list with highlight
# - Wait for user input -> can change STATE, can CD
#
# END
# When the STATE is neither NORMAL nor HELP the main loop breaks and CDI exits.
# First it exits alt-mode and restores the cursor visibility.
# Then if STATE==EXIT it will exit 0, else it will print the error and exit 3.
#
# LICENSE
# - This free/libre software is provided "AS IS", with NO WARRANTY.
# - You can use it, edit it, share it. You CANNOT ask money for it.
# - Derivatives must share their source code and this same license.
#

# Abort if not in Bash (compacted POSIX syntax)
[ -z "$BASH_VERSION" ] && { printf "ERROR: this script must be used with Bash.
WIKI: https://simple.wikipedia.org/wiki/Bash \nEXITING\n" >&2; return 1; }

# Script is not 100% compatible with Fish, so Fish won't run it, but since
# Fish echoes the first invalid statement we state an helpful msg
_=" ⚠️ This script must be used with Bash shell
#   (You're using a different incompatible shell)
#   WIKI: https://simple.wikipedia.org/wiki/Bash
" #_____________________________________________
unset _

# Abort if not sourced (= "source cdi" or ". cdi")
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    basename="${0##*/}"
    red="\e[1;4:4;31m"
    green="\e[1;4:4;32m"
    bad_cmd="'${red}bash $basename\e[0m' or '${red}./$basename\e[0m'"
    good_cmd="'${green}. $basename\e[0m'"
    echo -e "ERROR: this script doesn't work with $bad_cmd.\nFIX: use an" \
        "interactive Bash session, and launch with $good_cmd. \nEXITING" >&2
    exit 2
fi

# GLOBALS #####################################################################
STARTING_DIR="$PWD"
# when [ number of arguments > 0 ] -> STATE=HELP
STATE="NORMAL"; (($# > 0)) && STATE="HELP"
# associative arrays (maps)
declare -A HIGHLIGHT_INDEX HIGHLIGHT_NAME
# other vars
declare SUBDLIST SUBDLEN PAGELEN PAGES PAGE PREV_PWD

# FUNCTIONS ###################################################################

# Display the help screen, wait for input to resume
show_help() {
    clear
    # print the title (bold+inverted style)
    echo -e "\e[1;7m CDI: Change Dir Interactive - by DavidBevi \e[0m"
    echo -e "\nUSAGE:
    MOVE the cursor and select a subdir with arrow keys
    HELP-SCREEN (show this screen) with H
    RESET / RESTORE the starting directory with R
    EXIT from CDI with any other key"
    echo -e "\nABOUT:
    https://github.com/DavidBevi/cdi"
    echo -e "\nCREDITS:
    Inspired by CDI by Antonio Oliveria (inactive)
    https://github.com/antonioolf/cdi/issues/15"
    # print the footer (bold+inverted style)
    echo -e "\n\e[1;7m Press any key to close help and use CDI \e[0m"
    # wait for input, then consume the input buffer to avoid issues
    read -rsn1
    while IFS= read -rsn1 -t 0.01; do :; done
    # (re)set STATE=NORMAL to avoid printing help-screen again
    STATE="NORMAL"
}

# Display title, subtitle, and working directory
print_header_and_working_dir() {
    # print the title (bold+inverted style)
    echo -e "\e[1;7m CDI: Change Dir Interactive - by DavidBevi \e[0m"
    # print short help + newline
    echo -e " ARROWS:move  H:help  R:reset  OTHER:exit\n"
    # print PWD with trailing "/" (bold+inverted style)
    echo -e "\e[1;7m${PWD%/}/\e[0m"
}

# Fetch the subdirs list
build_subdirs() {
    # MTIME-based cache removed: checking MTIME is slower than getting list
    SUBDLIST=(*/)
    # if no subdirs then SUBDLIST will contain only "*/" -> clean up
    if [[ ${SUBDLIST[0]} == '*/' ]]; then SUBDLIST=(); fi
    # subdirs-list-len is used a lot, it's convenient to set this
    SUBDLEN="${#SUBDLIST[@]}"
}

# Set HIGHLIGHT_NAME and HIGHLIGHT_INDEX
build_highlight() {
    if [[ "$PREV_PWD" ]]; then
        # get NAME (= PREV_PWD) and find corresponding INDEX
        local index=0
        for dir in */; do
            if [[ "$dir" != "$PREV_PWD" ]]; then ((index++)); else break; fi
        done
        HIGHLIGHT_INDEX["$PWD"]=$index
        HIGHLIGHT_NAME["$PWD"]="$PREV_PWD"
        PREV_PWD=
    else
        # ensure INDEX is a valid number and find corresponding NAME
        HIGHLIGHT_INDEX["$PWD"]=$(((HIGHLIGHT_INDEX[$PWD] +SUBDLEN) %SUBDLEN))
        HIGHLIGHT_NAME["$PWD"]="${SUBDLIST[${HIGHLIGHT_INDEX[$PWD]}]}"
    fi
}

# Fetch the terminal window's height and paginize subdirs-list if needed
build_page() {
    local _ starting_row
    # ask the cursor pos, keep only the row
    IFS='[;' read -p $'\e[6n' -d R -rs _ starting_row _ _
    # ensure starting_row is numeric, else script crashes
    [[ "$starting_row" =~ ^[0-9]+$ ]] || starting_row=4
    # update globals
    PAGELEN=$((LINES - starting_row - 2))
    PAGES=$(( (SUBDLEN + PAGELEN - 1) / PAGELEN ))  # ceil
    PAGE=$(( ${HIGHLIGHT_INDEX["$PWD"]} / PAGELEN ))  # floor
}

# Display subdirs list, highlight the current selection
print_page_with_highlight() {
    # when multiple pages: write "Page X of Y"
    if ((PAGES > 1)); then
        echo -e " │  \e[33mPage $((PAGE+1)) of $PAGES\e[0m"
    fi
    #
    # print curr page using array expansion with slicing
    printf "\e7"  # save cursor pos
    printf ' ├─ %s\n' "${SUBDLIST[@]:$((PAGE*PAGELEN)):$PAGELEN}"
    printf "\e[A └"  # replace ├ in last row with └
    #
    # highlight selected item
    printf "\e8"  # jump back to previously saved cursor pos
    # if not in row 0: move to right row
    local row=$(( ${HIGHLIGHT_INDEX["$PWD"]} % PAGELEN ))
    if ((row != 0)); then echo -en "\e[${row}B"; fi
    echo -en "\e[5G\e[1;7m${HIGHLIGHT_NAME[$PWD]}\e[0m"
}

# Wait until the user presses a key and do the appropriate action
wait_for_input() {
    local input
    # wait for a keystroke -> read first byte and save into input
    read -rsn1 input;
    # if input is ESC (= multi-byte keystroke) read another 2 bytes
    if [[ "$input" == $'\e' ]]; then read -rsn2 input; fi
    # loop to consume/empty the input buffer
    # -> prevents aborting when user presses 2 arrow keys together
    while IFS= read -rsn1 -t 0.01; do :; done
    #
    # route input to proper action
    case "$input" in
        # Arrows codes in Normal Mode:  [A  [B  [C  [D
        #     Application Cursor Mode:  OA  OB  OC  OD
        [A|OA) up;;    [B|OB) down;;    [C|OC) right;;    [D|OD) left;;
        h) help;;      r) restore;;     *) set_exit;;
    esac
}

# POSSIBLE ACTIONS
up() {
    ((HIGHLIGHT_INDEX[$PWD]+=-1))
}

down() {
    ((HIGHLIGHT_INDEX[$PWD]+=1))
}

right() {
    cd "${HIGHLIGHT_NAME[$PWD]}" || : # ignore CD fails
}

left() {
    # return if pwd == root
    if [[ "$PWD" == "/" ]]; then return; fi
    # save PREV_PWD and CD up
    PREV_PWD="${PWD##*/}/"
    cd .. || STATE="ERROR DOING CD UP"
}

help() {
    STATE="HELP"
}

restore() {
    cd "$STARTING_DIR" || STATE="ERROR RESTORING STARTING DIR"
}

set_exit() {
    STATE="EXIT"
}

# BODY ########################################################################

# Enter alt-mode, hide cursor
tput smcup civis

# Main loop
while [[ $STATE == "HELP" ]] || [[ $STATE == "NORMAL" ]]; do
    if [[ $STATE == "HELP" ]]; then show_help; fi
    clear
    print_header_and_working_dir
    build_subdirs
    if ((SUBDLEN < 1)); then
        echo -e "\e[33m └─ [no dirs]\e[0m"
    else
        build_highlight; build_page
        print_page_with_highlight
    fi
    wait_for_input  # can update STATE + HIGHLIGHT
done

# Exit alt-mode, show cursor
tput cnorm rmcup

# Exit script
if [[ "$STATE" == "EXIT" ]]; then
    return 0
else
    echo "$STATE -- cdi aborted" >&2
    return 3
fi
