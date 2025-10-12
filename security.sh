#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Simple and smooth logging functions
log() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}>${NC} $1"
}

process() {
    echo -e "${BLUE}→${NC} $1"
}

license_info() {
    echo -e "${PURPLE}♠${NC} $1"
}

route_info() {
    echo -e "${GREEN}✓${NC} $1"
}

# Loading bar function
show_loading() {
    local text=$1
    local duration=2
    local steps=20
    local step_duration=$(echo "scale=3; $duration/$steps" | bc)
    
    printf "    ${text} ["
    for ((i=0; i<steps; i++)); do
        printf "▰"
        sleep $step_duration
    done
    printf "] Done!\n"
}

# ===============================
# AUTO SYNTAX REPAIR FUNCTIONS
# ===============================

# Function to check PHP syntax
check_php_syntax() {
    local file="$1"
    if php -l "$file" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to detect and fix common PHP syntax errors
auto_fix_php_syntax() {
    local file="$1"
    local backup_file="${file}.backup.auto.$(date +%Y%m%d_%H%M%S)"
    
    process "Scanning for syntax errors in: $(basename "$file")"
    
    # Create backup before fixing
    cp "$file" "$backup_file"
    
    # Common PHP syntax errors to fix
    local fixes_applied=0
    
    # 1. Fix missing closing parentheses and semicolons
    if grep -q "Route::get.*delete';$" "$file"; then
        sed -i "s/Route::get(.*delete';$/&)/" "$file"
        sed -i "s/delete';$/delete');/g" "$file"
        log "Fixed missing closing parenthesis"
        ((fixes_applied++))
    fi
    
    # 2. Fix missing semicolons at end of Route lines
    if grep -q "^[[:space:]]*Route::.*[^;]$" "$file"; then
        sed -i "/^[[:space:]]*Route::.*[^;]$/s/$/;/" "$file"
        log "Fixed missing semicolons in routes"
        ((fixes_applied++))
    fi
    
    # 3. Fix unclosed strings in routes
    if grep -q "'.*[^']$" "$file" || grep -q "\".*[^\"]$" "$file"; then
        sed -i "s/'\(.*[^']\)$/'\\1'/g" "$file"
        sed -i "s/\"\(.*[^\"]\)$\"/\"\\1\"/g" "$file"
        log "Fixed unclosed strings"
        ((fixes_applied++))
    fi
    
    # 4. Fix common Laravel route syntax errors
    if grep -q "Route::.*->middleware.*custom.security.*[^)]$" "$file"; then
        sed -i "s/->middleware(\\['custom.security'\\][^)]*$/->middleware(['custom.security']);/g" "$file"
        log "Fixed middleware syntax"
        ((fixes_applied++))
    fi
    
    # 5. Fix array syntax issues
    if grep -q "\\['[^]]*$" "$file"; then
        sed -i "s/\\['\\([^]]*\\)$/['\\1']/g" "$file"
        log "Fixed array syntax"
        ((fixes_applied++))
    fi
    
    # 6. Fix missing commas in arrays
    if grep -q "'.*'.*'[^,]$" "$file"; then
        sed -i "s/'\\(.*\\)''\\(.*\\)'$/''\\1'', ''\\2''/g" "$file"
        log "Fixed missing commas in arrays"
        ((fixes_applied++))
    fi
    
    # Verify if fixes worked
    if check_php_syntax "$file"; then
        log "Auto-repair successful! Fixed $fixes_applied issues in $(basename "$file")"
        return 0
    else
        warn "Auto-repair failed for $(basename "$file"), restoring backup"
        cp "$backup_file" "$file"
        return 1
    fi
}

# Function to safely modify PHP files with auto-repair
safe_php_modification() {
    local file="$1"
    local operation_desc="$2"
    
    process "$operation_desc"
    
    # Check current syntax
    if ! check_php_syntax "$file"; then
        warn "File $(basename "$file") has syntax errors before modification, attempting auto-repair..."
        if ! auto_fix_php_syntax "$file"; then
            error "Cannot proceed - $(basename "$file") has unfixable syntax errors"
        fi
    fi
    
    return 0
}

# Function to scan and repair all route files
scan_and_repair_routes() {
    echo
    route_info "Auto Syntax Repair System"
    echo "============================"
    echo
    
    PTERO_DIR="/var/www/pterodactyl"
    local repaired_count=0
    
    # Files to check
    local files_to_check=(
        "$PTERO_DIR/routes/admin.php"
        "$PTERO_DIR/routes/api-client.php"
        "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            if ! check_php_syntax "$file"; then
                warn "Syntax error detected in: $(basename "$file")"
                if auto_fix_php_syntax "$file"; then
                    log "✓ Successfully repaired: $(basename "$file")"
                    ((repaired_count++))
                else
                    error "✗ Failed to repair: $(basename "$file")"
                fi
            else
                log "✓ $(basename "$file") - No syntax errors"
            fi
        else
            warn "File not found: $(basename "$file")"
        fi
    done
    
    if [ $repaired_count -gt 0 ]; then
        log "Auto-repair completed: $repaired_count files fixed"
        
        # Clear cache after repair
        process "Clearing cache after repairs..."
        cd "$PTERO_DIR"
        sudo -u www-data php artisan config:clear
        sudo -u www-data php artisan route:clear
        sudo -u www-data php artisan cache:clear
    else
        log "No syntax errors found in route files"
    fi
    
    echo
}

# ===============================
# CORE FUNCTIONS
# ===============================

# License verification
verify_license() {
    echo
    license_info "License Verification"
    echo "======================"
    echo
    read -p "Enter license key: " license_key
    
    if [ -z "$license_key" ]; then
        error "License key cannot be empty!"
    fi
    
    # Simple license verification (kingstore)
    if [ "$license_key" != "kingstore" ]; then
        error "Invalid license key! Access denied."
    fi
    
    show_loading "Verifying license"
    log "License verified successfully!"
    echo
    license_info "Licensed to: @kingstore"
    license_info "Valid for: Custom Security Middleware"
    license_info "Type: Single Domain License"
    echo
}

show_menu() {
    clear
    cat <<'EOF'
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣦⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠄⠒⠒⠉⣩⣽⣿⣿⣿⣿⣿⠿⢿⣶⣶⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⣿⣿⣿⣿⣿⣿⣿⡷⠀⠈⠙⠻⢿⣿⣷⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⠿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠉⠻⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣤⣴⣶⣿⣿⣿⣿⣦⣄⣾⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢿⣿⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⠏⠉⢹⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣁⡀⠀⢸⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣷⠀⢸⣿⣿⡇⠻⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⣿⣿⣷⣼⣿⣿⡇⠀⠈⠻⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⡃⠙⣿⣿⣄⡀⠀⠈⠙⢷⣄⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠺⣿⣿⣿⣿⣿⣿⣿⡟⠁⠀⠘⣿⣿⣿⣷⣶⣤⣈⡟⢳⢄⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⢻⣿⣯⡉⠛⠻⢿⣿⣷⣧⡀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⡿⠹⣿⣿⣿⣷⠀⠀⠀⢀⣿⣿⣷⣄⠀⠀⠈⠙⠿⣿⣄⠀⠀⠀⢠⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⠋⠀⣀⣻⣿⣿⣿⣀⣠⣶⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠈⢹⠇⠀⠀⣾⣿⣿⣿⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣷⣿⣿⣿⣿⣿⣿⣿⣟⠛⠋⠉⠁⠀⠀⠀⠉⠻⢧⠀⠀⠀⠘⠃⠀⣼⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢢⡀⠀⠀⠀⠀⢿⣿⣿⠿⠟⠛⠉⠁⠈⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⢺⠀⠀⠀⠀⢀⣾⣿⣿⣿⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠊⠀⠀⠀⣰⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣾⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠿⣷⣤⣀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⠀⠀⠀⠀⠀⠀⣀⣤⣶⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠿⣿⣶⣦⣤⣤⣀⣀⣀⣻⣿⣀⣀⣤⣴⣶⣿⣿⣿⣿⣿⠿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⢿⣿⣯⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⡟⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
EOF

    echo
    echo "=========================================="
    echo "          SECURITY MIDDLEWARE PLUS"
    echo "    With Auto Syntax Repair System"
    echo "                 @kingstore               "
    echo "=========================================="
    echo
    echo "Menu options:"
    echo "1. Install Security Middleware"
    echo "2. Applying Routes"
    echo "3. Custom Error Message"
    echo "4. Clear Security (Uninstall)"
    echo "5. Refresh Cache VPS"
    echo "6. Delete All Routes"
    echo "7. Fix Server Status Problem"
    echo "8. Show Current Status"
    echo "9. Auto Repair Syntax Errors"
    echo "10. Exit"
    echo
}

show_license() {
    echo
    license_info "Software License Agreement"
    echo "=============================="
    echo
    echo "Product: Custom Security Middleware for Pterodactyl"
    echo "Version: 2.0"
    echo "License: kingstore"
    echo "Developer: @kingstore"
    echo
    echo "License Terms:"
    echo "• Single domain usage"
    echo "• Personal and commercial use allowed"
    echo "• Modification permitted"
    echo "• Redistribution not allowed"
    echo "• No warranty provided"
    echo
    echo "This software is protected by license key: kingstore"
    echo "Unauthorized use is prohibited."
    echo
}

# Fix Server Status Problem
fix_server_status() {
    echo
    route_info "Fix Server Status Problem"
    echo "=============================="
    echo
    warn "Problem: Server shows OFFLINE (red) but actually ONLINE"
    echo
    info "This will diagnose and fix server status issues"
    echo
    
    read -p "Proceed with diagnosis? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    PTERO_DIR="/var/www/pterodactyl"
    
    # 1. Check Wings connection
    process "Checking Wings connection..."
    if systemctl is-active --quiet wings; then
        log "✓ Wings service is running"
    else
        error "✗ Wings service is NOT running"
    fi
    
    # 2. Check Node configuration
    process "Checking node configuration..."
    NODES_JSON="$PTERO_DIR/database/seeders/nodes.json"
    if [ -f "$NODES_JSON" ]; then
        log "✓ Node configuration exists"
    else
        warn "⚠ Node configuration not found"
    fi
    
    # 3. Check SSL certificates
    process "Checking SSL configuration..."
    if openssl version &>/dev/null; then
        log "✓ OpenSSL is available"
        
        # Check if using self-signed certs
        if [ -f "/etc/ssl/certs/pterodactyl.crt" ]; then
            log "✓ Pterodactyl SSL certificate found"
        else
            warn "⚠ Using self-signed certificates (may cause issues)"
        fi
    fi
    
    # 4. Check firewall
    process "Checking firewall status..."
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            warn "⚠ UFW firewall is ACTIVE - checking ports"
            # Check essential ports
            for port in 8080 2022 3306; do
                if ufw status | grep -q "$port"; then
                    log "✓ Port $port is allowed"
                else
                    warn "⚠ Port $port might be blocked"
                fi
            done
        else
            log "✓ UFW firewall is inactive"
        fi
    fi
    
    # 5. Check wings config
    process "Checking wings configuration..."
    if [ -f "/etc/pterodactyl/config.yml" ]; then
        log "✓ Wings config file exists"
        
        # Check panel URL in wings config
        PANEL_URL=$(grep "remote:" /etc/pterodactyl/config.yml | head -1 | awk '{print $2}')
        if [ -n "$PANEL_URL" ]; then
            log "✓ Panel URL: $PANEL_URL"
            
            # Test connection to panel
            if curl -s --connect-timeout 10 "$PANEL_URL" &>/dev/null; then
                log "✓ Panel is accessible from wings"
            else
                error "✗ Panel is NOT accessible from wings!"
            fi
        fi
    else
        error "✗ Wings config file not found!"
    fi
    
    # 6. Restart services
    process "Restarting services..."
    
    # Restart wings
    systemctl restart wings
    log "✓ Wings service restarted"
    
    # Wait a bit
    sleep 3
    
    # Check wings status again
    if systemctl is-active --quiet wings; then
        log "✓ Wings is running after restart"
    else
        error "✗ Wings failed to start!"
    fi
    
    # 7. Clear panel cache
    process "Clearing panel cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan cache:clear
    log "✓ Panel cache cleared"
    
    echo
    log "Diagnosis completed!"
    echo
    info "Recommended actions:"
    echo "1. Check Wings logs: journalctl -u wings -f"
    echo "2. Verify node is online in admin panel"
    echo "3. Check SSL certificates"
    echo "4. Ensure ports 8080, 2022 are open"
    echo
    warn "If status still shows offline, check Wings configuration manually"
}

show_server_status() {
    echo
    route_info "Current Server Status"
    echo "========================"
    echo
    
    # Check wings service
    if systemctl is-active --quiet wings; then
        echo -e "${GREEN}✓${NC} Wings Service: ONLINE"
        WINGS_STATUS=$(systemctl status wings | grep "Active:" | cut -d':' -f2-)
        echo "   Status: $WINGS_STATUS"
    else
        echo -e "${RED}✗${NC} Wings Service: OFFLINE"
    fi
    
    # Check node connectivity
    process "Checking node connectivity..."
    if timeout 10 curl -s http://localhost:8080 &>/dev/null; then
        echo -e "${GREEN}✓${NC} Node API: RESPONSIVE"
    else
        echo -e "${RED}✗${NC} Node API: UNRESPONSIVE"
    fi
    
    # Check panel connectivity
    process "Checking panel connectivity..."
    if timeout 10 curl -s http://localhost &>/dev/null; then
        echo -e "${GREEN}✓${NC} Panel: ACCESSIBLE"
    else
        echo -e "${RED}✗${NC} Panel: INACCESSIBLE"
    fi
    
    echo
}

restore_default_routes() {
    echo
    route_info "Restore Default Routes"
    echo "========================"
    echo
    info "This will restore admin.php and api-client.php routes to their default state"
    echo
    warn "This will remove all custom middleware protection from routes!"
    echo
    read -p "Are you sure you want to restore default routes? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Routes restoration cancelled."
        return
    fi
    
    PTERO_DIR="/var/www/pterodactyl"
    
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
        return 1
    fi
    
    process "Restoring default routes..."
    
    # 1. Restore admin.php routes
    ADMIN_FILE="$PTERO_DIR/routes/admin.php"
    if [ -f "$ADMIN_FILE" ]; then
        process "Restoring admin.php routes to default..."
        
        # Method 1: Remove custom.security middleware with various patterns
        restored_count=0
        
        # Pattern 1: Standard middleware pattern
        if grep -q "middleware.*custom.security" "$ADMIN_FILE"; then
            sed -i "s/->middleware(\['custom.security'\])//g" "$ADMIN_FILE"
            log "✓ Removed standard custom.security middleware"
            ((restored_count++))
        fi
        
        # Pattern 2: Middleware with different quotes
        if grep -q "middleware.*custom.security" "$ADMIN_FILE"; then
            sed -i "s/->middleware(\[\"custom.security\"\])//g" "$ADMIN_FILE"
            sed -i "s/->middleware(\['custom.security'\])//g" "$ADMIN_FILE"
            log "✓ Removed custom.security middleware with different quotes"
            ((restored_count++))
        fi
        
        # Pattern 3: Middleware with spaces
        if grep -q "middleware.*custom.security" "$ADMIN_FILE"; then
            sed -i "s/->middleware( \[ 'custom.security' \] )//g" "$ADMIN_FILE"
            sed -i "s/->middleware( \['custom.security'\] )//g" "$ADMIN_FILE"
            log "✓ Removed custom.security middleware with spaces"
            ((restored_count++))
        fi
        
        # Pattern 4: Multiple middleware arrays
        if grep -q "middleware.*custom.security" "$ADMIN_FILE"; then
            # Remove from single middleware array
            sed -i "s/->middleware(\['custom.security'\])//g" "$ADMIN_FILE"
            # Remove from multiple middleware array
            sed -i "s/, 'custom.security'//g" "$ADMIN_FILE"
            sed -i "s/'custom.security', //g" "$ADMIN_FILE"
            log "✓ Removed custom.security from multiple middleware arrays"
            ((restored_count++))
        fi
        
        # Final cleanup: Remove empty middleware arrays
        sed -i "s/->middleware(\[\])//g" "$ADMIN_FILE"
        sed -i "s/->middleware(\[ \])//g" "$ADMIN_FILE"
        
        # Verify restoration
        if grep -q "custom.security" "$ADMIN_FILE"; then
            warn "⚠ Some custom.security middleware might still exist"
            process "Manual cleanup might be required"
        else
            log "✓ All custom.security middleware removed from admin.php"
        fi
        
    else
        warn "admin.php not found: $ADMIN_FILE"
    fi
    
    # 2. Restore api-client.php routes
    API_CLIENT_FILE="$PTERO_DIR/routes/api-client.php"
    if [ -f "$API_CLIENT_FILE" ]; then
        process "Restoring api-client.php routes to default..."
        
        # Remove custom.security from /files route group with various patterns
        api_restored=0
        
        # Pattern 1: Standard group pattern
        if grep -q "prefix.*files.*middleware.*custom.security" "$API_CLIENT_FILE"; then
            sed -i "s|Route::group(\['prefix' => '/files', 'middleware' => \['custom.security'\]|Route::group(['prefix' => '/files'|g" "$API_CLIENT_FILE"
            sed -i "s|Route::group(['prefix' => '/files', 'middleware' => ['custom.security']|Route::group(['prefix' => '/files'|g" "$API_CLIENT_FILE"
            log "✓ Restored /files route group to default"
            ((api_restored++))
        fi
        
        # Pattern 2: Remove individual middleware from routes
        if grep -q "->middleware.*custom.security" "$API_CLIENT_FILE"; then
            sed -i "s/->middleware(\['custom.security'\])//g" "$API_CLIENT_FILE"
            sed -i "s/->middleware(\[\"custom.security\"\])//g" "$API_CLIENT_FILE"
            log "✓ Removed individual middleware from api-client.php"
            ((api_restored++))
        fi
        
        # Cleanup empty middleware arrays
        sed -i "s/->middleware(\[\])//g" "$API_CLIENT_FILE"
        sed -i "s/->middleware(\[ \])//g" "$API_CLIENT_FILE"
        
        if [ "$api_restored" -eq 0 ]; then
            warn "No custom middleware found in api-client.php"
        else
            log "✓ api-client.php routes restored"
        fi
        
    else
        warn "api-client.php not found: $API_CLIENT_FILE"
    fi
    
    # 3. Clear cache
    process "Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan view:clear
    sudo -u www-data php artisan cache:clear
    sudo -u www-data php artisan optimize
    
    log "Cache cleared"
    
    echo
    log "Default routes restoration completed successfully!"
    echo
    info "Summary:"
    log "  • admin.php: Removed all custom.security middleware patterns"
    log "  • api-client.php: Restored route groups and removed middleware"
    log "  • All cache cleared"
    echo
    warn "Note: If routes still have issues, manual verification may be needed"
}

clear_pterodactyl_cache() {
    echo
    route_info "Clear Pterodactyl Cache"
    echo "==========================="
    echo
    info "This will clear all Pterodactyl cache and optimize the application"
    echo
    read -p "Are you sure you want to clear Pterodactyl cache? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Cache clearing cancelled."
        return
    fi
    
    PTERO_DIR="/var/www/pterodactyl"
    
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
        return 1
    fi
    
    process "Clearing Pterodactyl cache..."
    
    # Clear cache commands
    cd "$PTERO_DIR"
    
    process "Clearing config cache..."
    sudo -u www-data php artisan config:clear
    
    process "Clearing route cache..."
    sudo -u www-data php artisan route:clear
    
    process "Clearing view cache..."
    sudo -u www-data php artisan view:clear
    
    process "Clearing application cache..."
    sudo -u www-data php artisan cache:clear
    
    process "Optimizing application..."
    sudo -u www-data php artisan optimize
    
    log "✓ All cache cleared successfully!"
    echo
    log "Cache clearing completed!"
}

clear_security() {
    echo
    info "Clear Security Middleware"
    echo "========================="
    echo
    warn "Warning: This will remove security middleware and restore system to normal!"
    read -p "Are you sure you want to remove security middleware? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Removal cancelled."
        return
    fi
    
    PTERO_DIR="/var/www/pterodactyl"
    
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
    fi
    
    process "Cleaning up security middleware..."
    
    # 1. Remove middleware file
    if [ -f "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php" ]; then
        rm -f "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php"
        log "Middleware file removed"
    else
        warn "Middleware file not found"
    fi
    
    # 2. Remove from Kernel.php
    KERNEL_FILE="$PTERO_DIR/app/Http/Kernel.php"
    if [ -f "$KERNEL_FILE" ]; then
        if grep -q "custom.security" "$KERNEL_FILE"; then
            sed -i "/'custom.security' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\CustomSecurityCheck::class,/d" "$KERNEL_FILE"
            log "Middleware removed from Kernel"
        else
            warn "Middleware not registered in Kernel"
        fi
    fi
    
    # 3. Remove middleware from routes
    process "Cleaning routes..."
    
    # api-client.php
    API_CLIENT_FILE="$PTERO_DIR/routes/api-client.php"
    if [ -f "$API_CLIENT_FILE" ]; then
        if grep -q "Route::group(\['prefix' => '/files', 'middleware' => \['custom.security'\]" "$API_CLIENT_FILE"; then
            sed -i "s/Route::group(\['prefix' => '\/files', 'middleware' => \['custom.security'\]/Route::group(['prefix' => '\/files'/g" "$API_CLIENT_FILE"
            log "Middleware removed from api-client.php"
        fi
    fi
    
    # admin.php - remove middleware from all route groups
    ADMIN_FILE="$PTERO_DIR/routes/admin.php"
    if [ -f "$ADMIN_FILE" ]; then
        # Pattern 1: Remove from Route::group yang memiliki middleware array
        sed -i "s/, 'middleware' => \['custom.security'\]//g" "$ADMIN_FILE"
        
        # Pattern 2: Remove dari Route::group yang hanya memiliki middleware custom.security saja
        sed -i "s/'middleware' => \['custom.security'\], //g" "$ADMIN_FILE"
        sed -i "s/'middleware' => \['custom.security'\]//g" "$ADMIN_FILE"
        
        # Pattern 3: Remove dari individual routes
        sed -i "s/->middleware(\['custom.security'\])//g" "$ADMIN_FILE"
        
        # Pattern 4: Clean up empty middleware arrays jika ada
        sed -i "s/'middleware' => \[\],//g" "$ADMIN_FILE"
        sed -i "s/, 'middleware' => \[\]//g" "$ADMIN_FILE"
        
        log "Middleware removed from admin.php"
    fi
    
    # 4. Clear cache
    process "Clearing cache..."
    cd $PTERO_DIR
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan view:clear
    sudo -u www-data php artisan cache:clear
    sudo -u www-data php artisan optimize
    
    log "Cache cleared"
    
    # 5. Restart services
    process "Restarting services..."
    
    PHP_SERVICE=""
    if systemctl is-active --quiet php8.2-fpm; then
        PHP_SERVICE="php8.2-fpm"
    elif systemctl is-active --quiet php8.1-fpm; then
        PHP_SERVICE="php8.1-fpm"
    elif systemctl is-active --quiet php8.0-fpm; then
        PHP_SERVICE="php8.0-fpm"
    elif systemctl is-active --quiet php8.3-fpm; then
        PHP_SERVICE="php8.3-fpm"
    fi
    
    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart $PHP_SERVICE
        log "$PHP_SERVICE restarted"
    fi
    
    if systemctl is-active --quiet pteroq; then
        systemctl restart pteroq
        log "pteroq service restarted"
    fi
    
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "nginx reloaded"
    fi
    
    echo
    log "Security middleware successfully removed!"
    echo
    warn "System is now in NORMAL mode without security middleware protection"
}

# Safe version of add_custom_security_middleware with auto-repair
add_custom_security_middleware() {
    echo
    route_info "Add Custom Security Middleware"
    echo "=================================="
    echo
    info "This will add 'custom.security' middleware to specific routes in admin.php and api-client.php"
    echo
    warn "WARNING: This feature is experimental. Use Option 1 for full installation instead."
    echo
    read -p "Are you sure you want to add custom security middleware? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Custom security middleware addition cancelled."
        return
    fi
    
    PTERO_DIR="/var/www/pterodactyl"
    
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
        return 1
    fi
    
    ADMIN_FILE="$PTERO_DIR/routes/admin.php"
    API_CLIENT_FILE="$PTERO_DIR/routes/api-client.php"
    
    if [ ! -f "$ADMIN_FILE" ]; then
        error "admin.php not found: $ADMIN_FILE"
        return 1
    fi
    
    if [ ! -f "$API_CLIENT_FILE" ]; then
        error "api-client.php not found: $API_CLIENT_FILE"
        return 1
    fi
    
    # Run auto-repair before modification
    scan_and_repair_routes
    
    process "Adding custom security middleware to routes..."
    
    # Backup the files
    admin_backup="$ADMIN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    api_backup="$API_CLIENT_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ADMIN_FILE" "$admin_backup"
    cp "$API_CLIENT_FILE" "$api_backup"
    log "Backup created: $admin_backup"
    log "Backup created: $api_backup"
    
    # Counter for modified routes
    modified_count=0
    
    # 1. Admin.php routes - SAFE METHOD
    safe_php_modification "$ADMIN_FILE" "Processing admin.php routes"
    
    # 1.1 Settings group in admin.php - SAFE
    if grep -q "Route::group(\['prefix' => 'settings'\], function () {" "$ADMIN_FILE"; then
        # Use exact string replacement with proper escaping
        sed -i "s|Route::group(['prefix' => 'settings'], function () {|Route::group(['prefix' => 'settings', 'middleware' => ['custom.security']], function () {|g" "$ADMIN_FILE"
        log "✓ Added middleware to settings route group"
        modified_count=$((modified_count + 1))
    else
        warn "Settings route group not found or already modified"
    fi
    
    # 2. Api-client.php routes - SAFE METHOD
    safe_php_modification "$API_CLIENT_FILE" "Processing api-client.php routes"
    
    # 2.1 Files group in api-client.php - SAFE
    if grep -q "Route::group(\['prefix' => '/files'" "$API_CLIENT_FILE"; then
        # Use exact string replacement
        sed -i "s|Route::group(['prefix' => '/files'|Route::group(['prefix' => '/files', 'middleware' => ['custom.security']|g" "$API_CLIENT_FILE"
        log "✓ Added middleware to files route group"
        modified_count=$((modified_count + 1))
    else
        warn "Files route group not found or already modified"
    fi
    
    # 3. Verify syntax after modifications
    process "Verifying PHP syntax..."
    
    # Check admin.php syntax
    if check_php_syntax "$ADMIN_FILE"; then
        log "✓ admin.php syntax is valid"
    else
        warn "admin.php has syntax errors after modification, attempting auto-repair..."
        if auto_fix_php_syntax "$ADMIN_FILE"; then
            log "✓ admin.php auto-repaired successfully"
        else
            error "✗ admin.php has unfixable syntax errors! Restoring backup..."
            cp "$admin_backup" "$ADMIN_FILE"
            return 1
        fi
    fi
    
    # Check api-client.php syntax
    if check_php_syntax "$API_CLIENT_FILE"; then
        log "✓ api-client.php syntax is valid"
    else
        warn "api-client.php has syntax errors after modification, attempting auto-repair..."
        if auto_fix_php_syntax "$API_CLIENT_FILE"; then
            log "✓ api-client.php auto-repaired successfully"
        else
            error "✗ api-client.php has unfixable syntax errors! Restoring backup..."
            cp "$api_backup" "$API_CLIENT_FILE"
            return 1
        fi
    fi
    
    # 4. Verify modifications
    echo
    process "Verifying modifications..."
    
    admin_matches=$(grep -c "custom.security" "$ADMIN_FILE" || true)
    api_matches=$(grep -c "custom.security" "$API_CLIENT_FILE" || true)
    
    total_matches=$((admin_matches + api_matches))
    
    if [ "$total_matches" -gt 0 ]; then
        log "✓ Successfully added custom.security middleware to $total_matches locations"
        log "  - admin.php: $admin_matches locations"
        log "  - api-client.php: $api_matches locations"
    else
        warn "⚠ No custom.security middleware found after modification"
        warn "The routes might have different patterns than expected"
    fi
    
    # 5. Clear cache
    process "Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan cache:clear
    
    echo
    log "Custom security middleware added successfully!"
    echo
    info "Summary:"
    log "  • Modified admin.php: Settings route group"
    log "  • Modified api-client.php: Files route group" 
    log "  • Total modifications: $modified_count route groups"
    echo
    warn "Note: This is a minimal safe installation. Use Option 1 for full middleware installation."
}

# Safe version of apply_manual_routes with auto-repair
apply_manual_routes() {
    process "Applying middleware to routes (safe method)..."
    
    PTERO_DIR="/var/www/pterodactyl"
    API_CLIENT_FILE="$PTERO_DIR/routes/api-client.php"
    ADMIN_FILE="$PTERO_DIR/routes/admin.php"
    
    # Run auto-repair before modification
    if [ -f "$ADMIN_FILE" ] && ! check_php_syntax "$ADMIN_FILE"; then
        warn "admin.php has syntax errors before modification, attempting auto-repair..."
        auto_fix_php_syntax "$ADMIN_FILE"
    fi
    
    if [ -f "$API_CLIENT_FILE" ] && ! check_php_syntax "$API_CLIENT_FILE"; then
        warn "api-client.php has syntax errors before modification, attempting auto-repair..."
        auto_fix_php_syntax "$API_CLIENT_FILE"
    fi
    
    if [ -f "$API_CLIENT_FILE" ]; then
        process "Processing api-client.php..."
        
        if grep -q "Route::group(\['prefix' => '/files'" "$API_CLIENT_FILE"; then
            if ! grep -q "Route::group(\['prefix' => '/files', 'middleware' => \['custom.security'\]" "$API_CLIENT_FILE"; then
                # FIX: Use | as delimiter instead of / to avoid escaping issues
                sed -i "s|Route::group(['prefix' => '/files'|Route::group(['prefix' => '/files', 'middleware' => ['custom.security']|g" "$API_CLIENT_FILE"
                log "Applied to /files group in api-client.php"
                
                # Verify syntax after modification
                if ! check_php_syntax "$API_CLIENT_FILE"; then
                    warn "Syntax error detected after api-client.php modification, auto-repairing..."
                    auto_fix_php_syntax "$API_CLIENT_FILE"
                fi
            else
                warn "Already applied to /files group"
            fi
        else
            warn "/files group not found in api-client.php"
        fi
    fi

    if [ -f "$ADMIN_FILE" ]; then
        process "Processing admin.php..."

        # Safe method - only modify settings group
        if grep -q "Route::group(\['prefix' => '/settings'" "$ADMIN_FILE"; then
            if ! grep -q "Route::group(\['prefix' => '/settings', 'middleware' => \['custom.security'\]" "$ADMIN_FILE"; then
                # FIX: Use | as delimiter instead of /
                sed -i "s|Route::group(['prefix' => '/settings'|Route::group(['prefix' => '/settings', 'middleware' => ['custom.security']|g" "$ADMIN_FILE"
                log "Applied to /settings group in admin.php"
                
                # Verify syntax after modification
                if ! check_php_syntax "$ADMIN_FILE"; then
                    warn "Syntax error detected after admin.php modification, auto-repairing..."
                    auto_fix_php_syntax "$ADMIN_FILE"
                fi
            else
                warn "Already applied to /settings group"
            fi
        else
            warn "/settings group not found in admin.php"
        fi
    else
        error "Admin routes file not found: $ADMIN_FILE"
    fi
    
    log "Route protection completed safely"
}

install_middleware() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root: sudo bash <(curl -s https://raw.githubusercontent.com/iLyxxDev/hosting/main/security.sh)"
    fi

    # License verification before installation
    verify_license

    PTERO_DIR="/var/www/pterodactyl"

    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
    fi

    process "Installing Custom Security Middleware for Pterodactyl..."
    log "Pterodactyl directory: $PTERO_DIR"

    if [ ! -d "$PTERO_DIR/routes" ]; then
        error "Routes directory not found: $PTERO_DIR/routes"
    fi

    show_loading "Creating middleware file"
    cat > $PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Node;

class CustomSecurityCheck
{
    public function handle(Request $request, Closure $next)
    {
        if (!$request->user()) {
            return $next($request);
        }

        $currentUser = $request->user();

        // Auto-allow admin with ID 1 (full access, no restrictions)
        if ($currentUser->id === 1) {
            return $next($request);
        }

        $path = $request->path();
        $method = $request->method();

        if ($currentUser->root_admin && $this->isAdminAccessingRestrictedArea($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminAccessingSettings($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction', 
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminModifyingUser($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminModifyingServer($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminModifyingNode($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminDeletingViaAPI($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminAccessingSettingsPanel($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        if ($currentUser->root_admin && $this->isAdminAccessingNodeSettings($path, $method)) {
            return new JsonResponse([
                'error' => 'Security Restriction',
                'message' => 'This action is restricted for security reasons. Only the primary administrator (ID: 1) can perform this action.'
            ], 403);
        }

        $server = $request->route('server');
        if ($server instanceof Server) {
            $isServerOwner = $currentUser->id === $server->owner_id;
            if (!$isServerOwner) {
                return new JsonResponse([
                    'error' => 'Access Denied',
                    'message' => 'You do not have permission to access this resource. Only server owners are allowed.'
                ], 403);
            }
        }

        if (!$currentUser->root_admin) {
            $user = $request->route('user');
            if ($user instanceof User && $currentUser->id !== $user->id) {
                return new JsonResponse([
                    'error' => 'Access Denied',
                    'message' => 'You do not have permission to access this resource. Only administrators are allowed.'
                ], 403);
            }

            if ($this->isAccessingRestrictedList($path, $method, $user)) {
                return new JsonResponse([
                    'error' => 'Access Denied',
                    'message' => 'You do not have permission to access this resource. Only administrators are allowed.'
                ], 403);
            }
        }

        return $next($request);
    }

    private function isAdminAccessingRestrictedArea(string $path, string $method): bool
    {
        if ($method !== 'GET') {
            return false;
        }

        if (str_contains($path, 'admin/api')) {
            return false;
        }

        $restrictedPaths = [
            'admin/users',
            'admin/servers', 
            'admin/nodes',
            'admin/databases',
            'admin/locations',
            'admin/nests',
            'admin/mounts',
            'admin/eggs',
            'admin/settings',
            'admin/overview'
        ];

        foreach ($restrictedPaths as $restrictedPath) {
            if (str_contains($path, $restrictedPath)) {
                return true;
            }
        }

        if (str_starts_with($path, 'admin/') && !str_contains($path, 'admin/api')) {
            return true;
        }

        return false;
    }

    private function isAdminAccessingSettings(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/settings')) {
            return true;
        }

        if (str_contains($path, 'application/settings')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isAdminModifyingUser(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/users')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        if (str_contains($path, 'application/users')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isAdminModifyingServer(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/servers')) {
            if ($method === 'DELETE') {
                return true;
            }
            if ($method === 'POST' && str_contains($path, 'delete')) {
                return true;
            }
        }

        if (str_contains($path, 'application/servers')) {
            if ($method === 'DELETE') {
                return true;
            }
        }

        return false;
    }

    private function isAdminModifyingNode(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/nodes')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        if (str_contains($path, 'application/nodes')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isAdminDeletingViaAPI(string $path, string $method): bool
    {
        if ($method === 'DELETE' && preg_match('#application/users/\d+#', $path)) {
            return true;
        }

        if ($method === 'DELETE' && preg_match('#application/servers/\d+#', $path)) {
            return true;
        }

        if ($method === 'DELETE' && preg_match('#application/servers/\d+/.+#', $path)) {
            return true;
        }

        return false;
    }

    private function isAdminAccessingSettingsPanel(string $path, string $method): bool
    {
        if ($method !== 'GET') {
            return false;
        }

        $settingsPanelPaths = [
            'admin/settings/general',
            'admin/settings/mail',
            'admin/settings/advanced',
            'admin/settings/security',
            'admin/settings/features',
            'admin/settings/database',
            'admin/settings/ui',
            'admin/settings/theme'
        ];

        foreach ($settingsPanelPaths as $settingsPath) {
            if (str_contains($path, $settingsPath)) {
                return true;
            }
        }

        return false;
    }

    private function isAdminAccessingNodeSettings(string $path, string $method): bool
    {
        if ($method !== 'GET') {
            return false;
        }

        $nodeSettingsPaths = [
            'admin/nodes/view/',
            'admin/nodes/settings',
            'admin/nodes/configuration',
            'admin/nodes/allocation',
            'admin/nodes/servers'
        ];

        foreach ($nodeSettingsPaths as $nodePath) {
            if (str_contains($path, $nodePath)) {
                return true;
            }
        }

        if (preg_match('#admin/nodes/view/\d+/settings#', $path)) {
            return true;
        }

        if (preg_match('#admin/nodes/view/\d+/configuration#', $path)) {
            return true;
        }

        return false;
    }

    private function isAccessingRestrictedList(string $path, string $method, $user): bool
    {
        if ($method !== 'GET' || $user) {
            return false;
        }


        $restrictedPaths = [
            'admin/users', 'application/users',
            'admin/servers', 'application/servers',
            'admin/nodes', 'application/nodes',
            'admin/databases', 'admin/locations',
            'admin/nests', 'admin/mounts', 'admin/eggs',
            'admin/settings', 'application/settings'
        ];

        foreach ($restrictedPaths as $restrictedPath) {
            if (str_contains($path, $restrictedPath)) {
                return true;
            }
        }

        return false;
    }
}
EOF

    log "Middleware file created"

    KERNEL_FILE="$PTERO_DIR/app/Http/Kernel.php"
    process "Registering middleware in Kernel..."

    if grep -q "custom.security" "$KERNEL_FILE"; then
        warn "Middleware already registered in Kernel"
    else
        sed -i "/protected \$middlewareAliases = \[/a\\
        'custom.security' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\CustomSecurityCheck::class," "$KERNEL_FILE"
        log "Middleware registered in Kernel"
    fi

    apply_manual_routes

    show_loading "Clearing cache and optimizing"
    cd $PTERO_DIR
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan view:clear
    sudo -u www-data php artisan cache:clear
    sudo -u www-data php artisan optimize

    log "Cache cleared successfully"

    process "Restarting services..."

    PHP_SERVICE=""
    if systemctl is-active --quiet php8.2-fpm; then
        PHP_SERVICE="php8.2-fpm"
    elif systemctl is-active --quiet php8.1-fpm; then
        PHP_SERVICE="php8.1-fpm"
    elif systemctl is-active --quiet php8.0-fpm; then
        PHP_SERVICE="php8.0-fpm"
    elif systemctl is-active --quiet php8.3-fpm; then
        PHP_SERVICE="php8.3-fpm"
    else
        warn "PHP-FPM service not detected, skipping restart"
    fi

    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart $PHP_SERVICE
        log "$PHP_SERVICE restarted"
    fi

    if systemctl is-active --quiet pteroq; then
        systemctl restart pteroq
        log "pteroq service restarted"
    fi

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "nginx reloaded"
    fi

    echo
    log "Custom Security Middleware installed successfully!"
    echo
    info "Protection Summary:"
    log "  • Admin ID 1: Full access (no restrictions)"
    log "  • Other admins: View only, cannot modify"
    log "  • API DELETE operations blocked for non-ID-1 admins"
    log "  • Settings panel access restricted"
    log "  • Node settings access restricted"
    log "  • Server ownership protection active"
    log "  • User access restriction active"
    echo
    warn "Test by logging in as admin ID 2 and accessing blocked tabs"
    log "Use 'Clear Security' option to uninstall"
}

custom_error_message() {
    echo
    info "Custom Error Message"
    echo "===================="
    echo
    read -p "Enter custom error text (example: 'Access denied!'): " custom_error
    
    if [ -z "$custom_error" ]; then
        error "Error text cannot be empty!"
    fi
    
    echo
    process "Updating error message to: '$custom_error'..."
    
    if [ ! -f "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php" ]; then
        error "Middleware not installed! Please install first."
    fi
    
    # Update all error messages in the middleware file
    sed -i "s/'error' => 'Security Restriction'/'error' => '$custom_error'/g" "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php"
    sed -i "s/'error' => 'Access Denied'/'error' => '$custom_error'/g" "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php"
    
    log "Error message updated to: '$custom_error'"
    
    show_loading "Clearing cache"
    cd $PTERO_DIR
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan cache:clear
    
    echo
    log "Error message updated successfully!"
}

main() {
    # Run initial syntax check
    scan_and_repair_routes
    
    while true; do
        show_menu
        read -p "$(info 'Select option (1-10): ')" choice
        
        case $choice in
            1)
                echo
                install_middleware
                ;;
            2)
                add_custom_security_middleware
                ;;
            3)
                custom_error_message
                ;;
            4)
                clear_security
                ;;
            5)
                clear_pterodactyl_cache
                ;;
            6)
                restore_default_routes
                ;;
            7)
                fix_server_status
                ;;
            8)
                show_server_status
                ;;
            9)
                scan_and_repair_routes
                ;;
            10)
                echo
                log "Thank you! Exiting program."
                exit 0
                ;;
            *)
                error "Invalid option! Select 1-10."
                ;;
        esac
        
        echo
        read -p "$(info 'Press Enter to continue...')"
    done
}

# Run main function
main