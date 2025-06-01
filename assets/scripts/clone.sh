#!/bin/bash -e
###############################################################################
### This script wraps git clone to avoid arguments to be passed.
###############################################################################

readonly GITHUB_URL="https://github.com"

# Parse command line arguments
PROJECT_NAME=$1
REPO=$2
DEST_PATH=$3
shift 3

function fatal()
{
    echo -e "\033[35mFailure! $1\033[00m"
    exit 1
}

CLONE_ARGS=("$@")

# Check if repository should be cloned recursively
RECURSIVE=false
if [[ "$REPO" == *":recurse"* ]]; then
    RECURSIVE=true
    REPO=${repo/:recurse/}
fi

# Parse repository and reference
REPO_NAME=${REPO%@*}
REF=${REPO#*@}

# If no reference specified, use default branch
if [ "$REPO_NAME" = "$REPO" ]; then
    REF=""
fi

echo -e "\033[35m*** Cloning: \033[36m$GITHUB_URL/$REPO_NAME\033[00m => \033[33m$PROJECT_NAME\033[00m"
if [ -n "$REF" ]; then
    echo -e "\033[35m*** Using reference: \033[36m$REF\033[00m"
fi
if [ "$RECURSIVE" = true ]; then
    echo -e "\033[35m*** Cloning recursively\033[00m"
    CLONE_ARGS+=("--recursive")
fi

# Extract repo name for directory
DIR_NAME=${REPO_NAME##*/}

# Check if destination path does not exist
if [ -d "$DEST_PATH/$DIR_NAME" ]; then
    echo -e "\033[35m*** Destination path already exists: \033[36m$DEST_PATH/$DIR_NAME\033[00m"
    exit 0
fi

# Clone with specified reference if provided
if [ -n "$REF" ]; then
    # Check if ref is a SHA1 (40 characters hex)
    if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
        # For SHA1, use partial clone and create a branch
        git clone --filter=blob:none "$GITHUB_URL/$REPO_NAME" "$DEST_PATH/$DIR_NAME" "${CLONE_ARGS[@]}" > /dev/null
        (cd "$DEST_PATH/$DIR_NAME" && \
            git fetch origin "$REF" > /dev/null && \
            git checkout -b "sha1-$REF" "$REF" > /dev/null)
    else
        # For branches and tags, clone with specific reference
        git clone "$GITHUB_URL/$REPO_NAME" --branch "$REF" "$DEST_PATH/$DIR_NAME" "${CLONE_ARGS[@]}" > /dev/null || \
        git clone "$GITHUB_URL/$REPO_NAME" "$DEST_PATH/$DIR_NAME" "${CLONE_ARGS[@]}" > /dev/null && \
        (cd "$DEST_PATH/$DIR_NAME" && git checkout "$REF" > /dev/null)
    fi
else
    # For default branch, use shallow clone
    git clone "$GITHUB_URL/$REPO_NAME" --depth=1 "$DEST_PATH/$DIR_NAME" "${CLONE_ARGS[@]}" > /dev/null
fi