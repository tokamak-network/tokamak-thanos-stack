#!/usr/bin/env bash

reqenv() {
    if [ -z "${!1}" ]; then
        echo "Error: Required environment variable '$1' is undefined"
        exit 1
    fi
}

reqenv "NEW_BUCKET_NAME"

sed -i '' "s/^export TF_VAR_backend_bucket_name=.*/export TF_VAR_backend_bucket_name=${NEW_BUCKET_NAME}/" "../.envrc"

echo "Updated export TF_VAR_backend_bucket_name to ${NEW_BUCKET_NAME} in ${FILE_PATH}"
