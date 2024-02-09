# Example call update_domain_record 1234 "$updateObject" "$headers"
update_domain_record() {
    # Arguments:
    # $1 - domainId
    # $2 - updateObject (json string)
    # $3 - headers (json string)
    
    domainId=$1
    updateObject=$2
    headers=$3
    
    # Extract the id from the updateObject json string
    recordId=$(echo "$updateObject" | jq -r '.id')
    
    url="https://api.linode.com/v4/domains/${domainId}/records/${recordId}"
    method="PUT"
    
    # Call the API and store the response
    response=$(curl -s -X $method -H "Content-Type: application/json" -H "$headers" -d "$updateObject" "$url")
    
    # Check if the API call was successful
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to update record Domain/Record: ${domainId}/${recordId}"
        return 1
    fi
    
    # If the API call was successful, print the response
    echo $response
}

# Example call get_domain_records_list 1234 "$headers"
get_domain_records_list() {
    # Arguments:
    # $1 - domainId
    # $2 - headers (json string)
    
    domainId=$1
    headers=$2
    
    url="https://api.linode.com/v4/domains/${domainId}/records"
    method="GET"
    
    log "VERBOSE" "Calling API: $method $url Headers: $headers"
    
    # Call the API and store the response
    result=$(curl -s -X $method -H "Content-Type: application/json" -H "$headers" "$url")

    # Check if the API call was successful
    if [[ $? -ne 0 ]]; then
        # echo "Failed to get record list for Domain: ${domainId}"
        log "ERROR" "Failed to get record list for Domain: $domainId"
    fi
    
    log "VERBOSE" "API response: $result"
    
    # Check if the API returned an error: {"errors": [{"reason": "Invalid Token"}]}
    if [ $(echo "$result" | jq 'has("errors")') == "true" ]; then
        # Get error reason
        error=$(echo "$result" | jq -r '.errors[0].reason')
        log "ERROR" "get_domain_records_list returned error object: $error"
        return 1
    else
        # If the API call was successful, print the response
        log "VERBOSE" 'get_domain_records_list returned result'
        echo $result
    fi
}

# Log function
log() {
    # Arguments:
    # $1 - level
    # $2 - message
    
    # Get log level and its integer representation for comparison
    level=$(get_log_level $1 | head -n 1)
    levelInt=$(get_log_level $1 | tail -n 1)
    envLogLevelInt=$(get_log_level $LOG_LEVEL | tail -n 1)
    message=$2
    log_file="/var/log/dns-check/dns-update-$(date +%Y%m%d).log"
    outmsg="$(date +'%Y-%m-%d %H:%M:%S.%3N %z') [$level] $message"
    
    # Check if we should write the log to file, depending on $LOG_LEVEL
    if [ $levelInt -ge $envLogLevelInt ]; then
        # Print to docker logs
        echo "$outmsg" > /proc/1/fd/1
        # Write to log file
        echo "$outmsg" >> "$log_file"
    fi
}

# Function to get log level and its integer representation
get_log_level() {
    # Arguments:
    # $1 - level
    
    # Log level to abbreviated level
    case $1 in
        "VERBOSE")
            echo "VRB"
            echo 0
        ;;
        "DEBUG")
            echo "DBG"
            echo 1
        ;;
        "INFO")
            echo "INF"
            echo 2
        ;;
        "WARN")
            echo "WRN"
            echo 3
        ;;
        "ERROR")
            echo "ERR"
            echo 4
        ;;
        "FATAL")
            echo "FTL"
            echo 5
        ;;
        *)
            echo "UNK"
            echo 6
        ;;
    esac
}

# This function is called when the script receives a SIGTERM signal.
terminate_script() {
    log "INFO" "Received SIGTERM, exiting..."
    exit 0
}

# Try/Catch functions: https://stackoverflow.com/a/25180186/1417022
function try()
{
    [[ $- = *e* ]]; SAVED_OPT_E=$?
    set +e
}

function throw()
{
    exit $1
}

function catch()
{
    export ex_code=$?
    (( $SAVED_OPT_E )) && set +e
    return $ex_code
}

function throwErrors()
{
    set -e
}

function ignoreErrors()
{
    set +e
}