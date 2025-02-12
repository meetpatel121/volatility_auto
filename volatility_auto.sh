#!/bin/bash

# Enable history navigation with Up/Down arrows
HISTORY_FILE="plugin_history.txt"
touch "$HISTORY_FILE"

echo "[+] Enter memory dump file name with Extension:"
while true; do
    read -r memory_file
    file_path=$(find /root/ /home/ /tmp/ -type f -name "*$memory_file*" 2>/dev/null | head -n 1)
    [[ -n "$file_path" ]] && break
    echo "[-] File not found! Please enter the correct name."
done

echo "[+] File found: $file_path"

# Extract Volatility profile
profiles=$(python2 vol.py -f "$file_path" imageinfo | grep -oP 'Suggested Profile\(s\) : \K[^,]+')
IFS=',' read -ra profile_list <<< "$profiles"

if [[ ${#profile_list[@]} -gt 1 ]]; then
    echo "[+] Multiple profiles detected:"
    select profile in "${profile_list[@]}"; do
        [[ -n "$profile" ]] && break
    done
else
    profile="${profile_list[0]}"
fi

echo "[+] Selected Profile: $profile"

# Bind history file to support arrow keys like a Linux terminal
export HISTFILE="$HISTORY_FILE"
export HISTSIZE=1000
export HISTFILESIZE=1000
shopt -s histappend
history -r  # Load history into memory

while true; do
    echo "[+] Memory File: $file_path"
    echo "[+] Profile: $profile"
    echo "[+] Type 'exit' to quit or 'clear' to clean the terminal."

    # Read input with history navigation
    read -e -p "Enter plugin or optional filter (or 'exit'/'clear'): " input

    # Handle special commands
    if [[ "$input" == "exit" ]]; then
        break
    elif [[ "$input" == "clear" || "$input" == "clean" ]]; then
        clear
        continue  # Go back to prompt after clearing
    fi

    # Store the full input into history (both plugin name and optional filter)
    if [[ -n "$input" && "$(tail -n 1 $HISTORY_FILE 2>/dev/null)" != "$input" ]]; then
        echo "$input" >> "$HISTORY_FILE"
        history -s "$input"  # Append the full input to session history
    fi

    # Check if the input includes a pipe (|), indicating the use of grep or egrep
    if [[ "$input" =~ \| ]]; then
        # Split the input at the pipe, and execute the Volatility command followed by the filter
        plugin=$(echo "$input" | awk -F'|' '{print $1}' | xargs)
        filter_type=$(echo "$input" | awk -F'|' '{print $2}' | awk '{print $1}' | xargs)
        filter=$(echo "$input" | awk -F'|' '{print $2}' | awk '{$1=""; print $0}' | xargs)

        # Check if the filter type is valid (grep or egrep)
        if [[ "$filter_type" == "grep" || "$filter_type" == "egrep" ]]; then
            filter_cmd="$filter_type"
        else
            filter_cmd="grep"  # Default to grep if invalid filter is entered
        fi

        # Execute the Volatility command and pipe to the filter (grep or egrep)
        python2 vol.py -f "$file_path" --profile="$profile" "$plugin" | $filter_cmd "$filter"
    else
        # Run the Volatility command without filtering if no pipe is present
        python2 vol.py -f "$file_path" --profile="$profile" $input
    fi
done

echo "[+] Exiting..."
