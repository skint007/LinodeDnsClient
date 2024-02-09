#!/bin/bash
# This is an example script to check for DNS updates.
# This version is meant to be run not in a container. 
# You can setup a cron job or systemd timer to run this script.
# Make sure you grab the functions.sh file from the repo.

# Source the functions file
source functions.sh

# Configuration
headers='Authorization: Bearer YOUR_TOKEN'
domainIds="1234"
exclude=("example1" "example2") # replace with your excluded domains
lastPublicIPFile='/tmp/lastPublicIP'

# Query ipinfo.io for our public IP
ipinfo=$(curl -s "http://ipinfo.io/json")
if [[ $? -ne 0 ]]; then
    echo "http://ipinfo.io/json - failed"
    exit 1
fi

# Parse the IP from the response
publicIP=$(echo $ipinfo | jq -r '.ip')
if [[ $? -ne 0 ]]; then
    echo "$ipinfo was malformed"
    exit 1
fi

# Read last public IP
lastPublicIP=$(cat $lastPublicIPFile 2>/dev/null)
if [[ "$lastPublicIP" == "$publicIP" ]]; then
    log "INFO" "Public IP has not changed"
    throw 0 # Skip the rest of the loop
fi

# Save the new public IP
echo "$publicIP" >/tmp/lastPublicIP
log "INFO" "Public IP has changed from $lastPublicIP to $publicIP"

# Get list of DNS's using get_domain_records_list, excluding the ones from the exclude list
for domainId in $domainIds; do
    domainList=$(get_domain_records_list $domainId "$headers" | jq -c '.[]')
    for record in $domainList; do
        name=$(echo $record | jq -r '.name')
        type=$(echo $record | jq -r '.type')
        target=$(echo $record | jq -r '.target')

        if [[ " ${exclude[@]} " =~ " ${name} " ]] || [[ "$type" != "A" ]] || [[ "$target" == "$publicIP" ]]; then
            continue
        fi

        echo "Updating '$name' from '$target' to '$publicIP'"

        # Update the target property with the new public IP
        updateObject=$(echo $record | jq --arg publicIP "$publicIP" '.target = $publicIP')

        # Update the domain record with the new public IP
        result=$(update_domain_record $domainId "$updateObject" "$headers")
        if [[ $? -eq 0 ]]; then
            echo "Update successful for record $(echo $record | jq -r '.id')"
        else
            echo "Update failed for record $(echo $record | jq -r '.id')"
        fi
    done
done
