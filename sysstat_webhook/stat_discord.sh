#!/bin/bash

while getopts 'w:crdnt:f:o:' flag
do
    case "${flag}" in
        w) webhook_url=${OPTARG};;    # Discord Webhook URL
        c) CPU="True";;               # CPU
        r) RAM="True";;               # RAM
        d) DISK_IO="True";;           # DISK I/O
        n) NETWORK="True";;           # Network
        t) MESSAGE_TEXT=${OPTARG};;   # Add some text to your webhook message!
        f) datafile=${OPTARG};;       # where your data belongs!
        o) SYSSTAT_OPTIONS=${OPTARG};; # Sysstat options       
    esac
done

MAKE_DIR=$(mktemp -d)
DATETIME=$(date +"%Y-%m-%d")

function cpu {
    graph_gen "-u" "cpu"
}

function ram {
    graph_gen "-r" "ram"
}

function diskIO {
    graph_gen "-b" "diskio"
}

function network {
    graph_gen "-n DEV" "network"
}

function graph_gen {
    POSTSVG=$MAKE_DIR/sysstat_"$2"_data.svg
    POSTPNG=$MAKE_DIR/sysstat_"$2"_data.png

    /usr/bin/sadf -g -O skipempty,packed -- $1 ${EXPANSION[@]} > $POSTSVG
    svg_to_png $POSTSVG $POSTPNG
    Process $POSTPNG
}

function Process {
    POSTFILE=$1
    Discord_hooks
}

function svg_to_png {
    /usr/bin/rsvg-convert $1 -o $2
}
function Discord_hooks {
    curl \
        -F 'payload_json={"content": "'$MESSAGE_TEXT'"}' \
        -F "file1=@$POSTFILE" \
    $webhook_url
}

if [ ! -n "${webhook_url}" ]; then
    echo "Fatal : no webhook_url (-w) suppiled"
    exit 1
fi

if [ "$MESSAGE_TEXT" == "" ]; then
    MESSAGE_TEXT=$DATETIME
fi

EXPANSION=()
if [ ! "$SYSSTAT_OPTIONS" == "" ]; then
    EXPANSION+=("$SYSSTAT_OPTIONS")
fi

if [ -f "$datafile" ]; then
    EXPANSION+=("$datafile")
fi

if [ "$CPU" == "True" ]; then
    cpu
fi

if [ "$RAM" == "True" ]; then
    ram
fi

if [ "$DISK_IO" == "True" ]; then
    diskIO
fi

if [ "$NETWORK" == "True" ]; then
    network
fi

rm -rf $MAKE_DIR