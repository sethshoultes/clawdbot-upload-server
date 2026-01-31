# WordPress REST API Patterns

Quick reference for WordPress REST API endpoints used by the wp-publish skill. All commands use `curl` with Application Password authentication.

## Authentication

All requests use HTTP Basic Auth with the WordPress username and Application Password:

```bash
-u "${WP_USERNAME}:${WP_APP_PASSWORD}"
```

## Posts

### Create Post
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d @/tmp/wp-post.json
```

Post JSON fields:
```json
{
  "title": "Post Title",
  "content": "<!-- wp:paragraph --><p>Content</p><!-- /wp:paragraph -->",
  "excerpt": "Brief summary",
  "status": "draft",
  "slug": "url-slug",
  "categories": [1, 5],
  "tags": [10, 15],
  "featured_media": 123,
  "format": "standard",
  "meta": {}
}
```

**Status values:** `draft`, `publish`, `pending`, `private`, `future`

For scheduled posts, set `status: "future"` and add `"date": "2025-03-15T09:00:00"`.

### Update Post
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Title", "content": "Updated content"}'
```

### Get Posts
```bash
# Recent posts
curl -s "${WP_SITE_URL}/wp-json/wp/v2/posts?per_page=10&orderby=date&order=desc" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"

# Search posts
curl -s "${WP_SITE_URL}/wp-json/wp/v2/posts?search=keyword" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"

# Filter by category
curl -s "${WP_SITE_URL}/wp-json/wp/v2/posts?categories=5" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"

# Get single post
curl -s "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"
```

### Delete Post
```bash
# Move to trash
curl -s -X DELETE "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"

# Permanent delete
curl -s -X DELETE "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}?force=true" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"
```

## Pages

### Create Page
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Page Title",
    "content": "Page content",
    "status": "draft",
    "parent": 0,
    "template": ""
  }'
```

## Media

### Upload Image
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/media" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Disposition: attachment; filename=image.jpg" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/path/to/image.jpg
```

Content-Type by extension:
- `.jpg`, `.jpeg` → `image/jpeg`
- `.png` → `image/png`
- `.gif` → `image/gif`
- `.webp` → `image/webp`
- `.svg` → `image/svg+xml`
- `.pdf` → `application/pdf`
- `.mp4` → `video/mp4`

### Update Media Alt Text
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/media/{MEDIA_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"alt_text": "Descriptive alt text", "caption": "Image caption"}'
```

## Categories

### List Categories
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/categories?per_page=100" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" | jq '.[] | {id, name, slug, count}'
```

### Create Category
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/categories" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"name": "Category Name", "slug": "category-slug", "description": "Category description", "parent": 0}'
```

## Tags

### List Tags
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/tags?per_page=100&search=keyword" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" | jq '.[] | {id, name, slug}'
```

### Create Tag
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/tags" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"name": "Tag Name"}'
```

## SEO Metadata

### Yoast SEO
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "meta": {
      "_yoast_wpseo_title": "SEO Title — %%sitename%%",
      "_yoast_wpseo_metadesc": "Meta description under 160 characters",
      "_yoast_wpseo_focuskw": "target keyword",
      "_yoast_wpseo_canonical": "https://example.com/canonical-url"
    }
  }'
```

Yoast title variables: `%%title%%`, `%%sitename%%`, `%%sep%%`, `%%primary_category%%`

### RankMath SEO
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "meta": {
      "rank_math_title": "SEO Title %sep% %sitename%",
      "rank_math_description": "Meta description under 160 characters",
      "rank_math_focus_keyword": "target keyword",
      "rank_math_canonical_url": "https://example.com/canonical-url",
      "rank_math_robots": ["index", "follow"]
    }
  }'
```

## Gutenberg Block Markup

Standard block patterns for content conversion:

```html
<!-- Paragraph -->
<!-- wp:paragraph -->
<p>Text content here.</p>
<!-- /wp:paragraph -->

<!-- Heading (H2) -->
<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">Heading Text</h2>
<!-- /wp:heading -->

<!-- Heading (H3) -->
<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Subheading Text</h3>
<!-- /wp:heading -->

<!-- Unordered List -->
<!-- wp:list -->
<ul class="wp-block-list">
<li>Item one</li>
<li>Item two</li>
</ul>
<!-- /wp:list -->

<!-- Ordered List -->
<!-- wp:list {"ordered":true} -->
<ol class="wp-block-list">
<li>First</li>
<li>Second</li>
</ol>
<!-- /wp:list -->

<!-- Image -->
<!-- wp:image {"id":123,"sizeSlug":"large"} -->
<figure class="wp-block-image size-large">
<img src="https://example.com/image.jpg" alt="Alt text" class="wp-image-123"/>
<figcaption class="wp-element-caption">Caption text</figcaption>
</figure>
<!-- /wp:image -->

<!-- Quote -->
<!-- wp:quote -->
<blockquote class="wp-block-quote">
<p>Quote text here.</p>
<cite>Attribution</cite>
</blockquote>
<!-- /wp:quote -->

<!-- Code Block -->
<!-- wp:code -->
<pre class="wp-block-code"><code>code here</code></pre>
<!-- /wp:code -->

<!-- Separator -->
<!-- wp:separator -->
<hr class="wp-block-separator has-alpha-channel-opacity"/>
<!-- /wp:separator -->

<!-- Table -->
<!-- wp:table -->
<figure class="wp-block-table">
<table>
<thead><tr><th>Header 1</th><th>Header 2</th></tr></thead>
<tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody>
</table>
</figure>
<!-- /wp:table -->
```

## Useful Queries

### Check REST API availability
```bash
curl -s "${WP_SITE_URL}/wp-json/" | jq '.name, .description, .url'
```

### List available post types
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/types" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" | jq 'keys'
```

### Get site settings
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/settings" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"
```

### List users (for author assignment)
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/users?per_page=50" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" | jq '.[] | {id, name, slug}'
```

## Error Codes

| Code | Meaning |
|---|---|
| 200 | Success (GET, UPDATE) |
| 201 | Created (POST) |
| 400 | Bad request (check JSON) |
| 401 | Auth failed (check credentials) |
| 403 | Forbidden (insufficient role) |
| 404 | Not found (check URL/ID) |
| 413 | Payload too large (reduce file size) |
| 500 | Server error (check WP logs) |
| `rest_cannot_create` | Missing required fields or bad values |
| `rest_post_invalid_id` | Post ID doesn't exist |
| `rest_upload_no_data` | Empty file upload |
