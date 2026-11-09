/// Curated, public links supplied by the Sukun Life team for the free campaign.
///
/// These are links to the publisher's files/videos, not copies of third-party
/// media. The app never embeds credentials or copies downloads to its storage.
enum ChallengeResourceKind { pdf, audio, assessment, community }

class ChallengeResourceLink {
  const ChallengeResourceLink(this.title, this.url, this.kind);

  final String title;
  final String url;
  final ChallengeResourceKind kind;
}

const challengeGettingStartedLinks = <ChallengeResourceLink>[
  ChallengeResourceLink(
    'চ্যালেঞ্জ সম্পর্কে বিস্তারিত',
    'https://drive.google.com/file/d/1MIIvcs8qLMZDKqQdXdcuepmeW6Yop7Un/view?usp=drivesdk',
    ChallengeResourceKind.pdf,
  ),
  ChallengeResourceLink(
    '৪০ দিনের বই (সম্পূর্ণ PDF)',
    'https://drive.google.com/file/d/1YvoT3KeQSPWbIPw_BaU86m_ju0dOTK1A/view?usp=drivesdk',
    ChallengeResourceKind.pdf,
  ),
  ChallengeResourceLink(
    'সেলফ রুকইয়াহ ই-বুক',
    'https://drive.google.com/file/d/1BK8ahoeRK3YPpdfeqU0XRDFvMeR2-8Q2/view?usp=drivesdk',
    ChallengeResourceKind.pdf,
  ),
];

/// Exactly one collection for each of the five contiguous 40-day stages.
const challengeStageLinks = <List<ChallengeResourceLink>>[
  [
    ChallengeResourceLink(
      '১–৯ম দিনের সম্পূর্ণ গাইড',
      'https://drive.google.com/file/d/1FVaejfBonhfb0Xzd6rc_ole4v8sR2q5g/view?usp=drivesdk',
      ChallengeResourceKind.pdf,
    ),
    ChallengeResourceLink(
      'সকাল ও সন্ধ্যায় শোনার অডিও',
      'https://youtube.com/watch?v=TADMZCZnl70&feature=youtu.be',
      ChallengeResourceKind.audio,
    ),
    ChallengeResourceLink(
      'ঘুমানোর আগে শোনার অডিও',
      'https://www.youtube.com/watch?v=P7m-RmR6wTw&feature=youtu.be',
      ChallengeResourceKind.audio,
    ),
  ],
  [
    ChallengeResourceLink(
      '১০–১২তম দিনের বদনজর থেকে সুরক্ষার গাইড',
      'https://drive.google.com/file/d/1VciDWFrtPmZpU603ozkxlXKn5PA6ZoSC/view?usp=drivesdk',
      ChallengeResourceKind.pdf,
    ),
  ],
  [
    ChallengeResourceLink(
      'শুরু করার আগে: জাদু নবায়ন বিষয়ে শারয়ী আলোচনা',
      'https://drive.google.com/file/d/1OXeLC8bCrMv94hfAxLRMxICQQVnuwP7g/view?usp=drivesdk',
      ChallengeResourceKind.pdf,
    ),
    ChallengeResourceLink(
      '১৩–১৯তম দিনের জাদু থেকে সুরক্ষার গাইড',
      'https://drive.google.com/file/d/1kzIk4HX6Il5rIdcXZzO1CP1aQY1S1WAV/view?usp=drivesdk',
      ChallengeResourceKind.pdf,
    ),
  ],
  [
    ChallengeResourceLink(
      '২০–২৬তম দিনের গোসলের সম্পূর্ণ গাইড',
      'https://drive.google.com/file/d/1kKEsfb1ausWg0Msp0AtkW6WL1XabgHVC/view?usp=drivesdk',
      ChallengeResourceKind.pdf,
    ),
  ],
  [
    ChallengeResourceLink(
      '২৭–৪০তম দিনের সম্পূর্ণ গাইড',
      'https://drive.google.com/file/d/1N7MktDXm0OOuTtBlqta60T0GywI9qFpy/view?usp=drivesdk',
      ChallengeResourceKind.pdf,
    ),
  ],
];

const challengeSupportLinks = <ChallengeResourceLink>[
  ChallengeResourceLink(
    'ফ্রি সিমটমস সেলফ-অ্যাসেসমেন্ট',
    'https://test.sukunlife.com/general-test',
    ChallengeResourceKind.assessment,
  ),
  ChallengeResourceLink(
    'দিকনির্দেশনার জন্য ফেসবুক গ্রুপ',
    'https://www.facebook.com/share/g/1F6UpUu8zj/',
    ChallengeResourceKind.community,
  ),
];
