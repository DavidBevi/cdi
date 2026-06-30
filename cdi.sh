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
[ "${BASH_SOURCE[0]}" == "$0" ] && { N="filename"; echo -e "
ERROR: this script doesn't work with 'bash $N' or './$N'.
FIX: use an interactive Bash session and launch with '. $N'\nEXITING"; exit; }

# SETTINGS ####################################################################
IFS=$"\n"  # makes script compatible with dirnames-with-spaces
trap "MODE=ERROR" RETURN  # allows to catch errors and exit gracefully

# global vars
STARTING_DIR="$PWD"
# when called with argument(s) MODE=HELP
MODE="NORMAL"; [ $# -gt 0 ] && MODE="HELP"
# associative arrays to remember stuff for each visited dir
declare -A HIGHLIGHT_POS
declare -A HIGHLIGHT_ITEM


# FUNCTIONS ###################################################################
main() {
    clear
    if [ $MODE == "HELP" ]; then show_help; fi
    if [ $MODE == "NORMAL" ]; then
        print_title_and_pwd
        print_list_of_subdirs # update HIGHLIGHT_* globals
        wait_for_input # can update MODE + HIGHLIGHT_* globals
    else
        tput cnorm rmcup
        if [ "$MODE" != "EXIT" ]; then
            echo "ERROR: cdi aborted" >&2
            return 1
        fi
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

print_title_and_pwd() {
    # print PWD/ with style bold inverted
    echo -e "\e[1;7m $TITLE \e[0m\n $HELP_LINE\n\n\e[1;7m${PWD%/}/\e[0m"
}

print_list_of_subdirs() {
    # fetch subdirs; abort if no subdirs
    local SUBDIRS=(*/)
    if [ "${SUBDIRS[0]}" == "*/" ]; then
        echo -e "\e[33m └─ [no dirs]\e[0m"
        return
    fi
    local SUBDLEN="${#SUBDIRS[@]}"

    # update global HIGHLIGHT_POS
    # if CHILD exists it's the subdir we're coming from: use it + delete it
    if [ "$CHILD" ]; then
        for i in "${!SUBDIRS[@]}"; do
            if [ "$CHILD" == "${SUBDIRS[$i]}" ]
                then HIGHLIGHT_POS["$PWD"]=$i; break; fi
        done
        unset CHILD
    # else sanitize negative values (I think math func is faster than IF)
    else
        HIGHLIGHT_POS["$PWD"]=$(( (HIGHLIGHT_POS[$PWD] + SUBDLEN) % SUBDLEN ))
    fi
    local INDEX_IN_SUBDIRS=${HIGHLIGHT_POS["$PWD"]}

    # update global HIGHLIGHT_ITEM
    HIGHLIGHT_ITEM["$PWD"]="${SUBDIRS[$INDEX_IN_SUBDIRS]}"

    # make pages to display long lists
    local CURRENT_ROW; local _
    IFS='[;' read -p $'\e[6n' -d R -rs _ CURRENT_ROW _ _
    # ensure CURRENT_ROW is numeric, else script crashes
    [[ "$CURRENT_ROW" =~ ^[0-9]+$ ]] || CURRENT_ROW=4
    local PAGELEN=$((LINES - CURRENT_ROW - 2))
    local PAGES=$(( (SUBDLEN + PAGELEN - 1) / PAGELEN ))  # ceil()
    local CURR_PAGE=$(( INDEX_IN_SUBDIRS / PAGELEN ))
    local INDEX_IN_PAGE=$(( INDEX_IN_SUBDIRS % PAGELEN ))
    local OFFSET=$(( CURR_PAGE * PAGELEN ))

    # when multiple pages: write "Page X of Y"
    if [ $PAGES -gt 1 ]; then
        echo -e " │  \e[33mPage $((CURR_PAGE+1)) of $PAGES\e[0m"
    fi

    # display page using array expansion with slicing
    echo -en "\e[s"  # SAVE cursor pos
    printf ' ├─ %s\n' "${SUBDIRS[@]:$OFFSET:$PAGELEN}"
    echo -en "\e[A └"  # replace ├ in last row with └

    # highlight selected item
    echo -en "\e[u"  # USE previously saved cursor pos
    # if not in row 0: move to right row
    [ $INDEX_IN_PAGE != 0 ] && echo -en "\e[${INDEX_IN_PAGE}B"
    echo -en "\e[5G\e[1;7m${HIGHLIGHT_ITEM[$PWD]}\e[0m"
}

wait_for_input() {
    # ▼ wait for a keystroke -> read first byte and save into INPUT
    read -rsn1 INPUT;
    # ▼ if INPUT is ESC (= multi-byte keystroke) read another 2 bytes
    if [ "$INPUT" == $'\e' ]; then read -rsn2 INPUT; fi
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
up()       { (( HIGHLIGHT_POS[$PWD]+=-1 )); }
down()     { (( HIGHLIGHT_POS[$PWD]+=1 )); }
left()     { CHILD="$(basename $PWD)/"; cd ..; }
right()    { cd "${HIGHLIGHT_ITEM[$PWD]}"; }
help()     { MODE="HELP"; }
restore()  { cd "$STARTING_DIR"; }
set_exit() { MODE="EXIT"; }


# BODY ########################################################################
tput smcup  # call "alt screen" / "cup mode"
tput civis  # hide cursor
main        # launch cdi
