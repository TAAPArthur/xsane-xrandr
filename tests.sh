#!/bin/sh -e
cmd="./xsane-xrandr.sh "

checkDims(){
    name="$1"
    shift
    WILDCARD="[0-9]\+"
    expr="$name $3/${WILDCARD}x$4/${WILDCARD}+$1+$2"
    if ! xrandr --listmonitors |grep -q "$expr"; then
        echo "Failed to find expression matching $expr"
        xrandr --listmonitors
        return 1
    fi
}

clearAll(){
    $cmd clear
    [ "$(xrandr --listmonitors  |wc -l)" -eq 2 ]
}
addMonitor(){
    action="add-monitor"
    $cmd --name add0 $action 0 0 100 100
    checkDims add0 0 0 100 100
    $cmd --name add1 $action --right-of add0 0 0 100 100
    checkDims add1 100 0 100 100
    $cmd --name add2 $action --below add0 0 0 0 0
    checkDims add2 0 100 100 100
    $cmd --name add3 $action --above add0 0 0 100 100
    checkDims add3 0 -100 100 100
    $cmd --name add4 -t add0 $action --left-of 0 0 0 0
    checkDims add4 -100 0 100 100
    $cmd --name add5 -t add0 $action -10 0 10 20
    checkDims add5 90 0 10 20
    $cmd --name add6 -t add1 $action --inside-of 10 -10 10 20
    checkDims add6 110 90 10 20
    xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*current (\w+)\s*x\s*(\w+).*$/\1 \2/p" | {
        read -r X Y
        $cmd --name add7 $action -10 -20 10 10
        checkDims add7 $((X-10)) $((Y-20)) 10 10
    }
    clearAll
}
configure(){
    action="configure"
    dmenu="eval (cat ;exit 1) 1>&2"
    outputs="A B C"
    [ "$( ($cmd --outputs "$outputs" -i --dmenu "$dmenu" $action ) 2>&1 | wc -l)" -eq 21 ]
    $cmd --dryrun --outputs "$outputs" --debug $action A B 2>&1 |grep -q -- "--output B --right-of A"
    $cmd -a $action --mirror  >/dev/null
    $cmd -a $action --scale-mirror  >/dev/null
    clearAll
}
dup(){
    action="dup"
    dmenu="eval (cat ;exit 1) 1>&2"
    outputs="A B C"
    realOutput=$(xrandr |grep connected|cut -d" " -f1)
    [ "$($cmd --outputs "$outputs" -i --dmenu "$dmenu" $action  2>&1 | wc -l)" -eq 3 ]
    $cmd --dryrun --outputs "$outputs" -t "$realOutput" --debug $action A 2>&1 |grep -q -- "--output B --same-as $realOutput"
    clearAll
}
list(){
    action="list"
    outputs="A B C"
    ! $cmd --outputs "$outputs" $action | grep -q -v -e A -e B -e C
}
pip(){
    action="pip"
    $cmd --name pip1 -a $action 0 0 100 100
    checkDims pip1 0 0 100 100
    $cmd --name pip2 -t pip1 $action -1 -4 10 10
    checkDims pip2 99 96 10 10
    clearAll
}
setPrimary(){
    #! xrandr |grep -q "connected primary"
    $cmd --auto set-primary
    xrandr |grep -q "connected primary"
}
splitMonitor(){
    action="split-monitor"

    $cmd -a get-monitor-dims | {
        read -r _ _ W H _
        $cmd -a --name split0 $action W
        checkDims split0-0 0 0 $((W/2)) $((H))
        checkDims split0-1 $((W/2)) 0 $((W/2)) $((H))
        $cmd -a --name split1 $action H
        checkDims split1-0 0 0 $((W)) $((H/2))
        checkDims split1-1 0 $((H/2)) $((W)) $((H/2))
        $cmd -a --name split2 $action W 4
        checkDims split2-0 0 0 $((W/4)) $((H))
        checkDims split2-1 $((W/4)) 0 $((W/4)) $((H))
        checkDims split2-2 $((W*2/4)) 0 $((W/4)) $((H))
        checkDims split2-3 $((W*3/4)) 0 $((W/4)) $((H))
        $cmd -a --name split3 $action H 2 75
        checkDims split3-0 0 0 $((W)) $((H*3/4))
        checkDims split3-1 0 $((H/4)) $((W)) $((H*3/4))
    }
}
getMost(){
    action="add-monitor"
    $cmd -a --name base $action 0 0 0 0
    $cmd --name left -t base $action --left-of 0 0 0 0
    $cmd --name right $action --right-of base 0 0 0 0
    $cmd --name top $action --above base 0 0 0 0
    $cmd --name bottom $action --below base 0 0 0 0
    [ "$($cmd get-left-most)" = left ]
    [ "$($cmd get-right-most)" = right ]
    [ "$($cmd get-top-most)" = top ]
    [ "$($cmd get-bottom-most)" = bottom ]
    clearAll
}
getRotation() {
    $cmd -a get-rotation
}
rotateMonitor() {
    action="rotate"
    $cmd -a $action left
    [ left = "$(getRotation)" ]
    $cmd -a $action right
    [ right = "$(getRotation)" ]
    $cmd -a $action inverted
    [ inverted = "$(getRotation)" ]
    $cmd -a $action normal
    [ normal = "$(getRotation)" ]

    $cmd -a $action CC
    [ left = "$(getRotation)" ]
    $cmd -a $action CC
    [ inverted = "$(getRotation)" ]
    $cmd -a $action CC
    [ right = "$(getRotation)" ]
    $cmd -a $action CC
    [ normal = "$(getRotation)" ]
    $cmd -a $action C
    [ right = "$(getRotation)" ]
    $cmd -a $action C
    [ inverted = "$(getRotation)" ]
    $cmd -a $action C
    [ left = "$(getRotation)" ]
    $cmd -a $action C
    [ normal = "$(getRotation)" ]
}

TEST=$1
test(){
    if [ -z "$TEST" ] || [ "$TEST" = "$1" ]; then
        echo "Testing $1"
    else
        echo "Skipping $1"
        return
    fi
    $1
}


trap "clearAll" EXIT
clearAll
test addMonitor
test configure
test dup
test getMost
test list
test pip
test rotateMonitor
test setPrimary
test splitMonitor
echo "success"
