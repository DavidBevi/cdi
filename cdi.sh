#!/usr/bin/env bash
TITLE="CDI - Change Directory Interactively"
HOW_TO_USE="
 - MOVE with arrow keys
 - RESTORE starting-dir with R
 - EXIT with any other key"


# SETTINGS ####################################################################
IFS=$"\n"  # makes script compatible with dirnames-with-spaces
trap exit_script RETURN  # allows to turn errors into graceful exit
STARTING_DIR="$(pwd)/"
SUBDIRS_ARR=()
SUBDIRS_LEN=0
HIGHLIGHT_POS=0
HIGHLIGHT_ITEM=""


# FUNCTIONS ###################################################################
main() {
    clear
    print_header
    print_curr_dir
    print_list_of_subdirs # updates SUBDIRS_ARR + SUBDIRS_LEN
    # print_debug
    print_highligh_over_list # updates HIGHLIGHT_POS + HIGHLIGHT_ITEM
    wait_for_input
}

print_header() {
    echo -e "\e[1;7m $TITLE \e[0m$HOW_TO_USE\n"
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
    # ▼ read 1 char input without waiting for enter
    read -rsn1 INPUT;
    # ▼ if "r": restore starting dir
    if [ "$INPUT" == "r" ]; then
        cd "$STARTING_DIR"
        main
    # ▼ if esc_char: read 2 chars
    elif [ "$INPUT" == $(printf "\u1b") ]; then
        read -rsn2 INPUT
    fi
    # ▼ route input to proper action
    case "$INPUT" in
        [A) up;; [B) down;; [C) right;; [D) left;; *) exit_script;;
    esac
}

# POSSIBLE ACTIONS
up()   { ((HIGHLIGHT_POS+=-1)); main; }
down() { ((HIGHLIGHT_POS+=1));  main; }
left()  { cd ..; main; }
right() { cd "$HIGHLIGHT_ITEM"; main; }

exit_script() {
    if [ $? != 0 ];  # $? = exit code, if 0 OK else ERROR
        then tput rmcup cnorm; echo "ERROR: cdi aborted"
        else tput rmcup cnorm
    fi
}



# BODY ########################################################################
tput smcup  # call "alt screen" / "cup mode", once
tput civis  # hide cursor
main        # call the function that (re)draws everything
