# Magento 2 on Docker (Ubuntu EC2) with Nginx, OpenSearch & SSL

This guide covers end-to-end setup of Magento 2 (latest) on an AWS Ubuntu EC2 instance using Docker, Nginx, OpenSearch, SSL (Let's Encrypt) and phpMyAdmin.

## Prerequisites
- AWS EC2 Ubuntu 20.04+ instance
- Security Group opens: 22, 80, 443, 9200, 8081
- SSH keypair
- Magento Marketplace Access Keys (Public & Private)

## 1. SSH & Docker
```bash
ssh ubuntu@<EC2_IP>
# Install Docker & Compose
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
# Add ubuntu to docker group
# Add ubuntu to docker group
sudo usermod -aG docker ubuntu

# Refresh your groups in this session
newgrp docker

# Verify you can now run docker
docker ps
docker-compose ps
# log out/in or `newgrp docker`

sudo docker-compose down
sudo docker-compose up -d --build
```

## 2. Project Skeleton
mkdir -p ~/magento2/{src,config} && cd ~/magento2
```text
magento2/
├── auth.json            # repo.magento.com credentials
├── Dockerfile           # PHP-FPM + extensions + Composer
├── docker-compose.yml   # services: php, db, opensearch, nginx, phpmyadmin
├── config/
│   └── nginx.conf       # container Nginx vhost
└── src/                 # Magento application code (initially empty)
```

## 3. auth.json
Create `auth.json` in project root:
```json
{
  "http-basic": {
    "repo.magento.com": {
      "username": "<PUBLIC_KEY>",
      "password": "<PRIVATE_KEY>"
    }
  }
}
```

## 4. Dockerfile
Reviews PHP 8.2-FPM image, required `apt` packages (gd, intl, ftp, curl, zip, xml, icu…), installs Redis, Composer, and prepares `/var/www/.composer` for auth.json.

## 5. docker-compose.yml
Defines services:
- **php**: builds from Dockerfile, mounts `src` & `auth.json`
- **db**: MySQL 8.0 with credentials
- **opensearch**: single-node (9200)
- **nginx**: container Nginx proxy (host→8080)
- **phpmyadmin**: phpMyAdmin on port 8081

**Tip:** To speed up Docker builds and avoid host-level permission errors, add a `.dockerignore` file in the project root with:
```text
src/var
src/generated
src/pub/static
src/pub/media
src/vendor
```

## 6. Container Nginx vhost
`config/nginx.conf`:
```nginx
server {
    listen 80;
    server_name magento.shivjha.online www.magento.shivjha.online;
    set $MAGE_ROOT /var/www/html;
    root $MAGE_ROOT/pub;
    index index.php;

    # Bypass versioned static files (strip version prefix)
    location ~ ^/static/version\d*/ {
        rewrite ^/static/(version\d*/)?(.*)$ /static/$2 last;
    }

    # Serve static assets directly
    location /static/ {
        alias $MAGE_ROOT/pub/static/;
        expires max;
        add_header Cache-Control "public";
        try_files $uri $uri/ /static.php?resource=$uri;
    }

    # Serve media files directly
    location /media/ {
        alias $MAGE_ROOT/pub/media/;
        expires max;
        add_header Cache-Control "public";
        try_files $uri $uri/ =404;
    }

    # Handle URL rewrites: fall back to index.php if file/dir not found
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP-FPM via FastCGI
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass fastcgi_backend;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # Deny access to sensitive hidden files
    location ~* \.(htaccess|htpasswd)$ {
        deny all;
    }
}
```

## 7. Host Nginx & SSL
1. Create `/etc/nginx/sites-available/magento.shivjha.online`:
   ```nginx
   server {
     listen 80;
     server_name magento.shivjha.online www.magento.shivjha.online;
     location / {
       proxy_pass http://127.0.0.1:8080;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;

        # Prevent "upstream sent too big header" errors by increasing proxy buffers
        proxy_buffer_size           128k;
        proxy_buffers               4 256k;
        proxy_busy_buffers_size     256k;
        proxy_read_timeout          300;
        proxy_connect_timeout       300;
        proxy_send_timeout          300;
     }
   }
   ```
2. Enable & test:
   ```bash
   sudo ln -s /etc/nginx/sites-available/magento.shivjha.online /etc/nginx/
   sudo ln -s /etc/nginx/sites-available/magento.shivjha.online /etc/nginx/sites-enabled/
   sudo rm /etc/nginx/sites-enabled/default 
   sudo nginx -t && sudo systemctl reload nginx
   ls -l /etc/nginx/sites-enabled/
   ```
3. Obtain SSL:
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d magento.shivjha.online -d www.magento.shivjha.online


```

## 8. DNS
At your DNS provider, create A (or CNAME) records:
```
magento    A     <EC2_IP>
www.magento CNAME magento.shivjha.online
```
Verify:
```bash
dig +short magento.shivjha.online
dig +short www.magento.shivjha.online
```

## 9. Build & Launch Containers
```bash
`````````````````````````````````````````````
Add ubuntu to the docker group (so you can run docker without sudo):
# Add ubuntu to docker group
sudo usermod -aG docker ubuntu

# Refresh your groups in this session
newgrp docker

# Verify you can now run docker
docker ps
docker-compose ps

`````````````````````````````````````````
Or simply prefix your Docker commands with sudo:
sudo docker-compose down
sudo docker-compose up -d --build

````````````````````````````````


``````````````
sudo docker-compose up -d

``````````````

## 10. Scaffold Magento & Permissions
1. Empty `src/` if re-running:
   ```bash
   rm -rf src/*
   ```
2. Create project as root to avoid permissions errors:
   ```bash
docker-compose exec --user root php bash -lc "
  composer create-project --repository-url=https://repo.magento.com/ \
    magento/project-community-edition /var/www/html"
```
3. Fix ownership & permissions:
   ```bash
docker-compose exec --user root php bash -lc "
  chown -R www-data:www-data /var/www/html && \
  find var pub/static pub/media app/etc -type f -exec chmod 664 {} \; && \
  find var pub/static pub/media app/etc -type d -exec chmod 775 {} \; && \
  chmod u+x bin/magento"
```

# If you see cache or page_cache not writable errors after install, fix permissions:
```bash
# Ensure Magento var directory and subpaths are writable:
docker-compose exec --user root php bash -lc "
  cd /var/www/html &&
  chown -R www-data:www-data var &&
  find var -type d -exec chmod 770 {} \\; &&
  find var -type f -exec chmod 660 {} \\;
"
```

# If you see config.php not writable errors after upgrade, fix permissions:
```bash
docker-compose exec --user root php bash -lc "
  chown -R www-data:www-data app/etc &&
  find app/etc -type f -exec chmod 664 {} \\; &&
  find app/etc -type d -exec chmod 775 {} \\;
"
```

## 11. Magento Setup & Post-Install
```bash
docker-compose exec php bash -lc "bin/magento setup:install \
  --base-url=https://magento.shivjha.online/ \
  --db-host=db --db-name=magento --db-user=magento --db-password=magentopass \
  --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 \
  --opensearch-index-prefix=magento \
  --admin-firstname=Admin --admin-lastname=User --admin-email=admin@example.com \
  --admin-user=admin --admin-password=Admin123! --backend-frontname=admin"

# Post-install tasks
docker-compose exec php bash -lc "
  bin/magento setup:di:compile && \
  bin/magento setup:static-content:deploy -f && \
  bin/magento cache:flush"
```

## 12. phpMyAdmin
Accessible at `http://<EC2_IP>:8081`:
- Server: `db`
- Username: `magento`
- Password: `magentopass`

## 13. Next Steps
- Switch to production mode:
  ```bash
docker-compose exec php bin/magento deploy:mode:set production
```
- Configure cron jobs for Magento
- Add Varnish for full-page cache (see below)

## 14. Varnish Configuration
Magento supports Varnish for full-page caching. To enable:

1. Ensure the Varnish service is running:
```bash
docker-compose up -d varnish
```

2. Configure Magento to use Varnish (host: 127.0.0.1, port: 8080):
```bash
docker-compose exec php bash -lc \"bin/magento config:set system/full_page_cache/caching_application 2\"
docker-compose exec php bash -lc \"bin/magento config:set system/full_page_cache/varnish/access_list 127.0.0.1\"
docker-compose exec php bash -lc \"bin/magento config:set system/full_page_cache/varnish/backend_host 127.0.0.1\"
docker-compose exec php bash -lc \"bin/magento config:set system/full_page_cache/varnish/backend_port 8080\"
```

3. (Optional) Export Magento-generated VCL to `config/default.vcl`:
```bash
docker-compose exec php bash -lc \"bin/magento varnish:vcl:export > config/default.vcl\"
```

4. Flush Magento cache:
```bash
docker-compose exec php bash -lc \"bin/magento cache:flush\"
```

5. Test Varnish caching:
```bash
curl -I http://localhost:6081/<path>   # → X-Cache: MISS
curl -I http://localhost:6081/<path>   # → X-Cache: HIT
```

6. Purge Varnish cache:

```bash
# Purge Magento full-page cache (issues Varnish PURGE calls)
docker-compose exec php bash -lc "bin/magento cache:clean full_page"

# Direct PURGE via curl (must originate from 127.0.0.1):
curl -X PURGE http://127.0.0.1:6081/<path>
```

## 15. Install Sample Data (Optional)
Magento’s CLI can automatically register and install all sample-data modules:
```bash
# 1. Ensure composer.json and vendor are writable/owned by www-data
docker-compose exec --user root php bash -lc "
  cd /var/www/html &&
  chown www-data:www-data composer.json composer.lock &&
  chmod 664 composer.json composer.lock &&
  chown -R www-data:www-data vendor &&
  find vendor -type d -exec chmod 775 {} \\; &&
  find vendor -type f -exec chmod 664 {} \\;
"

# 2. Register sample data modules (runs as www-data; falls back to root if needed)
docker-compose exec php bash -lc "php bin/magento sampledata:deploy" \
  || docker-compose exec --user root php bash -lc "php bin/magento sampledata:deploy"

# 3. Update Composer dependencies & install sample-data packages
docker-compose exec --user root php bash -lc "composer update"

# 4. Upgrade schema/data, compile, deploy static content, and flush cache
docker-compose exec php bash -lc "php bin/magento setup:upgrade && \
  php bin/magento setup:di:compile && \
  php bin/magento setup:static-content:deploy -f && \
  php bin/magento cache:flush"
```

## Quick Setup CLI Commands (Docker CLI)

Below is a consolidated list of Docker Compose commands to run Magento setup & maintenance tasks:

```bash
# 1. Fix ownership & permissions
# Ensure var, vendor, config, and lock files are writable
docker-compose exec --user root php bash -lc "cd /var/www/html && \
  chown -R www-data:www-data var vendor composer.json composer.lock app/etc && \
  chmod -R 770 var vendor && \
  chmod 660 composer.json composer.lock app/etc"

# 2. Initial Magento installation
docker-compose exec php bash -lc "bin/magento setup:install \
  --base-url=https://magento.shivjha.online/ \
  --db-host=db --db-name=magento --db-user=magento --db-password=magentopass \
  --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 \
  --opensearch-index-prefix=magento \
  --admin-firstname=Admin --admin-lastname=User --admin-email=admin@example.com \
  --admin-user=admin --admin-password=Admin123! --backend-frontname=admin"

# 3. Post-install: compile, static deploy, flush cache
docker-compose exec php bash -lc "bin/magento setup:di:compile && \
  bin/magento setup:static-content:deploy -f && \
  bin/magento cache:flush"

# 4. Reindex & switch to production mode
docker-compose exec php bash -lc "bin/magento indexer:reindex"
docker-compose exec php bash -lc "bin/magento deploy:mode:set production"

# 5. (Optional) Run cron jobs to test scheduling
docker-compose exec php bash -lc "bin/magento cron:run"

# 6. Enable Web Server Rewrites (hide index.php)
docker-compose exec php bash -lc "bin/magento config:set web/seo/use_rewrites 1"
docker-compose exec php bash -lc "bin/magento cache:flush"
```

---

Enjoy your Magento 2 environment! If you hit any issues, consult logs (`docker-compose logs`, `/var/log/nginx`, `/var/log/letsencrypt`) or ask for help.
