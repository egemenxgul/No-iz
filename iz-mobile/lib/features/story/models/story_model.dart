
class StoryModel {
	final String id;
	final String userId;
	final String mediaUrl;
	final String? caption; // Encrypted caption blob
	final String mediaType; // 'image' | 'video' | 'text'
	final DateTime createdAt;
	final DateTime expiresAt;

	StoryModel({
		required this.id,
		required this.userId,
		required this.mediaUrl,
		this.caption,
		required this.mediaType,
		required this.createdAt,
		required this.expiresAt,
	});

	factory StoryModel.fromJson(Map<String, dynamic> json) {
		return StoryModel(
			id: json['id'] as String,
			userId: json['user_id'] as String,
			mediaUrl: json['media_url'] as String,
			caption: json['caption'] as String?,
			mediaType: json['media_type'] as String,
			createdAt: DateTime.parse(json['created_at'] as String),
			expiresAt: DateTime.parse(json['expires_at'] as String),
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'id': id,
			'user_id': userId,
			'media_url': mediaUrl,
			'caption': caption,
			'media_type': mediaType,
			'created_at': createdAt.toIso8601String(),
			'expires_at': expiresAt.toIso8601String(),
		};
	}
}

class FriendStoryFeedModel {
	final String userId;
	final String username;
	final String displayName;
	final String avatarUrl;
	final List<StoryModel> stories;

	FriendStoryFeedModel({
		required this.userId,
		required this.username,
		required this.displayName,
		required this.avatarUrl,
		required this.stories,
	});

	factory FriendStoryFeedModel.fromJson(Map<String, dynamic> json) {
		final rawStories = json['stories'] as List<dynamic>? ?? [];
		return FriendStoryFeedModel(
			userId: json['user_id'] as String,
			username: json['username'] as String,
			displayName: json['display_name'] as String? ?? json['username'] as String,
			avatarUrl: json['avatar_url'] as String? ?? '',
			stories: rawStories.map((s) => StoryModel.fromJson(s as Map<String, dynamic>)).toList(),
		);
	}
}
