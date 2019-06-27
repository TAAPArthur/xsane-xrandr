#! /bin/bash
#================================================================
# HEADER
#================================================================
#%Usage: ${SCRIPT_NAME} [<options>] <command> [<args>]
#%xrandr wrapper
#%
#% DIMS can either mean X,Y,W,H or WxH+X+Y
#%Option
#       --auto,-a                   automatically choose which monitor to use
#       --dmenu <cmd>               the command to use to select text when in interactive mode
#       --dryrun                    Performs all the actions specified except that no changes are made.
#       --help, -h                  display help
#       --interactive, -i           interactively choose args
#       --outputs <outputs>         Select outputs among this list. For use with interactive or auto
#       --target, -t                Monitor target
#       --version, -v               print version number
#%Action:
#%      add-monitor DIMS   creates a fake monitor. The monitor can be position relative to another by using one of the below options. If the width/height argument is 0, then the dimension will be the same as the reference point if defined below or through target flag. If the target flag is set the output argument should not be specified
#              --above output       the new monitor is above output
#              --below output       the new monitor is below output
#              --inside-of output   the new monitor is positioned relative to the upper left corner of output. Negative x, y values refer to an offset from the right/bottom edge
#              --right-of output    the new monitor is to the right of output
#              --left-of output     the new monitor is to the left of output
#%      clear                       clear all fake monitors
#%      configure  outputs...       A list of outputs in left to right order
#%      dup                         Mirrors the display of target across all monitors
#%      get-monitor-dims            Gets the space separated list of monitor dims
#%      list                        list all possible outputs
#%      pip DIMS                    alias for add-monitor --inside-of . The target flag needs to be set
#%      refresh                     refresh xrandr
#%      set-primary                 sets output to be the primary monitor
#%      split-monitor [W|H] [, num [,slice-dims] ]  The first argument dictates the dimension to split on. Upper case means to replace the existing monitor. Num is the number of resulting pieces (default 2). Slice-dims set the percent of the total width/height each slice gets (Default is they all get equal slices)
#%
#%
#%Examples:
#%    ${SCRIPT_NAME} --right-of --auto add-monitor              #Create a fake monitor or an arbitrary output with the same dimensions and place it to the right of the original
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME}
#-    author          Arthur Williams
#-    license         MIT
#================================================================
# END_OF_HEADER
#================================================================
#MAN generated with help2man -No xsane-xrandr.1 ./xsane-xrandr.sh

set -e
set -o pipefail

displayHelp(){
    SCRIPT_HEADSIZE=$(head -200 ${0} |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
    SCRIPT_NAME="$(basename ${0})"
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ;
}
version(){
    echo "1.0.0"
    exit 0
}

check(){
    if [ -z "$1" ]; then
        echo "$2" >&2
        displayHelp
        exit 1
    fi
}
checkTarget(){
    check $target "No target specified"
}

getDiff(){
    list1=( $1 )
    list2=( $2 )
    l2=" ${list2[*]} "                    # add framing blanks
    for item in ${list1[@]}; do
      if [[ ! $l2 =~ " $item " ]] ; then    # use $item as regexp
        result+=($item)
      fi
    done
    echo  ${result[@]}
}

getListOfOutputs(){
    echo $outputs | sed "s/ /\n/g"
}
getOutputDims(){
    (export D="[[:digit:]]"; xrandr -q|grep  "$1 connected .* " | sed -E -n "s/.* ($D+)+x($D+)\+($D+)\+($D+) (\([^\)]*\))? ?($D+)mm x ($D+)mm$/\6 \7 \1 \2 \3 \4/p")
}
getMonitorDims(){
    (export D="[[:digit:]]"; xrandr --listmonitors |grep  -E " +?$1 " | sed -E -n "s|.* ($D+)+/($D+)x($D+)/($D+)\+($D+)\+($D+)|\5 \6 \1 \3 \2 \4|p")
}
getEdgeMonitor(){
    declare -A arr
    arr=( [get-left-most]=1 [get-top-most]=2 [get-right-most]=3 [get-bottom-most]=4 )
    sortArgs=
    index=${arr[$1]}
    [ "$index" -gt 2 ] && sortArgs="-r"
    (export D="-?[[:digit:]]"; xrandr --listmonitors  | sed -E -n "s|.* \+?(\S+) ($D+)+/$D+x($D+)/$D+\+($D+)\+($D+)|\4 \5 \$((\2+\4)) \$((\3+\5)) \1 |p") |
        xargs -I{} bash -c 'echo  {}' |cut -d" " -f $index,5 |sort -n $sortArgs|head -n1 |cut -d' ' -f 2
}
getArbitaryOutput(){
    getListOfOutputs |head -n1
}

setPrimary(){
    if [[ "$interactive" ]]; then
        target=$(getListOfOutputs|$dmenu)
    else
        checkTarget
    fi
    xrandr --output $target --primary
}
clearFakeMonitors(){
    xrandr $dryrun --listmonitors |grep "$1" | sed -E -n "s/^\s+\w: ([^ *+]+).*/\1/p" |xargs -I {} xrandr $dryrun --delmonitor {}
}
clearAllFakeMonitors(){
    clearFakeMonitors
    refresh
}
refresh(){
   size=$(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*current (\w+)\s*x\s*(\w+).*$/\1x\2/p")
   size2=$(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*maximum (\w+)\s*x\s*(\w+).*$/\1x\2/p")
   if [[ "$size" == "$size2" ]]; then
       size2=$(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*minimum (\w+)\s*x\s*(\w+).*$/\1x\2/p")
   fi
   xrandr --nograb $dryrun --fb $size2
   xrandr --nograb $dryrun --fb $size
}
turnOffOutputs(){
    if [[ ! -z "${*}" ]]; then
        command="xrandr $dryrun "
        for out in "$@"
        do
            command="$command --output $out --off"
        done
        $command
    fi
}

################################## configure function and helpers
getOutputConfigurations(){
    cat << EOF |python
import itertools
outputs='$outputs'.split()
nonMirror=itertools.chain.from_iterable(itertools.permutations(outputs,x) for x in range(1,len(outputs)+1))
options=itertools.chain(nonMirror,map(lambda x:("--mirror: "+x,),outputs),map(lambda x:("--scaled-mirror: "+x,),outputs))
for option in options:
    print(" ".join(option))
EOF
}
mirror(){
    arr=( $outputs )
    command="xrandr $dryrun --output $1"
    for out in ${arr[*]}; do
        if [[ "$out" != "$1" ]]; then
            command="$command --output $out --same-as $1 $2"
        fi
    done
}
applyOutputConfiguration(){
    mirror=0
    if [[ "$1" == "--scale-mirror" ]]; then
        res=$(xrandr -q| sed -n "s/^$2.* connected \?\w* \([[:digit:]]\+x[[:digit:]]\+\).*$/\1/p")
        check "$res" "Could not get resolution of $2"
        mirror $2 " --scale-from $res "
        return 0
    elif [[ "$1" == "--mirror" ]]; then
        mirror $2 ""
        return 0
    else
        turnOffOutputs $(getDiff "$*" "$outputs")
    fi
    command="xrandr $dryrun "

    pos=""
    for out in "$@"
    do
        if [[ $mirror -eq 1 ]];then
            command="$command --output $out --same-as $1 $extra"
        else
            command="$command --output $out $pos --auto"
            pos="--right-of $out"
        fi
    done
    $command
}
configureOutputs(){
    if [[ "$interactive" ]]; then
        result=$(getOutputConfigurations|$dmenu)
    else
        result=$*
    fi
    applyOutputConfiguration $result
}
dup(){
    if [[ "$interactive" ]]; then
        target=$(getListOfOutputs |$dmenu)
    else
        checkTarget
    fi
    applyOutputConfiguration "--scale-mirror" $target
}
#################################################################

################################################### Add monitor and helper methods
#Transforms the arguments to be relative towards the monitor $target
getRelativeDims(){
    dims=($*)
    if [[ "$relativePos" || ! -z "$target" ]]; then
        checkTarget
        refDims=($(getMonitorDims $target))
        if [[ "${refDims[*]}" ]]; then
            case "$relativePos" in
                --above)
                    dims[1]=$((dims[1]-refDims[3]))
                    ;;
                --below)
                    dims[1]=$((dims[1]+refDims[3]))
                    ;;
                --right-of)
                    dims[0]=$((dims[0]+refDims[2]))
                    ;;
                --left-of)
                    dims[0]=$((dims[0]-refDims[2]))
                    ;;
                --inside-of)
                    if [[ "${dims[1]}" -lt 0 ]];then
                        dims[1]=$((dims[1]+refDims[1]+refDims[3]))
                    else
                        dims[1]=$((dims[1]+refDims[1]))
                    fi
                    if [[ "${dims[0]}" -lt 0 ]];then
                        dims[0]=$((dims[0]+refDims[0]+refDims[2]))
                    else
                        dims[0]=$((dims[0]+refDims[0]))
                    fi
                    ;;
            esac
            [ ${dims[3]} -eq 0 ] && dims[3]=${refDims[3]}
            [ ${dims[2]} -eq 0 ] && dims[2]=${refDims[2]}
        fi
    fi
    echo ${dims[*]}
}


# name x,y,w,h, w_mm, h_mm
createMonitor(){
    mName=$1
    if xrandr --listmonitors | grep -E -q " +?$name "; then
        mName=$name_$(date +%s%N | cut -b4-13)
    fi
    shift
    [ -z $7 ] && output="none" || output=$7
    xrandr $dryrun --setmonitor $mName $3/$5x$4/$6+$1+$2 $output >>/dev/null
}
convertDimInput(){
    echo $* | sed -E 's/([[:digit:]]+)x([[:digit:]]+)\+([[:digit:]]+)\+([[:digit:]]+)/\3 \4 \1 \2/g'
}
addMonitor(){
    dims=($(convertDimInput $*))
    if [[ "${#dims[@]}" -ne 4 ]];then
        echo "Wrong number of arguments: $*"
        displayHelp
        exit 1;
    fi
    createMonitor "${name:-fake_monitor_$(echo "$1$relativePos$(uuidgen)" |sed "s/-//g")}" $(getRelativeDims "${dims[*]}") 1 1
    refresh
}
##########################################################################

splitMonitor(){
    if [[ "$interactive" ]]; then
        result=$(getListOfOutputs | xargs -I{} echo -e "{} W\n {} H" |$dmenu)
    else
        # format: output, H or W, [, num [, slice-dim]]
        result=$*
    fi
    check $result "Arguments needed; aborting"
    checkTarget
    [ -z "$name" ] && name="split_$target"

    dims=( $(getOutputDims "$target") )
    if [[ ! "$dims" ]];then
        echo "could not get output dimensions; aborting"
        exit 1
    fi
    [[ "$1" == 'H' || "$1" == 'W' ]] && replace=1 || replace=0
    [ "$1" == 'H' ] && index=1 || index=0
    [ -z "$2" ] && num=2 || num=$2


    S=${dims[index+2]}

    if [ -z "$3" ]; then
        dims[index+2]=$((dims[index+2]/$num))
    else
        dims[index+2]=$((dims[index+2]*$3/100))
    fi
    step=$(((S-dims[index+2]*num)/(num-1)+dims[index+2]))
    for ((i=0; i < num ; i++)); do
        [[ "$i" -eq 0 && "$replace" -eq 1 ]] &&  monitorTarget=$target || monitorTarget="none"
        createMonitor "$name-$i" ${dims[*]} $monitorTarget
        dims[$index]=$((${dims[index]}+step))
    done
    refresh
}

outputs=$(xrandr -q|grep ' connected' |cut -d ' ' -f 1)
relativePos=""
target=
name=
interactive=
dmenu="dmenu"
dryrun=""
commands=""
while true; do
    case "$1" in
        --dmenu)
            dmenu="$2"
            shift
            ;;
        --target|-t)
            target=$2
            shift
            ;;
        --auto|-a)
            [ -z "$refPoint" ] && refpoint="$(getArbitaryOutput)"
            [ -z "$target" ] && target="$(getArbitaryOutput)"
            dmenu="head -n1"
            ;&
        --interactive|-i)
            interactive=1
            ;;
       --name)
            name=$2
            shift
            ;;
       --debug)
            set -xe
            ;;
        --outputs)
            outputs=$2
            shift
            ;;
        --dryrun)
            dryrun="--dryrun"
            ;;
        --help|-h)
            displayHelp
            ;;
        --version|-v)
            version
            ;;
        -*)
            echo "Unknown option $1" >&2
            displayHelp
            exit 1
            ;;
        *)
            break;
            ;;
    esac
    shift
done
if [[ -z "$1" ]]; then
    action="configureOutputs"
else
    case "$1" in
        add-monitor)
            action="addMonitor"
            case "$2" in
                --above);&
                --below);&
                --inside-of);&
                --right-of);&
                --left-of)
                    relativePos="$2"
                    if [ -z "$target" ]; then
                       target="$3";
                       shift
                    fi
                    shift
                    ;;
            esac
            ;;
        clear)
            action="clearAllFakeMonitors"
            ;;
        configure)
            action="configureOutputs"
            ;;
        dup)
            action="dup"
            ;;
        get-monitor-dims)
            checkTarget
            action="getMonitorDims $target"
            ;;
        list)
            action="getListOfOutputs"
            ;;
        pip)
            checkTarget
            relativePos="--inside-of"
            action="addMonitor"
            ;;
        set-primary)
            action="setPrimary"
            ;;
        split-monitor)
            action="splitMonitor"
            ;;
       refresh)
            action="refresh"
            ;;
        get-right-most);&
        get-left-most);&
        get-top-most);&
        get-bottom-most)
            action="getEdgeMonitor $1";
            ;;
        *)
            echo "Unknown option $1" >&2
            displayHelp
            exit 1
    esac;
fi
if [[ -z "$action" ]];then
    action="configureOutputs"
else
    shift
fi
$action $@
