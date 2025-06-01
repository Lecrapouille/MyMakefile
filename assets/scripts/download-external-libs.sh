#!/bin/bash -e
###############################################################################
### This script is called by (make download-external-libs). It will git clone
### third party libraries needed for this project but does not compile them.
### It replaces git submodules.
###############################################################################
###
### Input of this script:
### $1: target (your application name)
### $2: manifest file containing list of repositories to clone
###     Format: one repository per line: user/repo[@ref]
###     Example:
###     angeluriot/Dimension3D@84b20021f08aa89755fae83c39fc59a815f54033
###     angeluriot/ImGui-built@ad91c26d28d5a73f4fc1adf9b9930db2b296b2a1
###############################################################################

readonly GITHUB_URL="https://github.com"

function fatal()
{
    echo -e "\033[35mFailure! $1\033[00m"
    exit 1
}

function clone_repo()
{
    local repo=$1
    shift
    local clone_args=("$@")

    # Parse repository and reference
    local repo_name=${repo%@*}
    local ref=${repo#*@}

    # If no reference specified, use default branch
    if [ "$repo_name" = "$repo" ]; then
        ref=""
    fi

    echo -e "\033[35m*** Cloning: \033[36m$GITHUB_URL/$repo_name\033[00m => \033[33m$PROJECT_NAME\033[00m"
    if [ -n "$ref" ]; then
        echo -e "\033[35m*** Using reference: \033[36m$ref\033[00m"
    fi

    # Extract repo name for directory
    local dir_name=${repo_name##*/}
    rm -rf "$dir_name"

    # Clone with specified reference if provided
    if [ -n "$ref" ]; then
        # Check if ref is a SHA1 (40 characters hex)
        if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
            # For SHA1, use partial clone and create a branch
            git clone --filter=blob:none "$GITHUB_URL/$repo_name" "${clone_args[@]}" > /dev/null
            (cd "$dir_name" && \
             git fetch origin "$ref" > /dev/null && \
             git checkout -b "sha1-$ref" "$ref" > /dev/null)
        else
            # For branches and tags, clone with specific reference
            git clone "$GITHUB_URL/$repo_name" --branch "$ref" "${clone_args[@]}" > /dev/null || \
            git clone "$GITHUB_URL/$repo_name" "${clone_args[@]}" > /dev/null && \
            (cd "$dir_name" && git checkout "$ref" > /dev/null)
        fi
    else
        # For default branch, use shallow clone
        git clone "$GITHUB_URL/$repo_name" --depth=1 "${clone_args[@]}" > /dev/null
    fi
}

# Main script
PROJECT_NAME=$1
MANIFEST_FILE=$2

if [ -z "$PROJECT_NAME" ]; then
    fatal "Project name is required"
fi

if [ -z "$MANIFEST_FILE" ]; then
    fatal "Manifest file is required"
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    fatal "Manifest file '$MANIFEST_FILE' not found"
fi

# Read and process each line from the manifest file
while IFS= read -r repo || [ -n "$repo" ]; do
    # Skip empty lines and comments
    [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue

    # Remove any leading/trailing whitespace
    repo=$(echo "$repo" | xargs)

    # Skip lines starting with 'cloning' (for backward compatibility)
    [[ "$repo" =~ ^cloning[[:space:]] ]] && repo=${repo#cloning }

    if [ -n "$repo" ]; then
        clone_repo "$repo"
    fi
done < "$MANIFEST_FILE"
