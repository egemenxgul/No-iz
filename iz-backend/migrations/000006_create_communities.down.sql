-- Migration: 000006_create_communities.down.sql

DROP TABLE IF EXISTS community_post_likes;
DROP TABLE IF EXISTS community_posts;
DROP TABLE IF EXISTS community_groups;
DROP TABLE IF EXISTS community_members;
DROP TABLE IF EXISTS communities;
DROP TYPE  IF EXISTS community_role;
