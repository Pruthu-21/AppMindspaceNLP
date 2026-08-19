import 'package:flutter/foundation.dart';
import 'app_storage.dart';

class LanguageNotifier {
  static final ValueNotifier<String> language = ValueNotifier('en'); // 'en', 'hi', 'gu'

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'title': 'MindSpaceNLP Drive',
      'home': 'Home',
      'recent': 'Recent',
      'downloads': 'Downloads',
      'profile': 'Profile',
      'logout': 'Sign Out',
      'shared_files': 'Shared Files',
      'files': 'Files',
      'folders': 'Folders',
      'search': 'Search files & folders...',
      'user_id': 'User ID',
      'name': 'Name',
      'email': 'Email',
      'role': 'Role',
      'theme': 'Dark Mode',
      'language': 'Language',
      'no_files': 'No files found',
      'no_recent': 'No recent files',
      'no_downloads': 'No downloaded files',
      'loading': 'Loading...',
      'empty_drive': 'Your drive is empty',
      'confirm_logout': 'Are you sure you want to sign out?',
      'cancel': 'Cancel',
      'upgrade_title': 'Upgrade to Pro',
      'upgrade_desc': 'Get unlimited storage and features',
      'admin_panel': 'Admin Panel',
      'notifications': 'Notifications',
      'hello': 'Hello',
      'manage_space': 'Manage your secure space',
      'admin_dashboard': 'Administration Dashboard',
    },
    'hi': {
      'title': 'माइंडस्पेसएनएलपी ड्राइव',
      'home': 'होम',
      'recent': 'हाल का',
      'downloads': 'डाउनलोड',
      'profile': 'प्रोफ़ाइल',
      'logout': 'साइन आउट',
      'shared_files': 'साझा की गई फ़ाइलें',
      'files': 'फ़ाइलें',
      'folders': 'फ़ोल्डर',
      'search': 'फ़ाइलें और फ़ोल्डर खोजें...',
      'user_id': 'यूज़र आईडी',
      'name': 'नाम',
      'email': 'ईमेल',
      'role': 'भूमिका',
      'theme': 'डार्क मोड',
      'language': 'भाषा',
      'no_files': 'कोई फ़ाइल नहीं मिली',
      'no_recent': 'कोई हाल की फ़ाइलें नहीं',
      'no_downloads': 'कोई डाउनलोड की गई फ़ाइलें नहीं',
      'loading': 'लोड हो रहा है...',
      'empty_drive': 'आपकी ड्राइव खाली है',
      'confirm_logout': 'क्या आप वाकई साइन आउट करना चाहते हैं?',
      'cancel': 'रद्द करें',
      'upgrade_title': 'प्रो में अपग्रेड करें',
      'upgrade_desc': 'असीमित स्टोरेज और सुविधाएं प्राप्त करें',
      'admin_panel': 'एडमिन पैनल',
      'notifications': 'सूचनाएं',
      'hello': 'नमस्ते',
      'manage_space': 'अपने सुरक्षित स्थान को प्रबंधित करें',
      'admin_dashboard': 'प्रशासनिक डैशबोर्ड',
    },
    'gu': {
      'title': 'માઇન્ડસ્પેસએનએલપી ડ્રાઇવ',
      'home': 'હોમ',
      'recent': 'તાજેતરના',
      'downloads': 'ડાઉનલોડ્સ',
      'profile': 'પ્રોફાઇલ',
      'logout': 'સાઇન આઉટ',
      'shared_files': 'શેર કરેલી ફાઇલો',
      'files': 'ફાઇલો',
      'folders': 'ફોલ્ડર્સ',
      'search': 'ફાઇલો અને ફોલ્ડર્સ શોધો...',
      'user_id': 'વપરાશકર્તા ID',
      'name': 'નામ',
      'email': 'ઇમેઇલ',
      'role': 'ભૂમિકા',
      'theme': 'ડાર્ક મોડ',
      'language': 'ભાષા',
      'no_files': 'કોઈ ફાઇલો મળી નથી',
      'no_recent': 'કોઈ તાજેતરની ફાઇલો નથી',
      'no_downloads': 'કોઈ ડાઉનલોડ કરેલી ફાઇલો નથી',
      'loading': 'લોડ થઈ રહ્યું છે...',
      'empty_drive': 'તમારી ડ્રાઇવ ખાલી છે',
      'confirm_logout': 'શું તમે ખરેખર સાઇન આઉટ કરવા માંગો છો?',
      'cancel': 'રદ કરો',
      'upgrade_title': 'પ્રો માં અપગ્રેડ કરો',
      'upgrade_desc': 'અમર્યાદિત સ્ટોરેજ અને સુવિધાઓ મેળવો',
      'admin_panel': 'એડમિન પેનલ',
      'notifications': 'સૂચનાઓ',
      'hello': 'નમસ્તે',
      'manage_space': 'તમારી સુરક્ષિત જગ્યાનું સંચાલન કરો',
      'admin_dashboard': 'વહીવટી ડેશબોર્ડ',
    }
  };

  static String translate(String key) {
    return _localizedValues[language.value]?[key] ?? _localizedValues['en']![key]!;
  }

  static Future<void> loadLanguage() async {
    try {
      final lang = await AppStorage.read('app_lang');
      if (lang == 'hi' || lang == 'gu' || lang == 'en') {
        language.value = lang!;
      }
    } catch (_) {}
  }

  static Future<void> setLanguage(String langCode) async {
    language.value = langCode;
    try {
      await AppStorage.write('app_lang', langCode);
    } catch (_) {}
  }
}
