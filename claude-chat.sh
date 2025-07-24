#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DICTATE_SCRIPT="$SCRIPT_DIR/dictate.sh"

# Default settings
VERBOSE=false
CLAUDE_FLAGS="--dangerously-skip-permissions --print --verbose --output-format stream-json"
SESSION_ID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
DARK_GRAY='\033[0;90m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

print_prompt() {
    echo -e "${YELLOW}$1${NC}" >&2
}

print_user_input() {
    echo -e "${DARK_GRAY}$1${NC}" >&2
}


# Function to process JSON events from Claude stream
process_json_event() {
    local json_line="$1"
    local event_type=$(echo "$json_line" | jq -r '.type // empty' 2>/dev/null)
    
    case "$event_type" in
        "system")
            local subtype=$(echo "$json_line" | jq -r '.subtype // empty' 2>/dev/null)
            if [[ "$subtype" == "init" ]]; then
                local session_id=$(echo "$json_line" | jq -r '.session_id // empty' 2>/dev/null)
                if [[ -n "$session_id" && "$session_id" != "null" ]]; then
                    SESSION_ID="$session_id"
                fi
            fi
            ;;
        "assistant")
            # Handle assistant messages with text and tool usage
            local text_content=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null)
            if [[ -n "$text_content" ]]; then
                if command -v glow &> /dev/null; then
                    echo "$text_content" | glow - 2>/dev/null || echo "$text_content"
                else
                    echo "$text_content"
                fi
            fi
            
            # Show tool usage
            echo "$json_line" | jq -r '.message.content[]? | 
                if .type == "tool_use" then
                    "🔧 " + .name + ":"  +
                    (if .input.file_path then " on " + .input.file_path 
                     elif .name == "Bash" and .input.command then ": " + .input.command
                     else "" end)
                else
                    empty
                end' 2>/dev/null
            
            # Handle tool usage with special processing
            local tool_name=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)
            if [[ "$tool_name" == "Write" ]]; then
                local file_path=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_use") | .input.file_path' 2>/dev/null)
                if [[ -n "$file_path" && "$file_path" != "null" ]]; then
                    # Store file path for later display after tool result
                    export LAST_WRITTEN_FILE="$file_path"
                fi
            elif [[ "$tool_name" == "Edit" ]]; then
                local old_string=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_use") | .input.old_string' 2>/dev/null)
                local new_string=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_use") | .input.new_string' 2>/dev/null)
                if [[ -n "$old_string" && "$old_string" != "null" && -n "$new_string" && "$new_string" != "null" ]]; then
                    echo "📝 Edit diff:"
                    diff -u <(echo "$old_string") <(echo "$new_string") | delta --file-style=omit --hunk-header-style=omit || true 
                fi
            fi
            ;;
        "user")
            # Handle tool results - check if it's a tool result and suppress noisy ones
            local has_tool_result=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_result") | .type' 2>/dev/null)
            if [[ "$has_tool_result" == "tool_result" ]]; then
                local is_error=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_result") | .is_error // false' 2>/dev/null)
                local content=$(echo "$json_line" | jq -r '.message.content[]? | select(.type == "tool_result") | .content // ""' 2>/dev/null)
                
                # If it's a long output (likely from search/list tools), suppress it unless it's an error
                if [[ ${#content} -gt 200 && "$is_error" != "true" ]]; then
                    # Suppress long outputs (likely from Bash/Grep/LS/Read/etc)
                    :
                elif [[ "$is_error" == "true" ]]; then
                    echo "❌ Tool error: $content"
                elif [[ -n "$content" ]]; then
                    echo "✅ $content"
                else
                    echo "✅ Tool completed successfully"
                fi
            fi
            ;;
    esac
}

# Function to get input via dictation
get_dictated_input() {
    read -r input_choice # just used for blocking
    
    local dictated_text
    dictated_text=$("$DICTATE_SCRIPT")
    if [[ -n "$dictated_text" ]]; then
        print_user_input "$dictated_text"
        echo "$dictated_text"
    else
        print_error "No text was dictated"
        return 1
    fi
}


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--verbose] [-h|--help]"
            echo "  -v, --verbose    Show raw JSON output"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

while true; do
    print_prompt "Press Enter to dictate..."
    
    user_input=$(get_dictated_input) 
    
    if [[ -z "$user_input" ]]; then
        print_error "No input provided"
        continue
    fi
     
    # Stream JSON with optional verbose output or custom processing
    flags="$CLAUDE_FLAGS"
    if [[ -n "$SESSION_ID" ]]; then
        flags="$flags --resume $SESSION_ID"
    fi
    
    claude_exit_code=0
    if [[ "$VERBOSE" == "true" ]]; then
        claude $flags "$user_input" | jq -r --unbuffered .
        claude_exit_code=${PIPESTATUS[0]}
    else
        # Use named pipe to ensure synchronous processing and avoid timing issues
        temp_pipe=$(mktemp -u)
        mkfifo "$temp_pipe"
        
        # Process the output in a controlled way
        claude $flags "$user_input" > "$temp_pipe" &
        claude_pid=$!
        
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                process_json_event "$line"
            fi
        done < "$temp_pipe"
        
        wait $claude_pid
        claude_exit_code=$?
        
        # Clean up
        rm -f "$temp_pipe"
    fi
    
    if [[ $claude_exit_code -ne 0 ]]; then
        print_error "Failed to get response from Claude"
    fi
    
    echo
    echo "----------------------------------------"
    echo
done
