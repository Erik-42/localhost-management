#!/bin/bash

WWW_PATH="$HOME/Documents/Dev/www"
SITES_PATH="/etc/apache2/sites-available"
HOSTS_FILE="/etc/hosts"

function list_projects() {
    find "$WWW_PATH" -maxdepth 1 -type d -name "*.local" -exec basename {} \;
}

function create_project() {
    read -p "Nom du projet (sans .local) : " name
    domain="${name}.local"
    read -p "Port (par défaut 80) : " port
    port=${port:-80}
    project_path="$WWW_PATH/$domain"
    vhost_file="$SITES_PATH/$domain.conf"

    if [ -d "$project_path" ]; then
        echo "❌ Le projet existe déjà."
        return
    fi

    mkdir -p "$project_path"
    echo "# Projet $domain" > "$project_path/README.md"
    echo "Créé automatiquement le $(date)." >> "$project_path/README.md"

    cat <<EOF > "$project_path/index.html"
<!DOCTYPE html>
<html>
  <head><title>$domain</title></head>
  <body>
    <h1>Bienvenue sur $domain</h1>
    <pre>$(cat "$project_path/README.md")</pre>
  </body>
</html>
EOF

    chmod -R 755 "$project_path"
    chown -R "$USER:$USER" "$project_path"

    for d in "$HOME" "$HOME/Documents" "$HOME/Documents/Dev" "$WWW_PATH"; do
        chmod +x "$d"
    done

    sudo tee "$vhost_file" > /dev/null <<EOF
<VirtualHost *:$port>
    ServerName $domain
    DocumentRoot $project_path

    <Directory $project_path>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain}-error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}-access.log combined
</VirtualHost>
EOF

    if ! grep -q "$domain" "$HOSTS_FILE"; then
        echo "127.0.0.1 $domain" | sudo tee -a "$HOSTS_FILE" > /dev/null
    fi

    sudo a2ensite "${domain}.conf"
    sudo systemctl reload apache2

    echo "✅ Projet http://$domain:$port créé avec succès."
}

function modify_project() {
    echo "Projets existants :"
    list_projects
    read -p "Nom exact du projet à modifier (ex: monsite.local) : " old_domain
    old_path="$WWW_PATH/$old_domain"
    old_vhost="$SITES_PATH/$old_domain.conf"

    if [ ! -d "$old_path" ]; then
        echo "❌ Projet non trouvé."
        return
    fi

    read -p "Nouveau nom (sans .local, laisser vide pour ne pas changer) : " new_name
    read -p "Nouveau port (laisser vide pour ne pas changer) : " new_port

    new_domain=${new_name:-$old_domain}
    [[ "$new_domain" != "$old_domain" ]] && new_domain="${new_name}.local"
    new_path="$WWW_PATH/$new_domain"
    new_vhost="$SITES_PATH/$new_domain.conf"

    if [[ "$new_domain" != "$old_domain" ]]; then
        mv "$old_path" "$new_path"
        sudo mv "$old_vhost" "$new_vhost"
        sudo sed -i "s/$old_domain/$new_domain/g" "$new_vhost"
        sudo sed -i "s|$old_path|$new_path|g" "$new_vhost"
        sudo sed -i "s/$old_domain/$new_domain/g" "$HOSTS_FILE"
    fi

    if [ -n "$new_port" ]; then
        sudo sed -i "s/<VirtualHost \*:.*>/<VirtualHost *:$new_port>/" "$new_vhost"
    fi

    sudo a2dissite "$old_domain.conf"
    sudo a2ensite "$new_domain.conf"
    sudo systemctl reload apache2

    echo "✅ Projet modifié avec succès : http://$new_domain:$new_port"
}

function delete_project() {
    echo "Projets existants :"
    list_projects
    read -p "Nom exact du projet à supprimer (ex: monsite.local) : " domain
    project_path="$WWW_PATH/$domain"
    vhost_file="$SITES_PATH/$domain.conf"

    if [ ! -d "$project_path" ]; then
        echo "❌ Projet introuvable."
        return
    fi

    sudo a2dissite "$domain.conf"
    sudo rm -f "$vhost_file"
    sudo sed -i "/$domain/d" "$HOSTS_FILE"
    rm -rf "$project_path"
    sudo systemctl reload apache2

    echo "🗑️ Projet $domain supprimé avec succès."
}

function generate_dashboard() {
    dashboard_path="$WWW_PATH/dashboard.local"
    dashboard_file="$dashboard_path/index.html"

    mkdir -p "$dashboard_path"

    cat <<EOF > "$dashboard_file"
<!DOCTYPE html>
<html>
  <head><title>Dashboard local</title></head>
  <body>
    <h1>Projets locaux</h1>
    <ul>
EOF

    for d in $(list_projects); do
        echo "      <li><a href=\"http://$d\">$d</a></li>" >> "$dashboard_file"
    done

    cat <<EOF >> "$dashboard_file"
    </ul>
  </body>
</html>
EOF

    vhost_file="$SITES_PATH/dashboard.local.conf"
    sudo tee "$vhost_file" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName dashboard.local
    DocumentRoot $dashboard_path

    <Directory $dashboard_path>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

    if ! grep -q "dashboard.local" "$HOSTS_FILE"; then
        echo "127.0.0.1 dashboard.local" | sudo tee -a "$HOSTS_FILE" > /dev/null
    fi

    sudo a2ensite "dashboard.local.conf"
    sudo systemctl reload apache2
    echo "📊 Dashboard local disponible : http://dashboard.local"
}

function main_menu() {
    while true; do
        echo ""
        echo "=== GESTION DES PROJETS LOCAUX ==="
        echo "1) Créer un projet"
        echo "2) Modifier un projet"
        echo "3) Supprimer un projet"
        echo "4) Générer dashboard.local"
        echo "5) Quitter"
        read -p "Choix : " choice

        case $choice in
            1) create_project ;;
            2) modify_project ;;
            3) delete_project ;;
            4) generate_dashboard ;;
            5) exit 0 ;;
            *) echo "❌ Choix invalide" ;;
        esac
    done
}

main_menu

