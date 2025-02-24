

# AbuseIPDB API Key
ABUSEIPDB_API_KEY="34dc64b3b380e6fbb41512832677aca7185df48f3c98b3d6aa70d7c4e36b74cfb5e1383ea34a0645"

# Prompt for the app DB name
read -p "Enter the app DB name: " DB_Name <&1

# Prompt for the time frame with a default value of 1 if no input is given
read -p "Enter the time frame (default is 1): " Time_Frame
Time_Frame=${Time_Frame:-1}

# Define the temporary file path
TMP_FILE="/home/master/applications/${DB_Name}/tmp/top10_ips.tmp"

# Find the log file path dynamically
LOG_FILE=$(ls /home/master/applications/${DB_Name}/logs/apache_*.cloudwaysapps.com.access.log 2>/dev/null)

# Check if the log file was found
if [ -z "$LOG_FILE" ]; then
    echo -e "\e[31mLog file not found for DB: $DB_Name\e[0m"
    exit 1
fi

# Get the server's public IP
SERVER_IP=$(curl -s ifconfig.me)

# Get the current date in the format used by Apache logs
CURRENT_DATE=$(date "+%d/%b/%Y")
CURRENT_HOUR=$(date "+%H")

# Function to convert country code to full name using REST Countries API
declare -A country_cache
convert_country_code() {
    local code=$1
    # Check cache first
    if [[ -n "${country_cache[$code]}" ]]; then
        echo "${country_cache[$code]}"
    else
        local country_name=$(curl -s "https://restcountries.com/v3.1/alpha/${code}" | jq -r '.[0].name.common')
        [ "$country_name" == "null" ] && country_name="Unknown"
        country_cache[$code]="$country_name"
        echo "$country_name"
    fi
}

# Display Top 10 IPs
echo -e "\n\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[92m     === Top 10 IPs in the Last $Time_Frame Hour(s) ===   \e[0m"
echo -e "\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo

# Yellow Headers for Top 10 IPs
echo -e "\e[93mHits     IP Address                              Hostname\e[0m"
echo -e "\e[93m-------- -------------------------------------- -----------------------------------\e[0m"

top_ips=$(grep "$CURRENT_DATE" "$LOG_FILE" | awk -v timeframe="$Time_Frame" -v hour="$CURRENT_HOUR" '
{
    split($4, time_part, ":");
    log_hour = time_part[2];
    if (log_hour >= hour - timeframe && log_hour <= hour) {
        print $1;
    }
}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | head -n 10)

# Save the top 10 IPs to the temporary file
echo "$top_ips" > "$TMP_FILE"

declare -A hostname_map

while read -r count ip; do
    # Check if IP is not empty and is valid
    if [[ -z "$ip" || ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo -e "\e[31mInvalid or empty IP found, skipping: $ip\e[0m"
        continue
    fi
    
    # Get the hostname
    hostname=$(nslookup "$ip" | grep 'name = ' | awk -F' = ' '{print $2}' | sed 's/.$//')
    [ -z "$hostname" ] && hostname="Unknown"
    hostname_map[$ip]="$hostname"
    
    # Check if the IP is the server's own IP
    if [ "$ip" == "$SERVER_IP" ]; then
        printf "%-8s %-39s %-35s \e[91m(This is the Server IP)\e[0m\n" "$count" "$ip" "$hostname"
    else
        printf "%-8s %-39s %-35s\n" "$count" "$ip" "$hostname"
    fi
done <<< "$top_ips"

# Display Detailed IP Information
echo -e "\n\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[92m        === Detailed IP Information ===      \e[0m"
echo -e "\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[91m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo

# Yellow Headers for Detailed Information
echo -e "\e[93mIP Address                              | Domain Name               | Country              | Status    \e[0m"
echo -e "\e[93m--------------------------------------- | ------------------------- | -------------------- | ----------\e[0m"

# Read IPs from the temporary file to maintain order
while read -r count ip; do
    # Check if IP is valid
    if [[ -z "$ip" || ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        continue
    fi

    abuse_info=$(curl -sG https://api.abuseipdb.com/api/v2/check \
        --data-urlencode "ipAddress=$ip" \
        -d maxAgeInDays=90 \
        -H "Key: $ABUSEIPDB_API_KEY" \
        -H "Accept: application/json")

    domain=$(echo "$abuse_info" | jq -r '.data.domain')
    country_code=$(echo "$abuse_info" | jq -r '.data.countryCode')
    status=$(echo "$abuse_info" | jq -r '.data.abuseConfidenceScore')

    [ "$domain" == "null" ] && domain="Unknown"
    [ "$country_code" == "null" ] && country_code="Unknown"
    country=$(convert_country_code "$country_code")
    [ "$status" == "null" ] && status="Unknown" || status="$([ "$status" -gt 0 ] && echo -e "\e[31;1mAbusive\e[0m" || echo -e "\e[32mSafe\e[0m")"

    printf "%-39s | %-25s | %-20s | %-10s\n" "$ip" "$domain" "$country" "$status"
done < "$TMP_FILE"

# Delete the temporary file after processing
rm -f "$TMP_FILE"

