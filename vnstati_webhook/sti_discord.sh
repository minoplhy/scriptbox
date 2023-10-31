#!/bin/bash

while getopts 'w:s:d:g:h:i:t' flag
do
    case "${flag}" in
        w) webhook_url=${OPTARG};;   # Discord Webhook URL
        s) summary_types=${OPTARG};; # only support summary, hsummary, vsummary
        d) days_limit=${OPTARG};;    # Days limit in numbers
        g) graph_styles=${OPTARG};;  # Graph Styles '0, 1, 2, 3'
        h) header_text=${OPTARG};;   # Header text for graph, optional
        i) image_scale=${OPTARG};;   # Image Scale, in percentage
        t) image_Transparent="True";;  # Enable Image Transparent
    esac
done

PARAMS=()

if [ ! -n "${webhook_url}" ]; then
    echo "Fatal : no webhook_url (-w) suppiled"
    exit 1
fi
if [ ! -n "${graph_styles}" ]; then
    graph_styles=0
    PARAMS+=("--style $graph_styles")
fi

if [ -n "${summary_types}" ]; then
    PARAMS+=("--$summary_types")
fi

if [ -n "${days_limit}" ]; then
    PARAMS+=("--days $days_limit")
fi

if [ -n "${header_text}" ]; then
    PARAMS+=("--headertext '$header_text'")
fi

if [ -n "${image_scale}" ]; then
    PARAMS+=("--scale $image_scale")
fi

if [ "$image_Transparent" == "True" ]; then
    PARAMS+=("--transparent")
fi

MAKE_DIR=$(mktemp -d)
DATETIME=$(date +"%Y-%m-%d")
/usr/bin/vnstati -o $MAKE_DIR/output.png ${PARAMS[@]}
curl \
  -F 'payload_json={"content": "'$DATETIME'"}' \
  -F "file1=@$MAKE_DIR/output.png" \
  $webhook_url
rm -rf $MAKE_DIR