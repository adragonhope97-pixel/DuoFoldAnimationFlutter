import 'package:flutter/widgets.dart';

import 'portfolio_data.dart';
import 'portfolio_tokens.dart';

/// `<section id="about">`: an `<h2>` with no gap under it (the `.prose`
/// rule `> :first-child { margin-top: 0 }` eats the first paragraph's
/// margin), then `<p>`s `1.25em` apart.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('About', style: kSectionHeading),
        for (int i = 0; i < kAboutParagraphs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: kProseGap),
          Text(kAboutParagraphs[i], style: kProse),
        ],
      ],
    );
  }
}

/// `<section id="education">`: `flex min-h-0 flex-col gap-y-3`.
class EducationSection extends StatelessWidget {
  const EducationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Education', style: kSectionHeading),
        for (final EducationEntry e in kEducation) ...<Widget>[
          const SizedBox(height: kCardGap),
          EducationCard(entry: e),
        ],
      ],
    );
  }
}

/// `ResumeCard`: a `size-10 border m-auto object-contain` logo, then a
/// `flex-grow ml-4` column of a title/period row and the degree line.
///
/// The `ChevronRight` in the markup is `opacity-0` until `group-hover`,
/// which never happens on a touch screen, so it is not drawn.
class EducationCard extends StatelessWidget {
  const EducationCard({super.key, required this.entry});

  final EducationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: kCardLogo,
          height: kCardLogo,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: Image.asset(entry.logoAsset, fit: BoxFit.contain),
        ),
        const SizedBox(width: kCardLogoGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Flexible(child: Text(entry.school, style: kCardTitle)),
                  const SizedBox(width: kCardTitleGap),
                  Text(
                    entry.period,
                    style: kCardMeta,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              Text(entry.degree, style: kCardMeta),
            ],
          ),
        ),
      ],
    );
  }
}

/// `<section id="contact">`: `flex flex-col items-start gap-4`. The `<br/>`
/// after the first question is a hard break, not a wrap.
class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Contact', style: kSectionHeading),
        const SizedBox(height: kContactGap),
        Text.rich(
          const TextSpan(
            children: <InlineSpan>[
              TextSpan(text: '$kContactLine1\n$kContactLine2'),
              TextSpan(text: kContactLinkX, style: kProseLink),
              TextSpan(text: kContactBetween),
              TextSpan(text: kContactLinkTelegram, style: kProseLink),
            ],
          ),
          style: kProse,
        ),
      ],
    );
  }
}
