#!/bin/bash

set -e
cmd="./xsane-xrandr.sh "


checkDims(){
    arr=("$1")
    for i in {2..7}; do
        if [[ "${!i}" -eq -1 || -z ${!i} ]]; then
            arr+=("\d+")
        else
            arr+=(${!i})
        fi
    done
    expr="${arr[0]} ${arr[3]}/${arr[5]}x${arr[4]}/${arr[6]}\+${arr[1]}\+${arr[2]}"

    if ! xrandr --listmonitors |grep -Pq "$expr"; then
        echo Failed to find expression matching $expr
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
    name=( add1 add2 add3 add4 add5 add6 add7 add8 )
    $cmd --name ${name[0]} $action 0 0 100 100
    checkDims ${name[0]} 0 0 100 100
    $cmd --name ${name[1]} $action --right-of ${name[0]} 0 0 100 100
    checkDims ${name[1]} 100 0 100 100
    $cmd --name ${name[2]} $action --below ${name[0]} 0 0 0 0
    checkDims ${name[2]} 0 100 100 100
    $cmd --name ${name[3]} $action --above ${name[0]} 0 0 100 100
    checkDims ${name[3]} 0 -100 100 100
    $cmd --name ${name[4]} -t ${name[0]} $action --left-of 0 0 0 0
    checkDims ${name[4]} -100 0 100 100
    $cmd --name ${name[5]} -t ${name[0]} $action -10 0 10 20
    checkDims ${name[5]} 90 0 10 20
    $cmd --name ${name[6]} -t ${name[1]} $action --inside-of 10 -10 10 20
    checkDims ${name[6]} 110 90 10 20
    size=( $(xrandr -q |grep "Screen $SCREEN" |head -n1 |sed -E -n "s/.*current (\w+)\s*x\s*(\w+).*$/\1 \2/p") )
    $cmd --name ${name[7]} $action -10 -20 10 10
    checkDims ${name[7]} $((size[0]-10)) $((size[1]-20)) 10 10
    clearAll
}
configure(){
    action="configure"
    dmenu="eval (cat ;exit 1) 1>&2"
    outputs="A B C"
    [ "$( ($cmd --outputs "$outputs" -i --dmenu "$dmenu" $action ) 2>&1 | wc -l)" -eq 21 ]
    $cmd --dryrun --outputs "$outputs" --debug $action A B 2>&1 |grep -q -- "--output B --right-of A"
    clearAll
}
dup(){
    action="dup"
    dmenu="eval (cat ;exit 1) 1>&2"
    outputs="A B C"
    realOutput=$(xrandr |grep connected|cut -d" " -f1)
    [ "$($cmd --outputs "$outputs" -i --dmenu "$dmenu" $action  2>&1 | wc -l)" -eq 3 ]
    $cmd --dryrun --outputs "$outputs" -t $realOutput --debug $action A 2>&1 |grep -q -- "--output B --same-as $realOutput"
    clearAll
}
list(){
    action="list"
    outputs="A B C"
    echo $($cmd --outputs "$outputs" $action) |grep -q "$outputs"
}
pip(){
    action="pip"
    name=( pip1 pip2 pip3 pip4 pip5)
    $cmd --name ${name[0]} -a $action 0 0 100 100
    checkDims ${name[0]} 0 0 100 100
    $cmd --name ${name[1]} -t ${name[0]} $action -1 -4 10 10
    checkDims ${name[1]} 99 96 10 10
    clearAll
}
setPrimary(){
    ! xrandr |grep -q "connected primary"
    $cmd --auto set-primary
    xrandr |grep -q "connected primary"
}
splitMonitor(){
    action="split-monitor"
    name=( split1 split2 split3 split4 split5)
    dims=( $( $cmd -a get-monitor-dims) )
    $cmd -a --name ${name[0]} $action W
    checkDims ${name[0]}-0 0 0 $((dims[2]/2)) $((dims[3]))
    checkDims ${name[0]}-1 $((dims[2]/2)) 0 $((dims[2]/2)) $((dims[3]))
    $cmd -a --name ${name[1]} $action H
    checkDims ${name[1]}-0 0 0 $((dims[2])) $((dims[3]/2))
    checkDims ${name[1]}-1 0 $((dims[3]/2)) $((dims[2])) $((dims[3]/2))
    $cmd -a --name ${name[2]} $action W 4
    checkDims ${name[2]}-0 0 0 $((dims[2]/4)) $((dims[3]))
    checkDims ${name[2]}-1 $((dims[2]/4)) 0 $((dims[2]/4)) $((dims[3]))
    checkDims ${name[2]}-2 $((dims[2]/4*2)) 0 $((dims[2]/4)) $((dims[3]))
    checkDims ${name[2]}-3 $((dims[2]/4*3)) 0 $((dims[2]/4)) $((dims[3]))
    $cmd -a --name ${name[3]} $action H 2 75
    checkDims ${name[3]}-0 0 0 $((dims[2])) $((dims[3]/4*3))
    checkDims ${name[3]}-1 0 $((dims[3]/4)) $((dims[2])) $((dims[3]/4*3))
}
getMost(){
    action="add-monitor"
    name=( base left right top bottom)
    $cmd -a --name ${name[0]} $action 0 0 0 0
    $cmd --name ${name[1]} -t ${name[0]} $action --left-of 0 0 0 0
    $cmd --name ${name[2]} $action --right-of ${name[0]} 0 0 0 0
    $cmd --name ${name[3]} $action --above ${name[0]} 0 0 0 0
    $cmd --name ${name[4]} $action --below ${name[0]} 0 0 0 0
    [ "$($cmd get-left-most)" == left ]
    [ "$($cmd get-right-most)" == right ]
    [ "$($cmd get-top-most)" == top ]
    [ "$($cmd get-bottom-most)" == bottom ]
    clearAll
}
getRotation() {
    xrandr --verbose|grep -Po "$target.*\K(normal|right|left|inverted) .*\(" | cut -d" " -f1
}
rotateMonitor() {
    action="rotate"
    $cmd -a $action left
    [ left == $(getRotation) ]
    $cmd -a $action right
    [ right == $(getRotation) ]
    $cmd -a $action inverted
    [ inverted == $(getRotation) ]
    $cmd -a $action normal
    [ normal == $(getRotation) ]

    $cmd -a $action CC
    getRotation
    [ left == $(getRotation) ]
    $cmd -a $action CC
    getRotation
    [ inverted == $(getRotation) ]
    $cmd -a $action CC
    [ right == $(getRotation) ]
    $cmd -a $action CC
    [ normal == $(getRotation) ]
    $cmd -a $action C
    [ right == $(getRotation) ]
    $cmd -a $action C
    [ inverted == $(getRotation) ]
    $cmd -a $action C
    [ left == $(getRotation) ]
    $cmd -a $action C
    [ normal == $(getRotation) ]
}

TEST=$1
test(){
    if [ -z "$TEST" ] || [ "$TEST" = "$1" ]; then
        echo Testing $1
    else
        echo Skipping $1
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
