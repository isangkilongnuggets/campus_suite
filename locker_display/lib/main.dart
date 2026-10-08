import 'dart:async';
import 'package:campus_shared/campus_shared.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'firebase_options.dart';

final hub = Hub();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await hub.start();
  runApp(MaterialApp(
    title: 'Smart Locker Display',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFE9EEF4)),
    home: const LockerScreen(),
  ));
}

enum Stage { welcome, pin, qr, open, done }

class LockerScreen extends StatefulWidget {
  const LockerScreen({super.key});
  @override
  State<LockerScreen> createState() => _LockerState();
}

class _LockerState extends State<LockerScreen> {
  Stage stage = Stage.welcome;
  String action = 'dropoff', pin = '';
  String? msg, code;
  Txn? txn;
  StreamSubscription? sub;
  Timer? tick;
  int secs = qrSeconds, wrong = 0, lateFee = 0;
  DateTime? lockedUntil;

  @override
  void dispose() {
    sub?.cancel();
    tick?.cancel();
    super.dispose();
  }

  void reset([String? m]) {
    sub?.cancel();
    tick?.cancel();
    setState(() { stage = Stage.welcome; pin = ''; txn = null; code = null; msg = m; });
  }

  void choose(String a) => setState(() { action = a; pin = ''; msg = null; stage = Stage.pin; });

  void key(String k) {
    if (stage != Stage.pin) return;
    setState(() {
      if (k == 'C') {
        pin = '';
      } else if (k == '<') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 6) {
        pin += k;
      }
    });
    if (pin.length == 6) submit();
  }

  Future<void> submit() async {
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil!)) {
      setState(() { pin = ''; msg = 'PIN entry locked. Try again in ${lockedUntil!.difference(DateTime.now()).inMinutes + 1} min.'; });
      return;
    }
    final t = hub.findByPin(pin, action);
    if (t == null) {
      wrong++;
      if (wrong >= 3) {
        wrong = 0;
        lockedUntil = DateTime.now().add(const Duration(minutes: 5));
        setState(() { pin = ''; msg = 'Too many wrong PINs. Locked for 5 minutes.'; });
      } else {
        setState(() { pin = ''; msg = 'Wrong PIN. ${3 - wrong} attempt(s) left.'; });
      }
      return;
    }
    wrong = 0;
    final c = await hub.startSession(t, action);
    sub = hub.sessionStream(c).listen((m) {
      if (m != null && m['state'] == 'approved' && stage == Stage.qr) {
        tick?.cancel();
        lateFee = ((m['latePaid'] ?? 0) as num).toInt();
        setState(() => stage = Stage.open);
      }
    });
    secs = qrSeconds;
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      secs--;
      if (secs <= 0) {
        reset('QR code expired. Please try again.');
      } else {
        setState(() {});
      }
    });
    setState(() { txn = t; code = c; stage = Stage.qr; msg = null; });
  }

  /// Simulates the door sensor confirming the door is closed and locked.
  Future<void> closeDoor() async {
    final t = txn!;
    if (action == 'dropoff') {
      await hub.confirmDeposit(t);
    } else {
      await hub.confirmRetrieval(t, lateFee);
    }
    await hub.finishSession(code!);
    sub?.cancel();
    setState(() => stage = Stage.done);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && stage == Stage.done) reset();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListenableBuilder(
          listenable: hub,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              Expanded(child: _lockerBody()),
              const SizedBox(width: 24),
              SizedBox(width: 380, child: _screen()),
            ]),
          ),
        ),
      );

  Widget _lockerBody() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFD5DBE3), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          for (final c in hub.comps)
            Expanded(
              flex: c.size == LockerSize.small ? 2 : c.size == LockerSize.medium ? 3 : 4,
              child: Builder(builder: (_) {
                final open = stage == Stage.open && txn?.comp.id == c.id;
                final (label, color) = cStatusInfo(c.status);
                final base = c.size == LockerSize.small ? teal : c.size == LockerSize.medium ? gcash : purple;
                return Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: open ? Colors.white : base.withAlpha(170),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: open ? green : base, width: open ? 4 : 2)),
                  child: Row(children: [
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.id, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(sizeLabel(c.size).toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ]),
                    const Spacer(),
                    if (open) const Text('DOOR OPEN', style: TextStyle(fontWeight: FontWeight.bold, color: green)),
                    const SizedBox(width: 12),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.circle, color: color, size: 18),
                      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ]),
                  ]),
                );
              }),
            ),
        ]),
      );

  Widget _screen() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(28)),
        child: Center(child: SingleChildScrollView(child: _content())),
      );

  static const _w = TextStyle(color: Colors.white);
  Widget _title(String t, [String? sub]) => Column(children: [
        Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 18),
      ]);
  Widget _btn(String t, VoidCallback f, {Color color = teal, Color fg = Colors.white}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: fg), onPressed: f, child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
      );

  Widget _content() {
    switch (stage) {
      case Stage.welcome:
        return Column(children: [
          const Icon(Icons.lock_outline, color: teal, size: 48),
          const SizedBox(height: 8),
          _title('Hello, welcome!', 'Choose an option'),
          if (msg != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(msg!, textAlign: TextAlign.center, style: const TextStyle(color: amber))),
          _btn('Drop-off', () => choose('dropoff')),
          _btn('Pick-up', () => choose('pickup'), color: Colors.white, fg: navy),
        ]);
      case Stage.pin:
        return Column(children: [
          _title('Enter your PIN', action == 'dropoff' ? 'Drop-off' : 'Pick-up'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 6; i++)
              Container(width: 14, height: 14, margin: const EdgeInsets.all(5), decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? teal : Colors.white24)),
          ]),
          SizedBox(height: 32, child: Center(child: Text(msg ?? '', textAlign: TextAlign.center, style: const TextStyle(color: amber, fontSize: 12)))),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '<'])
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF223A63)),
                    onPressed: () => key(k),
                    child: Text(k == '<' ? '⌫' : k, style: const TextStyle(fontSize: 22))),
            ],
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: reset, child: const Text('Cancel', style: _w)),
        ]);
      case Stage.qr:
        return Column(children: [
          _title('Scan this QR code', 'Open the app and scan it'),
          Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: QrImageView(data: code!, size: 200, backgroundColor: Colors.white)),
          const SizedBox(height: 10),
          Text('Code: $code', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text('Expires in 0:${secs.toString().padLeft(2, '0')}', style: const TextStyle(color: amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextButton(onPressed: reset, child: const Text('Cancel', style: _w)),
        ]);
      case Stage.open:
        return Column(children: [
          const Icon(Icons.lock_open, color: green, size: 56),
          const SizedBox(height: 8),
          _title('Door open', 'Compartment ${txn!.comp.id}'),
          Text(action == 'dropoff' ? 'Place your item inside, then close the door.' : 'Take your item, then close the door.', textAlign: TextAlign.center, style: _w),
          const SizedBox(height: 22),
          _btn('Close door (simulates door sensor)', closeDoor),
        ]);
      case Stage.done:
        return Column(children: [
          const CircleAvatar(radius: 40, backgroundColor: green, child: Icon(Icons.check, size: 48, color: Colors.white)),
          const SizedBox(height: 14),
          _title(action == 'dropoff' ? 'Item deposited!' : 'Thank you!', action == 'dropoff' ? 'The recipient has been notified.' : 'Item retrieved successfully.'),
        ]);
    }
  }
}
