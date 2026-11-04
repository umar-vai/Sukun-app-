/// Sukun Life's review-only transcription inventory from nine supplied
/// prescription photographs. These are NOT published medical instructions.
/// No patient identifiers or private record contents are stored here.
/// Always let a responsible admin compare and approve the original paper.
final class OfficialPrescriptionTemplate {
  const OfficialPrescriptionTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.instruction,
    required this.actionType,
  });

  final String id;
  final String category;
  final String title;
  final String instruction;
  final String actionType;

  /// Nothing is silently inferred: every variable needs a reviewer value.
  static const variables = ['দিন', 'বার', 'মিনিট'];
  List<String> get requiredVariables => variables
      .where((variable) => instruction.contains('{$variable}'))
      .toList();

  String render(Map<String, int> values) {
    var result = instruction;
    for (final variable in requiredVariables) {
      final value = values[variable];
      if (value == null || value < 1 || value > 365) {
        throw ArgumentError('Review and fill $variable first');
      }
      result = result.replaceAll('{$variable}', '$value');
    }
    return result;
  }

  bool get requiresLinkedResource =>
      category == 'audio' ||
      (category == 'amal' && (id == 'a05' || id == 'a06' || id == 'a07'));
}

final class OfficialTemplateCategory {
  const OfficialTemplateCategory({
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final String id;
  final String title;
  final String subtitle;
}

const officialTemplateCategories = <OfficialTemplateCategory>[
  OfficialTemplateCategory(
    id: "amal",
    title: "আমল",
    subtitle: "ঈমানি আমল ও তিলাওয়াতের খসড়া",
  ),
  OfficialTemplateCategory(
    id: "supplement",
    title: "সাপ্লিমেন্ট",
    subtitle: "রুকইয়াহ পড়া পানি/তেল/মধু/আতর প্রস্তুত ও ব্যবহারের খসড়া",
  ),
  OfficialTemplateCategory(
    id: "bath",
    title: "গোসল",
    subtitle: "দিনভিত্তিক গোসলের ধাপ ও অডিও-নির্দেশনা",
  ),
  OfficialTemplateCategory(
    id: "audio",
    title: "অডিও",
    subtitle: "যাচাইকৃত অডিও লিংক করার খসড়া",
  ),
  OfficialTemplateCategory(
    id: "special",
    title: "বিশেষ আমল",
    subtitle: "পরিবার/বিশেষ প্রয়োজনে আলাদা খসড়া",
  ),
];

const officialPrescriptionTemplates = <OfficialPrescriptionTemplate>[
  OfficialPrescriptionTemplate(
    id: "a01",
    category: "amal",
    title: "সকাল–সন্ধ্যার মাসনুন আমল",
    instruction: "সকাল ও সন্ধ্যার মাসনুন আমল গুরুত্ব দিয়ে করবেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a02",
    category: "amal",
    title: "ঘুমের পূর্বের আমল",
    instruction: "প্রতিদিন ঘুমানোর আগে নির্ধারিত মাসনুন আমল করবেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a03",
    category: "amal",
    title: "কাজের শুরুতে বিসমিল্লাহ",
    instruction: "সব কাজের শুরুতে বিসমিল্লাহ বলার অভ্যাস করবেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a04",
    category: "amal",
    title: "নামাজের পর তাসবীহে ফাতেমী",
    instruction: "প্রতি নামাজের পরে তাসবীহে ফাতেমী পড়বেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a05",
    category: "amal",
    title: "আয়াতুল কুরসি ও ফালাক–নাস",
    instruction: "সকাল ও সন্ধ্যায় মাথায়/বুকে হাত রেখে আয়াতুল কুরসি ও সূরা ফালাক–নাস {বার} বার পড়বেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a06",
    category: "amal",
    title: "সূরা বাকারা খতম",
    instruction: "প্রতি {দিন} দিনে সূরা বাকারা এক খতম করার নির্দেশনা—পাঠ/শ্রবণ পদ্ধতি অ্যাডমিন যাচাই করবেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a07",
    category: "amal",
    title: "প্রতিদিন সূরা বাকারা শ্রবণ",
    instruction: "নির্ধারিত সূরা বাকারা তিলাওয়াত শুনবেন; কতদিন/কতবার হবে তা অ্যাডমিন লিখবেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a08",
    category: "amal",
    title: "দরূদ শরীফ",
    instruction: "দৈনিক দরূদ শরীফ {বার} বার পড়বেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a09",
    category: "amal",
    title: "ইস্তিগফার",
    instruction: "দৈনিক ইস্তিগফার {বার} বার পড়বেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a10",
    category: "amal",
    title: "সকালের শুরু দোয়া",
    instruction: "সকালে নির্ধারিত শুরু দোয়া {বার} বার পড়বেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "a11",
    category: "amal",
    title: "সন্ধ্যা ও ঘুমের শেষ দোয়া",
    instruction:
        "সকাল, সন্ধ্যা ও ঘুমের পূর্বে নির্ধারিত শেষ দোয়া {বার} বার পড়বেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "s01",
    category: "supplement",
    title: "রুকইয়াহ পাঠ দিয়ে পানি প্রস্তুত",
    instruction: "পানি প্রস্তুতের জন্য সূরা ফাতিহা, আয়াতুল কুরসি, তিন কুল এবং নির্বাচিত আয়াত পড়ার নির্দেশনা; সুনির্দিষ্ট আয়াত/পুনরাবৃত্তি প্রেসক্রিপশন অনুযায়ী যাচাই করুন।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s02",
    category: "supplement",
    title: "নির্বাচিত সিহর/শিফা আয়াত",
    instruction: "অনুমোদিত সিহর, শিফা, হারক ও কিতাল আয়াতের তালিকা যাচাই করে তেল/পানি/মধু/আতরে ফুঁ দেওয়ার খসড়া নির্দেশনা।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s03",
    category: "supplement",
    title: "রুকইয়াহ পানি দুই বেলা",
    instruction: "নির্ধারিত রুকইয়াহ পানি দিনে {বার} বেলা পান করার নির্দেশনা; পরিমাণ ও স্বাস্থ্যগত উপযোগিতা দায়িত্বপ্রাপ্ত ব্যক্তি যাচাই করবেন।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s04",
    category: "supplement",
    title: "বাসায় পানি স্প্রে",
    instruction: "নির্ধারিত পানি বাসায় স্প্রে করার নির্দেশনা; সময় ও নিয়ম অ্যাডমিন নিশ্চিত করবেন।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s05",
    category: "supplement",
    title: "গোসলের পানিতে মেশানো",
    instruction: "গোসলের পানির সঙ্গে অনুমোদিত রুকইয়াহ পানি মেশানোর নির্দেশনা।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s06",
    category: "supplement",
    title: "সকালের পানিতে মধু",
    instruction: "সকালের পানির সঙ্গে মধু মেশানোর নির্দেশনা; অ্যালার্জি ও স্বাস্থ্যগত বিষয় যাচাই করতে হবে।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s07",
    category: "supplement",
    title: "নির্ধারিত তেল মালিশ",
    instruction: "নির্বাচিত জায়গায় (পিঠ, ঘাড়, কোমর, মাথা বা ব্যথার স্থান) তেল ব্যবহারের খসড়া; প্রয়োগের স্থান ও ত্বকের উপযোগিতা নিশ্চিত করুন।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s08",
    category: "supplement",
    title: "বিছানার আশপাশে আতর",
    instruction: "প্রয়োজনে ও ঘুমের পূর্বে বিছানার আশপাশে আতর ব্যবহারের নির্দেশনা; সংবেদনশীলতা যাচাই করুন।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s09",
    category: "supplement",
    title: "মেহেদী ব্যবহারের নির্দেশনা",
    instruction: "প্রেসক্রিপশন অনুযায়ী মেহেদী ব্যবহার; প্রস্তুতি ও প্রয়োগ যাচাই করতে হবে।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "s10",
    category: "supplement",
    title: "প্রতি নির্ধারিত দিনে পুনঃপ্রস্তুত",
    instruction: "রুকইয়াহ পানি/অন্যান্য উপকরণ প্রতি {দিন} দিন পর নতুন করে প্রস্তুত করার নির্দেশনা।",
    actionType: "supplement",
  ),
  OfficialPrescriptionTemplate(
    id: "b01",
    category: "bath",
    title: "বদনজরের গোসল",
    instruction:
        "{দিন} দিন নজর/বদনজরের গোসল করবেন। সময় ও পদ্ধতি অ্যাডমিন যাচাই করবেন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b02",
    category: "bath",
    title: "বরই পাতার গোসল",
    instruction: "{দিন} দিন বরই পাতার গোসল করবেন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b03",
    category: "bath",
    title: "ডিটক্স গোসল",
    instruction:
        "{দিন} দিন ডিটক্স গোসল করবেন। গোসলের পদ্ধতি ও উপযোগিতা যাচাই করুন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b04",
    category: "bath",
    title: "সাপ্তাহিক নজরের গোসল",
    instruction: "সপ্তাহে {বার} দিন নজরের গোসল করবেন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b05",
    category: "bath",
    title: "নজর → বরই পাতা → ডিটক্স",
    instruction: "প্রথম {দিন} দিন নজরের গোসল; পরবর্তী পর্যায়ে বরই পাতার ও ডিটক্স গোসলের দিন অ্যাডমিন পৃথকভাবে নির্ধারণ করবেন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b06",
    category: "bath",
    title: "বরই পাতা → ডিটক্স → নজর",
    instruction: "প্রথম {দিন} দিন বরই পাতার গোসল; তারপর ডিটক্স ও নজরের গোসলের পর্যায় অ্যাডমিন পৃথকভাবে নির্ধারণ করবেন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b07",
    category: "bath",
    title: "নজরের গোসলের অডিও",
    instruction: "নজরের গোসলের আগে/পরে যাচাইকৃত বদনজরের অডিও অন্তত {মিনিট} মিনিট শুনবেন। অডিওটি আলাদাভাবে লিংক করুন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b08",
    category: "bath",
    title: "বরই পাতার গোসলের অডিও",
    instruction: "বরই পাতার গোসলের আগে/পরে যাচাইকৃত সিহর হিবশী অডিও {মিনিট} মিনিট শুনবেন। অডিওটি আলাদাভাবে লিংক করুন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "b09",
    category: "bath",
    title: "আরবি মাসের মাঝামাঝি গোসল",
    instruction: "আরবি মাসের মাঝামাঝি গোসলের নির্দেশনা; নির্দিষ্ট তারিখ অ্যাডমিন নিশ্চিত করবেন।",
    actionType: "bath",
  ),
  OfficialPrescriptionTemplate(
    id: "u01",
    category: "audio",
    title: "জিনের আছর রুকইয়াহ",
    instruction: "অনুমোদিত জিনের আছরের রুকইয়াহ অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u02",
    category: "audio",
    title: "আয়াতুল হারক অডিও",
    instruction: "অনুমোদিত আয়াতুল হারক অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u03",
    category: "audio",
    title: "কিতাল অডিও",
    instruction:
        "অনুমোদিত কিতাল অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u04",
    category: "audio",
    title: "শিফা–সাকিনা অডিও",
    instruction: "অনুমোদিত শিফা–সাকিনা অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u05",
    category: "audio",
    title: "খুরুজ অডিও",
    instruction:
        "অনুমোদিত খুরুজ অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u06",
    category: "audio",
    title: "বদনজর Evil Eye অডিও",
    instruction:
        "অনুমোদিত বদনজরের অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u07",
    category: "audio",
    title: "সিহর হিবশী অডিও",
    instruction: "অনুমোদিত Sihr Hibshi অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u08",
    category: "audio",
    title: "আট সূরার রুকইয়াহ",
    instruction:
        "নির্ধারিত আট সূরার রুকইয়াহ শুনবেন; প্রকাশিত রেকর্ডিং নির্বাচন করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u09",
    category: "audio",
    title: "তিন কুল রুকইয়াহ",
    instruction:
        "প্রকাশিত তিন কুলের রুকইয়াহ অডিও শুনবেন; পাঠক/লাইসেন্স যাচাই করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u10",
    category: "audio",
    title: "আয়াতুল কুরসির রুকইয়াহ",
    instruction:
        "প্রকাশিত আয়াতুল কুরসির রুকইয়াহ শুনবেন; পাঠক/লাইসেন্স যাচাই করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u11",
    category: "audio",
    title: "ইদরিস আবকার তিলাওয়াত",
    instruction: "নির্দিষ্ট সূরা/আয়াতের অনুমোদিত তিলাওয়াত প্রকাশিত লাইব্রেরি থেকে বেছে নিন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u12",
    category: "audio",
    title: "আহমাদ আল আজমী তিলাওয়াত",
    instruction: "নির্দিষ্ট তিন কুল/আয়াতুল কুরসির অনুমোদিত তিলাওয়াত প্রকাশিত লাইব্রেরি থেকে বেছে নিন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "u13",
    category: "audio",
    title: "সিরিয়াল অডিও সেশন",
    instruction: "নির্বাচিত অডিওগুলো ধারাবাহিকভাবে প্রতিটি {মিনিট} মিনিট করে, দিনে {বার} বার শুনবেন; প্রতিটি প্রকাশিত অডিও যুক্ত করুন।",
    actionType: "audio",
  ),
  OfficialPrescriptionTemplate(
    id: "x01",
    category: "special",
    title: "বিয়ের জন্য বিশেষ আমল",
    instruction: "সূরা মুমতাহিনা, সূরা কাসাসের ২৪ নং আয়াত ও সূরা ফুরকানের ৭৪ নং আয়াতের প্রেসক্রিপশনে উল্লেখিত ব্যবহার যাচাই করুন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x02",
    category: "special",
    title: "ইয়া ফাত্তাহু তাসবীহ",
    instruction: "প্রতি নামাজের পরে নির্ধারিত তাসবীহ {বার} বার পাঠ; মূল নির্দেশনা যাচাই করুন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x03",
    category: "special",
    title: "শিশুর হেফাজতের আমল",
    instruction: "শিশুর জন্য নির্বাচিত আয়াতের পাঠ/ফুঁ দেওয়ার খসড়া; নির্দিষ্ট আয়াত ও সংখ্যা দায়িত্বপ্রাপ্ত ব্যক্তি যাচাই করবেন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x04",
    category: "special",
    title: "স্বামী/স্ত্রীর সহায়ক আমল",
    instruction: "পরিবারের সদস্যের জন্য ব্যক্তিগতভাবে নির্ধারিত মাসনুন আমল; আসল প্রেসক্রিপশন অনুযায়ী সংশোধন করুন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x05",
    category: "special",
    title: "মাথায় হাত রেখে আমল",
    instruction: "মাথায়/ব্যথার স্থানে হাত রেখে নির্দিষ্ট আয়াত পাঠের খসড়া; প্রয়োগ, সংখ্যা ও সময় যাচাই করুন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x06",
    category: "special",
    title: "পানিতে ফুঁ দিয়ে পান",
    instruction: "নির্দিষ্ট যাচাইকৃত আয়াত পড়ে পানিতে ফুঁ দিয়ে পান করার খসড়া; স্বাস্থ্যগত উপযোগিতা ও পরিমাণ যাচাই করুন।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x07",
    category: "special",
    title: "হিজামা/কাউন্সেলিং পরামর্শ",
    instruction: "হিজামা বা কাউন্সেলিং সম্পর্কিত অ্যাডমিন পরামর্শ; চিকিৎসা-সংশ্লিষ্ট সিদ্ধান্ত কেবল যোগ্য ব্যক্তির অনুমোদনে।",
    actionType: "amal",
  ),
  OfficialPrescriptionTemplate(
    id: "x08",
    category: "special",
    title: "পুনরায় পরামর্শ ও ফলোআপ",
    instruction: "{দিন} দিন পর অগ্রগতি জানিয়ে দায়িত্বপ্রাপ্ত পরামর্শদাতার সঙ্গে যোগাযোগ করুন।",
    actionType: "amal",
  ),
];

OfficialPrescriptionTemplate? findOfficialTemplate(String id) {
  for (final template in officialPrescriptionTemplates) {
    if (template.id == id) return template;
  }
  return null;
}
