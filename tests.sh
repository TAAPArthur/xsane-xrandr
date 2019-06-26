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
    name=( add1 add2 add3 add4 add5)
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
    clearAll
}
configure(){
    action="configure"
    dmenu="eval (cat ;exit 1) 1>&2"
    outputs="A B C"
    [ "$(($cmd --outputs "$outputs" -i --dmenu "$dmenu" $action ) 2>&1 | wc -l)" -eq 21 ]
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
other(){
    $cmd refresh
}
pip(){
    action="pip"
    name=( pip1 pip2 pip3 pip4 pip5)
    $cmd --name ${name[0]} $action 0 0 100 100 
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
test(){
    echo Testing $1
    $1
}
test addMonitor
test configure
test dup
test list
test pip
test other
test setPrimary
test splitMonitor
echo "success"
