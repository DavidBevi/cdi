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
WIKI: https://simple.wikipedia.org/wiki/Bash \nEXITING" >&2; return 1; }

# ENFORCE SOURCE (".") ########################################################
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { N="filename"; echo -e "
ERROR: this script doesn't work with 'bash $N' or './$N'.
FIX: use an interactive Bash session and launch with '. $N'\nEXITING"; exit; }

# SETTINGS ####################################################################
IFS=$'\n'  # makes script compatible with dirnames-with-spaces
trap "MODE=ERROR" RETURN  # allows to catch errors and exit gracefully

# global vars
STARTING_DIR="$PWD"
declare MTIME SUBDLIST SUBDLEN
declare -A HLINDEX HLNAME
declare PAGELEN PAGES PAGE
# when called with argument(s) MODE=HELP
MODE="NORMAL"; [[ $# > 0 ]] && MODE="HELP"

# FUNCTIONS ###################################################################
main() {
    tput smcup civis  # enter alt-mode, hide cursor
    while [[ $MODE == "HELP" ]] || [[ $MODE == "NORMAL" ]]; do
        if [[ $MODE == "HELP" ]]; then show_help; fi
        clear
        print_title_and_curr_dir
        update_subdirs; update_highlight; update_pagination
        print_list_of_subdirs
        wait_for_input  # can update MODE + HLINDEX + HLNAME
    done
    tput cnorm rmcup  # exit alt-mode, show cursor
    if [[ "$MODE" == "EXIT" ]];
        then return 0
        else echo "ERROR: cdi aborted" >&2; return 1
    fi
}

show_help() {
    # ▼ display HELP_SCREEN and wait for input to resume cdi
    clear
    echo -e "\e[1;7m $TITLE \e[0m\n$HELP_SCREEN\n"
    echo -e "\e[1;7m Press any key to close help and use CDI \e[0m"
    read -rsn1; MODE="NORMAL"  # wait for input; unset help-mode
    while IFS= read -rsn1 -t 0.01; do :; done  # clear input buffer
}

print_title_and_curr_dir() {
    # print PWD/ with style bold inverted
    echo -e "\e[1;7m $TITLE \e[0m\n $HELP_LINE\n\n\e[1;7m${PWD%/}/\e[0m"
}

update_subdirs() {
    local time="$PWD::$(stat -c %Y .)"
    [[ "$MTIME" == "$time" ]] && return
    MTIME="$time"
    SUBDLIST=(*/)
    SUBDLEN="${#SUBDLIST[@]}"
}

update_highlight() {
    [[ $SUBDLEN == 0 ]] && return
    HLINDEX["$PWD"]=$(( (HLINDEX[$PWD] + SUBDLEN) % SUBDLEN ))
    HLNAME["$PWD"]="${SUBDLIST[${HLINDEX[$PWD]}]}"
}

update_pagination() {
    local _ row
    IFS='[;' read -p $'\e[6n' -d R -rs _ row _ _
    # ensure row is numeric, else script crashes
    [[ "$row" =~ ^[0-9]+$ ]] || row=4
    PAGELEN=$((LINES - row - 2))
    PAGES=$(( (SUBDLEN + PAGELEN - 1) / PAGELEN ))  # ceil
    PAGE=$(( ${HLINDEX["$PWD"]} / PAGELEN ))  # floor
}

print_list_of_subdirs() {
    # if no list: abort
    if [[ "${SUBDLIST[0]}" == "*/" ]]; then
        echo -e "\e[33m └─ [no dirs]\e[0m"
        return
    fi

    # when multiple pages: write "Page X of Y"
    if [[ $PAGES -gt 1 ]]; then
        echo -e " │  \e[33mPage $((PAGE+1)) of $PAGES\e[0m"
    fi

    # display page using array expansion with slicing
    echo -en "\e[s"  # SAVE cursor pos
    printf ' ├─ %s\n' "${SUBDLIST[@]:$((PAGE*PAGELEN)):$PAGELEN}"
    echo -en "\e[A └"  # replace ├ in last row with └

    # highlight selected item
    echo -en "\e[u"  # USE previously saved cursor pos
    # if not in row 0: move to right row
    local row=$(( ${HLINDEX["$PWD"]} % PAGELEN ))
    if [[ $row != 0 ]]; then echo -en "\e[${row}B"; fi
    echo -en "\e[5G\e[1;7m${HLNAME[$PWD]}\e[0m"
}

wait_for_input() {
    local INPUT
    # ▼ wait for a keystroke -> read first byte and save into INPUT
    read -rsn1 INPUT;
    # ▼ if INPUT is ESC (= multi-byte keystroke) read another 2 bytes
    if [[ "$INPUT" == $'\e' ]]; then read -rsn2 INPUT; fi
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
}

# POSSIBLE ACTIONS
up()       { (( HLINDEX[$PWD]+=-1 )); }
down()     { (( HLINDEX[$PWD]+=1 )); }
right()    { cd "${HLNAME[$PWD]}"; }
left() {
    [[ $PWD == "/" ]] && return
    local child="${PWD##*/}/" i=0
    cd ..
    for d in */; do
        if [[ "$d" == "$child" ]]
            then break
            else ((i++))
        fi
    done
    HLNAME["$PWD"]="$child"
    HLINDEX["$PWD"]=$i
}
help()     { MODE="HELP"; }
restore()  { cd "$STARTING_DIR"; }
set_exit() { MODE="EXIT"; }


# BODY ########################################################################
main # launch cdi
