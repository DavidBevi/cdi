#!/usr/bin/env bash
#
# CDI - Change Dir Interactive - https://github.com/DavidBevi/cdi
# v2.1 (2026-07-28)
#
# SYNOPSIS
# CDI displays the Working Dir and its subdirs, and lets the user CD by using
# the arrow keys. "R" CDs to starting dir, "H" displays help, other keys exit.
#
# START
# The first step is checking if CDI is in Bash and it's sourced, if not it
# exits with a brief explanation of error and fix.
# If it passes the checks CDI enters alt mode and hides the cursor.
#
# HELP MODE
# Because of its nature CDI doesn't need any argument, therefore if arg(s) are
# given CDI will set MODE=HELP and the help page will be displayed. Pressing
# any key sets MODE=NORMAL and resumes the normal execution.
#
# MAIN LOOP
# - If MODE=HELP -> display help screen
# - Clear screen
# - Print title, subtitle, $PWD
# - Check if subdirs-list is cached, (re)build cache when needed
# - Check and validate selection / subdir to be highlighted
# - Check $ROWS and paginize subdirs-list when it doesn't fit the window
# - Print subdirs-list or the proper page
# - Print highlight by overwriting selected subdir in inverted style
# - Wait for user input -> can change MODE, can CD
#
# END
# When the MODE is neither NORMAL nor HELP the main loop breaks and CDI exits.
# First it exits alt mode and restores the cursor visibility.
# Then if MODE==EXIT it will exit 0, else it will print the error and exit 3.
#
# LICENSE
# - This free/libre software is provided "AS IS", with NO WARRANTY.
# - You can use it, edit it, share it. You CANNOT ask money for it.
# - Derivatives must share their source code and this same license.
#

# Workaround to print an helpful msg in some shells that crash (Fish)
_=" this script must be used with Bash shell
#   (You're using a different shell, it crashed)
#   WIKI: https://simple.wikipedia.org/wiki/Bash
" #_____________________________________________
unset _

# Abort if not in Bash (compacted POSIX syntax)
[ -z "$BASH_VERSION" ] && { printf "ERROR: this script must be used with Bash.
WIKI: https://simple.wikipedia.org/wiki/Bash \nEXITING\n" >&2; return 1; }

# Abort if not sourced (= "source cdi" or ". cdi")
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    basename="${0##*/}"
    red="\e[1;4:4;31m"
    green="\e[1;4:4;32m"
    bad="'${red}bash $basename\e[0m' or '${red}./$basename\e[0m'"
    good="'${green}. $basename\e[0m'"
    echo -e "ERROR: this script doesn't work with $bad.\nFIX: use an" \
        "interactive Bash session, and launch with $good. \nEXITING" >&2
    exit 2
fi

# GLOBALS #####################################################################
STARTING_DIR="$PWD"
# when [ number of arguments < 0 ] -> MODE=HELP
MODE="NORMAL"; (($#>0)) && MODE="HELP"
# associative arrays (maps)
declare -A HIGHLIGHTED_ITEM_INDEX HIGHLIGHTED_ITEM_NAME
# other vars (I don't want many rows for these)
declare CACHED_DIR_MTIME SUBDLIST SUBDLEN PAGELEN PAGES PAGE

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
    # set mode back to "NORMAL" so next cycle resumes CDI
    MODE="NORMAL"
}

# Display the "normal" header and current directory
print_header_and_working_dir() {
    # print the title (bold+inverted style)
    echo -e "\e[1;7m CDI: Change Dir Interactive - by DavidBevi \e[0m"
    # print short help + newline
    echo -e " ARROWS:move  H:help  R:reset  OTHER:exit\n"
    # print PWD with trailing "/" (bold+inverted style)
    echo -e "\e[1;7m${PWD%/}/\e[0m"
}

# Fetch the subdirs list (only when CDing and when mtime changed)
build_subdirs() {
    # build a string with PWD and CACHED_DIR_MTIME (modification time)
    local curr_dir_mtime
    curr_dir_mtime="$PWD::$(stat -c %Y .)"
    #
    # return if the cached and the current dir_mtime strings are equal
    if [[ "$CACHED_DIR_MTIME" == "$curr_dir_mtime" ]]; then return; fi
    #
    # else save dir_mtime to cache and rebuild the subdirs list
    CACHED_DIR_MTIME="$curr_dir_mtime"
    SUBDLIST=(*/)
    SUBDLEN="${#SUBDLIST[@]}"
}

# Fetch the selected dir that will be highlighted
build_highlight() {
    # return if curr-dir has no subdirs
    if [[ $SUBDLEN == 0 ]]; then return; fi
    # use modulo to ensure that the index is valid
    HIGHLIGHTED_ITEM_INDEX["$PWD"]=$((
        (HIGHLIGHTED_ITEM_INDEX[$PWD] + SUBDLEN) % SUBDLEN ))
    # save the name of the highlighted item
    HIGHLIGHTED_ITEM_NAME["$PWD"]="${SUBDLIST[${HIGHLIGHTED_ITEM_INDEX[$PWD]}]}"
}

# Fetch the terminal window's height and paginize subdirs-list if needed
build_pages() {
    local _ row
    # ask the cursor pos, keep only the row
    IFS='[;' read -p $'\e[6n' -d R -rs _ row _ _
    # ensure row is numeric, else script crashes
    [[ "$row" =~ ^[0-9]+$ ]] || row=4
    # update globals
    PAGELEN=$((LINES - row - 2))
    PAGES=$(( (SUBDLEN + PAGELEN - 1) / PAGELEN ))  # ceil
    PAGE=$(( ${HIGHLIGHTED_ITEM_INDEX["$PWD"]} / PAGELEN ))  # floor
}

# Display subdirs list, highlight the current selection
print_page_of_subdirs_with_highlight() {
    # return if no list
    if [[ "${SUBDLIST[0]}" == "*/" ]]; then
        echo -e "\e[33m └─ [no dirs]\e[0m"
        return
    fi
    #
    # when multiple pages: write "Page X of Y"
    if ((PAGES > 1)); then
        echo -e " │  \e[33mPage $((PAGE+1)) of $PAGES\e[0m"
    fi
    #
    # display curr page using array expansion with slicing
    echo -en "\e[s"  # SAVE cursor pos
    printf ' ├─ %s\n' "${SUBDLIST[@]:$((PAGE*PAGELEN)):$PAGELEN}"
    echo -en "\e[A └"  # replace ├ in last row with └
    #
    # highlight selected item
    echo -en "\e[u"  # USE previously saved cursor pos
    # if not in row 0: move to right row
    local row=$(( ${HIGHLIGHTED_ITEM_INDEX["$PWD"]} % PAGELEN ))
    if ((row != 0)); then echo -en "\e[${row}B"; fi
    echo -en "\e[5G\e[1;7m${HIGHLIGHTED_ITEM_NAME[$PWD]}\e[0m"
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
    ((HIGHLIGHTED_ITEM_INDEX[$PWD]+=-1))
}

down() {
    ((HIGHLIGHTED_ITEM_INDEX[$PWD]+=1))
}

right() {
    cd "${HIGHLIGHTED_ITEM_NAME[$PWD]}" || : # ignore CD fails
}

left() {
    # return if pwd == root
    if [[ "$PWD" == "/" ]]; then return; fi
    # save child_dir and CD up
    local child_dir="${PWD##*/}/"
    cd .. || MODE="ERROR DOING CD UP"
    # find and highlight child_dir
    local i=0
    for d in */; do
        if [[ "$d" == "$child_dir" ]]
            then break
            else ((i++))
        fi
    done
    HIGHLIGHTED_ITEM_NAME["$PWD"]="$child_dir"
    HIGHLIGHTED_ITEM_INDEX["$PWD"]=$i
}

help() {
    MODE="HELP"
}

restore() {
    cd "$STARTING_DIR" || MODE="ERROR RESTORING STARTING DIR"
}

set_exit() {
    MODE="EXIT"
}

# BODY ########################################################################

# Enter alt-mode, hide cursor
tput smcup civis

# Main loop
while [[ $MODE == "HELP" ]] || [[ $MODE == "NORMAL" ]]; do
    if [[ $MODE == "HELP" ]]; then show_help; fi
    clear
    print_header_and_working_dir
    build_subdirs
    build_highlight
    build_pages
    print_page_of_subdirs_with_highlight
    wait_for_input  # can update MODE + HIGHLIGHTED_ITEM
done

# Exit alt-mode, show cursor
tput cnorm rmcup

# Exit script
if [[ "$MODE" == "EXIT" ]]; then
    return 0
else
    echo "$MODE -- cdi aborted" >&2
    return 3
fi
