#!/bin/bash

getIntersection(){
    a1=( $1 )
    a2=( $2 )
    comm -12 <(for X in "${a1[@]}"; do echo "${X}"; done|sort)  <(for X in "${a2[@]}"; do echo "${X}"; done|sort)
}
_xsanexrandrAutocomplete()   #  By convention, the function name
{                 #+ starts with an underscore.
    local cur
    # Pointer to current completion word.
    # By convention, it's named "cur" but this isn't strictly necessary.

    options=" --dmenu --interactive -i -t --target --debug --auto -a --outputs --dryrun --help -h --version -v"
    addMonitorOptions="--above --below --right-of --left-of --inside-of"
    actions="add-monitor clear configure dup get-monitor-dims list pip set-primary split-monitor get-left-most get-right-most get-top-most get-bottom-most"

    COMPREPLY=() # Array variable storing the possible completions.
    cur=${COMP_WORDS[COMP_CWORD]}
    last=${COMP_WORDS[COMP_CWORD-1]}

    if [[ COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $( compgen -W "$options $actions" -- $cur ) )
    elif [[ "$last" == "add-monitor" ]]; then
        COMPREPLY=( $( compgen -W "$addMonitorOptions " -- $cur ) )
    elif [[ "$last" == "--dmenu" ]]; then
        COMPREPLY=( $( compgen -W "dmenu rofi " -- $cur ) )
    elif [[ "$last" == "--outputs" || "$last" == "-t" || "$last" == "--target" || "$last" == "configure" || "$last" == "dup" ]]; then
        COMPREPLY=( $( compgen -W "$(xrandr -q |grep connected |cut -d' ' -f1) " -- $cur ) )
    elif [[ -z $(getIntersection "${COMP_WORDS[*]}" "$actions") ]]; then
        COMPREPLY=( $( compgen -W "$actions " -- $cur ) )
    fi
    return 0
}
complete -F _xsanexrandrAutocomplete xsane-xrandr
