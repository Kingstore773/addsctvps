#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[MENU]${NC} $1"; }

show_header() {
    clear
    echo "=========================================="
    echo "      STRICT ADMIN SECURITY INSTALLER     "
    echo "    ONLY ADMIN ID 1 HAS FULL ACCESS      "
    echo "           @KingStoreGanteng             "
    echo "=========================================="
    echo
}

show_menu() {
    show_header
    echo "Menu Options:"
    echo "1. Install Strict Admin Security"
    echo "2. Change Credit Name"
    echo "3. Custom Error Message" 
    echo "4. Uninstall Security (Restore Original)"
    echo "5. Exit"
    echo
}

backup_files() {
    local backup_dir="/root/pterodactyl-security-backup"
    mkdir -p "$backup_dir"
    
    PTERO_DIR="/var/www/pterodactyl"
    
    # Backup original files
    if [ -f "$PTERO_DIR/app/Http/Kernel.php" ]; then
        cp "$PTERO_DIR/app/Http/Kernel.php" "$backup_dir/Kernel.php.backup"
    fi
    
    if [ -f "$PTERO_DIR/routes/web.php" ]; then
        cp "$PTERO_DIR/routes/web.php" "$backup_dir/web.php.backup"
    fi
    
    if [ -f "$PTERO_DIR/routes/api.php" ]; then
        cp "$PTERO_DIR/routes/api.php" "$backup_dir/api.php.backup"
    fi
    
    log "📁 Backups saved to: $backup_dir"
}

install_security() {
    show_header
    
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root: sudo bash <(curl -s https://raw.githubusercontent.com/Kingstore773/addsctvps/main/security.sh)"
    fi

    PTERO_DIR="/var/www/pterodactyl"
    
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
    fi

    log "🚀 Installing Strict Admin Security Middleware..."
    log "📁 Pterodactyl directory: $PTERO_DIR"

    # Create backup first
    log "📦 Creating backup of original files..."
    backup_files

    # Create middleware directory if not exists
    mkdir -p "$PTERO_DIR/app/Http/Middleware"

    # Create middleware
    log "📝 Creating StrictAdminSecurity middleware..."
    
    cat > "$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StrictAdminSecurity
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        
        if (!$user) {
            return $next($request);
        }

        $path = $request->path();
        $method = $request->method();

        // Admin ID 1 has full access - no restrictions
        if ($user->id === 1) {
            return $next($request);
        }

        // For non-ID-1 admin users - apply strict restrictions
        if ($user->root_admin) {
            // BLOCK ALL ADMIN PANEL ACCESS except Overview
            if ($this->isAdminPanelRestrictedArea($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can access this area. - @KingStoreGanteng');
            }

            // BLOCK ALL SETTINGS ACCESS
            if (str_contains($path, 'admin/settings') || str_contains($path, 'application/settings')) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify settings. - @KingStoreGanteng');
            }

            // BLOCK ALL MANAGEMENT SECTIONS
            if ($this->isManagementSection($path)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can access management sections. - @KingStoreGanteng');
            }

            // BLOCK ALL SERVICE MANAGEMENT
            if ($this->isServiceManagement($path)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can access service management. - @KingStoreGanteng');
            }

            // BLOCK USER MODIFICATIONS
            if ($this->isUserModification($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify users. - @KingStoreGanteng');
            }

            // BLOCK SERVER MODIFICATIONS
            if ($this->isServerModification($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify servers. - @KingStoreGanteng');
            }

            // BLOCK NODE MODIFICATIONS
            if ($this->isNodeModification($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify nodes. - @KingStoreGanteng');
            }

            // BLOCK DATABASE OPERATIONS
            if (str_contains($path, 'admin/databases') && $method !== 'GET') {
                return $this->denyAccess($request, 'Access denied! Only main admin can manage databases. - @KingStoreGanteng');
            }

            // BLOCK LOCATION OPERATIONS
            if (str_contains($path, 'admin/locations') && $method !== 'GET') {
                return $this->denyAccess($request, 'Access denied! Only main admin can manage locations. - @KingStoreGanteng');
            }
        }

        // For regular users - prevent accessing other users' servers
        $server = $request->route('server');
        if ($server instanceof \Pterodactyl\Models\Server) {
            if ($user->id !== $server->owner_id && !$user->root_admin) {
                return $this->denyAccess($request, 'Access denied! You cannot access this server. - @KingStoreGanteng');
            }
        }

        return $next($request);
    }

    private function denyAccess(Request $request, string $message)
    {
        if ($request->is('api/*') || $request->expectsJson()) {
            return new JsonResponse([
                'error' => $message
            ], 403);
        }
        
        if ($request->hasSession()) {
            $request->session()->flash('error', $message);
        }
        
        return redirect()->back();
    }

    private function isAdminPanelRestrictedArea(string $path, string $method): bool
    {
        $restrictedPaths = [
            'admin/users',
            'admin/servers', 
            'admin/nodes',
            'admin/databases',
            'admin/locations',
            'admin/nests',
            'admin/mounts',
            'admin/eggs',
            'admin/settings'
        ];

        foreach ($restrictedPaths as $restrictedPath) {
            if (str_contains($path, $restrictedPath)) {
                return true;
            }
        }

        return false;
    }

    private function isManagementSection(string $path): bool
    {
        $managementPaths = [
            'admin/databases',
            'admin/locations', 
            'admin/nodes',
            'admin/servers',
            'admin/users'
        ];

        foreach ($managementPaths as $managementPath) {
            if (str_contains($path, $managementPath)) {
                return true;
            }
        }

        return false;
    }

    private function isServiceManagement(string $path): bool
    {
        $servicePaths = [
            'admin/mounts',
            'admin/nests',
            'admin/eggs'
        ];

        foreach ($servicePaths as $servicePath) {
            if (str_contains($path, $servicePath)) {
                return true;
            }
        }

        return false;
    }

    private function isUserModification(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/users') || str_contains($path, 'application/users')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isServerModification(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/servers') || str_contains($path, 'application/servers')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isNodeModification(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/nodes') || str_contains($path, 'application/nodes')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }
}
EOF

    log "✅ Strict admin middleware created"

    # Register middleware in Kernel
    KERNEL_FILE="$PTERO_DIR/app/Http/Kernel.php"
    log "📝 Registering middleware in Kernel..."

    if [ ! -f "$KERNEL_FILE" ]; then
        error "Kernel file not found: $KERNEL_FILE"
    fi

    if grep -q "strict.admin" "$KERNEL_FILE"; then
        warn "⚠️ Middleware already registered in Kernel"
    else
        # Add middleware to Kernel
        if grep -q "protected \$middlewareAliases = \[" "$KERNEL_FILE"; then
            sed -i "/protected \$middlewareAliases = \[/a\\
        'strict.admin' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\StrictAdminSecurity::class," "$KERNEL_FILE"
            log "✅ Middleware registered in Kernel (middlewareAliases)"
        elif grep -q "protected \$routeMiddleware = \[" "$KERNEL_FILE"; then
            sed -i "/protected \$routeMiddleware = \[/a\\
        'strict.admin' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\StrictAdminSecurity::class," "$KERNEL_FILE"
            log "✅ Middleware registered in Kernel (routeMiddleware)"
        else
            error "Could not find middleware aliases in Kernel.php"
        fi
    fi

    # Apply to web routes
    WEB_FILE="$PTERO_DIR/routes/web.php"
    if [ -f "$WEB_FILE" ]; then
        if ! grep -q "strict.admin" "$WEB_FILE"; then
            sed -i "s/Route::middleware(\['web', 'auth', 'admin'\])->prefix('admin')->group/Route::middleware(['web', 'auth', 'admin', 'strict.admin'])->prefix('admin')->group/g" "$WEB_FILE"
            log "✅ Applied middleware to web admin routes"
        else
            warn "⚠️ Middleware already applied to web routes"
        fi
    else
        warn "⚠️ Web routes file not found: $WEB_FILE"
    fi

    # Apply to API routes
    API_FILE="$PTERO_DIR/routes/api.php"
    if [ -f "$API_FILE" ]; then
        if ! grep -q "strict.admin" "$API_FILE"; then
            sed -i "s/Route::middleware(\['api', 'auth:api', 'admin'\])->prefix('application')->group/Route::middleware(['api', 'auth:api', 'admin', 'strict.admin'])->prefix('application')->group/g" "$API_FILE"
            log "✅ Applied middleware to API admin routes"
        else
            warn "⚠️ Middleware already applied to API routes"
        fi
    else
        warn "⚠️ API routes file not found: $API_FILE"
    fi

    # Clear cache
    log "🧹 Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan route:clear > /dev/null 2>&1 || php artisan route:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    sudo -u www-data php artisan optimize > /dev/null 2>&1 || php artisan optimize > /dev/null 2>&1

    # Restart services
    log "🔄 Restarting services..."
    
    # Find PHP service
    PHP_SERVICE=""
    for version in 8.3 8.2 8.1 8.0 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            PHP_SERVICE="php${version}-fpm"
            break
        fi
    done

    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart "$PHP_SERVICE"
        log "✅ $PHP_SERVICE restarted"
    else
        warn "⚠️ PHP-FPM service not detected"
    fi

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "✅ nginx reloaded"
    fi

    if systemctl is-active --quiet pteroq; then
        systemctl restart pteroq
        log "✅ pteroq service restarted"
    fi

    echo
    log "🎉 STRICT ADMIN SECURITY installed successfully!"
    echo
    log "📊 PROTECTION SUMMARY:"
    log "   ✅ FULL ACCESS: Admin ID 1 only"
    log "   ❌ RESTRICTED: Other admins blocked from:"
    log "      - Management sections (Users, Servers, Nodes, etc)"
    log "      - Service management (Nests, Mounts, Eggs)" 
    log "      - Settings and modifications"
    log "   🔒 Server ownership protection active"
    echo
    log "💬 Credit: @KingStoreGanteng"
    echo
    warn "⚠️ IMPORTANT: Only admin with ID 1 has full access!"
    warn "⚠️ Other admins will see errors when accessing restricted areas"
    echo
    log "📦 Backup created in: /root/pterodactyl-security-backup"
    log "🔧 To uninstall: Run this script again and choose option 4"
}

change_credit_name() {
    show_header
    echo "CHANGE CREDIT NAME"
    echo "================="
    echo
    
    PTERO_DIR="/var/www/pterodactyl"
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    
    if [ ! -f "$MW_FILE" ]; then
        error "Middleware not installed! Please install security first (Option 1)."
    fi
    
    read -p "Enter new name to replace '@KingStoreGanteng': " new_name
    
    if [ -z "$new_name" ]; then
        error "Name cannot be empty!"
    fi
    
    # Remove @ if user included it
    new_name=$(echo "$new_name" | sed 's/^@//')
    
    echo
    log "Replacing '@KingStoreGanteng' with '@$new_name'..."
    
    # Replace all occurrences in the middleware file
    sed -i "s/@KingStoreGanteng/@$new_name/g" "$MW_FILE"
    
    log "✅ Name changed from '@KingStoreGanteng' to '@$new_name'"
    
    # Clear cache
    log "🧹 Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    
    echo
    log "🎉 Credit name updated successfully!"
    log "💬 New credit: @$new_name"
}

custom_error_message() {
    show_header
    echo "CUSTOM ERROR MESSAGE"
    echo "==================="
    echo
    
    PTERO_DIR="/var/www/pterodactyl"
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    
    if [ ! -f "$MW_FILE" ]; then
        error "Middleware not installed! Please install security first (Option 1)."
    fi
    
    read -p "Enter custom error message: " custom_error
    
    if [ -z "$custom_error" ]; then
        error "Error message cannot be empty!"
    fi
    
    echo
    log "Updating all error messages to: '$custom_error'..."
    
    # Replace all error messages in the middleware file
    sed -i "s/'error' => 'Access denied! Only main admin can access this area. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can modify settings. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can access management sections. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can access service management. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can modify users. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can modify servers. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can modify nodes. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can manage databases. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! Only main admin can manage locations. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    sed -i "s/'error' => 'Access denied! You cannot access this server. - @.*/'error' => '$custom_error'/g" "$MW_FILE"
    
    log "✅ All error messages updated"
    
    # Clear cache
    log "🧹 Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    
    echo
    log "🎉 Error message customized successfully!"
}

uninstall_security() {
    show_header
    echo "UNINSTALL SECURITY"
    echo "================="
    echo
    
    PTERO_DIR="/var/www/pterodactyl"
    BACKUP_DIR="/root/pterodactyl-security-backup"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "No backup found! Cannot uninstall. Backup directory not found: $BACKUP_DIR"
    fi
    
    warn "⚠️ This will remove all security modifications and restore original files!"
    echo
    read -p "Are you sure you want to uninstall? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Uninstall cancelled."
        return
    fi
    
    log "🔄 Starting uninstall process..."
    
    # Remove middleware file
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    if [ -f "$MW_FILE" ]; then
        rm -f "$MW_FILE"
        log "✅ Removed middleware file"
    fi
    
    # Restore Kernel.php from backup
    if [ -f "$BACKUP_DIR/Kernel.php.backup" ]; then
        cp "$BACKUP_DIR/Kernel.php.backup" "$PTERO_DIR/app/Http/Kernel.php"
        log "✅ Restored Kernel.php from backup"
    else
        # Remove middleware from Kernel manually
        if [ -f "$PTERO_DIR/app/Http/Kernel.php" ]; then
            sed -i "/'strict.admin' => .*StrictAdminSecurity::class,/d" "$PTERO_DIR/app/Http/Kernel.php"
            log "✅ Removed middleware from Kernel.php"
        fi
    fi
    
    # Restore web.php from backup
    if [ -f "$BACKUP_DIR/web.php.backup" ]; then
        cp "$BACKUP_DIR/web.php.backup" "$PTERO_DIR/routes/web.php"
        log "✅ Restored web.php from backup"
    else
        # Remove middleware from web routes manually
        if [ -f "$PTERO_DIR/routes/web.php" ]; then
            sed -i "s/Route::middleware(\['web', 'auth', 'admin', 'strict.admin'\])->prefix('admin')->group/Route::middleware(['web', 'auth', 'admin'])->prefix('admin')->group/g" "$PTERO_DIR/routes/web.php"
            log "✅ Removed middleware from web.php"
        fi
    fi
    
    # Restore api.php from backup
    if [ -f "$BACKUP_DIR/api.php.backup" ]; then
        cp "$BACKUP_DIR/api.php.backup" "$PTERO_DIR/routes/api.php"
        log "✅ Restored api.php from backup"
    else
        # Remove middleware from API routes manually
        if [ -f "$PTERO_DIR/routes/api.php" ]; then
            sed -i "s/Route::middleware(\['api', 'auth:api', 'admin', 'strict.admin'\])->prefix('application')->group/Route::middleware(['api', 'auth:api', 'admin'])->prefix('application')->group/g" "$PTERO_DIR/routes/api.php"
            log "✅ Removed middleware from api.php"
        fi
    fi
    
    # Clear cache
    log "🧹 Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan route:clear > /dev/null 2>&1 || php artisan route:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    sudo -u www-data php artisan optimize > /dev/null 2>&1 || php artisan optimize > /dev/null 2>&1
    
    # Restart services
    log "🔄 Restarting services..."
    
    # Find PHP service
    PHP_SERVICE=""
    for version in 8.3 8.2 8.1 8.0 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            PHP_SERVICE="php${version}-fpm"
            break
        fi
    done

    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart "$PHP_SERVICE"
        log "✅ $PHP_SERVICE restarted"
    fi

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "✅ nginx reloaded"
    fi

    if systemctl is-active --quiet pteroq; then
        systemctl restart pteroq
        log "✅ pteroq service restarted"
    fi
    
    echo
    log "🎉 Security successfully uninstalled!"
    log "📁 Original files restored from: $BACKUP_DIR"
    echo
    log "🔓 All restrictions have been removed."
    log "👥 All admins now have full access again."
    echo
    warn "💡 You can delete the backup folder if you want: rm -rf $BACKUP_DIR"
}

main() {
    while true; do
        show_menu
        echo
        read -p "$(info 'Choose option (1-5): ')" choice
        
        case $choice in
            1)
                install_security
                ;;
            2)
                change_credit_name
                ;;
            3)
                custom_error_message
                ;;
            4)
                uninstall_security
                ;;
            5)
                echo
                log "Thank you! Exiting."
                exit 0
                ;;
            *)
                error "Invalid choice! Please choose 1, 2, 3, 4, or 5."
                ;;
        esac
        
        echo
        read -p "$(info 'Press Enter to continue...')"
    done
}

# Run main function
main