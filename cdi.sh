#!/usr/bin/env bash
TITLE="CDI: Change Dir Interactive - by DavidBevi"
HELP_LINE="ARROWS:move  H:help  R:reset  OTHER:exit"
HELP_SCREEN="
DISAMBIGUATION
- You're using CDI remade by DavidBevi in 2026
   https://github.com/DavidBevi/cdi
- CDI by Antonio Oliveria is inactive since 2020
   https://github.com/antonioolf/cdi/issues/15

USAGE
- MOVE the cursor and select a subdir with arrow keys
- HELP_SCREEN (show this screen) with H
- RESET / RESTORE the starting directory with R
- EXIT from CDI with any other key"

# ENFORCE BASH ################################################################
[ -z "$BASH_VERSION" ] && { echo -e "ERROR: this script must be used with Bash.
WIKI: https://simple.wikipedia.org/wiki/Bash \nEXITING"; return; }

# ENFORCE SOURCE (".") ########################################################
[ "${BASH_SOURCE[0]}" == "$0" ] && { N="filename"; echo -e "
ERROR: this script doesn't work with 'bash $N' or './$N'.
FIX: use an interactive Bash session and launch with '. $N'\nEXITING"; exit; }

# SETTINGS ####################################################################
IFS=$"\n"  # makes script compatible with dirnames-with-spaces
trap "EXIT=ERR" RETURN  # allows to catch errors and exit gracefully

# global vars
STARTING_DIR="$(pwd)/"
HEADER_ROWS=0
SUBDIRS_ARR=()
SUBDIRS_LEN=0
HIGHLIGHT_POS=0
HIGHLIGHT_ITEM=""
EXIT="NO"

# ▼ when called with argument(s) enter help, else normal
if [ $# -gt 0 ]; then MODE="help"; else MODE="normal"; fi


# FUNCTIONS ###################################################################
main() {
    if [ $EXIT == "NO" ]; then
        show_help_if_needed
        clear
        print_header
        print_curr_dir # updates HEADER_ROWS
        print_list_of_subdirs # updates SUBDIRS_ARR + SUBDIRS_LEN
        # print_debug
        print_highligh_over_list # updates HIGHLIGHT_POS + HIGHLIGHT_ITEM
        wait_for_input  # can update MODE
    elif [ $EXIT == "YES" ]; then
        clear
        tput cnorm rmcup
    else  # $EXIT == "ERR"
        clear
        tput cnorm rmcup
        echo "ERROR: cdi aborted"
    fi
}

show_help_if_needed() {
    if [ $MODE == "help" ]; then
        clear
        echo -e "\e[1;7m $TITLE \e[0m\n$HELP_SCREEN\n"
        echo -e "\e[1;7m Press any key to close help and use CDI \e[0m"
        # wait for any input and then set normal mode
        read -rsn1 _; MODE="normal"
        # IMPORTANT clear input buffer so enter and arrows don't bug
        while IFS= read -rsn1 -t 0.01 _; do :; done
    fi  # resume main
}

print_header() {
    echo -e "\e[1;7m $TITLE \e[0m\n $HELP_LINE\n"
}

print_curr_dir() {
    # ▼ prints path with trailing "/", mode: bold inverted
    DIR=$(pwd)
    if [ "$DIR" == "/" ];
        then echo -e "\e[1;7m/\e[0m"
        else echo -e "\e[1;7m$DIR/\e[0m"
    fi
    # ▼ updates HEADER_ROWS
    IFS='[;' read -p $'\e[6n' -d R -rs _ HEADER_ROWS COL _
}

print_list_of_subdirs() {
    # global variables are reset
    SUBDIRS_ARR=()
    SUBDIRS_LEN=0
    # (ls -p | grep "/") lists all subdirs
    # its result goes into the while loop, where
    # each dir is printed and stored in global variables
    while IFS= read -r DIR; do
        echo -e " ├─ $DIR"
        SUBDIRS_ARR+=("$DIR")
        SUBDIRS_LEN=$(( $SUBDIRS_LEN + 1 ))
    done < <(ls -p | grep "/")
}

print_debug() {
    echo
    echo -e "\e[1m[Debug]\e[0m"
    echo -e "\e[1mSUBDIRS_ARR=\e[0m${SUBDIRS_ARR[*]}"
    echo -e "\e[1mSUBDIRS_LEN=\e[0m$SUBDIRS_LEN"
    echo -e "\e[1mHIGHLIGHT_POS=\e[0m$HIGHLIGHT_POS"
    echo -e "\e[1mHIGHLIGHT_ITEM=\e[0m$HIGHLIGHT_ITEM"
}

print_highligh_over_list() {
    # ▼ if dir HAS subdirs: highlight (invert) selection
    if [ "$SUBDIRS_LEN" -gt 0 ]; then
        HIGHLIGHT_POS=$(( ($HIGHLIGHT_POS + $SUBDIRS_LEN) % $SUBDIRS_LEN ))
        HIGHLIGHT_ITEM="${SUBDIRS_ARR[$HIGHLIGHT_POS]}"
        POS=$(( $HIGHLIGHT_POS + $HEADER_ROWS ))
        echo -en "\e[$POS;5H\e[1;7m$HIGHLIGHT_ITEM\e[0m"
    # ▼ if dir has NO subdirs: echo [no dirs]
    else
        POS=$HEADER_ROWS
        echo -en "\e[$POS;1H\e[33m ├─ [no dirs]\e[0m\e[K"
    fi
}

wait_for_input() {
    # ▼ wait for a keystroke -> read first byte and save into INPUT
    read -rsn1 INPUT;
    # ▼ if INPUT is ESC (= multi-byte keystroke) read another 2 bytes
    if [ $INPUT == $'\e' ]; then read -rsn2 INPUT; fi
    # ▼ loop to consume/empty the input buffer
    #   -> prevents aborting when user presses 2 arrow keys together
    while IFS= read -rsn1 -t 0.001 BYTE; do :; done
    # ▼ route INPUT to proper action
    case "$INPUT" in
        # Normal mode arrows      →  [A  [B  [C  [D
        # Application cursor mode →  OA  OB  OC  OD
        [A|OA) up;;    [B|OB) down;;    [C|OC) right;;    [D|OD) left;;
        h ) help;;  r ) restore;;
        * ) set_exit ;;
    esac
    # ▼ continue by relaunching main
    main
}

# POSSIBLE ACTIONS
up()   { ((HIGHLIGHT_POS+=-1)); }
down() { ((HIGHLIGHT_POS+=1)); }
left()  { HIGHLIGHT_POS=0; cd ..; }
right() { HIGHLIGHT_POS=0; cd "$HIGHLIGHT_ITEM"; }
help() { MODE="help"; }
restore() { cd "$STARTING_DIR"; }
set_exit() { EXIT="YES"; }


# BODY ########################################################################
tput smcup  # call "alt screen" / "cup mode", once
tput civis  # hide cursor
main        # launch cdi
