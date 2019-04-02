#!/bin/bash
_xsanexrandrAutocomplete ()   #  By convention, the function name
{                 #+ starts with an underscore.
    local cur
    # Pointer to current completion word.
    # By convention, it's named "cur" but this isn't strictly necessary.

options="--above --below --right-of --left-of--dmenu--interactive -i --debug --auto --outputs--dryrun --help -h --version -v "
actions="add-monitor set-primary reset pip list clear refresh split-monitor configure"    
    COMPREPLY=() # Array variable storing the possible completions.
    cur=${COMP_WORDS[COMP_CWORD]}
    last=${COMP_WORDS[COMP_CWORD-1]}
    firstArg=${COMP_WORDS[1]}

    options=""
    if [[ ! "$last" || "$last" == "--*" ]]; then
        COMPREPLY=( $( compgen -W "$options $actions --" -- $cur ) )
        return 0;
    fi
    return 0
}
complete -F _xsanexrandrAutocomplete
