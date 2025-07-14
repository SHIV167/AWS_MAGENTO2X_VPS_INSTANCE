# Shiv Ayurveda Theme Setup

This guide covers installing and configuring the custom **Shiv Ayurveda** theme in Magento 2.

## 1. Directory Structure

```
app/design/frontend/Shiv/ayurveda/
├── composer.json
├── etc/view.xml
├── Magento_Theme/
│   ├── layout/default.xml
│   └── templates/html/
│       ├── promo_top.phtml
│       └── custom_footer.phtml
├── registration.php
├── theme.xml
├── web/
│   └── css/
│       └── source/_extend.less
└── media/preview.png      # optional theme preview image
```

## 2. Installation Steps

1. Place the theme folder:  
   Copy `Shiv/ayurveda` into `app/design/frontend`.

2. Upgrade setup:  
   ```bash
   docker-compose exec php bash -lc "bin/magento setup:upgrade"
   ```

3. Enable the theme:  
   ```bash
   THEME_ID=$(docker-compose exec php bash -lc "bin/magento theme:show | grep 'Shiv Ayurveda Theme' | awk '{print $1}'")
   docker-compose exec php bash -lc "bin/magento config:set design/theme/theme_id $THEME_ID"
   ```

4. Deploy static content:  
   ```bash
   docker-compose exec php bash -lc "bin/magento setup:static-content:deploy -f"
   ```

5. Flush cache:  
   ```bash
   docker-compose exec php bash -lc "bin/magento cache:flush"
   ```

## 3. Development Mode (Optional)

For live CSS/LESS updates without redeploy:
```bash
docker-compose exec php bash -lc "bin/magento deploy:mode:set developer"
```  
After edits, flush cache:
```bash
docker-compose exec php bash -lc "bin/magento cache:flush"
```

## 4. Customization Points

- **Promo bar**: `Magento_Theme/templates/html/promo_top.phtml`  
- **Navigation**: `Magento_Theme/layout/default.xml` (uses default topmenu block)
- **Footer**: `Magento_Theme/templates/html/custom_footer.phtml`
- **Styles**: `web/css/source/_extend.less`

## 5. Homepage Override

The theme overrides the default Magento homepage to include a backend-managed slider and a category carousel.

1. **Create Slider Block**: In Admin → Content → Blocks, create a static block with identifier `homepage_slider`. Insert your slider markup (e.g., Owl/Slick HTML) into this block.

2. **Layout Override**: The file `app/design/frontend/Shiv/ayurveda/Magento_Theme/layout/cms_index_index.xml` replaces the default CMS page and loads:
   - `home.phtml` (`Magento_Theme/templates/html/home/home.phtml`)
   - `category_slider.phtml` (`Magento_Catalog/templates/home/category_slider.phtml`)

3. **Customize Category**: To change the product category displayed, update the `<argument name="category_id">` value in `cms_index_index.xml`.

4. **Deploy**: Run static content deploy and clear caches:
```bash
docker-compose exec php bash -lc "bin/magento setup:static-content:deploy -f && bin/magento cache:clean"
```


## 6. Notes

- If you add new static assets (images, fonts), place under `web/` and rerun static deploy.
- To preview theme in Admin, upload `media/preview.png` and refresh Themes list.

Enjoy your new Shiv Ayurveda theme! If you hit any issues, consult logs or flush caches as needed.
