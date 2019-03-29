#! /bin/bash
#================================================================
# HEADER
#================================================================
#%Usage: ${SCRIPT_NAME} [<options>] <command> [<args>]
#%MPX aware window manager
#%
#%Option
#       --above,--below, --right-of, --left-of relative position of monitors
#       --dmenu=<cmd.               the command to use to select text when in interactive mode
#       --interactive, -i           interactivly choose args
#       --debug                     enable debuggin (set -x)
#       --auto                      automatically choose which monitor to use
#       --outputs=<outputs>         Select outputs among this list. For use with interactive or auto
#       --dryrun                    Performs all the actions specified except that no changes are made.
#       --help, -h                  display help
#       --version, -v               print version number
#%Action:
#%      add-monitor output [dims]   creates a fake monitor next to output. If dims aren't specifed, the they are the same as the outputs dimensions. The monitor can be position relative to another by using one of --above,--below, --right-of, left-of.
#%      set-primary output          sets output to be the primary monitor
#%      reset                       turns ouputs off then on again
#%      pip output dims                         creates a fake monitor relative to the bounds of output's bounds. Negative x, y values refer to an offset from the right/bottom edge
#%      list                        list all possible outputs
#%      clear                       clear all fake monitors
#%      refresh                     refresh xrandr
#%      split-monitor output [W|H] [, num [,slice-dims] ]
#%      configure [--scaled-mirror] [--mirror] outputs...
#%
#%
#%Examples:
#%    ${SCRIPT_NAME} --right-of --auto add-monitor              #Create a fake monitor or an arbitary output with the same dimensions and place it to the right of the original
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME}
#-    author          Arthur Williams
#-    license         MIT
#================================================================
# END_OF_HEADER
#================================================================
#MAN generated with help2man -No mpxmanager.1 ./mpxmanager.sh
set -e
displayHelp(){
    SCRIPT_HEADSIZE=$(head -200 ${0} |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
    SCRIPT_NAME="$(basename ${0})"
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ;
}
version(){
    echo "1.0.0"
    exit 0
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

getAllOutputs(){
    xrandr -q|grep ' connected' |cut -d ' ' -f 1
}
getListOfOutputs(){
    echo $outputs | sed "s/ /\n/g"
}
getResolutions(){
    res=$(echo $(getListOfOutputs | sed -n 's/^\s*\([[:digit:]]\+x[[:digit:]]\+\).*\*.*/\1/p'))
    #echo $(xrandr -q| sed -n 's/^.* connected \?\w* \([[:digit:]]\+x[[:digit:]]\+\).*$/\1/p')
}
getOutputDims(){
    (export D="[[:digit:]]"; xrandr -q|grep  "$1 connected .* " | sed -E -n "s/.* ($D+)+x($D+)\+($D+)\+($D+) (\([^\)]*\))? ?($D+)mm x ($D+)mm$/\1 \2 \3 \4 \6 \7/p")
}

refresh(){
   size=$(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*current (\w+)\s*x\s*(\w+).*$/\1x\2/p")
   xrandr $dryrun --fb $(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*maximum (\w+)\s*x\s*(\w+).*$/\1x\2/p")
   xrandr $dryrun --fb $size
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

getOutputConfigurations(){
    cat << EOF |python
import itertools
outputs='$1'.split()
nonMirror=itertools.chain.from_iterable(itertools.permutations(outputs,x) for x in range(1,len(outputs)+1))
options=itertools.chain(nonMirror,map(lambda x:("--mirror: "+x,),outputs),map(lambda x:("--scaled-mirror: "+x,),outputs))
for option in options:
    print(" ".join(option))
EOF
}
applyOutputConfiguration(){
    mirror=0
    if [[ "$1" == "--scale-mirror" ]]; then
        res=$(getResolutions "$3")
        extra=" --scale-from $res "
        mirror=1
        shift
    elif [[ "$1" == "--mirror" ]]; then
        mirror=1
        shift
    else
        turnOffOutputs $(getDiff "$(getAllOutputs)" "$outputs")
    fi
    command="xrandr $dryrun "

    pos=""
    for out in "$@"
    do
        if [[ $mirror -eq 1 ]];then
            command="$command --output $out --same-as $1 $extra"
        else
            command="$command --output $out $pos --auto"
            pos=" $relativePos $out"
        fi
    done
    $command
}

resetOutputs(){
    turnOffOutputs $outputs
    applyOutputConfiguration $outputs
}
setPrimary(){
    if [[ "$interactive" ]]; then
        result=$(getListOfOutputs|$dmenu)
    else
        result=$commands
    fi
    xrandr --output $result --primary
}
configureOutputs(){
    if [[ "$interactive" ]]; then
        result=$(getOutputConfigurations|$dmenu)
    else
        result=$commands
    fi
    applyOutputConfiguration $result
}
clearFakeMonitors(){
    xrandr $dryrun --listmonitors |grep "$1" | sed -E -n "s/^\s+\w: ([^ *+]+).*/\1/p" |xargs -I {} xrandr $dryrun --delmonitor {}
}
clearAllFakeMonitors(){
    clearFakeMonitors
    refresh
}
createAdjMonitor(){
    name=$(echo "$1$relativePos$(uuidgen)" |sed "s/-//g")
    shift
    case "$relativePos" in
        *)
            ;;
        pip)
            xrandr --setmonitor $name $1/$5x$2/$6+$3+$4 "none";
            ;;
        --below)
            y=$(($4+$2))
            xrandr --setmonitor $name $1/$5x$2/$6+$3+$y "none";
            ;;
        --right-of)
            x=$(($3+$1))
            xrandr --setmonitor $name $1/$5x$2/$6+$x+$4 "none";
            ;;
    esac
    refresh
}
getArbitaryOutput(){
    getListOfOutputs |head -n1
}
pip(){
    relativePos="pip"
    args=( $commands )
    # assuse arbitary monitor if nothing is specified
    name=${args[0]}
    dims=( $(getOutputDims $name) )
    # X
    if [[ "${args[1]}" -lt 0 ]];then
        dims[2]=$((${dims[0]}+${args[1]}+${dims[2]}))
        echo adjusting
    else
        dims[2]=${args[1]}
    fi
    # Y
    if [[ "${args[2]}" -lt 0 ]];then
        dims[3]=$((${dims[1]}+${args[2]}+${dims[3]}))
    else
        dims[3]=${args[2]}
    fi
    [ ! -z "${args[3]}" ] && [ "${args[3]}" -ne 0 ] && dims[0]=${args[3]}
    [ ! -z "${args[4]}" ] && [ "${args[4]}" -ne 0 ] && dims[1]=${args[4]}

    createAdjMonitor "$name" ${dims[@]}
}
addMonitor(){
    if [[ "$interactive" ]]; then
        commands=( $(getListOfOutputs |$dmenu) )
    fi
    name=${commands[0]}
    dims=${commands[@]:1:4}
    if [[ ! "$name" ]];then
        echo "Missing output; aborting"
        exit 1
    fi
    if [[ ! "$dims" ]]; then
        dims=$(getOutputDims $name)
    fi
    createAdjMonitor "$name" $dims
}
splitMonitor(){
    if [[ "$interactive" ]]; then
        result=$(getListOfOutputs | xargs -I{} echo -e "{} W\n {} H" |$dmenu)
    else
        # format: output, H or W, [, num [, slice-dim]]
        result=$commands
    fi
    if [[ ! "$result" ]];then
        echo "Arguments needed; aborting"
        exit 1
    fi

    target=$(echo $result |cut -d' ' -f 1)

    dims=$(getOutputDims "$target")
    if [[ ! "$dims" ]];then
        echo "could not get output dimensions; aborting"
        exit 1
    fi

    command=$(cat << EOF |python
result=("$result").split()
result[0]="$target"
dims=list(map(int,"$dims".split()))
index=int(result[1] == 'H')
num=int(result[2]) if len(result)>2 else 2
S=dims[index]
if len(result) > 3:
    slicePercent=int(result[3])
    dims[index]*=slicePercent/100
    dims[index-2]*=slicePercent/100
else:
    dims[index]/=num
    dims[index-2]/=num
dims=list(map(int,dims))
offset=int((S-dims[index]*num)/(num-1))

for i in range(num):
    start=dims[index]*i+offset*i
    print("xrandr --setmonitor {}-$(uuidgen)-{} {}/{}x{}/{}+{}+{} {}; ".format(result[0],start,dims[0],dims[-2],dims[1],dims[-1],dims[2]+start*(index==0),dims[3]+start*(index==1),"none" if i else result[0]))
EOF
)
    if [[ ! "$dryrun" ]]; then
        bash -c "$command"
    else
        echo "$command"
    fi

    refresh
}
outputs=$(echo $(getAllOutputs))
relativePos=""
interactive=
dmenu="dmenu"
dryrun=""
optspec=":hvi-:"
commands=""
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                dmenu)
                    dmenu="${OPTARG[1]}"
                    ;;
                above);&
                below);&
                right-of);&
                left-of)
                    relativePos="--${OPTARG[0]}"
                    ;;
                relative)
                    relativePos=${OPTARG[1]}
                    ;;
                interactive)
                    interactive=1
                    ;;
               debug)
                    set -xe
                    ;;
                outputs)
                    outputs=${OPTARG[@]:1}
                    ;;
                auto)
                    commands="$(getArbitaryOutput) "
                    ;;
                dryrun)
                    dryrun="--dryrun"
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                        displayHelp
                    fi
                    ;;
            esac;;

        i)
            interactive=1
            ;;

        h)
            displayHelp
            ;;
        v)
            version
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            displayHelp
            ;;
    esac
done
shift $((OPTIND-1))
case "$1" in
    add-adj)
        action="addMonitor"
        ;;
    add-monitor)
        action="addMonitor"
        ;;
    set-primary)
        action="setPrimary"
        ;;
    configure)
        action="configureOutputs"
        ;;
    reset)
        action="resetOutputs"
        ;;
    split-monitor)
        action="splitMonitor"
        ;;
    pip)
        action="pip"
        ;;
    list)
        action="getAllOutputs"
        ;;
    clear)
        action="clearAllFakeMonitors"
        ;;
   refresh)
        action="refresh"
        ;;
    *)
        action="configureOutputs"
        ;;
esac;
if [[ -z "$action" ]];then
    action="configureOutputs"
else
    shift
fi
commands="$commands $@"
args=( $commands )
$action
