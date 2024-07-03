#!/bin/bash

# Constants
LOG_FILE="/var/log/user_management.log"
SECURE_DIR="/var/secure"
PASSWORD_FILE="$SECURE_DIR/user_passwords.csv"

# Ensure the secure directory exists and has correct permissions
mkdir -p $SECURE_DIR
chmod 700 $SECURE_DIR
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Log function
log_action() {
    echo "$(date) - $1" | tee -a $LOG_FILE
}

# Error handling function
error_exit() {
    log_action "ERROR: $1"
    exit 1
}

# Check if a file is provided as an argument
if [ -z "$1" ]; then
    error_exit "No input file specified. Usage: $0 <input-file>"
fi

INPUT_FILE=$1

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
    error_exit "Input file $INPUT_FILE does not exist."
fi

# Process each line in the input file
while IFS=';' read -r username groups; do
    # Remove leading and trailing whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    if [ -z "$username" ]; then
        log_action "Skipping empty username line"
        continue
    fi

    # Create a personal group for the user
    if ! getent group "$username" > /dev/null 2>&1; then
        groupadd "$username"
        log_action "Created group: $username"
    else
        log_action "Group $username already exists"
    fi

    # Create the user if they don't already exist
    if ! id "$username" > /dev/null 2>&1; then
        useradd -m -g "$username" -s /bin/bash "$username"
        log_action "Created user: $username"
    else
        log_action "User $username already exists"
        continue
    fi

    # Generate a random password
    password=$(openssl rand -base64 12)

    # Set the user's password
    echo "$username:$password" | chpasswd
    log_action "Set password for user: $username"

    # Save the password securely
    echo "$username,$password" >> "$PASSWORD_FILE"

    # Add user to additional groups
    if [ -n "$groups" ]; then
        IFS=',' read -ra ADDR <<< "$groups"
        for group in "${ADDR[@]}"; do
            if ! getent group "$group" > /dev/null 2>&1; then
                groupadd "$group"
                log_action "Created group: $group"
            fi
            usermod -aG "$group" "$username"
            log_action "Added $username to group: $group"
        done
    fi

    # Set appropriate permissions for the home directory
    chmod 700 "/home/$username"
    chown "$username:$username" "/home/$username"
    log_action "Set permissions for /home/$username"

done < "$INPUT_FILE"

log_action "User creation process completed successfully."

