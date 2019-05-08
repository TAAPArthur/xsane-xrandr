#!/bin/bash
_xsanexrandrAutocomplete()   #  By convention, the function name
{                 #+ starts with an underscore.
    local cur
    # Pointer to current completion word.
    # By convention, it's named "cur" but this isn't strictly necessary.

    options="--above --below --right-of --left-of --dmenu --interactive -i --debug --auto --outputs"
    actions="add-monitor set-primary reset pip list clear refresh split-monitor configure"
    general=" --dryrun --help -h --version -v"

    COMPREPLY=() # Array variable storing the possible completions.
    cur=${COMP_WORDS[COMP_CWORD]}
    last=${COMP_WORDS[COMP_CWORD-1]}

    if [[ ! "$last" || "$last" == "--*" ]]; then
        COMPREPLY=( $( compgen -W "$options $actions $general --" -- $cur ) )
    else
        COMPREPLY=( $( compgen -W "$actions $general --" -- $cur ) )
    fi
    return 0
}
complete -F _xsanexrandrAutocomplete xsane-xrandr
