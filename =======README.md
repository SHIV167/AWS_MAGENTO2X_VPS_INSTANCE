# Magento 2 on Docker (Ubuntu, AWS EC2, Nginx, OpenSearch)

This guide walks you through setting up Magento 2 (latest) on an Ubuntu EC2 instance using Docker, Nginx, and OpenSearch.

## Prerequisites

- AWS EC2 instance running Ubuntu 20.04+ with security group allowing ports: 22, 80, 443, 9200.
- SSH access to the instance.
- Docker & Docker Compose installed.
- Magento Marketplace Access Keys (Public & Private).

## Project Structure

```text
magento2/
├── auth.json            # Magento repo credentials
├── Dockerfile           # PHP-FPM image configuration
├── docker-compose.yml   # Docker services: php, db, opensearch, nginx
├── config/
│   └── nginx.conf       # Nginx vhost config
└── src/                 # Magento application code
``` 

## 1. SSH into EC2

```bash
ssh ubuntu@YOUR_PUBLIC_IP
```

## 2. Install Docker & Compose

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# then log out and back in
```

## 3. Create Project Directory

```bash
mkdir -p ~/magento2/{src,config} && cd ~/magento2
```

## 4. Add Magento Marketplace Keys

Create `auth.json` in project root:

```json
{
  "http-basic": {
    "repo.magento.com": {
      "username": "YOUR_PUBLIC_KEY",
      "password": "YOUR_PRIVATE_KEY"
    }
  }
}
```

## 5. Docker Configuration

### Dockerfile
Defines PHP 8.2-FPM with required extensions.

### docker-compose.yml
Services:
- **php**: builds from `Dockerfile`, mounts `src` & `auth.json`
- **db**: MySQL 8.0 database
- **opensearch**: single-node OpenSearch
- **nginx**: serves static and proxies PHP

## 6. Nginx Setup

Place in `config/nginx.conf`:

```nginx
server {
  listen 80;
  server_name YOUR_DOMAIN_OR_IP;
  set $MAGE_ROOT /var/www/html;
  set $MAGE_MODE developer; # or production
  include /var/www/html/nginx.conf.sample;
}
```

## 7. Launch Containers

```bash
docker-compose up -d
```

## 8. Install Magento via Composer

```bash
docker-compose exec php bash -c "
  composer create-project --repository-url=https://repo.magento.com/ \
    magento/project-community-edition /var/www/html"
```

## 9. File Permissions

```bash
docker-compose exec php bash -c "
  chown -R www-data:www-data /var/www/html && \
  find var pub/static pub/media app/etc -type f -exec chmod 664 {} \; && \
  find var pub/static pub/media app/etc -type d -exec chmod 775 {} \; && \
  chmod u+x bin/magento"
```

## 10. Magento Setup (with OpenSearch)

```bash
docker-compose exec php bash -c "
  bin/magento setup:install \
    --base-url=http://YOUR_PUBLIC_IP/ \
    --db-host=db \
    --db-name=magento \
    --db-user=magento \
    --db-password=magentopass \
    --search-engine=opensearch \
    --elasticsearch-host=opensearch \
    --elasticsearch-port=9200 \
    --elasticsearch-index-prefix=magento \
    --admin-firstname=Admin \
    --admin-lastname=User \
    --admin-email=admin@example.com \
    --admin-user=admin \
    --admin-password=Admin123! \
    --backend-frontname=admin"
```

## 11. Post-install Tasks

```bash
docker-compose exec php bash -c "
  bin/magento setup:di:compile && \
  bin/magento setup:static-content:deploy -f && \
  bin/magento cache:flush"
```

## 12. Accessing Your Store

- Frontend: http://YOUR_PUBLIC_IP/
- Admin:    http://YOUR_PUBLIC_IP/admin

## Troubleshooting

- Ensure Docker daemon is running.
- Verify file permissions.
- Check container logs: `docker-compose logs -f`.

---

Enjoy your Magento 2 setup! Feel free to open issues or request help.

## 13. Domain Setup & SSL

1. DNS
   - At your DNS provider, create an A record for `magento.shivjha.online` (and `www`) pointing to your EC2 public IP.

2. Update Docker Compose Nginx port
   - In `docker-compose.yml`, under the `nginx` service, change to:
     ```yaml
     ports:
       - "8080:80"
     ```
   - Recreate the service:
     ```bash
     docker-compose up -d nginx
     ```

3. Install host Nginx
   ```bash
   sudo apt update
   sudo apt install -y nginx
   ```

4. Configure host-level Nginx
   Create `/etc/nginx/sites-available/magento.shivjha.online`:
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
   Enable & test:
   ```bash
   sudo ln -s /etc/nginx/sites-available/magento.shivjha.online /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

5. Obtain SSL with Certbot
   ```bash
   sudo apt install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d magento.shivjha.online -d www.magento.shivjha.online
   ```

6. Verify
   - Visit `https://magento.shivjha.online` to confirm SSL.
   - Certbot auto-renewal is configured via systemd timer.

