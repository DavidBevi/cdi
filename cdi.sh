#!/usr/bin/env bash
# ERROR is here to print an helpful msg in some shells that crash (Fish) ######
ERROR=" this script must be used with Bash shell
#   (You're using a different shell, it crashed)
#   WIKI: https://simple.wikipedia.org/wiki/Bash
" #_____________________________________________
unset ERROR

TITLE="CDI: Change Dir Interactive - by DavidBevi"
HELP_LINE="ARROWS:move  H:help  R:reset  OTHER:exit"
HELP_SCREEN="
USAGE:
   MOVE the cursor and select a subdir with arrow keys
   HELP_SCREEN (show this screen) with H
   RESET / RESTORE the starting directory with R
   EXIT from CDI with any other key

ABOUT:
   https://github.com/DavidBevi/cdi

CREDITS:
   Inspired by CDI by Antonio Oliveria (inactive)
   https://github.com/antonioolf/cdi/issues/15"

# ENFORCE BASH ################################################################
[ -z "$BASH_VERSION" ] && { echo -e "ERROR: this script must be used with Bash.
WIKI: https://simple.wikipedia.org/wiki/Bash \nEXITING"; return; }

# ENFORCE SOURCE (".") ########################################################
[ "${BASH_SOURCE[0]}" == "$0" ] && { N="filename"; echo -e "
ERROR: this script doesn't work with 'bash $N' or './$N'.
FIX: use an interactive Bash session and launch with '. $N'\nEXITING"; exit; }

# SETTINGS ####################################################################
IFS=$"\n"  # makes script compatible with dirnames-with-spaces
trap "MODE=ERROR" RETURN  # allows to catch errors and exit gracefully

# global vars
STARTING_DIR="$(pwd)/"
# when called with argument(s) MODE=HELP
MODE="NORMAL"; [ $# -gt 0 ] && MODE="HELP"
# associative arrays to remember stuff for each visited dir
declare -A HIGHLIGHT_POS ; HIGHLIGHT_POS["$WD"]=0
declare -A HIGHLIGHT_ITEM; HIGHLIGHT_ITEM["$WD"]=0


# FUNCTIONS ###################################################################
main() {
    clear
    if [ $MODE == "HELP" ]; then show_help; fi
    if [ $MODE == "NORMAL" ]; then
        print_working_dir # set WD + HEADER_OFFSET
        print_list_of_subdirs # set SUBDIRS_ARR, save cursor pos
        print_highlight_over_list # update HIGHLIGHT globals
        # print_debug # after subdirs, using saved cursor pos
        wait_for_input # can update MODE + HIGHLIGHT globals
    else
        tput cnorm rmcup
        if [ "$MODE" != "EXIT" ]; then echo "ERROR: cdi aborted"; fi
    fi
}

show_help() {
    # ▼ display HELP_SCREEN and wait for input to resume cdi
    echo -e "\e[1;7m $TITLE \e[0m\n$HELP_SCREEN\n"
    echo -e "\e[1;7m Press any key to close help and use CDI \e[0m"
    read -rsn1; MODE="NORMAL"  # wait for input; unset help-mode
    while IFS= read -rsn1 -t 0.01; do :; done  # clear input buffer
    clear
}

print_working_dir() {
    echo -e "\e[1;7m $TITLE \e[0m\n $HELP_LINE\n"
    # set WD and if NOT root add trailing "/"
    WD="$(pwd)"; [ "$WD" == "/" ] || WD+="/"
    # print WD with style bold inverted
    echo -e "\e[1;7m$WD\e[0m"
    # set HEADER_OFFSET
    IFS='[;' read -p $'\e[6n' -d R -rs _ HEADER_OFFSET COL _
}

print_list_of_subdirs() {
    # each subdir is printed and stored in SUBDIRS_ARR
    SUBDIRS_ARR=()
    for DIR in */; do
        echo -e " ├─ $DIR"
        SUBDIRS_ARR+=("$DIR")
        # WHEN 'CD'ING UP A LEVEL HIGHLIGHT SUBDIR OF PROVENANCE
        # using the length of SUBDIRS_ARR when DIR == CHILD
        [ "$DIR" == "$CHILD" ] && {
            HIGHLIGHT_POS["$WD"]=$(( ${#SUBDIRS_ARR[@]} - 1 ))
        }
    done
    # clean up variable else highlight is stuck
    unset CHILD
    # save cursor pos (for print-debug)
    echo -en "\e[s"
}

print_highlight_over_list() {
    # ▼ if dir has NO subdirs: display "[no dirs]"
    if [ "${SUBDIRS_ARR[0]}" == "*/" ]; then
        HIGHLIGHT_POS["$WD"]=0
        CURSOR_POS=$HEADER_OFFSET
        echo -e "\e[$CURSOR_POS;1H\e[33m ├─ [no dirs]\e[0m\e[K"
        # ▼ if dir HAS subdirs: highlight selected dir
    else
        MOD=${#SUBDIRS_ARR[@]}
        HIGHLIGHT_POS["$WD"]=$(( (${HIGHLIGHT_POS["$WD"]} + $MOD) % $MOD ))
        HIGHLIGHT_ITEM["$WD"]=${SUBDIRS_ARR[${HIGHLIGHT_POS["$WD"]}]}
        CURSOR_POS=$(( ${HIGHLIGHT_POS["$WD"]} + $HEADER_OFFSET ))
        echo -en "\e[$CURSOR_POS;5H\e[1;7m${HIGHLIGHT_ITEM["$WD"]}\e[0m"
    fi
}

print_debug() {
    echo -e "\e[u"  # use previously saved cursor pos
    echo -e "\e[1m[Debug]\e[0m"
    echo "POS: ${HIGHLIGHT_POS[$WD]} -- ITEM: ${HIGHLIGHT_ITEM[$WD]}"
    declare -p MODE WD SUBDIRS_ARR
}

wait_for_input() {
    # ▼ wait for a keystroke -> read first byte and save into INPUT
    read -rsn1 INPUT;
    # ▼ if INPUT is ESC (= multi-byte keystroke) read another 2 bytes
    if [ $INPUT == $'\e' ]; then read -rsn2 INPUT; fi
    # ▼ loop to consume/empty the input buffer
    #   -> prevents aborting when user presses 2 arrow keys together
    while IFS= read -rsn1 -t 0.01; do :; done
    # ▼ route INPUT to proper action
    case "$INPUT" in
        # Arrows codes in Normal Mode:  [A  [B  [C  [D
        #     Application Cursor Mode:  OA  OB  OC  OD
        [A|OA) up;;    [B|OB) down;;    [C|OC) right;;    [D|OD) left;;
        h) help;;      r) restore;;     *) set_exit;;
    esac
    # ▼ continue by relaunching main
    main
}

# POSSIBLE ACTIONS
# after each action main() repeats
up()       { (( HIGHLIGHT_POS["$WD"]+=-1 )); }
down()     { (( HIGHLIGHT_POS["$WD"]+=1 )); }
left()     { CHILD="$(basename $WD)/"; cd ..; }
right()    { cd "${HIGHLIGHT_ITEM["$WD"]}"; }
help()     { MODE="HELP"; }
restore()  { cd "$STARTING_DIR"; }
set_exit() { MODE="EXIT"; }


# BODY ########################################################################
tput smcup  # call "alt screen" / "cup mode", once
tput civis  # hide cursor
main        # launch cdi
