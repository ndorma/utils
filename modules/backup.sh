#! /usr/bin/env bash

_backup() {
    __check-dependencies && __check-variables

    if [ ! -d "$NDU_BACKUP_DIR" ]; then
        mkdir -p "$NDU_BACKUP_DIR"
    fi

    echo "Backing up bucket [${NDU_BACKUP_BUCKET}] to [${NDU_BACKUP_DIR}] using profile [${NDU_BACKUP_PROFILE}]..."

    start_data=$(__collect-size)

    __do_backup "${NDU_BACKUP_BUCKET}" "${NDU_BACKUP_DIR}"

    end_data=$(__collect-size)

    # shellcheck disable=SC2086
    __data2json $start_data $end_data | __do_notify
    # __data2json "$start_date" "$start_size" "$start_nfiles" "$end_date" "$end_size" "$end_nfiles" | __do_notify
}

__backup-notify-test() {
    start_data=$(__collect-size)
    sleep 1
    end_data=$(__collect-size)

    # shellcheck disable=SC2086
    __data2json $start_data $end_data | __do_notify
}

_backup-check-config() {
    __check-dependencies && __check-variables

    echo "All dependencies are installed and variables are set."

    response=$(__backup-notify-test)
    if [ "$(echo "$response" | jq .error)" == true ]; then
        echo "Backup notify test failed:"
        echo "$response" | jq -r ".errors | join(\"\\n\")"
        exit 1
    fi

    echo "Backup notify test passed:"
    echo "$response" | jq -r ".messages | join(\"\\n\")"
}

__check-dependencies() {
    if ! command -v aws &>/dev/null; then
        echo "aws is not installed."
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "jq is not installed."
        exit 1
    fi
}

__check-variables() {
    if [ -z "$NDU_BACKUP_BUCKET" ]; then
        echo "NDU_BACKUP_BUCKET is not set."
        exit 1
    fi

    if [ -z "$NDU_BACKUP_DIR" ]; then
        echo "NDU_BACKUP_DIR is not set."
        exit 1
    fi

    if [ -z "$NDU_BACKUP_PROFILE" ]; then
        echo "NDU_BACKUP_PROFILE is not set."
        exit 1
    fi

    if [ -z "$NDU_BACKUP_NOTIFY_API_URL" ]; then
        echo "NDU_BACKUP_NOTIFY_API_URL is not set."
        exit 1
    fi

    if [ -z "$NDU_BACKUP_NOTIFY_API_TOKEN" ]; then
        echo "NDU_BACKUP_NOTIFY_API_TOKEN is not set."
        exit 1
    fi
}

__collect-size() {
    size=$(du -s "${NDU_BACKUP_DIR}" | cut -f1)
    nfiles=$(find "${NDU_BACKUP_DIR}" -type f | wc -l)
    date=$(date +"%Y-%m-%dT%H:%M:%S")

    echo "$date $size $nfiles"
}

__data2json() {
    jq -n \
        --arg start_time "$1" \
        --arg start_size "$2" \
        --arg start_nfiles "$3" \
        --arg end_time "$4" \
        --arg end_size "$5" \
        --arg end_nfiles "$6" \
        --arg bucket "$NDU_BACKUP_BUCKET" \
        --arg dir "$NDU_BACKUP_DIR" \
        --arg hostname "$HOSTNAME" \
        '
            {
                start: {
                    time: $start_time,
                    size: $start_size,
                    nfiles: $start_nfiles,
                },
                end: {
                    time: $end_time,
                    size: $end_size,
                    nfiles: $end_nfiles,
                },
                bucket: $bucket,
                dir: $dir,
                hostname: $hostname
            }
        '
}

__do_notify() {
    data=$(cat)

    if [ -z "$data" ]; then
        echo "Data is empty."
        exit 1
    fi

    curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${NDU_BACKUP_NOTIFY_API_TOKEN}" -d "$data" "https://$NDU_BACKUP_NOTIFY_API_URL"
}

__do_backup() {
    if [ -z "$NDU_BACKUP_PROFILE" ]; then
        echo "NDU_BACKUP_PROFILE is not set."
        exit 1
    fi

    aws --profile "${NDU_BACKUP_PROFILE}" s3 cp --recursive s3://"${1}"/ "${2}"
}
