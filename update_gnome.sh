#!/bin/bash

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Arbeitsverzeichnis
WORK_DIR="$HOME/Dokumente/gnome_rounded"

# Patch URLs
GNOME_SHELL_PATCH="https://raw.githubusercontent.com/root9191/Fix-Gnome-Rounded-Corners/refs/heads/main/gnome-shell/Shell_BlurEffect__rounded_corners_mask.patch"
# ohne UI 
#BLUR_MY_SHELL_PATCH="https://raw.githubusercontent.com/root9191/Fix-Gnome-Rounded-Corners/refs/heads/main/blurmyshell/Add_corner_radius_to_NativeDynamicBlurEffect.patch"

# mit UI
BLUR_MY_SHELL_PATCH="https://raw.githubusercontent.com/root9191/Fix-Gnome-Rounded-Corners/refs/heads/main/blurmyshell/Add_corner_radius_to_NativeDynamicBlurEffect_UI.patch"

# Dry-run Modus
DRY_RUN=false
BUILD_GNOME_SHELL=true
BUILD_BLUR_MY_SHELL=true

# Hilfe-Funktion
show_help() {
    echo -e "${GREEN}=== GNOME Rounded Corners Auto-Builder ===${NC}"
    echo -e ""
    echo -e "${YELLOW}Verwendung:${NC}"
    echo -e "  $0 [OPTIONEN]"
    echo -e ""
    echo -e "${YELLOW}Optionen:${NC}"
    echo -e "  -d, --dry-run         Zeigt nur an, was gemacht würde (keine Änderungen)"
    echo -e "  -g, --gnome-only      Baut nur gnome-shell"
    echo -e "  -b, --blur-only       Baut nur blur-my-shell"
    echo -e "  -h, --help            Zeigt diese Hilfe an"
    echo -e ""
    echo -e "${YELLOW}Beschreibung:${NC}"
    echo -e "  Dieses Skript aktualisiert und baut automatisch:"
    echo -e "  1. gnome-shell mit rounded corners patch"
    echo -e "  2. blur-my-shell extension mit corner radius patch"
    echo -e ""
    echo -e "${YELLOW}Arbeitsverzeichnis:${NC}"
    echo -e "  $WORK_DIR"
    echo -e ""
    echo -e "${YELLOW}Beispiele:${NC}"
    echo -e "  $0                    # Beide Pakete bauen"
    echo -e "  $0 --dry-run          # Keine Änderung"
    echo -e "  $0 --gnome-only       # Nur gnome-shell bauen"
    echo -e "  $0 --blur-only        # Nur blur-my-shell bauen"
    echo -e ""
    exit 0
}

# Kommandozeilen-Argumente verarbeiten
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -g|--gnome-only)
            BUILD_GNOME_SHELL=true
            BUILD_BLUR_MY_SHELL=false
            shift
            ;;
        -b|--blur-only)
            BUILD_GNOME_SHELL=false
            BUILD_BLUR_MY_SHELL=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unbekannte Option: $1${NC}"
            echo "Verwende --help für weitere Informationen"
            exit 1
            ;;
    esac
done

# Header mit Dry-Run Info
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  GNOME Rounded Corners Auto-Builder       ║${NC}"
    echo -e "${CYAN}║  ${YELLOW}[DRY-RUN MODUS - Keine Änderungen]${CYAN}      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}\n"
else
    echo -e "${GREEN}=== GNOME Rounded Corners Auto-Builder ===${NC}\n"
fi

# Arbeitsverzeichnis erstellen falls nicht vorhanden
if [ ! -d "$WORK_DIR" ]; then
    echo -e "${YELLOW}Erstelle Arbeitsverzeichnis: $WORK_DIR${NC}"
    mkdir -p "$WORK_DIR"
fi

cd "$WORK_DIR" || exit 1

# Funktion: Repo klonen oder aktualisieren
update_repo() {
    local repo_url=$1
    local repo_name=$2
    
    echo -e "\n${YELLOW}=== Aktualisiere $repo_name ===${NC}"
    
    if [ -d "$repo_name" ]; then
        echo "Repository existiert bereits"
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN] Würde Updates ziehen:${NC}"
            echo -e "${CYAN}  → git fetch --all${NC}"
            echo -e "${CYAN}  → git reset --hard origin/HEAD${NC}"
            echo -e "${CYAN}  → git clean -fdx${NC}"
        else
            echo "Ziehe Updates..."
            cd "$repo_name" || return 1
            git fetch --all
            git reset --hard origin/HEAD
            git clean -fdx
            cd "$WORK_DIR" || return 1
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN] Würde Repository klonen:${NC}"
            echo -e "${CYAN}  → git clone $repo_url $repo_name${NC}"
        else
            echo "Klone Repository..."
            git clone "$repo_url" "$repo_name"
        fi
    fi
}

# Funktion: PKGBUILD für gnome-shell anpassen
patch_gnome_shell_pkgbuild() {
    echo -e "\n${YELLOW}=== Passe gnome-shell PKGBUILD an ===${NC}"
    
    if [ ! -d "$WORK_DIR/gnome-shell" ]; then
        echo -e "${RED}Fehler: gnome-shell Verzeichnis existiert nicht${NC}"
        return 1
    fi
    
    cd "$WORK_DIR/gnome-shell" || exit 1
    
    # Prüfen ob Patch bereits hinzugefügt wurde
    if grep -q "Shell_BlurEffect__rounded_corners_mask.patch" PKGBUILD 2>/dev/null; then
        echo "PKGBUILD ist bereits angepasst"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN] Würde PKGBUILD anpassen:${NC}"
        echo -e "${CYAN}  → Backup erstellen: PKGBUILD.original${NC}"
        echo -e "${CYAN}  → Patch-URL zur source() hinzufügen${NC}"
        echo -e "${CYAN}  → b2sums auf SKIP setzen${NC}"
        echo -e "${CYAN}  → 'patch -Np1' zur prepare() hinzufügen${NC}"
        echo -e "${GREEN}✓ [DRY-RUN] gnome-shell PKGBUILD würde angepasst${NC}"
        return 0
    fi
    
    # Backup erstellen
    cp PKGBUILD PKGBUILD.original
    
    # Patch-URL zur source() hinzufügen
    awk -v patch="  \"$GNOME_SHELL_PATCH\"\n" '
        /^source=\(/ { in_source=1 }
        in_source && /^\)/ { 
            printf "%s", patch
            in_source=0
        }
        { print }
    ' PKGBUILD > PKGBUILD.tmp
    mv PKGBUILD.tmp PKGBUILD
    
    # b2sums auf SKIP setzen
    sed -i "/^b2sums=(/,/)/ c\\b2sums=('SKIP'\n        'SKIP'\n        'SKIP'\n        'SKIP'\n        'SKIP')" PKGBUILD
    
    # Patch in prepare() hinzufügen
    sed -i '/cd \$pkgbase/a\  patch -Np1 -i ../Shell_BlurEffect__rounded_corners_mask.patch' PKGBUILD
    
    echo -e "${GREEN}✓ gnome-shell PKGBUILD angepasst${NC}"
}

# Funktion: PKGBUILD für blur-my-shell anpassen
patch_blur_my_shell_pkgbuild() {
    echo -e "\n${YELLOW}=== Passe blur-my-shell PKGBUILD an ===${NC}"
    
    if [ ! -d "$WORK_DIR/gnome-shell-extension-blur-my-shell-git" ]; then
        echo -e "${RED}Fehler: blur-my-shell Verzeichnis existiert nicht${NC}"
        return 1
    fi
    
    cd "$WORK_DIR/gnome-shell-extension-blur-my-shell-git" || exit 1
    
    # Prüfen ob Patch bereits hinzugefügt wurde
    if grep -q "Add_corner_radius_to_NativeDynamicBlurEffect.patch" PKGBUILD 2>/dev/null; then
        echo "PKGBUILD ist bereits angepasst"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN] Würde PKGBUILD anpassen:${NC}"
        echo -e "${CYAN}  → Backup erstellen: PKGBUILD.original${NC}"
        echo -e "${CYAN}  → Patch-URL zur source() hinzufügen${NC}"
        echo -e "${CYAN}  → sha256sums auf SKIP setzen${NC}"
        echo -e "${CYAN}  → 'patch -Np1' zur prepare() hinzufügen${NC}"
        echo -e "${GREEN}✓ [DRY-RUN] blur-my-shell PKGBUILD würde angepasst${NC}"
        return 0
    fi
    
    # Backup erstellen
    cp PKGBUILD PKGBUILD.original

    # Patch-Dateinamen aus URL extrahieren
    local patch_filename=$(basename "$BLUR_MY_SHELL_PATCH")

    # Patch-URL zur source() hinzufügen
    sed -i "s|^source=('git+https://github.com/aunetx/blur-my-shell.git')|source=('git+https://github.com/aunetx/blur-my-shell.git'\n        '$BLUR_MY_SHELL_PATCH')|" PKGBUILD

    # sha256sums auf SKIP setzen
    sed -i "s/^sha256sums=('SKIP')/sha256sums=('SKIP'\n            'SKIP')/" PKGBUILD

    # Patch in prepare() hinzufügen (nur einmal, nach der cd Zeile) - mit dynamischem Dateinamen
    sed -i "/^prepare() {$/,/^}$/ { /cd blur-my-shell$/a\\  patch -Np1 -i ../$patch_filename
}" PKGBUILD
    
    echo -e "${GREEN}✓ blur-my-shell PKGBUILD angepasst${NC}"
}

# Funktion: Pakete bauen
build_package() {
    local pkg_name=$1
    local pkg_dir=$2

    echo -e "\n${YELLOW}=== Baue $pkg_name ===${NC}"

    if [ ! -d "$WORK_DIR/$pkg_dir" ]; then
        echo -e "${RED}Fehler: Verzeichnis $pkg_dir existiert nicht${NC}"
        return 1
    fi

    cd "$WORK_DIR/$pkg_dir" || exit 1

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN] Würde alte Build-Dateien bereinigen:${NC}"
        echo -e "${CYAN}  → rm -rf src/ pkg/ *.pkg.tar.zst${NC}"
        echo -e "\n${CYAN}[DRY-RUN] Würde Paket bauen und installieren:${NC}"
        echo -e "${CYAN}  → makepkg -si${NC}"
        echo -e "${GREEN}✓ [DRY-RUN] $pkg_name würde gebaut und installiert${NC}"
        return 0
    fi

    # Alte Builds bereinigen
    echo "Bereinige alte Build-Dateien..."
    rm -rf src/ pkg/ *.pkg.tar.zst

    # Paket bauen und installieren
    echo -e "\n${GREEN}Starte makepkg -si für $pkg_name...${NC}"
    makepkg -si

    local result=$?
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ $pkg_name erfolgreich gebaut und installiert${NC}"
        return 0
    else
        echo -e "${RED}✗ Fehler beim Bauen von $pkg_name${NC}"
        return 1
    fi
}

# Funktion: Blur-my-shell Extension ins User-Verzeichnis kopieren
copy_blur_extension() {
    echo -e "\n${YELLOW}=== Kopiere blur-my-shell Extension ins User-Verzeichnis ===${NC}"

    local source_dir="$WORK_DIR/gnome-shell-extension-blur-my-shell-git/pkg/gnome-shell-extension-blur-my-shell-git/usr/share/gnome-shell/extensions/blur-my-shell@aunetx"
    local target_dir="$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx"
    local schema_source="$WORK_DIR/gnome-shell-extension-blur-my-shell-git/pkg/gnome-shell-extension-blur-my-shell-git/usr/share/glib-2.0/schemas"

    # Prüfe ob UI-Patch verwendet wird (anhand des Dateinamens)
    local is_ui_patch=false
    if [[ "$BLUR_MY_SHELL_PATCH" == *"_UI.patch" ]]; then
        is_ui_patch=true
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN] Würde Extension kopieren:${NC}"
        echo -e "${CYAN}  Von: $source_dir${NC}"
        echo -e "${CYAN}  Nach: $target_dir${NC}"
        if [ "$is_ui_patch" = true ]; then
            echo -e "${CYAN}[DRY-RUN] UI-Patch erkannt - würde Schemas kopieren und kompilieren${NC}"
        fi
        echo -e "${GREEN}✓ [DRY-RUN] Extension würde kopiert${NC}"
        return 0
    fi

    if [ ! -d "$source_dir" ]; then
        echo -e "${RED}Fehler: Source-Verzeichnis existiert nicht: $source_dir${NC}"
        return 1
    fi

    # Zielverzeichnis erstellen falls nicht vorhanden
    mkdir -p "$(dirname "$target_dir")"

    # Extension kopieren und überschreiben
    echo "Kopiere Extension..."
    cp -rf "$source_dir" "$(dirname "$target_dir")/"

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Fehler beim Kopieren der Extension${NC}"
        return 1
    fi

    # Schemas kopieren und kompilieren (nur bei UI-Patch)
    if [ "$is_ui_patch" = true ]; then
        echo "UI-Patch erkannt - kopiere und kompiliere Schemas..."
        mkdir -p "$target_dir/schemas"
        cp -f "$schema_source"/*.gschema.xml "$target_dir/schemas/"

        if [ $? -eq 0 ]; then
            glib-compile-schemas "$target_dir/schemas/"

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Schemas erfolgreich kompiliert${NC}"
            else
                echo -e "${YELLOW}⚠ Warnung: Schema-Kompilierung fehlgeschlagen${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Warnung: Schema-Kopie fehlgeschlagen${NC}"
        fi
    fi

    echo -e "${GREEN}✓ Extension erfolgreich kopiert nach: $target_dir${NC}"
    return 0
}

# Hauptablauf
main() {
    # 1. Repositories aktualisieren
    if [ "$BUILD_GNOME_SHELL" = true ]; then
        update_repo "https://gitlab.archlinux.org/archlinux/packaging/packages/gnome-shell.git" "gnome-shell"
    fi

    if [ "$BUILD_BLUR_MY_SHELL" = true ]; then
        update_repo "https://aur.archlinux.org/gnome-shell-extension-blur-my-shell-git.git" "gnome-shell-extension-blur-my-shell-git"
    fi

    # 2. PKGBUILDs anpassen
    if [ "$BUILD_GNOME_SHELL" = true ]; then
        patch_gnome_shell_pkgbuild
    fi

    if [ "$BUILD_BLUR_MY_SHELL" = true ]; then
        patch_blur_my_shell_pkgbuild
    fi

    # 3. gnome-shell bauen und installieren
    if [ "$BUILD_GNOME_SHELL" = true ]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}    BAUE GNOME-SHELL${NC}"
        echo -e "${GREEN}========================================${NC}"

        if ! build_package "gnome-shell" "gnome-shell"; then
            echo -e "\n${RED}Abbruch: gnome-shell Build fehlgeschlagen${NC}"
            exit 1
        fi
    fi

    # 4. blur-my-shell bauen und installieren
    if [ "$BUILD_BLUR_MY_SHELL" = true ]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}    BAUE BLUR-MY-SHELL${NC}"
        echo -e "${GREEN}========================================${NC}"

        if ! build_package "blur-my-shell" "gnome-shell-extension-blur-my-shell-git"; then
            echo -e "\n${RED}Abbruch: blur-my-shell Build fehlgeschlagen${NC}"
            exit 1
        fi

        # 5. Blur-my-shell Extension ins User-Verzeichnis kopieren
        if ! copy_blur_extension; then
            echo -e "\n${RED}Warnung: Extension konnte nicht kopiert werden${NC}"
        fi
    fi

    # Fertig
    echo -e "\n${GREEN}========================================${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}    DRY-RUN ABGESCHLOSSEN${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "\n${YELLOW}Dies war ein Probelauf. Keine Änderungen wurden vorgenommen.${NC}"
        echo -e "${YELLOW}Führe das Skript ohne --dry-run aus, um die Pakete tatsächlich zu bauen.${NC}\n"
    else
        echo -e "${GREEN}    ALLE PAKETE ERFOLGREICH GEBAUT!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "\n${YELLOW}Die Änderungen erfordern eine Neuanmeldung.${NC}"

        # Abmelde-Abfrage
        echo -e "\n${CYAN}Möchtest du dich jetzt abmelden? [j/N]${NC}"
        read -r response

        if [[ "$response" =~ ^[jJyY]$ ]]; then
            echo -e "${GREEN}Melde ab...${NC}"
            gnome-session-quit --logout --no-prompt
        else
            echo -e "${YELLOW}Bitte melde dich später manuell ab, um die Änderungen zu aktivieren.${NC}\n"
        fi
    fi
}

# Skript ausführen
main