---
name: wp-publish
version: 1.0.0
description: When the user wants to publish content to a WordPress site. Also use when the user mentions "publish to WordPress," "WordPress post," "wp publish," "blog post to WordPress," "create WordPress post," "upload to WordPress," "publish article," "WordPress draft," or "push to WordPress." This skill publishes content via the WordPress REST API, supporting posts, pages, media uploads, categories, tags, featured images, and SEO metadata (Yoast/RankMath). Chains with content-pipeline output.
---

# WordPress Publish

You are an expert WordPress publishing assistant. Your goal is to take content (raw text, HTML, or a content-pipeline artifact) and publish it to a WordPress site via the REST API using `curl`.

## Initial Assessment

**Check for product marketing context first:**
If `.claude/product-marketing-context.md` exists, read it before asking questions. Use that context and only ask for information not already covered or specific to this task.

Before publishing, understand:

1. **Content Source**
   - Is this a new post to write from scratch?
   - An existing HTML artifact from content-pipeline (in `~/clawd/canvas/`)?
   - Raw text or markdown to convert?

2. **Publication Settings**
   - Publish immediately, or save as **draft** for review? (default: draft)
   - Post type: post or page?
   - Category and tag assignments?
   - Featured image (upload a file or use existing media)?

3. **SEO (if Yoast or RankMath installed)**
   - Target keyword?
   - Custom meta title and description?

---

## Prerequisites

### WordPress Application Password

This skill requires a WordPress Application Password for REST API authentication.

**To create one:**
1. Log into WordPress Admin > Users > Profile
2. Scroll to "Application Passwords"
3. Enter a name (e.g., "ClawdBot") and click "Add New Application Password"
4. Copy the generated password (spaces included)

### Environment Variables (auto-configured)

WordPress credentials are pre-configured in `clawdbot.json` under `skills.entries.wp-publish.env`. ClawdBot automatically injects them as environment variables — **the user does NOT need to provide credentials in the chat prompt**.

| Variable | Description |
|---|---|
| `WP_SITE_URL` | WordPress site URL (no trailing slash) |
| `WP_USERNAME` | WordPress username |
| `WP_APP_PASSWORD` | Application password (with spaces) |

**At the start of every wp-publish invocation, read the credentials from env:**
```bash
# Read pre-configured credentials — do NOT ask the user for these
echo "WP_SITE_URL=$WP_SITE_URL"
echo "WP_USERNAME=$WP_USERNAME"
echo "WP_APP_PASSWORD is $([ -n "$WP_APP_PASSWORD" ] && echo 'set' || echo 'NOT SET')"
```

If any variable is empty, tell the user to configure them in `clawdbot.json`:
```json
{
  "skills": {
    "entries": {
      "wp-publish": {
        "enabled": true,
        "env": {
          "WP_SITE_URL": "https://example.com",
          "WP_USERNAME": "admin",
          "WP_APP_PASSWORD": "xxxx xxxx xxxx xxxx xxxx xxxx"
        }
      }
    }
  }
}
```

If the user provides credentials in the prompt (override), use those instead.

**Verify connectivity before publishing:**
```bash
curl -s -o /dev/null -w "%{http_code}" \
  "${WP_SITE_URL}/wp-json/wp/v2/posts?per_page=1" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"
```
Expected: `200`. If `401`, the credentials are wrong. If connection refused, check the URL.

---

## Core Workflow

### Step 1: Validate Connection

Run the connectivity check above. If it fails, stop and tell the user to verify their WordPress credentials.

Also check which plugins are available for SEO:
```bash
# Check for Yoast
curl -s "${WP_SITE_URL}/wp-json/yoast/v1/get_head?url=${WP_SITE_URL}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" -o /dev/null -w "%{http_code}"

# Check for RankMath
curl -s "${WP_SITE_URL}/wp-json/rankmath/v1/getHead?url=${WP_SITE_URL}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" -o /dev/null -w "%{http_code}"
```

### Step 2: Prepare Content

**If from content-pipeline artifact (HTML file in `~/clawd/canvas/`):**
1. Read the HTML file
2. Extract the article body content (inside `<article>` or `<main>` tags)
3. Convert to WordPress-compatible HTML (Gutenberg block format preferred)
4. Extract title, excerpt, and meta description from the article

**If from raw text or markdown:**
1. Convert markdown to HTML
2. Wrap in Gutenberg block markup:
   - Paragraphs: `<!-- wp:paragraph --><p>text</p><!-- /wp:paragraph -->`
   - Headings: `<!-- wp:heading {"level":2} --><h2>text</h2><!-- /wp:heading -->`
   - Lists: `<!-- wp:list --><ul><li>text</li></ul><!-- /wp:list -->`
   - Images: `<!-- wp:image --><figure class="wp-block-image"><img src="URL" alt="alt"/></figure><!-- /wp:image -->`
   - Blockquotes: `<!-- wp:quote --><blockquote class="wp-block-quote"><p>text</p></blockquote><!-- /wp:quote -->`

**If writing from scratch:**
1. Ask for the topic, angle, and key points
2. Draft the content
3. Format as Gutenberg blocks

### Step 3: Handle Categories and Tags

**List existing categories:**
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/categories?per_page=100" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" | jq '.[] | {id, name, slug}'
```

**Create a new category if needed:**
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/categories" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"name": "Category Name", "slug": "category-slug"}'
```

**List existing tags:**
```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/tags?per_page=100&search=keyword" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" | jq '.[] | {id, name}'
```

**Create a new tag if needed:**
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/tags" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"name": "Tag Name"}'
```

### Step 4: Upload Featured Image (if provided)

```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/media" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Disposition: attachment; filename=image.jpg" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/path/to/image.jpg
```

Save the returned `id` for use as `featured_media` in the post.

**Supported image types:** JPEG (`image/jpeg`), PNG (`image/png`), GIF (`image/gif`), WebP (`image/webp`)

### Step 5: Create the Post

Write the post JSON to a temporary file to avoid shell escaping issues:

```bash
cat > /tmp/wp-post.json << 'POSTEOF'
{
  "title": "Post Title Here",
  "content": "<!-- wp:paragraph --><p>Content here</p><!-- /wp:paragraph -->",
  "excerpt": "Brief summary for archives and search results",
  "status": "draft",
  "categories": [1, 5],
  "tags": [10, 15],
  "featured_media": 123,
  "slug": "post-url-slug"
}
POSTEOF

curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d @/tmp/wp-post.json
```

**Status options:** `draft` (default), `publish`, `pending` (for review), `private`

Save the returned post `id` and `link` for the next steps.

### Step 6: Set SEO Metadata (if Yoast or RankMath detected)

**Yoast SEO:**
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "meta": {
      "_yoast_wpseo_title": "SEO Title — %%sitename%%",
      "_yoast_wpseo_metadesc": "Meta description under 160 chars",
      "_yoast_wpseo_focuskw": "target keyword"
    }
  }'
```

**RankMath SEO:**
```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "meta": {
      "rank_math_title": "SEO Title %sep% %sitename%",
      "rank_math_description": "Meta description under 160 chars",
      "rank_math_focus_keyword": "target keyword"
    }
  }'
```

### Step 7: Confirm and Report

After creating the post, report back to the user:

- **Post ID:** The WordPress post ID
- **Status:** Draft, Published, or Pending Review
- **Edit URL:** `${WP_SITE_URL}/wp-admin/post.php?post={POST_ID}&action=edit`
- **View URL:** The post permalink (from the API response `link` field)
- **Categories and tags** assigned
- **Featured image** (if uploaded)
- **SEO metadata** (if set)

If status is `draft`, remind the user: "The post is saved as a draft. Log into WordPress to review and publish when ready."

---

## Publishing a Content-Pipeline Artifact

When chaining with the content-pipeline skill:

1. User runs content-pipeline to create an article → HTML saved to `~/clawd/canvas/article-*.html`
2. User invokes wp-publish, referencing the artifact
3. wp-publish reads the HTML, extracts the article body, title, and excerpt
4. Converts inline-styled HTML to Gutenberg blocks (strip `<style>` tags, keep semantic HTML)
5. Creates the WordPress post as a draft
6. Reports the draft URL for review

**Conversion rules for content-pipeline HTML:**
- `<h2>` → `<!-- wp:heading {"level":2} --><h2>text</h2><!-- /wp:heading -->`
- `<h3>` → `<!-- wp:heading {"level":3} --><h3>text</h3><!-- /wp:heading -->`
- `<p>` → `<!-- wp:paragraph --><p>text</p><!-- /wp:paragraph -->`
- `<blockquote>` → `<!-- wp:quote --><blockquote class="wp-block-quote"><p>text</p></blockquote><!-- /wp:quote -->`
- `<ul>/<ol>` → `<!-- wp:list --><ul>items</ul><!-- /wp:list -->`
- `<figure><img>` → `<!-- wp:image --><figure class="wp-block-image"><img src="..." alt="..."/></figure><!-- /wp:image -->`
- Strip all `<style>`, `<script>`, `<header>`, `<footer>`, `<nav>` tags
- Strip inline `style` attributes
- Preserve `<a>` links, `<strong>`, `<em>` formatting

---

## Creating Pages (instead of posts)

For WordPress pages, use the pages endpoint:

```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d @/tmp/wp-post.json
```

Pages don't support categories or tags but do support `parent` (page hierarchy) and `template` (page template slug).

---

## Output Format

### Chat Summary
After publishing, provide:
- Post title and status
- WordPress edit URL and preview URL
- Categories and tags assigned
- Featured image (if any)
- SEO metadata summary (if set)
- Next steps (review draft, add images, publish)

---

## Error Handling

| HTTP Code | Meaning | Fix |
|---|---|---|
| 401 | Authentication failed | Check WP_USERNAME and WP_APP_PASSWORD |
| 403 | Insufficient permissions | User needs Editor or Administrator role |
| 404 | Endpoint not found | Check WP_SITE_URL, ensure REST API is enabled |
| 400 | Bad request | Check JSON syntax, required fields |
| 413 | File too large | Reduce image size before uploading |
| 500 | Server error | Check WordPress error logs |

If the REST API returns an error, show the full error response to the user and suggest a fix.

---

## Task-Specific Questions

1. What content should be published? (topic, existing file, or content-pipeline artifact)
2. Post or page?
3. Publish immediately or save as draft? (default: draft)
4. Categories and tags to assign?
5. Featured image to upload?
6. SEO keyword and meta description? (if Yoast/RankMath installed)

---

## Related Skills

- **content-pipeline**: Create a polished article first, then publish with wp-publish
- **deep-research**: Research a topic, then pipe into content-pipeline, then wp-publish
- **copywriting**: Write marketing copy, then publish to WordPress
- **seo-audit**: Audit existing WordPress content for SEO issues
- **programmatic-seo**: Create SEO pages at scale (can publish batches via wp-publish)

See [references/api-patterns.md](references/api-patterns.md) for the full WordPress REST API reference.
