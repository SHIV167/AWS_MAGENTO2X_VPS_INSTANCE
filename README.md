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

## 6. Container Nginx vhost
`config/nginx.conf`:
```nginx
server {
  listen 80;
  server_name magento.shivjha.online www.magento.shivjha.online;
  set $MAGE_ROOT /var/www/html;
  set $MAGE_MODE developer; # change to production
  include /var/www/html/nginx.conf.sample;
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
- (Optional) Add Redis for session & page cache
- Harden Nginx headers (HSTS, X-Frame-Options, etc.)
- Configure SMTP (e.g. Mageplaza SMTP)
- (Optional) Install sample data
- Backup (DB dumps, media) & monitoring
- Regular security patches and updates

---

Enjoy your Magento 2 environment! If you hit any issues, consult logs (`docker-compose logs`, `/var/log/nginx`, `/var/log/letsencrypt`) or ask for help.
