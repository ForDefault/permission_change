#!/bin/bash
set -a

# Debug log for tracking the execution
DEBUG_LOG="/tmp/nemo_debug.log"
exec > >(tee -a "$DEBUG_LOG") 2>&1
echo "Script started at: $(date)"
echo "Arguments received: $@"

# Ensure at least one target is provided
if [[ $# -eq 0 ]]; then
    echo "No targets provided. Exiting."
    exit 1
fi

# Create a temporary list file to hold targets
DIR="$(dirname "$1")"
list_all="$DIR/list_all.txt"

# Change to the target directory
cd "$DIR" || { echo "Failed to change to directory: $DIR"; exit 1; }
echo "Now operating in directory: $(pwd)"

# Generate the target list from passed arguments
> "$list_all"
for TARGET in "$@"; do
    if [[ -e "$TARGET" ]]; then
        echo "$(basename "$TARGET")" >> "$list_all"
    else
        echo "Target does not exist: $TARGET"
    fi
done
echo "Target list generated at: $list_all"
cat "$list_all"

# Backup the list file for safety
backup_list() {
    i=1
    while [[ -f "/tmp/$i.list_all.bak" ]]; do
        i=$((i + 1))
    done
    cp "$list_all" "/tmp/$i.list_all.bak"
    echo "Backup created: /tmp/$i.list_all.bak"
}
backup_list

#### Process Targets ####

# Loop through the list file and process each target
while [[ -s "$list_all" ]]; do
    # Create and execute the processing script dynamically
    cat <<'EOF' > process_file.sh
#!/bin/bash

# Directory where the script operates
DIR="$(pwd)"
exec > >(tee -a "$DIR/logz.txt") 2>&1

# Read the first target from the list
file=$(head -n 1 "$DIR/list_all.txt")

# Remove it from the list
sed -i "1d" "$DIR/list_all.txt"

# Process the target
if [[ -d "$DIR/$file" ]]; then
    echo "Processing directory: $file"
    chmod -R +x "$DIR/$file"
    echo "Made directory executable recursively: $file"
elif [[ -f "$DIR/$file" ]]; then
    echo "Processing file: $file"
    chmod +x "$DIR/$file"
    echo "Made file executable: $file"
else
    echo "Skipping invalid target: $file"
fi

# Append the processed target to the completed list
echo "$file" >> "$DIR/list_all.completed.txt"
EOF

    # Make the script executable and run it
    chmod +x process_file.sh
    ./process_file.sh

    # Remove the temporary processing script
    rm -f process_file.sh
done

# Clean up
echo "All targets processed. Cleaning up."
rm -f "$list_all"
rm -f "list_all.completed.txt"
rm -f "logz.txt"
echo "Script completed successfully. Exiting."
