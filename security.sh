#!/bin/bash

# Custom Security Middleware Installer for Pterodactyl
# Created by @KingStoreGanteng
# Usage: bash <(curl -s https://raw.githubusercontent.com/iLyxxDev/hosting/main/security.sh)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[MENU]${NC} $1"
}

# Function to show menu
show_menu() {
    echo
    info "=========================================="
    info "    CUSTOM SECURITY MIDDLEWARE INSTALLER"
    info "=========================================="
    echo
    info "Pilihan yang tersedia:"
    info "1. Install Security Middleware"
    info "2. Ganti Nama Credit di Middleware"
    info "3. Keluar"
    echo
}

# Function to replace credit name
replace_credit_name() {
    echo
    info "GANTI NAMA CREDIT"
    info "================="
    echo
    read -p "Masukkan nama baru untuk mengganti '@KingStoreGanteng': " new_name
    
    if [ -z "$new_name" ]; then
        error "Nama tidak boleh kosong!"
    fi
    
    # Remove @ if user included it
    new_name=$(echo "$new_name" | sed 's/^@//')
    
    echo
    info "Mengganti '@KingStoreGanteng' dengan '@$new_name'..."
    
    # Check if middleware file exists
    if [ ! -f "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php" ]; then
        error "Middleware belum diinstall! Silakan install terlebih dahulu."
    fi
    
    # Replace all occurrences in the middleware file
    sed -i "s/@KingStoreGanteng/@$new_name/g" "$PTERO_DIR/app/Http/Middleware/CustomSecurityCheck.php"
    
    log "✅ Nama berhasil diganti dari '@KingStoreGanteng' menjadi '@$new_name'"
    
    # Clear cache
    log "🧹 Membersihkan cache..."
    cd $PTERO_DIR
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan cache:clear
    
    echo
    log "🎉 Nama credit berhasil diubah!"
    log "💬 Credit sekarang: @$new_name"
}

# Function to install middleware
install_middleware() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root: sudo bash <(curl -s https://raw.githubusercontent.com/iLyxxDev/hosting/main/security.sh)"
    fi

    # Pterodactyl directory
    PTERO_DIR="/var/www/pterodactyl"

    # Check if Pterodactyl exists
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
    fi

    log "🚀 Installing Custom Security Middleware for Pterodactyl..."
    log "📁 Pterodactyl directory: $PTERO_DIR"

    # Create custom middleware file
    log "📝 Creating CustomSecurityCheck middleware..."
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
        $path = $request->path();
        $method = $request->method();

        // === PROTECTION: BLOCK ADMIN ACCESS TO ALL WEB PANEL TABS EXCEPT APPLICATION API ===
        if ($currentUser->root_admin && $this->isAdminAccessingRestrictedPanel($path, $method)) {
            return new JsonResponse([
                'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
            ], 403);
        }

        // === PROTECTION: BLOCK ADMIN SETTINGS OPERATIONS ===
        if ($currentUser->root_admin && $this->isAdminAccessingSettings($path, $method)) {
            return new JsonResponse([
                'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
            ], 403);
        }

        // === PROTECTION: BLOCK ADMIN USER OPERATIONS ===
        if ($currentUser->root_admin && $this->isAdminModifyingUser($path, $method)) {
            return new JsonResponse([
                'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
            ], 403);
        }

        // === PROTECTION: BLOCK ADMIN SERVER OPERATIONS ===
        if ($currentUser->root_admin && $this->isAdminModifyingServer($path, $method)) {
            return new JsonResponse([
                'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
            ], 403);
        }

        // === PROTECTION: BLOCK ADMIN NODE OPERATIONS ===
        if ($currentUser->root_admin && $this->isAdminModifyingNode($path, $method)) {
            return new JsonResponse([
                'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
            ], 403);
        }

        // === PROTECTION: BLOCK ADMIN API DELETE OPERATIONS ===
        if ($currentUser->root_admin && $this->isAdminDeletingViaAPI($path, $method)) {
            return new JsonResponse([
                'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
            ], 403);
        }

        // === PROTECTION: SERVER OWNERSHIP CHECK ===
        $server = $request->route('server');
        if ($server instanceof Server) {
            $isServerOwner = $currentUser->id === $server->owner_id;
            if (!$isServerOwner) {
                return new JsonResponse([
                    'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
                ], 403);
            }
        }

        // === PROTECTION: USER ACCESS CHECK (NON-ADMIN ONLY) ===
        if (!$currentUser->root_admin) {
            $user = $request->route('user');
            if ($user instanceof User && $currentUser->id !== $user->id) {
                return new JsonResponse([
                    'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
                ], 403);
            }

            if ($this->isAccessingRestrictedList($path, $method, $user)) {
                return new JsonResponse([
                    'error' => 'Mau ngapain hama wkwkwk - @KingStoreGanteng'
                ], 403);
            }
        }

        return $next($request);
    }

    /**
     * Block admin access to all web panel tabs except Application API
     */
    private function isAdminAccessingRestrictedPanel(string $path, string $method): bool
    {
        if ($method !== 'GET') {
            return false;
        }

        // ✅ ALLOW: Application API routes only
        if (str_contains($path, 'admin/api')) {
            return false;
        }

        // ❌ BLOCK: All other admin panel routes
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

    /**
     * Block admin settings operations
     */
    private function isAdminAccessingSettings(string $path, string $method): bool
    {
        // Block all settings operations
        if (str_contains($path, 'admin/settings')) {
            return true;
        }

        // Block settings operations in application API
        if (str_contains($path, 'application/settings')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    /**
     * Block admin user operations (update, delete, etc.)
     */
    private function isAdminModifyingUser(string $path, string $method): bool
    {
        // Block all user modification operations
        if (str_contains($path, 'admin/users')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        // Block application API user operations
        if (str_contains($path, 'application/users')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    /**
     * Block admin server operations (delete, etc.)
     */
    private function isAdminModifyingServer(string $path, string $method): bool
    {
        // Block server delete operations in admin panel
        if (str_contains($path, 'admin/servers')) {
            if ($method === 'DELETE') {
                return true;
            }
            if ($method === 'POST' && str_contains($path, 'delete')) {
                return true;
            }
        }

        // Block server delete operations in application API
        if (str_contains($path, 'application/servers')) {
            if ($method === 'DELETE') {
                return true;
            }
        }

        return false;
    }

    /**
     * Block admin node operations
     */
    private function isAdminModifyingNode(string $path, string $method): bool
    {
        // Block all node modification operations
        if (str_contains($path, 'admin/nodes')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        // Block application API node operations
        if (str_contains($path, 'application/nodes')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    /**
     * Block admin delete operations via API Application
     */
    private function isAdminDeletingViaAPI(string $path, string $method): bool
    {
        // Block DELETE user via API: DELETE /api/application/users/{id}
        if ($method === 'DELETE' && preg_match('#application/users/\d+#', $path)) {
            return true;
        }

        // Block DELETE server via API: DELETE /api/application/servers/{id}
        if ($method === 'DELETE' && preg_match('#application/servers/\d+#', $path)) {
            return true;
        }

        // Block force delete server via API: DELETE /api/application/servers/{id}/force
        if ($method === 'DELETE' && preg_match('#application/servers/\d+/.+#', $path)) {
            return true;
        }

        return false;
    }

    /**
     * Check if accessing restricted lists (non-admin only)
     */
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

    log "✅ Custom middleware created"

    # Register middleware in Kernel
    KERNEL_FILE="$PTERO_DIR/app/Http/Kernel.php"
    log "📝 Registering middleware in Kernel..."

    if grep -q "custom.security" "$KERNEL_FILE"; then
        warn "⚠️ Middleware already registered in Kernel"
    else
        # Add middleware to Kernel
        sed -i "/protected \$middlewareAliases = \[/a\\
        'custom.security' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\CustomSecurityCheck::class," "$KERNEL_FILE"
        log "✅ Middleware registered in Kernel"
    fi

    # Apply middleware to routes
    log "🔧 Applying middleware to routes..."

    # Function to apply middleware to route group
    apply_middleware_to_group() {
        local file="$1"
        local group_pattern="$2"
        
        if [ -f "$file" ]; then
            # Check if group exists without our middleware
            if grep -q "$group_pattern" "$file" && ! grep -q "custom.security" "$file" && grep -q "$group_pattern" "$file"; then
                # Add middleware to the group
                sed -i "s/$group_pattern/$group_pattern, 'middleware' => ['custom.security']/g" "$file"
                log "✅ Applied middleware to group in $(basename $file)"
            else
                warn "⚠️ Group not found or already has middleware in $(basename $file)"
            fi
        else
            warn "⚠️ File not found: $(basename $file)"
        fi
    }

    # Function to apply middleware to individual routes
    apply_middleware_to_route() {
        local file="$1"
        local route_pattern="$2"
        
        if [ -f "$file" ]; then
            # Find routes that don't have custom.security middleware yet
            while IFS= read -r line; do
                if [[ $line =~ $route_pattern ]] && [[ ! $line =~ "custom.security" ]]; then
                    # Add middleware to the route
                    if [[ $line =~ \)\; ]]; then
                        # Route without existing middleware
                        new_line=$(echo "$line" | sed "s/);/)->middleware(['custom.security']);/")
                    elif [[ $line =~ \)\-\>middleware\( ]]; then
                        # Route with existing middleware
                        new_line=$(echo "$line" | sed "s/)->middleware(\[/)->middleware(['custom.security', /")
                    else
                        # Route with other formatting
                        new_line=$(echo "$line" | sed "s/);/)->middleware(['custom.security']);/")
                    fi
                    
                    # Replace the line in the file
                    escaped_line=$(printf '%s\n' "$line" | sed 's/[[\.*^$/]/\\&/g')
                    escaped_new_line=$(printf '%s\n' "$new_line" | sed 's/[[\.*^$/]/\\&/g')
                    sed -i "s|$escaped_line|$escaped_new_line|g" "$file"
                    
                    log "✅ Applied middleware to route: $(echo "$line" | tr -d '\n' | sed 's/^[[:space:]]*//')"
                fi
            done < <(grep "$route_pattern" "$file")
        fi
    }

    # Apply middleware to api-client.php files group
    log "🔧 Applying middleware to api-client.php files group..."
    apply_middleware_to_group "$PTERO_DIR/routes/api-client.php" "Route::group(\['prefix' => '/files'"

    # Apply middleware to specific routes in admin.php
    log "🔧 Applying middleware to admin.php routes..."
    ADMIN_FILE="$PTERO_DIR/routes/admin.php"
    
    if [ -f "$ADMIN_FILE" ]; then
        # Define routes to protect in admin.php
        admin_routes=(
            "Route::patch('/view/{user:id}', \[Admin\\UserController::class, 'update'\])"
            "Route::delete('/view/{user:id}', \[Admin\\UserController::class, 'delete'\])"
            "Route::get('/view/{server:id}/details', \[Admin\\Servers\\ServerViewController::class, 'details'\])->name('admin.servers.view.details')"
            "Route::get('/view/{server:id}/delete', \[Admin\\Servers\\ServerViewController::class, 'delete'\])->name('admin.servers.view.delete')"
            "Route::post('/view/{server:id}/delete', \[Admin\\ServersController::class, 'delete'\])"
            "Route::patch('/view/{server:id}/details', \[Admin\\ServersController::class, 'setDetails'\])"
            "Route::get('/view/{node:id}/settings', \[Admin\\Nodes\\NodeViewController::class, 'settings'\])->name('admin.nodes.view.settings')"
            "Route::get('/view/{node:id}/configuration', \[Admin\\Nodes\\NodeViewController::class, 'configuration'\])->name('admin.nodes.view.configuration')"
            "Route::post('/view/{node:id}/settings/token', Admin\\NodeAutoDeployController::class)->name('admin.nodes.view.configuration.token')"
            "Route::patch('/view/{node:id}/settings', \[Admin\\NodesController::class, 'updateSettings'\])"
            "Route::delete('/view/{node:id}/delete', \[Admin\\NodesController::class, 'delete'\])->name('admin.nodes.view.delete')"
        )
        
        for route in "${admin_routes[@]}"; do
            apply_middleware_to_route "$ADMIN_FILE" "$route"
        done
    fi

    # Clear cache and optimize
    log "🧹 Clearing cache and optimizing..."
    cd $PTERO_DIR

    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan view:clear
    sudo -u www-data php artisan cache:clear
    sudo -u www-data php artisan optimize

    log "✅ Cache cleared successfully"

    # Restart services
    log "🔄 Restarting services..."

    # Detect PHP version
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
        warn "⚠️ PHP-FPM service not detected, skipping restart"
    fi

    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart $PHP_SERVICE
        log "✅ $PHP_SERVICE restarted"
    fi

    if systemctl is-active --quiet pteroq-service; then
        systemctl restart pteroq-service
        log "✅ pterodactyl-service restarted"
    fi

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "✅ nginx reloaded"
    fi

    # Final verification
    log "🔍 Verifying middleware application..."
    echo
    log "📋 Applied middleware to:"
    log "   ✅ api-client.php: /files group"
    log "   ✅ admin.php: multiple user, server, and node routes"
    echo
    log "🎉 Custom Security Middleware installed successfully!"
    echo
    log "📊 PROTECTION SUMMARY:"
    log "   ✅ Admin hanya bisa akses: Application API"
    log "   ❌ Admin DIBLOKIR dari:"
    log "      - Users, Servers, Nodes, Settings"
    log "      - Databases, Locations, Nests, Mounts, Eggs"
    log "      - Delete/Update operations"
    log "   🔒 API DELETE Operations DIBLOKIR:"
    log "      - DELETE /api/application/users/{id}"
    log "      - DELETE /api/application/servers/{id}" 
    log "      - DELETE /api/application/servers/{id}/force"
    log "   🔒 Server ownership protection aktif"
    log "   🛡️ User access restriction aktif"
    echo
    log "💬 Source Code Credit by - @KingStoreGanteng'"
    echo
    warn "⚠️ IMPORTANT: Test dengan login sebagai admin dan coba akses tabs yang diblokir"
    log "   Untuk uninstall, hapus middleware dari Kernel.php dan routes"
}

# Main program
main() {
    while true; do
        show_menu
        read -p "$(info 'Pilih opsi (1-3): ')" choice
        
        case $choice in
            1)
                echo
                install_middleware
                ;;
            2)
                replace_credit_name
                ;;
            3)
                echo
                log "Terima kasih! Keluar dari program."
                exit 0
                ;;
            *)
                error "Pilihan tidak valid! Silakan pilih 1, 2, atau 3."
                ;;
        esac
        
        echo
        read -p "$(info 'Tekan Enter untuk kembali ke menu...')"
    done
}

# Run main program
main
