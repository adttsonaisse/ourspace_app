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
  // Session restore lives in AuthGate now, so this page only shows when
  // no session exists. No redirect logic here.
  @override
  Widget build(BuildContext context) {
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
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Kawaii.ink, width: 2.5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.favorite_rounded,
                          size: 14, color: Kawaii.ink),
                      SizedBox(width: 6),
                      Text('for two',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
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
                        KawaiiAvatar(text: 'M', bg: Kawaii.sky, size: 72),
                        SizedBox(width: 8),
                        Text('+',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w900)),
                        SizedBox(width: 8),
                        KawaiiAvatar(text: 'J', bg: Kawaii.sunny, size: 72),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: Kawaii.ink, width: 2)),
                      child: const Text('Sticker-book for couples',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.6)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your little\nuniverse of two',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 36,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          fontFamily: Kawaii.displayFamily),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Notes, galleries, dates & tiny rituals — pasted together like a stationery shop scrapbook.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KawaiiCard(
                      color: Kawaii.skySubtle,
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KawaiiIcon(
                                icon: Icons.edit_note_rounded,
                                bg: Colors.white),
                            SizedBox(height: 6),
                            Text('Love notes',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Text('daily drops',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KawaiiCard(
                      color: Kawaii.sunnySubtle,
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KawaiiIcon(
                                icon: Icons.photo_library_rounded,
                                bg: Colors.white),
                            SizedBox(height: 6),
                            Text('Galleries',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Text('photo piles',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KawaiiCard(
                      color: Kawaii.mintSubtle,
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KawaiiIcon(
                                icon: Icons.calendar_month_rounded,
                                bg: Colors.white),
                            SizedBox(height: 6),
                            Text('Date plans',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Text('never forget',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
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
              const Center(
                child: Text(
                  'Private by design • Only you two can peek',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
