-- Top 10 Trending Videos by Region (Last 30 Days)
SELECT
    region,
    trending_rank,
    title,
    channel_title,
    category_title,
    views,
    likes,
    comment_count,
    engagement_rate,
    like_ratio,
    days_to_trend,
    trending_date
FROM enriched_trending
WHERE trending_rank <= 10
    AND trending_date >= date_add('day', -30, current_date)
ORDER BY region, trending_date DESC, trending_rank ASC;
