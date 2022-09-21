#!/bin/bash
set -o pipefail

# Create /root/.edgerc file from env variable
echo -e "${EDGERC}" > ~/.edgerc

#  Set Variables./
edgeworkersName=$1
network=$2
groupid=$3
resourceTierId=$4
hasUploaded=$5
tokenfile=$6
edgeworkersVersion=$7

echo "edgeworkersName: $edgeworkersName"
echo "network: $network"
echo "groupid: $groupid"
echo "hasUploaded: $hasUploaded"
echo "tokenfile: $tokenfile"
echo "edgeworkersVersion: $edgeworkersVersion"

echo ${edgeworkersName}
response=$(akamai edgeworkers list-ids --json edgeworkers.json --section edgeworkers --edgerc ~/.edgerc)
errorMessage=$(cat edgeworkers.json | grep "ERROR: Unable to retrieve Edgeworkers list")
if [ ! -z "$errorMessage" ]; then
  echo "Errro happened on get edgeworkers list: $errorMessage, Exit!!!"
  exit 1
fi
cat edgeworkers.json
edgeworkerList=$( cat edgeworkers.json )
rm edgeworkers.json

edgeworkersID=$(echo ${edgeworkerList} | jq --arg edgeworkersName "${edgeworkersName}" '.data[] | select(.name == $edgeworkersName) | .edgeWorkerId')
#edgeworkersgroupID=$(echo $edgeworkerList | jq --arg edgeworkersName "$edgeworkersName" '.data[] | select(.name == $edgeworkersName) | .groupId')

echo "current edgeworkersID: $edgeworkersID"

if [ -n "${WORKER_DIR}" ]; then
  GITHUB_WORKSPACE="${GITHUB_WORKSPACE}/${WORKER_DIR}"
fi

cd ${GITHUB_WORKSPACE}

tarCommand='tar -czvf ~/deploy.tgz'
# check if needed files exist
mainJSFile='main.js'
bundleFile='bundle.json'
edgekvJSFile='edgekv.js'
edgekv_tokensJSFile='edgekv_tokens.js'
utilitiesDir='utils'
if [ -f $tokenfile ]; then
  cp $tokenfile edgekv_tokens.js
fi
if [ -f $mainJSFile ] ; then 
  tarCommand=${tarCommand}" $mainJSFile"
else
  echo "Error: $mainJSFile is missing" && exit 123
fi
if [ -f $edgekvJSFile ] ; then 
  tarCommand=${tarCommand}" $edgekvJSFile"
else
  echo "Error: $edgekvJSFile is missing" && exit 123
fi
if [ -f $edgekv_tokensJSFile ] ; then 
  tarCommand=${tarCommand}" $edgekv_tokensJSFile"
else
  echo "Error: $edgekv_tokensJSFile is missing" && exit 123
fi 
if [ -f $bundleFile ] ; then 
  tarCommand=${tarCommand}" $bundleFile"
else
  echo "Error: $bundleFile is missing" && exit 123
fi 
# pack optional JS libriries if exist 
if [ -d $utilitiesDir ] ; then 
  tarCommand=${tarCommand}" $utilitiesDir"
fi
# execute tar command
eval $tarCommand
if [ "$?" -ne "0" ]
then
  echo "ERROR: tar command failed" 
  exit 1
fi


if [ -z "$edgeworkersID" ]; then
    edgeworkersgroupID=${groupid}
    # Register ID
    echo "Registering Edgeworker: '${edgeworkersName}' in group '${edgeworkersgroupID}' with resourceTierId '${resourceTierId}' ..."
    edgeworkerRegisterStdOut=$(akamai edgeworkers register \
                      --json --section edgeworkers \
                      --edgerc ~/.edgerc  \
                      --resourceTierId ${resourceTierId} \
                      ${edgeworkersgroupID} \
                      ${edgeworkersName})
    filename=$(echo "${edgeworkerRegisterStdOut##*:}")
    echo ${edgeworkerRegisterStdOut}
    edgeworkerList=$(cat $filename)
    if [[ ! ${edgeworkerList} =~ "Created new EdgeWorker Identifier" ]]; then
      echo "Registration failed!!!! See above."
      exit 1
    fi
  
    echo ${edgeworkerList}
    echo "edgeworker registered!"
    edgeworkersID=$(echo ${edgeworkerList} | jq '.data[] | .edgeWorkerId')
    edgeworkersgroupID=$(echo ${edgeworkerList} | jq '.data[] | .groupId')
fi

if [ ! -z "$edgeworkersID" -a "$hasUploaded" == "no" ]; then
  echo "Uploading Edgeworker Version ... "
  #UPLOAD edgeWorker
  uploadreponse=$(akamai edgeworkers upload \
    --edgerc ~/.edgerc \
    --section edgeworkers \
    --bundle ~/deploy.tgz \
    ${edgeworkersID})

  echo "Upload Response: ${uploadreponse}"
  #TODO: check if upload succeeded
  if [[ ! ${uploadreponse} =~ "New version uploaded" ]]; then
    echo "upload failed!!!! See Upload Response above."
    exit 1
  fi
fi

if [ -z "edgeworkersVersion" ]; then
  edgeworkersVersion=$(echo $(<$GITHUB_WORKSPACE/bundle.json) | jq '.["edgeworker-version"]' | tr -d '"')
fi
echo "Activating Edgeworker Version: ${edgeworkersVersion} on akamai ${network}..."
for akenv in $network; do
  activateStdOut=$(akamai edgeworkers activate \
          --edgerc ~/.edgerc \
          --section edgeworkers \
          ${edgeworkersID} \
          ${akenv} \
          ${edgeworkersVersion})
  echo "activateStdOut:$activateStdOut"
  if [[ ${activateStdOut} =~ "New Activation record created" ]]; then
      echo "Activation on ${akenv} has started"
  else 
      echo "Activation on ${akenv} failed. Exit!!!"
      exit 1
  fi
  sleep 60
  networkUp=$(echo $akenv | tr [a-z] [A-Z])
  echo "networkUp: $networkUp"
  checkStdOutput=$(akamai edgeworkers status ${edgeworkersID} --section edgeworkers --edgerc ~/.edgerc | grep $edgeworkersVersion | grep ${networkUp} | sed -n 1p)
  echo "checkStdOutput1: $checkStdOutput"
  stdString=$(echo $checkStdOutput | cut -d " " -f 10 | tr "'" "_")
  echo "stdString1: $stdString"
  #status command has PRESUBMIT, PENDING, IN_PROGRESS, COMPLETE status
  while [ "$stdString" == "_PRESUBMIT_" -o "$stdString" == "_PENDING_" -o "$stdString" == "_IN_PROGRESS_" ]
    do
      sleep 60
      checkStdOutput=$(akamai edgeworkers status ${edgeworkersID} --section edgeworkers --edgerc ~/.edgerc | grep $edgeworkersVersion | grep ${networkUp} | sed -n 1p)
      echo "checkStdOutput2: $checkStdOutput"
      stdString=$(echo $checkStdOutput | cut -d " " -f 10 | tr "'" "_")
      echo "stdString2: $stdString"
    done
  echo "stdString3: $stdString"
  if [ "$stdString" == "_COMPLETE_" ]; then
    echo "Activation edgeworker  ${edgeworkersID} on $akenv network completed successfully!"
    exitStatus=succeeded
  else
    echo "Activation edgeworker  ${edgeworkersID} on $akenv network got issue! Break loop!"
    exitStatus=failed
    exit 1
  fi
  if [ "exitStatus" == "failed" ]; then
    break
  fi  
done