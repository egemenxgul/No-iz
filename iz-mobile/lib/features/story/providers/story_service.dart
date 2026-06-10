import 'package:dio/dio.dart';
import '../models/story_model.dart';

class StoryService {
	final Dio _dio;

	StoryService(this._dio);

	Future<void> postStory({
		required String mediaUrl,
		required String? caption,
		required String mediaType,
	}) async {
		await _dio.post('/api/stories', data: {
			'media_url': mediaUrl,
			'caption': caption,
			'media_type': mediaType,
		});
	}

	Future<List<FriendStoryFeedModel>> getFeed() async {
		final res = await _dio.get('/api/stories');
		final data = res.data as List<dynamic>? ?? [];
		return data.map((item) => FriendStoryFeedModel.fromJson(item as Map<String, dynamic>)).toList();
	}

	Future<void> deleteStory(String storyId) async {
		await _dio.delete('/api/stories/$storyId');
	}
}
