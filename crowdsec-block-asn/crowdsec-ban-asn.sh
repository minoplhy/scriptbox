#!/usr/bin/env bash
SILENT=0
DELIST=false
DURATION=999d

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--silent)
        SILENT=1
        shift
        ;;
    -d|--delist)
        DELIST=true
        shift
        ;;
    *)
      break
      ;;
  esac
done

if [[ -z "$1" ]]; then
  echo "Usage: $0 [--silent] <ASN>"
  exit 1
fi

base_url="https://asn.ipinfo.app/api/text/list/AS$1"

networks=$(curl -s "${base_url}" | grep -v "^#")

if [[ $DELIST == "false" ]]; then
    echo "$networks" | while read network; do
        if [[ $SILENT -eq 0 ]]; then
            echo "Banning network $network for $DURATION..."
        fi
        cscli decisions add --range "$network" --duration "$DURATION" --warning --reason "Mass banning AS$1"
    done
else
    echo "$networks" | while read network; do
        if [[ $SILENT -eq 0 ]]; then
            echo "Deleting network $network for $DURATION..."
        fi
        cscli decisions delete --range "$network"
    done
fi



