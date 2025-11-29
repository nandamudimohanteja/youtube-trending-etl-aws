-- Category Trend Over Time (Monthly)
SELECT
    year,
    month,
    region,
    category_title,
    COUNT(*) AS trending_video_count,
    SUM(views) AS total_views,
    ROUND(AVG(engagement_rate), 2) AS avg_engagement,
    COUNT(DISTINCT channel_title) AS unique_channels,
    -- Category share within region
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY year, month, region),
        1
    ) AS category_share_pct
FROM enriched_trending
GROUP BY year, month, region, category_title
ORDER BY year DESC, month DESC, region, trending_video_count DESC;
