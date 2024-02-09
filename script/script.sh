#!/bin/bash
export EXCEPTION_LAST=""

# Verify api key is set
if [[ "$LINODE_API_KEY" == "YourKey" ]]; then
    echo "Please set the LINODE_API_KEY environment variable"
    exit 1
fi

# Source the functions file
source functions.sh

headers="Authorization: Bearer $LINODE_API_KEY"
domainIds=$LINODE_DOMAIN_IDS
exclude=$LINODE_EXCLUDE_DOMAINS # replace with your excluded domains

# Trap the SIGTERM signal
trap 'terminate_script' SIGTERM

log "INFO" "Starting script.sh"

# Keep the script running for docker
while true; do
    try
    (
        # Query ipinfo.io for our public IP
        ipinfo=$(curl -s "http://ipinfo.io/json")
        if [[ $? -ne 0 ]]; then
            log "FATAL" "http://ipinfo.io/json - failed"
            throw 1
        fi
        
        # Parse the IP from the response
        publicIP=$(echo "$ipinfo" | jq -r '.ip')
        if [[ $? -ne 0 ]]; then
            log "FATAL" "$ipinfo was malformed"
            throw 2
        fi
        
        # Read last public IP
        lastPublicIP=$(cat /tmp/lastPublicIP 2>/dev/null)
        if [[ "$lastPublicIP" == "$publicIP" ]]; then
            log "INFO" "Public IP has not changed"
            throw 0 # Skip the rest of the loop
        fi

        # Save the new public IP
        echo "$publicIP" > /tmp/lastPublicIP
        log "INFO" "Public IP has changed from $lastPublicIP to $publicIP"

        # Loop through the domainIds
        for domainId in $domainIds; do
            log "VERBOSE" "Checking domainId: $domainId"
            # Get list of DNS's using get_domain_records_list
            domainJson=$(get_domain_records_list $domainId "$headers")
            if [[ $? -ne 0 ]]; then
                log "FATAL" "Failed to get domain list"
                throw 3
            fi
            
            # Parse the domain list
            domainList=$(echo $domainJson | jq -c '.data[]')
            
            log "VERBOSE" "Domain list: $domainList"
            
            # Loop through the domain list, excluding the ones from the exclude list
            for record in $domainList; do
                log "VERBOSE" "Checking record: $record"
                name=$(echo "$record" | jq -r '.name')
                type=$(echo "$record" | jq -r '.type')
                target=$(echo "$record" | jq -r '.target')
                
                log "DEBUG" "Checking '$name', Type: '$type', Target: '$target'"
                if [[ " ${exclude[@]} " =~ " ${name} " ]]; then
                    log "DEBUG" "Skipping '$name': Excluded domain"
                    continue
                fi
                
                if [[ "$type" != "A" ]]; then
                    log "DEBUG" "Skipping '$name': Not an 'A' record"
                    continue
                fi
                
                if [[ "$target" == "$publicIP" ]]; then
                    log "DEBUG" "Skipping '$name': Target already set to $publicIP"
                    continue
                fi
                
                log "INFO" "Updating '$name' from '$target' to '$publicIP'"
                
                # Update the target property with the new public IP
                updateObject=$(echo "$record" | jq --arg publicIP "$publicIP" '.target = $publicIP')
                log "VERBOSE" "Update object: $updateObject"
                
                # Update the domain record with the new public IP
                result=$(update_domain_record $domainId "$updateObject" "$headers")
                if [[ $? -eq 0 ]]; then
                    log "INFO" "Update successful for record $(echo "$record" | jq -r '.id')"
                else
                    log "ERROR" "Update failed for record $(echo "$record" | jq -r '.id')"
                fi
            done
        done
    )
    catch || {
        if [[ $ex_code -gt 0 ]]; then
            log "ERROR" "An error occurred in main loop: $ex_code"
        fi
    }

    # Sleep for a bit
    log "INFO" "Sleeping for $CHECK_INTERVAL seconds"
    # Sleep async, so we can catch the SIGTERM signal
    sleep $CHECK_INTERVAL &
    wait $!
done
