/// Language codes match Bulk Blaster's TTS call API exactly, so the same
/// code drives both the on-device alarm text AND the spoken call text:
/// EN, HI, TE, TA, KN, ML, BN, GU, MR, PA
///
/// IMPORTANT — read before shipping: these phrases were drafted for
/// structure and placeholder testing, not verified by native speakers.
/// Get each one reviewed by a fluent speaker before this goes to real
/// users — a wrong or awkward phrase in a health reminder, read aloud to
/// an elderly person, is a real trust problem, not just a typo.
class LocalizationService {
  static const Map<String, String> languageNames = {
    'EN': 'English',
    'HI': 'हिन्दी (Hindi)',
    'TE': 'తెలుగు (Telugu)',
    'TA': 'தமிழ் (Tamil)',
    'KN': 'ಕನ್ನಡ (Kannada)',
    'ML': 'മലയാളം (Malayalam)',
    'BN': 'বাংলা (Bengali)',
    'GU': 'ગુજરાતી (Gujarati)',
    'MR': 'मराठी (Marathi)',
    'PA': 'ਪੰਜਾਬੀ (Punjabi)',
  };

  /// Used for the on-device alarm notification title.
  static String alarmTitle(String languageCode, String medicineName) {
    final template = _alarmTitleTemplates[languageCode] ?? _alarmTitleTemplates['EN']!;
    return template.replaceAll('{medicine}', medicineName);
  }

  static String alarmBody(String languageCode) {
    return _alarmBodyTemplates[languageCode] ?? _alarmBodyTemplates['EN']!;
  }

  /// Used as the `text` field sent to Bulk Blaster's /api/tts-call.
  static String callMessage(String languageCode, String medicineName, String personName) {
    final template = _callTemplates[languageCode] ?? _callTemplates['EN']!;
    return template.replaceAll('{medicine}', medicineName).replaceAll('{name}', personName);
  }

  static const _alarmTitleTemplates = {
    'EN': 'This time is for {medicine}',
    'HI': 'यह समय {medicine} के लिए है',
    'TE': 'ఈ సమయం {medicine} కోసం',
    'TA': 'இந்த நேரம் {medicine} க்கானது',
    'KN': 'ಈ ಸಮಯ {medicine} ಗಾಗಿ',
    'ML': 'ഈ സമയം {medicine}-നുള്ളതാണ്',
    'BN': 'এই সময়টি {medicine}-এর জন্য',
    'GU': 'આ સમય {medicine} માટે છે',
    'MR': 'ही वेळ {medicine} साठी आहे',
    'PA': 'ਇਹ ਸਮਾਂ {medicine} ਲਈ ਹੈ',
  };

  static const _alarmBodyTemplates = {
    'EN': 'Tap to mark it as taken.',
    'HI': 'लिया गया चिह्नित करने के लिए टैप करें।',
    'TE': 'తీసుకున్నట్లు గుర్తించడానికి నొక్కండి.',
    'TA': 'எடுத்ததாக குறிக்க தட்டவும்.',
    'KN': 'ತೆಗೆದುಕೊಂಡಿದ್ದೀರಿ ಎಂದು ಗುರುತಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ.',
    'ML': 'കഴിച്ചതായി അടയാളപ്പെടുത്താൻ ടാപ്പ് ചെയ്യുക.',
    'BN': 'নেওয়া হয়েছে বলে চিহ্নিত করতে ট্যাপ করুন।',
    'GU': 'લીધું છે એમ ચિહ્નિત કરવા ટેપ કરો.',
    'MR': 'घेतले असे चिन्हांकित करण्यासाठी टॅप करा.',
    'PA': 'ਲਿਆ ਗਿਆ ਵਜੋਂ ਨਿਸ਼ਾਨਬੱਧ ਕਰਨ ਲਈ ਟੈਪ ਕਰੋ।',
  };

  static const _callTemplates = {
    'EN': 'Hello {name}, it is time to take your {medicine}.',
    'HI': 'नमस्ते {name}, आपकी {medicine} लेने का समय हो गया है।',
    'TE': 'హలో {name}, మీ {medicine} తీసుకోవాల్సిన సమయం అయింది.',
    'TA': 'வணக்கம் {name}, உங்கள் {medicine} எடுக்க வேண்டிய நேரம் இது.',
    'KN': 'ಹಲೋ {name}, ನಿಮ್ಮ {medicine} ತೆಗೆದುಕೊಳ್ಳುವ ಸಮಯ ಇದು.',
    'ML': 'ഹലോ {name}, നിങ്ങളുടെ {medicine} കഴിക്കേണ്ട സമയമായി.',
    'BN': 'নমস্কার {name}, আপনার {medicine} খাওয়ার সময় হয়েছে।',
    'GU': 'નમસ્તે {name}, તમારી {medicine} લેવાનો સમય થયો છે.',
    'MR': 'नमस्कार {name}, तुमची {medicine} घेण्याची वेळ झाली आहे.',
    'PA': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ {name}, ਤੁਹਾਡੀ {medicine} ਲੈਣ ਦਾ ਸਮਾਂ ਹੋ ਗਿਆ ਹੈ।',
  };
}
