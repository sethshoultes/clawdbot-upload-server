# Future Skills

Detailed specifications for skills to be built in future sessions. Each spec contains enough detail to implement without re-research.

---

## video-content

### Purpose
Generate short-form video (30-90 seconds) from article content — scripted narration over an image sequence with voiceover, assembled into a final MP4.

### Trigger Phrases
"create video from article," "video content," "short-form video," "turn article into video," "video from blog post," "social video," "video script"

### Input Sources
1. **Article text** — raw text or markdown
2. **Canvas artifact** — read HTML from `~/clawd/canvas/article-*.html`
3. **Topic** — generate script from scratch

### Pipeline

#### Phase 1: Script (Subagent)
- Extract 3-5 key points from the source content
- Write a 30-90 second narration script (150-250 words)
- Structure: Hook (5s) → Problem (10s) → Solution (30-40s) → CTA (10s)
- Include scene descriptions for each segment (what visuals to show)

#### Phase 2: Image Sequence (Parallel Subagents)
- Spawn 5-8 subagents, each generating one scene image via DALL-E or Google Imagen
- Image style: consistent across all scenes (same art style, color palette)
- Resolution: 1920x1080 (landscape for YouTube/LinkedIn) or 1080x1920 (portrait for Reels/TikTok/Shorts)
- Save to `/tmp/video-frames/scene-01.png` through `scene-N.png`

#### Phase 3: Voiceover (OpenAI TTS)
- Use OpenAI TTS API (`tts-1-hd` model) to generate narration audio
- Voice options: alloy, echo, fable, onyx, nova, shimmer
- Save to `/tmp/video-audio/narration.mp3`
- Alternatively: Google Cloud TTS for more voice options

#### Phase 4: Assembly (FFmpeg)
- Run on DO droplet (FFmpeg installed on host)
- Combine image sequence + audio into MP4:
  ```bash
  ffmpeg -framerate 0.15 -i /tmp/video-frames/scene-%02d.png \
    -i /tmp/video-audio/narration.mp3 \
    -c:v libx264 -pix_fmt yuv420p -c:a aac \
    -shortest ~/clawd/canvas/video-[slug]-[date].mp4
  ```
- Add crossfade transitions between scenes
- Add text overlays (key points, CTA) using FFmpeg drawtext filter
- Generate thumbnail from first frame

#### Phase 5: Output
- MP4 saved to `~/clawd/canvas/video-[slug]-[YYYY-MM-DD].mp4`
- Thumbnail saved as `video-[slug]-[YYYY-MM-DD]-thumb.png`
- Canvas HTML player page with embedded video

### Advanced: Google Veo
- For higher-quality video clips, use Google Veo API to generate short clips per scene
- Requires `GOOGLE_API_KEY` with Veo access
- Each clip: 4-8 seconds, assembled via FFmpeg
- Fallback: image sequence with Ken Burns effect if Veo unavailable

### Dependencies
- FFmpeg on host (installed on DO droplet)
- OpenAI API key (TTS)
- DALL-E or Google Imagen API key (images)
- Optional: Google Veo API key (video clips)

### Chains With
- `content-pipeline` → `video-content` (article to video)
- `content-pipeline` → `wp-publish` → `video-content` → `social-repurpose` (full pipeline)

### Reference Files Needed
- `references/video-templates.md` — FFmpeg command patterns, transition effects, text overlay templates
- `references/tts-voices.md` — Voice samples and use cases per voice option

---

## seo-cluster

### Purpose
Build a topic cluster (1 pillar page + 5-10 supporting posts) from a seed keyword. Research, plan, generate, interlink, and optionally publish all posts.

### Trigger Phrases
"topic cluster," "SEO cluster," "pillar content," "content cluster," "build cluster from keyword," "cluster strategy," "hub and spoke content"

### Input
- Seed keyword or topic (e.g., "SaaS pricing strategy")
- Target site (from `~/clawd/.wp-sites.json`)
- Number of supporting posts (default: 7)

### Pipeline

#### Phase 1: Keyword Research (Browser + Subagents)
- Spawn 3-4 subagents to research:
  - Main keyword search volume and difficulty (using browser to check tools)
  - Related long-tail keywords (Google autocomplete, People Also Ask, Related Searches)
  - Competitor content analysis (what's ranking for these terms)
  - Content gaps (what competitors aren't covering)
- Primary agent compiles keyword map

#### Phase 2: Cluster Architecture
- Define pillar page: broad, authoritative overview (2,500-4,000 words)
- Define supporting posts: each targets a specific long-tail keyword (1,200-2,000 words)
- Map internal linking structure: each supporting post links to pillar, pillar links to all supporting posts
- Present cluster map to user for approval before generating

**Cluster map format:**
```
Pillar: "The Complete Guide to SaaS Pricing Strategy"
  → Target: "saas pricing strategy" (high volume)

Supporting:
  1. "Value-Based Pricing for SaaS" → target: "value based pricing saas"
  2. "SaaS Pricing Page Best Practices" → target: "saas pricing page"
  3. "How to Price a New SaaS Product" → target: "how to price saas"
  4. "SaaS Pricing Models Compared" → target: "saas pricing models"
  5. "Enterprise SaaS Pricing Strategy" → target: "enterprise saas pricing"
  6. "SaaS Free Trial vs Freemium" → target: "free trial vs freemium"
  7. "SaaS Pricing Psychology" → target: "pricing psychology saas"
```

#### Phase 3: Content Generation (Parallel Subagents)
- Use `content-pipeline` skill for each post (spawn parallel subagents)
- Each subagent gets: topic, target keyword, word count target, internal linking targets
- Pillar page generated first (other posts reference it)
- Supporting posts generated in parallel after pillar is done

#### Phase 4: Internal Linking
- Primary agent reviews all generated posts
- Inserts contextual internal links between posts (not just footer links)
- Each supporting post links to pillar page at least once
- Pillar page links to each supporting post
- Cross-links between related supporting posts where natural

#### Phase 5: Publish (Optional)
- If user approves, use `wp-publish` to publish all posts as drafts
- Publish pillar first, then supporting posts
- Set categories and tags consistently across the cluster
- Generate featured images for each post

#### Phase 6: Dashboard Output
- Canvas HTML dashboard showing:
  - Cluster map visualization (Mermaid diagram)
  - Status of each post (draft URL, word count, target keyword)
  - Internal link map
  - Next steps checklist

### Dependencies
- `content-pipeline` skill (for article generation)
- `wp-publish` skill (for publishing)
- `deep-research` skill (for keyword research)
- Browser tool (for SERP analysis)

### Reference Files Needed
- `references/cluster-templates.md` — Cluster map formats, internal linking patterns
- `references/keyword-research.md` — Research methodology, tools, data extraction patterns

---

## wp-optimize

### Purpose
Audit and batch-update existing WordPress posts for SEO, readability, metadata, and image optimization. Non-destructive — saves changes as draft revisions.

### Trigger Phrases
"optimize WordPress posts," "audit WordPress," "WordPress SEO audit," "batch update posts," "wp optimize," "fix WordPress SEO," "update old posts," "content audit"

### Input
- WordPress site (from `~/clawd/.wp-sites.json`)
- Scope: all posts, specific category, date range, or specific post IDs
- Optimization focus: SEO, readability, metadata, images, or all

### Pipeline

#### Phase 1: Fetch Posts
```bash
# Fetch all published posts (paginated)
PAGE=1
while true; do
  RESPONSE=$(curl -s "${WP_SITE_URL}/wp-json/wp/v2/posts?per_page=100&page=${PAGE}&status=publish" \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}")
  # Process posts, break if empty
  PAGE=$((PAGE + 1))
done
```
- Collect: ID, title, content, excerpt, slug, categories, tags, featured_media, meta (Yoast/RankMath), date

#### Phase 2: Audit (Parallel Subagents)
- Spawn subagents (batch of 5-10 posts each) to audit:

**SEO Audit per post:**
- Title tag length (50-60 chars)
- Meta description length (120-160 chars)
- Focus keyword presence in title, H1, first paragraph, URL
- Heading hierarchy (H1 → H2 → H3, no skipping)
- Internal links count (minimum 2-3)
- External links count (minimum 1-2 authoritative)
- Image alt text completeness
- URL slug optimization

**Readability Audit per post:**
- Average sentence length (target: 15-20 words)
- Paragraph length (target: 2-3 sentences)
- Passive voice percentage (target: <10%)
- Transition word usage
- Flesch-Kincaid readability score estimate

**Metadata Audit per post:**
- Excerpt present and optimized
- Featured image present
- Categories assigned (not just "Uncategorized")
- Tags present (3-5 relevant)
- Yoast/RankMath score if available

#### Phase 3: Generate Fixes
- For each post with issues, generate specific fixes:
  - Rewritten meta title and description
  - Updated excerpt
  - Missing alt text for images
  - Suggested internal links to add
  - Heading structure fixes
- Present fix summary to user for approval

#### Phase 4: Batch Update
- Apply approved fixes via REST API
- **Non-destructive:** WordPress saves revisions automatically
- Update one post at a time with error handling
- Track successes and failures

```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/posts/{POST_ID}" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d @/tmp/wp-update-{POST_ID}.json
```

#### Phase 5: Dashboard Output
- Canvas HTML dashboard with:
  - Summary: posts audited, issues found, fixes applied
  - Per-post audit scores (before/after)
  - Issues breakdown by category (SEO, readability, metadata, images)
  - List of changes made per post
  - Posts that still need manual attention

### Safety
- All updates saved as revisions (WordPress built-in)
- Never changes post status (published stays published)
- Never deletes content — only adds or improves
- User approval required before any batch update
- Dry-run mode: audit only, no changes

### Dependencies
- `wp-publish` skill (reuses site config and REST API patterns)
- `seo-audit` skill (reuses audit methodology)

### Reference Files Needed
- `references/audit-checklist.md` — Complete audit criteria with scoring rubric
- `references/fix-templates.md` — Common fix patterns (meta descriptions, alt text, etc.)

---

## email-digest

### Purpose
Generate an email newsletter HTML from recent published WordPress posts. Output is ready to paste into Mailchimp, ConvertKit, Beehiiv, or any email platform.

### Trigger Phrases
"email newsletter," "weekly digest," "email digest," "newsletter from posts," "generate newsletter," "email from recent posts," "weekly roundup"

### Input
- WordPress site (from `~/clawd/.wp-sites.json`)
- Date range (default: last 7 days)
- Newsletter name/branding (default: site name)
- Number of posts to include (default: all from date range, max 10)

### Pipeline

#### Phase 1: Fetch Recent Posts
```bash
# Fetch posts from the last 7 days
AFTER_DATE=$(date -u -d '7 days ago' +%Y-%m-%dT00:00:00 2>/dev/null || date -u -v-7d +%Y-%m-%dT00:00:00)
curl -s "${WP_SITE_URL}/wp-json/wp/v2/posts?after=${AFTER_DATE}&per_page=10&orderby=date&order=desc" \
  -u "${WP_USERNAME}:${WP_APP_PASSWORD}"
```
- Collect: title, excerpt, link, featured_media, date, categories

#### Phase 2: Summarize Posts (Subagents)
- Spawn subagents (1 per post) to create newsletter summaries:
  - 2-3 sentence summary (not the excerpt — write fresh for email context)
  - Key takeaway or teaser to drive clicks
  - CTA text ("Read more", "See the full guide", etc.)

#### Phase 3: Build Newsletter HTML
- Use a pre-built responsive email HTML template
- Structure:
  1. **Header** — Newsletter name, date range, logo placeholder
  2. **Intro** — 2-3 sentence editorial intro (what's in this issue)
  3. **Featured post** — Larger card with image, title, summary, CTA button
  4. **Post list** — Remaining posts as smaller cards (image, title, one-line summary, link)
  5. **Footer** — Unsubscribe placeholder, social links, copyright

- **Email HTML requirements:**
  - Table-based layout (email client compatibility)
  - Inline CSS only (no `<style>` block — many email clients strip it)
  - Max width: 600px
  - System fonts only (Arial, Helvetica, Georgia — no web fonts in email)
  - Images: absolute URLs from WordPress media library
  - All links: absolute URLs
  - Alt text on all images
  - Preheader text (hidden text that appears in email preview)

#### Phase 4: Output
- **Canvas HTML artifact:** `newsletter-[site]-[YYYY-MM-DD].html`
  - Dark-theme preview wrapper (for canvas gallery)
  - Embedded newsletter HTML in an iframe or light-background container
  - Copy button for the raw email HTML
- **Plain text version:** Also generate a plain text version of the newsletter
- Both saved to `~/clawd/canvas/`

### Template Sections

**Featured post card:**
```html
<table width="100%" cellpadding="0" cellspacing="0" border="0">
  <tr>
    <td>
      <img src="[FEATURED_IMAGE_URL]" alt="[TITLE]" width="600" style="display:block;width:100%;max-width:600px;">
    </td>
  </tr>
  <tr>
    <td style="padding:20px;font-family:Arial,sans-serif;">
      <h2 style="margin:0 0 10px;font-size:22px;color:#333;">[TITLE]</h2>
      <p style="margin:0 0 15px;font-size:16px;line-height:1.5;color:#555;">[SUMMARY]</p>
      <a href="[LINK]" style="display:inline-block;padding:12px 24px;background:#007bff;color:#fff;text-decoration:none;border-radius:4px;font-size:14px;">Read More</a>
    </td>
  </tr>
</table>
```

### Dependencies
- `wp-publish` skill (reuses site config)
- WordPress REST API access

### Reference Files Needed
- `references/email-template.html` — Complete responsive email HTML template
- `references/email-best-practices.md` — Subject line formulas, preheader text, deliverability tips
