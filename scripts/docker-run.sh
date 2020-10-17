#!/usr/bin/env bash

# Thank you: https://github.com/anordal/shellharden/blob/master/how_to_do_things_safely_in_bash.md#how-to-begin-a-bash-script
if test "$BASH" = "" || "$BASH" -uc "a=();true \"\${a[@]}\"" 2>/dev/null; then
    # Bash 4.4, Zsh
    set -euo pipefail
else
    # Bash 4.3 and older chokes on empty arrays with set -u.
    set -eo pipefail
fi
shopt -s nullglob globstar
IFS=$'\n\t'

### Check for presence of other tools

# Azure CLI
hash az 2>/dev/null || {
    echo >&2 "I require 'az' but it's not installed: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# JQ
hash jq 2>/dev/null || {
    echo >&2 "I require 'jq' but it's not installed: https://github.com/stedolan/jq/wiki/Installation"
    exit 1
}

### Set up usage/help output
ProgName=$(basename "$0")

function usage() {
    cat << HEREDOC

    Usage: $ProgName [--help] [--interactive] [--local|--remote]

    Optional arguments:
        -h, --help          show this help message and exit
        -i, --interactive   run the container interactively, rather than following the entrypoint

    Mutually exclusive options to select Docker image:
        -l, --local         run from a local image (default behaviour)
        -r, --remote        run from the image in the Azure container registry

HEREDOC
}

### Get flags ready to parse given arguments
INTERACTIVE=0
LOCAL=0
REMOTE=0

for i in "$@"; do
    case $i in
        -h|--help)
            usage;          exit 0;;
        -i|--interactive)
            INTERACTIVE=1;  shift;;
        -l|--local)
            LOCAL=1;        shift;;
        -r|--remote)
            REMOTE=1;       shift;;
        *) # unknown option
            usage;          exit 1;;
    esac
done

if [ $LOCAL == 1 ] && [ $REMOTE == 1 ]; then
    echo "'--local' and '--remote' are mutually exclusive!"
    exit 1
fi

# $LOCAL is default behaviour
IMAGE="IMAGE/module-test:local-dev" ##TODO

if [ $REMOTE == 1 ]; then
    IMAGE="IMAGE/module-test:latest" ##TODO
    echo "Running image from Azure container registry: $IMAGE"
else
    echo "Running local image: $IMAGE"
fi

### Secrets
echo -n "Fetching GitHub PAT from Key Vault... "

##TODO
GIT_TOKEN=$(az keyvault secret show \
    --id="URL" \
    | jq -r '.value')
echo "Done."
export GIT_TOKEN

echo -n "Fetching sandbox SPN from Key Vault... "

##TODO
ARM_CLIENT_SECRET=$(az keyvault secret show \
    --id="URL" \
    | jq -r '.value')
echo "Done."
export ARM_CLIENT_SECRET

##TODO
export ARM_CLIENT_ID=''
export ARM_SUBSCRIPTION_ID=''
export ARM_TENANT_ID=''

echo -n "Exported Azure and GitHub auth values to environment. "
echo "(ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, GIT_TOKEN)."

### Build arguments list for Docker
DockerArgs=(run --env ARM_CLIENT_ID --env ARM_CLIENT_SECRET)
DockerArgs+=(--env ARM_SUBSCRIPTION_ID --env ARM_TENANT_ID --env GIT_TOKEN)

# Pass through Mage targets, if they are set
if [[ -n "${MAGE_TARGET_IT:-}" ]]; then
    DockerArgs+=(--env MAGE_TARGET_IT)
fi

if [[ -n "${MAGE_TARGET_UT:-}" ]]; then
    DockerArgs+=(--env MAGE_TARGET_UT)
fi

if [ $INTERACTIVE == 1 ]; then
    DockerArgs+=(--entrypoint /bin/sh --interactive --tty)
fi

DockerArgs+=(--rm --volume "$(pwd):/gitrepo" "$IMAGE")

### Show arguments and execute with them
echo "Running Docker with following arguments:"
echo "${DockerArgs[@]}"

docker "${DockerArgs[@]}"
