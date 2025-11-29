-- Engagement Analysis by Category and Region
WITH category_stats AS (
    SELECT
        region,
        category_title,
        COUNT(*) AS video_count,
        AVG(views) AS avg_views,
        AVG(likes) AS avg_likes,
        AVG(comment_count) AS avg_comments,
        AVG(engagement_rate) AS avg_engagement_rate,
        AVG(like_ratio) AS avg_like_ratio,
        AVG(days_to_trend) AS avg_days_to_trend,
        AVG(tag_count) AS avg_tag_count,
        AVG(title_length) AS avg_title_length
    FROM enriched_trending
    WHERE year >= 2024
    GROUP BY region, category_title
)
SELECT
    region,
    category_title,
    video_count,
    ROUND(avg_views, 0) AS avg_views,
    ROUND(avg_engagement_rate, 2) AS avg_engagement_rate,
    ROUND(avg_like_ratio, 1) AS avg_like_ratio,
    ROUND(avg_days_to_trend, 1) AS avg_days_to_trend,
    ROUND(avg_tag_count, 1) AS avg_tag_count,
    ROUND(avg_title_length, 0) AS avg_title_length
FROM category_stats
ORDER BY region, avg_engagement_rate DESC;
