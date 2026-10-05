import 'package:flutter/material.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import 'auth_login.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});
  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const KawaiiPill(
                      label: 'ourspace • v1.0', color: Kawaii.sunnySubtle),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Kawaii.cardOf(context),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: edge, width: Kawaii.paperBorderW),
                    ),
                    child: Row(children: [
                      const Icon(Icons.favorite_rounded,
                          size: 14, color: Kawaii.bubble),
                      const SizedBox(width: 6),
                      Text('for two',
                          style: TextStyle(
                              fontFamily: Kawaii.displayFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Kawaii.textOf(context))),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              KawaiiCard(
                color: Kawaii.peach,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        KawaiiAvatar(text: 'M', bg: Kawaii.sky, size: 68),
                        SizedBox(width: 8),
                        Text('+',
                            style: TextStyle(
                                fontFamily: Kawaii.displayFamily,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Kawaii.ink)),
                        SizedBox(width: 8),
                        KawaiiAvatar(text: 'J', bg: Kawaii.sunny, size: 68),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: Kawaii.ink, width: Kawaii.paperBorderW)),
                      child: const Text('Sticker-book for couples',
                          style: TextStyle(
                              fontFamily: Kawaii.displayFamily,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: Kawaii.ink,
                              letterSpacing: 0.4)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your little\nuniverse of two',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          fontFamily: Kawaii.displayFamily,
                          color: Kawaii.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Notes, galleries, dates & tiny rituals — pasted together like a stationery shop scrapbook.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: Kawaii.displayFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Kawaii.ink.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KawaiiCard(
                      sticker: false,
                      color: Kawaii.skySubtle,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const KawaiiIcon(
                                icon: Icons.edit_note_rounded,
                                bg: Colors.white,
                                size: 36,
                                iconSize: 20),
                            const SizedBox(height: 8),
                            const Text('Love notes',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Kawaii.ink)),
                            Text('daily drops',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Kawaii.ink.withValues(alpha: 0.7))),
                          ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KawaiiCard(
                      sticker: false,
                      color: Kawaii.sunnySubtle,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const KawaiiIcon(
                                icon: Icons.photo_library_rounded,
                                bg: Colors.white,
                                size: 36,
                                iconSize: 20),
                            const SizedBox(height: 8),
                            const Text('Galleries',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Kawaii.ink)),
                            Text('photo piles',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Kawaii.ink.withValues(alpha: 0.7))),
                          ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KawaiiCard(
                      sticker: false,
                      color: Kawaii.mintSubtle,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const KawaiiIcon(
                                icon: Icons.calendar_month_rounded,
                                bg: Colors.white,
                                size: 36,
                                iconSize: 20),
                            const SizedBox(height: 8),
                            const Text('Date plans',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Kawaii.ink)),
                            Text('never forget',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Kawaii.ink.withValues(alpha: 0.7))),
                          ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              KawaiiButton(
                label: "Get started — it's cute in here",
                icon: Icons.arrow_forward_rounded,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LoginRegisterPage())),
              ),
              const SizedBox(height: 12),
              KawaiiButton(
                label: 'I have an account',
                color: KawaiiBtnColor.white,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LoginRegisterPage(loginFirst: true))),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Private by design • Only you two can peek',
                  style: TextStyle(
                      fontFamily: Kawaii.displayFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Kawaii.mutedOf(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
