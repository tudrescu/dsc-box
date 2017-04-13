#!/usr/bin/env bash

#
# Helper script to package a base box
#

DEFAULT_SERVER="persehone.example.com"
DEFAULT_PORT="4300"

DEFAULT_BOX_NAME="elk"

DEFAULT_OUTPUT="/media/data/exported-vm-boxes"

METADATA_FILE="metadata.json"

function show_help() {
cat << EOF

Usage ${0##*/} [-h] [-o OUTPUT_PATH ] [-b BOX_NAME] [-v BOX_VERSION]

    -h                     display this help and exit.

    -o OUTPUT_PATH         where to save the box, default $DEFAULT_OUTPUT

    -b BOX_NAME            box name, default $DEFAULT_BOX_NAME

    -v BOX_VERSION         box version

EOF
}

##############################################################
# Main
# ------------------------------------------------------------

OUTPUT_PATH="${DEFAULT_OUTPUT}"
BOX_NAME="${DEFAULT_BOX_NAME}"
BOX_VERSION=

OPTIND=1                                # Reset is necessary if getopts was used previously in the script.
while getopts ":ho:b:v:" opt; do
  case "$opt" in
      h)
            show_help >&2
            exit 0
            ;;
      o)
            unset OUTPUT_PATH
            OUTPUT_PATH=$OPTARG
            printf "output = ${OUTPUT_PATH}\n"
            ;;
      b)
            unset BOX_NAME
            BOX_NAME=$OPTARG
            printf "Box name = ${BOX_NAME}\n"
            ;;
      v)
            unset BOX_VERSION
            BOX_VERSION=$OPTARG
            printf "Box version = ${BOX_VERSION}\n"
            ;;
      *)
            printf -- "\nError : Unknown parameter supplied! Available parameters : \n\n"
            show_help >&2
            exit 1
            ;;
  esac
done

if [[ "$OPTIND" -eq 1 ]]; then
  show_help >&2
  exit 0
fi

shift "$((OPTIND-1))"                   # Shift off the options and optional --.

if [ -z "${BOX_VERSION}" ]; then
    printf -- "\nERROR: You have to specify a Box Version!\n"
    exit 0
fi

EXPORT_PATH="${OUTPUT_PATH}/${BOX_NAME}_${BOX_VERSION}.box"

printf "**************** Compute VM id ****************\n"

# extract VM ID from virtualbox
VM_ID=$(echo `vboxmanage list runningvms` | cut -d " " -f1 | sed 's/\"//g')
echo "VM id = ${VM_ID}"

printf "**************** Package Box ****************\n"

vagrant package --base "${VM_ID}" --output "${EXPORT_PATH}"

printf "**************** Compute SHA1 ****************\n"

SHA1_STR=`openssl sha1 "${EXPORT_PATH}"`
echo "$SHA1_STR"
SHA1_CODE=$( echo "$SHA1_STR" | cut -d "=" -f2 | tr -d '[:space:]' )


printf "**************** Box metadata ****************\n"


BOX_METADATA="{ version:\"$BOX_VERSION\",
   providers:[{
     name: \"virtualbox\",
     url: \"http://${DEFAULT_SERVER}:${DEFAULT_PORT}/vagrant/${BOX_NAME}/boxes/${BOX_NAME}_${BOX_VERSION}.box\",
     checksum_type: \"sha1\",
     checksum: \"$SHA1_CODE\"}]
}"

# jq -n "${BOX_METADATA}"

# append to metadata.json
tmpf=$(mktemp)

check=`cat "${OUTPUT_PATH}/${METADATA_FILE}" | jq ".versions[] | select(.version==\"$BOX_VERSION\")"`

if [[ -z "$check" ]]; then

   printf "\nUpdated ${OUTPUT_PATH}/${METADATA_FILE} :\n\n"
   cat "${OUTPUT_PATH}/${METADATA_FILE}" | jq ".versions = .versions + [${BOX_METADATA}]" > "$tmpf" && mv "$tmpf" "${OUTPUT_PATH}/${METADATA_FILE}"
   cat "${OUTPUT_PATH}/${METADATA_FILE}" | jq .

else
  printf "WARNING: Version $BOX_VERSION already added!\n"
fi

printf "\n"

read -p "Proceed with ${BOX_NAME}_${BOX_VERSION}.box release process [Y/n]?" -n 1
printf "\n"
if [[ $REPLY =~ ^[Nn]$ ]]; then
    printf "Finished\n"
    exit 0
fi

printf "**************** Release box ****************\n"

scp ${OUTPUT_PATH}/${BOX_NAME}_${BOX_VERSION}.box persephone:/var/www/vagrant/${BOX_NAME}/boxes
scp ${OUTPUT_PATH}/${METADATA_FILE} persephone:/var/www/vagrant/${BOX_NAME}/${METADATA_FILE}

printf "Finished\n"
