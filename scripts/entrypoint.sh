#!/bin/ash

# Reference: https://linux.die.net/man/1/ash
# -e (errexit): If not interactive, exit immediately if any untested command fails. The exit status of a command is
#               considered to be explicitly tested if the command is used to control an if, elif, while, or until; or
#               if the command is the left hand operand of an ''&&'' or ''||'' operator.
# -u (nounset): Write a message to standard error when attempting to expand a variable that is not set, and if the
#               shell is not interactive, exit immediately. (UNIMPLEMENTED for 4.4alpha)
set -eu

# GitHub token goes from the environment into the credential helper.
if [ "x${GIT_TOKEN:-notoken}" = "xnotoken" ]; then
    echo "Git token not provided."
    exit 1
fi

git config --global credential.helper store \
    && echo "https://URL:$GIT_TOKEN@github.com/" > "$HOME/.git-credentials" ##TODO

# Start the tests!
static-magefile
