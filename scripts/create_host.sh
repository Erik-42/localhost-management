#!/bin/bash

base_dir="$HOME/Documents/Dev/www"

# ─────────────────────────
# Sélection : créer / modifier
# ─────────────────────────

echo "🔧 Que souhaitez-vous faire ?"
select action in "Créer un projet" "Modifier un projet" "Quitter"; do
    case $action in
        "Créer un projet")
            read -p "Nom du projet local (ex: monsite) : " project_name_input
            domain="${project_name_input}.local"
            project_path="${base_dir}/${domain}"
            vhost_path="/etc/apache2/sites-available/${domain}.conf"
            break
            ;;
        "Modifier un projet")
            echo "📂 Projets existants :"
            existing_projects=($(find "$base_dir" -maxdepth 1 -type d -exec basename {} \; | grep '\.local' | sort))
            if [ ${#existing_projects[@]} -eq 0 ]; then
                echo "❌ Aucun projet trouvé dans $base_dir"
                exit 1
            fi
            select project in "${existing_projects[@]}" "Annuler"; do
                if [ "$project" = "Annuler" ]; then
                    exit 0
                elif [[ " ${existing_projects[*]} " == *" $project "* ]]; then
                    domain="$project"
                    project_path="${base_dir}/${domain}"
                    vhost_path="/etc/apache2/sites-available/${domain}.conf"
                    break 2
                else
                    echo "❌ Choix invalide."
                fi
            done
            ;;
        "Quitter")
            exit 0
            ;;
    esac
done

# ─────────────────────────
# Demande du port
# ─────────────────────────

read -p "Port à utiliser (par défaut 80) : " port
port=${port:-80}

readme_file="$project_path/README.md"
index_file="$project_path/index.html"

# ─────────────────────────
# Mode modification
# ─────────────────────────

if [ -d "$project_path" ]; then
    echo "🛠️ Modification du projet $domain"
    echo "📋 Que voulez-vous faire ?"
    select choice in "Régénérer README/index.html" "Changer le port Apache" "Renommer le projet" "Annuler"; do
        case $choice in
            "Régénérer README/index.html")
                echo "# Projet $domain" > "$readme_file"
                echo "Mis à jour automatiquement le $(date)." >> "$readme_file"
                if ! command -v pandoc &> /dev/null; then
                    echo "❌ Pandoc est requis. sudo apt install pandoc"
                    exit 1
                fi
                readme_html=$(pandoc "$readme_file" -f markdown -t html)

                cat <<EOF > "$index_file"
<!DOCTYPE html>
<html>
  <head><meta charset="UTF-8"><title>$domain</title></head>
  <body>
    <h1>Bienvenue sur $domain</h1>
    <div>$readme_html</div>
  </body>
</html>
EOF
                echo "✅ README et index.html mis à jour."
                break
                ;;
            "Changer le port Apache")
                if ! grep -q "Listen $port" /etc/apache2/ports.conf; then
                    echo "Listen $port" | sudo tee -a /etc/apache2/ports.conf > /dev/null
                fi
                sudo tee "$vhost_path" > /dev/null <<EOF
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
                sudo systemctl reload apache2
                echo "✅ Port mis à jour."
                break
                ;;
            "Renommer le projet")
                read -p "Nouveau nom de projet (sans .local) : " new_name
                new_domain="${new_name}.local"
                new_path="${base_dir}/${new_domain}"
                new_vhost="/etc/apache2/sites-available/${new_domain}.conf"

                if [ -d "$new_path" ]; then
                    echo "❌ Le dossier $new_path existe déjà."
                    exit 1
                fi

                echo "📁 Renommage de $project_path → $new_path"
                mv "$project_path" "$new_path"

                echo "🛠️ Mise à jour des fichiers Apache"
                sudo a2dissite "${domain}.conf"
                sudo rm "$vhost_path"

                if ! grep -q "Listen $port" /etc/apache2/ports.conf; then
                    echo "Listen $port" | sudo tee -a /etc/apache2/ports.conf > /dev/null
                fi

                sudo tee "$new_vhost" > /dev/null <<EOF
<VirtualHost *:$port>
    ServerName $new_domain
    DocumentRoot $new_path

    <Directory $new_path>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${new_domain}-error.log
    CustomLog \${APACHE_LOG_DIR}/${new_domain}-access.log combined
</VirtualHost>
EOF

                echo "🧠 Mise à jour de /etc/hosts"
                sudo sed -i "/$domain/d" /etc/hosts
                echo "127.0.0.1 $new_domain" | sudo tee -a /etc/hosts > /dev/null

                sudo a2ensite "${new_domain}.conf"
                sudo systemctl reload apache2

                echo "✅ Projet renommé : $new_domain"
                exit 0
                ;;
            "Annuler")
                echo "❌ Annulé."
                exit 0
                ;;
        esac
    done
    exit 0
fi

# ─────────────────────────
# Création d’un nouveau projet
# ─────────────────────────

echo "📁 Création du projet $domain"
mkdir -p "$project_path"
echo "# Projet $domain" > "$readme_file"
echo "Créé automatiquement le $(date)." >> "$readme_file"

if ! command -v pandoc &> /dev/null; then
    echo "❌ Pandoc est requis. sudo apt install pandoc"
    exit 1
fi

readme_html=$(pandoc "$readme_file" -f markdown -t html)

cat <<EOF > "$index_file"
<!DOCTYPE html>
<html>
  <head><meta charset="UTF-8"><title>$domain</title></head>
  <body>
    <h1>Bienvenue sur $domain</h1>
    <div>$readme_html</div>
  </body>
</html>
EOF

chown -R "$USER:$USER" "$project_path"
chmod -R 755 "$project_path"
chmod +x "$HOME" "$HOME/Documents" "$HOME/Documents/Dev" "$base_dir"

if ! grep -q "Listen $port" /etc/apache2/ports.conf; then
    echo "Listen $port" | sudo tee -a /etc/apache2/ports.conf > /dev/null
fi

sudo tee "$vhost_path" > /dev/null <<EOF
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

if ! grep -q "$domain" /etc/hosts; then
    echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts > /dev/null
fi

sudo a2ensite "${domain}.conf"
sudo systemctl reload apache2

echo "✅ Projet http://$domain:$port créé avec succès !"

