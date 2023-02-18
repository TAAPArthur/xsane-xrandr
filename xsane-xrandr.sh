#! /bin/sh -e
# shellcheck disable=SC2086
#================================================================
# HEADER
#================================================================
#%Usage: ${SCRIPT_NAME} [<options>] <command> [<args>]
#%xrandr wrapper
#%
#% DIMS can either mean X,Y,W,H or WxH+X+Y
#%Option
#       --auto,-a                   automatically choose which monitor to use
#       --DMENU <cmd>               the command to use to select text
#       --dryrun                    Performs all the actions specified except that no changes are made.
#       --help, -h                  display help
#       --outputs <outputs>         Select outputs among this list.
#       --target, -t                Monitor target
#       --version, -v               print version number
#%Action:
#%      add-monitor [relative_to] DIMS            creates a fake monitor. The monitor can be position relative to another by using one of the below options. If the width/height argument is 0, then the dimension will be the same as the reference point if defined below or through target flag. If the target flag is set the output argument should not be specified. relative_to can be one of the following:
#              --above output       the new monitor is above output
#              --below output       the new monitor is below output
#              --inside-of output   the new monitor is positioned relative to the upper left corner of output. Negative x, y values refer to an offset from the right/bottom edge
#              --right-of output    the new monitor is to the right of output
#              --left-of output     the new monitor is to the left of output
#%      clear                       clear all fake monitors
#%      configure  outputs...       A list of outputs in left to right order
#%      dup                         Mirrors the display of target across all monitors
#%      get-monitor-dims            Gets the space separated list of monitor dims
#%      get-rotation                Returns the rotation status of the given output
#%      list                        list all possible outputs
#%      pip DIMS                    alias for add-monitor --inside-of . The target flag needs to be set
#%      resolution
#%      rotate                      Wrapper around rotate-monitor and rotate-touchscreen
#%      rotate-monitor [C|CC]       Rotate target either clockwise or counter clockwise. If no argument is specified, the current rotation is printed. Absolute axis like left, right, inverted, normal are valid if they are supported by the monitor
#%      rotate-touchscreen          Rotate touch device axis to match monitor. If there are no touch devices, this is a no-op
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

displayHelp(){
    SCRIPT_HEADSIZE=$(head -200 "$0" |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
    SCRIPT_NAME="$(basename "$0")"
    head "-${SCRIPT_HEADSIZE:-99}" "$0" | grep -e "^#[%+]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ;
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
    check "$TARGET" "No target specified"
}

getListOfOutputs(){
    if [ -z "$OUTPUTS" ]; then
        xrandr -q | grep ' connected' | cut -d ' ' -f 1
    else
        echo "$OUTPUTS" | sed "s/ /\n/g"
    fi
}

set_target() {
    if [ -n "$1" ]; then
        TARGET="$1"
    elif [ -z "$TARGET" ]; then
        TARGET=$(getListOfOutputs|$DMENU)
    fi
}

getOutputDims(){
    xrandr -q|grep  "^$1 connected .* " | sed -E -n "s/.* ([0-9]+)+x([0-9]+)\+([0-9]+)\+([0-9]+) (\([^\)]*\))? ?([0-9]+)mm x ([0-9]+)mm$/\3 \4 \1 \2 \6 \7 /p"
}
getMonitorDims(){
    if [ -z "$TARGET" ]; then
        echo 0 0 "$(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*current (\w+)\s*x\s*(\w+).*$/\1 \2/p")" 1 1
   else
        xrandr --listmonitors |grep  -E " +?$1 " | sed -E -n "s|.* ([0-9]+)+/([0-9]+)x([0-9]+)/([0-9]+)\+([0-9]+)\+([0-9]+)|\5 \6 \1 \3 \2 \4|p"
    fi
}
getEdgeMonitor(){
    case "$1" in
        get-left-most)
            index=1;;
        get-top-most)
            index=2;;
        get-right-most)
            index=3;;
        get-bottom-most)
            index=4;;
        *)
            exit 4
            ;;
    esac
    sortArgs=
    [ "$index" -gt 2 ] && sortArgs="-r"

    xrandr --listmonitors  | sed -E -n "s|.* \+?(\S+) ([0-9]+)+/[0-9]+x([0-9]+)/[0-9]+\+(-?[0-9]+)\+(-?[0-9]+)|\4 \5 \2 \3 \1 |p" |
     awk '{print $1, $2, $1+$3, $2+4, $5}' | sort -n $sortArgs -k $index | head -n1 | awk '{print $5}'
}

setPrimary(){
    set_target
    xrandr --output "$TARGET" --primary
}

clearFakeMonitors(){
    xrandr --listmonitors | sed -E -n "s/^\s+\w: ([^ *+]+).*/\1/p" | xargs -n1 xrandr $DRYRUN --delmonitor
}

turnOffOtherOutputs(){
    file=$(mktemp)
    trap 'rm "$file"' EXIT
    for out; do
        echo "$out"
    done | sort > "$file"
    getListOfOutputs | sort | comm -23  - "$file" | {
        cmd="xrandr $DRYRUN "
        while read -r output; do
            $cmd --output $output --off
        done
    }
}

################################## configure function and helpers

contains() {
    # Check if a "string list" contains a word.
    case " $1 " in *" $2 "*|*" $2"|"$2 "*) return 0; esac; return 1
}

getOutputConfigurations(){
    if [ "$#" -eq 0 ]; then
        # shellcheck disable=SC2046
        set -- "" $(getListOfOutputs)
    else
        temp=$1
        shift 2
        set -- "$temp" "$@"
    fi

    first=0
    for output ; do
        if [ "$first" -eq 0 ]; then
            first=1
            continue
        fi
        ! contains "$1" "$output" || continue
        echo "$1$output"
        if [ "$1" = "" ]; then
            echo "--mirror: $output"
            echo "--scaled-mirror: $output"
        fi
        getOutputConfigurations "$1$output " "$@"
    done
}

applyOutputConfiguration(){
    mirror_cmd=
    if [ "$1" = --scaled-mirror ] || [ "$1" = --mirror ]; then
        set_target "$2"
        if [ "$1" = --scaled-mirror ]; then
            res=$(xrandr -q| sed -n "s/^$TARGET.* connected \?\w* \([0-9]\+x[0-9]\+\).*$/\1/p")
            check "$res" "Could not get resolution of $TARGET"
            mirror_cmd=" --scale-from $res "
        elif [ "$1" = --mirror ]; then
            mirror_cmd=" --same-as $TARGET "
        fi
        # shellcheck disable=SC2046
        set -- $(getListOfOutputs)
    else
        (turnOffOtherOutputs "$@")
    fi
    cmd="xrandr $DRYRUN "

    pos=""
    for out; do
        if [ -n "$mirror_cmd" ];then
            [ "$out" = "$TARGET" ] || cmd="$cmd --output $out $mirror_cmd"
        else
            mode="$(getOutputDims "$out" | {
                if read -r x y w h mx my; then
                    echo "--mode ${w}x${h}"
                else
                    echo --auto
                fi
                })"
            cmd="$cmd --output $out $pos $mode"
            pos="--right-of $out"
        fi
    done
    echo $cmd
    $cmd
}

configureOutputs(){
    if [ "$#" -eq 0 ]; then
        # shellcheck disable=SC2046
        if [ -n "$NUM" ]; then
            [ "${NUM%+}" = "$NUM" ] && range= || range=,
            config=$(getOutputConfigurations | grep -E "^([A-z0-9-]+( |\$)){${NUM%+}$range}\$" | $DMENU)
        else
            config=$(getOutputConfigurations | $DMENU)
        fi
        set -- $config
    fi
    applyOutputConfiguration "$@"
}

getResolutionsForMonitor() {
    xrandr | sed "1,/$1/ d" | sed '/connected/,$d'
}

resolution(){
    set_target

    res="$(
    getResolutionsForMonitor "$TARGET" | {
        delta=${2:-1}
        if [ "$1" = up ]; then
             grep -F -B${delta} '*' | head -n1
        elif [ "$1" = down ]; then
            grep -F -A${delta} "*" | tail -n1
        else
             $DMENU
        fi
    } | awk '{print $1}')"
    xrandr --output "$TARGET" --mode "$res"
}

dup(){
    set_target
    applyOutputConfiguration "--scale-mirror" "$TARGET"
}
#################################################################

################################################### Add monitor and helper methods
#Transforms the arguments to be relative towards the monitor $TARGET
getRelativeDims(){
    getMonitorDims "$TARGET" | {
        read -r refX refY refW refH _
        x=$1
        y=$2
        w=$3
        h=$4
        relativePos=$5
        case "$relativePos" in
            --above)
                y=$((y-refH))
                ;;
            --below)
                y=$((y+refH))
                ;;
            --right-of)
                x=$((x+refW))
                ;;
            --left-of)
                x=$((x-refW))
                ;;
            --inside-of)
                if [ "$y" -lt 0 ];then
                    y=$((y+refY+refH))
                else
                    y=$((y+refY))
                fi
                if [ "$x" -lt 0 ];then
                    x=$((x+refX+refW))
                else
                    x=$((x+refX))
                fi
                ;;
            *)
                echo "Unknown relative pos $relativePos"
                exit 3
        esac
        [ "$w" -eq 0 ] && w=$refW
        [ "$h" -eq 0 ] && h=$refH
        echo "$x $y $w $h"
    }
}

# name x,y,w,h, w_mm, h_mm
createMonitor(){
    mName=$1
    shift
    [ -z "$7" ] && output="none" || output=$7
    xrandr $DRYRUN --setmonitor "$mName" "$3/$5x$4/$6+$1+$2" "$output"
}

addMonitor(){
    relativePos=--inside-of
    case "$1" in
        --above|--below|--inside-of|--right-of|--left-of)
            relativePos="$1"
            shift
            if [ -z "$TARGET" ]; then
               TARGET="$1";
               shift
            fi
            ;;
    esac
    echo "$@" | sed -E 's/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/\3 \4 \1 \2/g' | {
        read -r x y w h _
        getRelativeDims "$x" "$y" "$w" "$h" "$relativePos" | {
            read -r x y w h
            createMonitor "${NAME:-fake_monitor_$(echo "$1$relativePos$$" |sed "s/-//g")}" "$x" "$y" "$w" "$h" 1 1
        }
    }
}

pip(){
    set_target
    addMonitor --inside-of "$@"
}
##########################################################################

getRotation(){
    set_target
    xrandr --verbose | grep -w "$TARGET" | grep -w -Eo "(normal|right|left|inverted)" | head -n1
}
getTransformRotation(){

    rotation=$1
    transform=$2
    #in clockwise order
    set -- normal right inverted left

    i=2
    for r; do
        if [ "$r" = "$rotation" ];then
           break
        fi
        i=$((i+1))
    done

    set -- $4 "$@" $1

    case "$transform" in
        CC|cc)
            i=$((i-1))
            eval "echo \$$i"
            ;;
        C|c)
            i=$((i+1))
            eval "echo \$$i"
            ;;
        *)
            echo $transform
            ;;
    esac
}
rotateMonitor(){
    set_target
    rotation=$(getRotation)

    if [ -z "$1" ]; then
        echo "$rotation"
        return
    fi
    newRotation=$(getTransformRotation "$rotation" "$1")
    xrandr $DRYRUN --output "$TARGET" --rotate "$newRotation"

}
rotateTouchscreens() {
    rotation=$(getRotation)

    case "$rotation" in
       normal)
         matrix="1 0 0 0 1 0 0 0 1"
         ;;
       inverted)
         matrix="-1 0 1 0 -1 1 0 0 1"
         ;;
       left)
         matrix="0 -1 1 1 0 0 0 0 1"
         ;;
       right)
         matrix="0 1 0 -1 0 1 0 0 1"
         ;;
    esac
    # list ids -> id, name tuple -> filer for touch devices -> extra just the id -> perform transformation
    xinput --list --id-only | while read -r id; do printf "%s %s\n" "$id" "$(xinput --list --name-only "$id")"; done | grep -i touch | cut -d" " -f 1 | while read -r id; do xinput set-prop "$id" "Coordinate Transformation Matrix" $matrix 2>/dev/null; done  || true
}
rotateAll() {
    rotateMonitor "$@"
    rotateTouchscreens
}
splitMonitor(){
    if [ "$#" -eq 0 ]; then
        # shellcheck disable=SC2046
        set -- $(getListOfOutputs | sed "s/.*/& W\n& H/g" |$DMENU)
        TARGET=$1
        shift
        # format: H or W, [, num [, slice-dim]
    else
        set_target
    fi
    [ -z "$NAME" ] && NAME="split_$TARGET"

    if [ "$1" = 'H' ] || [ "$1" = 'W' ];then
        replace=1
    else
        replace=0
    fi
    [ "$1" = 'H' ] && index=1 || index=0
    [ -z "$2" ] && num=2 || num=$2

    getOutputDims "$TARGET" | {
        read -r x y w h mx my

        check "$x" "could not get output dimensions; aborting"

        [ "$index" -eq 0 ] && dim=w || dim=h

        eval "S=\$$dim";
        if [ -z "$3" ]; then
            # shellcheck disable=SC2004
            eval "$dim=$(($dim/num))"
        else
            # shellcheck disable=SC2004
            eval "$dim=$(($dim*$3/100))"
        fi
        # shellcheck disable=SC2004
        step=$(((S-$dim*num)/(num-1)+$dim))
        for i in $(seq 0 $((num-1))); do
            [ "$i" -eq 0 ] && [ "$replace" -eq 1 ] && monitorTarget=$TARGET || monitorTarget="none"
            createMonitor "$NAME-$i" "$x" "$y" "$w" "$h" "$mx" "$my" "$monitorTarget"
            [ "$index" -eq 0 ] && x=$((x+step)) || y=$((y+step))
        done
    }
}

TARGET=
NAME=
DMENU="dmenu"
DRYRUN=
OUTPUTS=
while true; do
    case "$1" in
        --dmenu)
            DMENU="$2"
            shift
            ;;
        --target|-t)
            TARGET=$2
            shift
            ;;
        --auto|-a)
            DMENU="head -n1"
            ;;
        --interactive|-i) # legacy option
            ;;
       --name)
            NAME=$2
            shift
            ;;
       --num)
            NUM=$2
            shift
            ;;
       --debug)
            set -x
            ;;
        --outputs)
            OUTPUTS=$2
            shift
            ;;
        --dryrun | --dry-run)
            DRYRUN="--dryrun"
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
if [ -z "$1" ]; then
    action="configureOutputs"
else
    case "$1" in
        add-monitor)
            action="addMonitor"
            ;;
        clear)
            action="clearFakeMonitors"
            ;;
        configure)
            action="configureOutputs"
            ;;
        dup)
            action="dup"
            ;;
        get-monitor-dims)
            action="getMonitorDims"
            ;;
        get-rotation)
            action="getRotation"
            ;;
        list)
            action="getListOfOutputs"
            ;;
        pip)
            action="pip"
            ;;
        res*)
            action="resolution"
            ;;
        rotate)
            action="rotateAll"
            ;;
        rotate-monitor)
            action="rotateMonitor"
            ;;
        rotate-touchscreen)
            action="rotateTouchscreens"
            ;;
        set-primary)
            action="setPrimary"
            ;;
        split-monitor)
            action="splitMonitor"
            ;;
        get-right-most|get-left-most|get-top-most|get-bottom-most)
            action="getEdgeMonitor $1";
            ;;
        *)
            echo "Unknown option $1" >&2
            displayHelp
            exit 1
    esac;
fi
if [ -z "$action" ];then
    action="configureOutputs"
else
    shift
fi
$action "$@"
