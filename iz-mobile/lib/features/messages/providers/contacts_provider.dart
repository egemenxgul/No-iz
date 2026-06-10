import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';

class ContactInfo {
  final String name;
  final String phoneNumber;
  final bool isActive;
  final String? userId;
  final String? username;
  final String? avatarUrl;

  ContactInfo({
    required this.name,
    required this.phoneNumber,
    this.isActive = false,
    this.userId,
    this.username,
    this.avatarUrl,
  });

  ContactInfo copyWith({
    String? name,
    String? phoneNumber,
    bool? isActive,
    String? userId,
    String? username,
    String? avatarUrl,
  }) {
    return ContactInfo(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class ContactsState {
  final List<ContactInfo> localContacts;
  final bool isLoading;
  final String? error;

  ContactsState({
    required this.localContacts,
    this.isLoading = false,
    this.error,
  });

  ContactsState copyWith({
    List<ContactInfo>? localContacts,
    bool? isLoading,
    String? error,
  }) {
    return ContactsState(
      localContacts: localContacts ?? this.localContacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ContactsNotifier extends Notifier<ContactsState> {
  final List<ContactInfo> _initialMockContacts = [
    ContactInfo(name: 'Ahmet Yılmaz', phoneNumber: '+905321112233'),
    ContactInfo(name: 'Ayşe Kaya', phoneNumber: '+905324445566'),
    ContactInfo(name: 'Zeynep Çelik', phoneNumber: '+905051234567'),
    ContactInfo(name: 'Emily Smith', phoneNumber: '+15550199'),
    ContactInfo(name: 'Can Kaplan', phoneNumber: '+905429876543'),
  ];

  @override
  ContactsState build() {
    // Start with unmatched mock contacts
    return ContactsState(localContacts: _initialMockContacts);
  }

  // Matches mock local contacts against the backend's registered user phone numbers
  Future<void> syncContacts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dio = ref.read(dioProvider);
      final phoneNumbers = state.localContacts.map((c) => c.phoneNumber).toList();

      final response = await dio.post('/api/users/contacts', data: {
        'phone_numbers': phoneNumbers,
      });

      final matchedList = response.data['matched_contacts'] as List?;
      if (matchedList == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      // Map phone to active user info
      final Map<String, Map<String, dynamic>> matchedMap = {};
      for (var item in matchedList) {
        final phone = item['phone'] as String?;
        if (phone != null) {
          matchedMap[phone] = item;
        }
      }

      // Update contacts status
      final updatedContacts = state.localContacts.map((contact) {
        // Normalize search (just in case)
        final normPhone = _normalize(contact.phoneNumber);
        // Look for match (try original or normalized)
        var match = matchedMap[contact.phoneNumber] ?? matchedMap[normPhone];

        if (match != null) {
          return contact.copyWith(
            isActive: true,
            userId: match['id'],
            username: match['username'],
            avatarUrl: match['avatar_url'],
          );
        } else {
          return contact.copyWith(isActive: false, userId: null, username: null);
        }
      }).toList();

      state = ContactsState(localContacts: updatedContacts, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Rehber eşitleme hatası: ${e.toString()}',
      );
    }
  }

  // Recessive Name Override Logic:
  // If contact phone is in local address book, returns local name; otherwise returns fallback
  String getContactNameOr(String? phone, String fallback) {
    if (phone == null || phone.isEmpty) return fallback;
    final normSearch = _normalize(phone);

    for (var contact in state.localContacts) {
      if (_normalize(contact.phoneNumber) == normSearch) {
        return contact.name;
      }
    }
    return fallback;
  }

  String _normalize(String phone) {
    final sb = StringBuffer();
    for (var i = 0; i < phone.length; i++) {
      final char = phone[i];
      if ((char.compareTo('0') >= 0 && char.compareTo('9') <= 0) || char == '+') {
        sb.write(char);
      }
    }
    return sb.toString();
  }
}

final contactsProvider = NotifierProvider<ContactsNotifier, ContactsState>(ContactsNotifier.new);
