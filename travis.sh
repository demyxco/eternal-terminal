#!/bin/bash
# Demyx
# https://demyx.sh

# Get versions
DEMYX_ALPINE_VERSION=$(docker exec -t et cat /etc/os-release | grep VERSION_ID | cut -c 12- | sed 's/\r//g')
DEMYX_OPENSSH_VERSION=$(docker exec -t et ssh -V | awk -F '[,]' '{print $1}' | cut -c 9- | sed 's/\r//g')
DEMYX_ET_VERSION=$(docker exec -t et etserver --version | awk -F '[ ]' '{print $3}' | sed 's/\r//g')

# Replace versions
sed -i "s|alpine-.*.-informational|alpine-${DEMYX_ALPINE_VERSION}-informational|g" README.md
sed -i "s|openssh-.*.-informational|openssh-${DEMYX_OPENSSH_VERSION}-informational|g" README.md
sed -i "s|et-.*.-informational|et-${DEMYX_ET_VERSION}-informational|g" README.md

# Push back to GitHub
git config --global user.email "travis@travis-ci.com"
git config --global user.name "Travis CI"
git remote set-url origin https://"$DEMYX_GITHUB_TOKEN"@github.com/demyxco/"$DEMYX_REPOSITORY".git
git add .; git commit -m "Travis Build $TRAVIS_BUILD_NUMBER"; git push origin HEAD:master

# Send a PATCH request to update the description of the repository
echo "Sending PATCH request"
DEMYX_DOCKER_TOKEN="$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'"$DEMYX_USERNAME"'", "password": "'"$DEMYX_PASSWORD"'"}' "https://hub.docker.com/v2/users/login/" | jq -r .token)"
DEMYX_RESPONSE_CODE="$(curl -s --write-out "%{response_code}" --output /dev/null -H "Authorization: JWT ${DEMYX_DOCKER_TOKEN}" -X PATCH --data-urlencode full_description@"README.md" "https://hub.docker.com/v2/repositories/${DEMYX_USERNAME}/${DEMYX_REPOSITORY}/")"
echo "Received response code: $DEMYX_RESPONSE_CODE"

# Return an exit 1 code if response isn't 200
[[ "$DEMYX_RESPONSE_CODE" != 200 ]] && exit 1
