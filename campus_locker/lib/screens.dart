import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'core.dart';

// ───────── shared widgets ─────────
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: child,
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, this.color, {super.key});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withAlpha(35), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.bold = false, this.color});
  final String k, v;
  final bool bold;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: color))),
        ]),
      );
}

class BigButton extends StatelessWidget {
  const BigButton(this.text, this.onTap, {super.key, this.color = teal, this.outline = false});
  final String text;
  final VoidCallback? onTap;
  final Color color;
  final bool outline;
  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: outline
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(shape: shape, foregroundColor: navy),
              onPressed: onTap,
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)))
          : FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color, shape: shape),
              onPressed: onTap,
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(16), children: children));
}

class Steps extends StatelessWidget {
  const Steps(this.labels, this.done, {super.key});
  final List<String> labels;
  final int done;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(children: [
                CircleAvatar(
                    radius: 13,
                    backgroundColor: i < done ? green : Colors.white,
                    child: i < done
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : const Icon(Icons.circle_outlined, size: 15, color: Colors.black26)),
                const SizedBox(height: 4),
                Text(labels[i], style: const TextStyle(fontSize: 11)),
              ]),
            ),
          ]
        ],
      );
}

Widget bigCheck(String title, String sub) => Column(children: [
      const SizedBox(height: 8),
      const CircleAvatar(radius: 40, backgroundColor: green, child: Icon(Icons.check, size: 48, color: Colors.white)),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
      Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 16),
    ]);

Widget pinBox(String pin) => Panel(
      child: Column(children: [
        const Text('Your one-time pickup PIN', style: TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 6),
        Text(pin.split('').join(' '), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: navy)),
        const Text('Shown only in your account', style: TextStyle(color: Colors.black45, fontSize: 11)),
      ]),
    );

// ───────── login ─────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final mob = TextEditingController(), otp = TextEditingController();
  bool sent = false, busy = false;

  void say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> go() async {
    if (digits(mob.text).length < 10) { say('Enter a valid mobile number.'); return; }
    if (sent && otp.text.length != 6) { say('Enter the 6-digit code.'); return; }
    setState(() => busy = true);
    String? err;
    if (sent) {
      err = await app.verify(otp.text);
    } else {
      err = await app.sendCode(mob.text);
      if (err == null) sent = true;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) say(err);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Icon(Icons.lock_outline, color: teal, size: 56),
                const SizedBox(height: 12),
                const Text('Smart Campus Drop-Off Locker',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('CampusEdge Solutions', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 28),
                Panel(
                  child: Column(children: [
                    TextField(
                        controller: mob,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile number', hintText: '0917 123 4567', border: OutlineInputBorder())),
                    if (sent) ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: otp,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(labelText: 'One-time code', border: OutlineInputBorder())),
                    ],
                    const SizedBox(height: 12),
                    BigButton(busy ? 'Please wait...' : (sent ? 'Log In' : 'Send Code'), busy ? null : go),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ───────── sign up (profile) ─────────
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpState();
}

class _SignUpState extends State<SignUpScreen> {
  static const types = ['Student', 'Faculty', 'Staff', 'Parent', 'Visitor', 'Delivery Rider'];
  final name = TextEditingController(), sr = TextEditingController();
  String type = 'Student';
  InputDecoration deco(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set Up Your Profile'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: app.logout)]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Your name is shown as the sender on every booking.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: deco('Full name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              initialValue: type,
              decoration: deco('User type'),
              items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => type = v!)),
          if (type == 'Student') ...[const SizedBox(height: 12), TextField(controller: sr, decoration: deco('SR-Code'))],
          const SizedBox(height: 20),
          BigButton('Create Profile', () {
            if (name.text.trim().isEmpty || (type == 'Student' && sr.text.trim().isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile.')));
              return;
            }
            app.saveProfile(name.text.trim(), type, type == 'Student' ? sr.text.trim() : '');
          }),
        ]),
      );
}

// ───────── shell ─────────
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int i = 0;
  static const titles = ['Available Compartments', 'Pick Up Item', 'My Transactions'];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titles[i]), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: app.logout)]),
        body: ListenableBuilder(listenable: app, builder: (_, __) => [const CompartmentsTab(), const PickupTab(), const TransactionsTab()][i]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view), label: 'Lockers'),
            NavigationDestination(icon: Icon(Icons.lock_open), label: 'Pick Up'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'History'),
          ],
        ),
      );
}

// ───────── compartments ─────────
class CompartmentsTab extends StatefulWidget {
  const CompartmentsTab({super.key});
  @override
  State<CompartmentsTab> createState() => _CompState();
}

class _CompState extends State<CompartmentsTab> {
  LockerSize? filter;
  String? sel;
  @override
  Widget build(BuildContext context) {
    final list = app.comps.where((c) => filter == null || c.size == filter).toList();
    final chosen = app.comps.where((c) => c.id == sel && c.status == CStatus.available && rateOf(c.size) != null).firstOrNull;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.circle, size: 9, color: green),
            SizedBox(width: 6),
            Text('Campus Locker Hub · Live', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [null, ...LockerSize.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(f == null ? 'All' : sizeLabel(f)),
                      selected: filter == f,
                      onSelected: (_) => setState(() => filter = f)),
                ),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final c in list)
            GestureDetector(
              onTap: () => setState(() => sel = c.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel == c.id ? teal : const Color(0xFFE2E8F0), width: sel == c.id ? 2 : 1),
                ),
                child: Row(children: [
                  Container(width: 5, height: 44, color: c.size == LockerSize.small ? teal : c.size == LockerSize.medium ? gcash : purple),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${sizeLabel(c.size)} Locker  ·  ${c.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(rateOf(c.size) == null ? 'Price to be set' : '${peso(rateOf(c.size)!)} per booked hour',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  Pill(cStatusInfo(c.status).$1, cStatusInfo(c.status).$2),
                ]),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: BigButton('Book Selected Locker', chosen == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookScreen(chosen)))),
      ),
    ]);
  }
}

// ───────── book ─────────
class BookScreen extends StatefulWidget {
  const BookScreen(this.c, {super.key});
  final Compartment c;
  @override
  State<BookScreen> createState() => _BookState();
}

class _BookState extends State<BookScreen> {
  String item = 'Package', rType = 'Student';
  int hours = 1;
  final name = TextEditingController(), mobile = TextEditingController(), sr = TextEditingController();
  InputDecoration deco(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true);
  @override
  Widget build(BuildContext context) {
    final rate = rateOf(widget.c.size)!;
    return AppPage('Book Compartment', [
      Pill('${sizeLabel(widget.c.size)} Locker · ${widget.c.id}', gcash),
      const SizedBox(height: 14),
      const Text('Item type', style: TextStyle(fontWeight: FontWeight.bold)),
      Wrap(spacing: 8, children: [for (final t in itemTypes) ChoiceChip(label: Text(t), selected: item == t, onSelected: (_) => setState(() => item = t))]),
      const SizedBox(height: 14),
      const Text('Recipient details', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(controller: name, decoration: deco('Full name')),
      const SizedBox(height: 10),
      TextField(controller: mobile, keyboardType: TextInputType.phone, decoration: deco('Mobile number (links to recipient\'s account)')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: DropdownButtonFormField<String>(
                initialValue: rType,
                decoration: deco('Recipient type'),
                items: [for (final t in recipientTypes) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setState(() => rType = v!))),
        if (rType == 'Student') ...[const SizedBox(width: 10), Expanded(child: TextField(controller: sr, decoration: deco('SR-Code')))],
      ]),
      const SizedBox(height: 14),
      const Text('Hours to book', style: TextStyle(fontWeight: FontWeight.bold)),
      Panel(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton.filledTonal(onPressed: hours > 1 ? () => setState(() => hours--) : null, icon: const Icon(Icons.remove)),
          Text('$hours hr${hours > 1 ? 's' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: teal),
              onPressed: hours < limitHours - 1 ? () => setState(() => hours++) : null,
              icon: const Icon(Icons.add)),
        ]),
      ),
      Text('${peso(rate)} per booked hour × $hours hr', style: const TextStyle(color: Colors.black54, fontSize: 12)),
      Text('Total to pay (sender): ${peso(rate * hours)}', style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      BigButton('Continue to Payment', () async {
        if (name.text.trim().isEmpty || mobile.text.replaceAll(' ', '').length < 10) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the recipient\'s name and a valid mobile number.')));
          return;
        }
        final t = await app.book(widget.c, item, name.text.trim(), mobile.text, rType, rType == 'Student' ? sr.text : '', hours, app.name, app.mobile);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SummaryScreen(t)));
      }),
    ]);
  }
}

class SummaryScreen extends StatelessWidget {
  const SummaryScreen(this.t, {super.key});
  final Txn t;
  @override
  Widget build(BuildContext context) {
    final rate = rateOf(t.comp.size)!;
    return AppPage('Transaction Summary', [
      Align(alignment: Alignment.centerLeft, child: Pill(tStatusInfo(t.status).$1, amber)),
      const SizedBox(height: 10),
      Panel(
          child: Column(children: [
        KV('Booking Ref', t.ref),
        KV('Locker', '${t.comp.id} (${sizeLabel(t.comp.size)})'),
        KV('Item type', t.item),
        KV('Recipient', t.recipient),
        KV('Booked hours', '${t.hours} hrs'),
        const KV('Pickup PIN', 'In recipient\'s app'),
      ])),
      Panel(
          child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Price breakdown', style: TextStyle(fontWeight: FontWeight.bold))),
        KV('${sizeLabel(t.comp.size)} locker, per booked hour', peso(rate)),
        KV('Booked hours', '× ${t.hours}'),
        const Divider(),
        KV('Total to pay now', peso(t.fee), bold: true, color: teal),
      ])),
      const Text('Recipient pays only if a late fee applies (₱10 per late hour).', style: TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 14),
      BigButton('Pay ${peso(t.fee)} via GCash', () {
        app.pay(t); // TODO: real GCash gateway (test mode during pilot)
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DepositScreen(t)));
      }, color: gcash),
    ]);
  }
}

// ───────── deposit ─────────
class DepositScreen extends StatelessWidget {
  const DepositScreen(this.t, {super.key});
  final Txn t;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          if (t.status == TStatus.booked) {
            final left = t.paidAt!.add(const Duration(minutes: graceMinutes)).difference(app.now);
            return AppPage('Drop Off', [
              Panel(
                  child: Column(children: [
                const Text('Your one-time drop-off PIN', style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 6),
                Text(t.dropPin.split('').join(' '), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: navy)),
                const SizedBox(height: 6),
                Text('Deposit within ${dur(left)} or the booking expires.', style: const TextStyle(color: red, fontSize: 12)),
              ])),
              const Panel(
                  child: Text('1. At the locker, choose Drop Off and enter the PIN.\n2. Scan the one-time QR code on the locker screen with this app.\n3. Place the item inside and close the door.',
                      style: TextStyle(height: 1.6))),
              BigButton('Scan Locker QR Code', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(t, 'dropoff')))),
            ]);
          }
          if (t.depositedAt == null) {
            return AppPage('Drop Off', [bigCheck('Booking ${tStatusInfo(t.status).$1}', t.ref), BigButton('Done', () => Navigator.popUntil(context, (r) => r.isFirst))]);
          }
          return AppPage('Deposit Status', [
            bigCheck('Item Deposited!', 'Locker ${t.comp.id} is locked and secure'),
            Panel(
                child: Column(children: [
              KV('Deposited at', clock(t.depositedAt!)),
              KV('Booked until', clock(t.bookedUntil!)),
              KV('Latest pickup', stamp(t.limitAt!)),
              const KV('Recipient', 'Notified · PIN in app'),
            ])),
            const Panel(child: Steps(['Booked', 'Deposited', 'Retrieved'], 2)),
            BigButton('View Transaction Details', () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TxnDetail(t))), outline: true),
            const SizedBox(height: 8),
            BigButton('Done', () => Navigator.popUntil(context, (r) => r.isFirst)),
          ]);
        },
      );
}

// ───────── pickup ─────────
class PickupTab extends StatelessWidget {
  const PickupTab({super.key});
  @override
  Widget build(BuildContext context) {
    final list = app.txns.where((t) => t.ready && app.isRecipient(t)).toList();
    if (list.isEmpty) return const Center(child: Text('No items waiting for pickup.', style: TextStyle(color: Colors.black54)));
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final t in list)
        Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${t.comp.id} · ${t.item}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('From ${t.sender}'),
            trailing: Pill(tStatusInfo(t.status).$1, tStatusInfo(t.status).$2),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PickupScreen(t))),
          ),
        ),
    ]);
  }
}

class PickupScreen extends StatelessWidget {
  const PickupScreen(this.t, {super.key});
  final Txn t;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          if (!t.ready) return AppPage('Pick Up Item', [bigCheck(tStatusInfo(t.status).$1, t.ref), BigButton('Back', () => Navigator.pop(context))]);
          final fee = app.lateFee(t);
          final elapsed = app.now.difference(t.depositedAt!);
          return AppPage('Pick Up Item', [
            Panel(
                child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${t.comp.id} · ${t.item}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Pill(tStatusInfo(t.status).$1, tStatusInfo(t.status).$2),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (elapsed.inMinutes / (limitHours * 60)).clamp(0, 1).toDouble(), color: fee > 0 ? amber : green, minHeight: 7),
              const SizedBox(height: 6),
              Text(fee > 0 ? 'Booked time ended ${dur(app.now.difference(t.bookedUntil!))} ago' : 'Booked time left: ${dur(t.bookedUntil!.difference(app.now))}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text('24-hour limit in: ${dur(t.limitAt!.difference(app.now))}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ])),
            pinBox(t.pickupPin),
            const Panel(child: Text('1. Enter the PIN on the locker (Pick Up).\n2. Scan the QR shown on its screen.\n3. Pay the late fee, if any, then it unlocks.', style: TextStyle(height: 1.6))),
            if (fee > 0)
              Panel(child: KV('Late fee so far (${app.lateHours(t)} hrs × ${peso(lateRate)})', peso(fee), bold: true, color: red)),
            BigButton('Scan Locker QR Code', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(t, 'pickup')))),
          ]);
        },
      );
}

class ScanScreen extends StatefulWidget {
  const ScanScreen(this.t, this.action, {super.key});
  final Txn t;
  final String action; // 'dropoff' or 'pickup'
  @override
  State<ScanScreen> createState() => _ScanState();
}

class _ScanState extends State<ScanScreen> {
  final manual = TextEditingController();
  String? code; // scanned, waiting for late-fee payment
  bool approved = false, busy = false, nav = false;
  bool get pickup => widget.action == 'pickup';
  bool get camera => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> onCode(String c) async {
    if (busy || approved || code != null) return;
    if (pickup && app.lateFee(widget.t) > 0) {
      setState(() => code = c);
      return;
    }
    await approve(c);
  }

  Future<void> approve(String c) async {
    setState(() => busy = true);
    final err = await app.approveSession(c, app.mobile);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() { busy = false; code = null; });
      return;
    }
    setState(() { busy = false; approved = true; });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final t = widget.t;
          final fee = app.lateFee(t);
          if (approved) {
            final done = pickup ? t.status == TStatus.completed : t.depositedAt != null;
            if (done && !nav) {
              nav = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => pickup ? RetrievedScreen(t) : DepositScreen(t)));
              });
            }
            return AppPage('Unlocked', [
              bigCheck('Compartment unlocked!', 'Locker ${t.comp.id} is open'),
              Panel(child: Text(pickup ? 'Take your item and close the door.' : 'Place your item inside and close the door.')),
              const Text('This screen updates once the locker confirms the door is closed.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]);
          }
          return AppPage(pickup ? 'Scan Locker QR' : 'Scan to Drop Off', [
            if (code != null) ...[
              Panel(child: Column(children: [KV('Late hours', '${app.lateHours(t)} hrs'), KV('Rate per late hour', peso(lateRate)), const Divider(), KV('Amount due', peso(fee), bold: true, color: red)])),
              BigButton(busy ? 'Please wait...' : 'Pay ${peso(fee)} via GCash & Unlock', busy ? null : () => approve(code!), color: gcash),
            ] else ...[
              const Center(child: Text('Point the camera at the QR code shown on the locker screen', textAlign: TextAlign.center)),
              const SizedBox(height: 12),
              Container(
                height: 260,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(16)),
                child: camera
                    ? MobileScanner(onDetect: (cap) {
                        final v = cap.barcodes.firstOrNull?.rawValue;
                        if (v != null) onCode(v);
                      })
                    : const Icon(Icons.qr_code_scanner, color: teal, size: 100),
              ),
              const SizedBox(height: 6),
              const Center(child: Text('QR code expires in about 60 seconds', style: TextStyle(fontSize: 12, color: Colors.black54))),
              const SizedBox(height: 14),
              TextField(controller: manual, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Or type the code shown on the locker (LK-XXXXXXXX)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              BigButton(busy ? 'Please wait...' : 'Submit Code', busy ? null : () => onCode(manual.text), outline: true),
            ],
          ]);
        },
      );
}

class RetrievedScreen extends StatelessWidget {
  const RetrievedScreen(this.t, {super.key});
  final Txn t;
  @override
  Widget build(BuildContext context) => AppPage('Pick Up Complete', [
        bigCheck('Item Retrieved Successfully!', 'Locker ${t.comp.id} is available again'),
        Panel(
            child: Column(children: [
          KV('Retrieved at', clock(t.retrievedAt!)),
          KV('Time stored', dur(t.retrievedAt!.difference(t.depositedAt!))),
          KV('Late fee paid', peso(t.latePaid)),
          KV('Status', tStatusInfo(t.status).$1, color: green),
        ])),
        const Panel(child: Steps(['Booked', 'Deposited', 'Retrieved'], 3)),
        BigButton('Done', () => Navigator.popUntil(context, (r) => r.isFirst)),
      ]);
}

// ───────── transactions ─────────
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});
  @override
  State<TransactionsTab> createState() => _TxState();
}

class _TxState extends State<TransactionsTab> {
  String f = 'All';
  @override
  Widget build(BuildContext context) {
    final list = app.txns
        .where((t) => (app.isSender(t) || app.isRecipient(t)) && (f == 'All' || (f == 'Active' ? t.active : !t.active)))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [for (final s in ['All', 'Active', 'Completed']) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s), selected: f == s, onSelected: (_) => setState(() => f = s)))]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final t in list)
            Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${t.comp.id} · ${t.item}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(t.ref),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(peso(t.fee + t.latePaid), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Pill(tStatusInfo(t.status).$1, tStatusInfo(t.status).$2),
                ]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TxnDetail(t))),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class TxnDetail extends StatelessWidget {
  const TxnDetail(this.t, {super.key});
  final Txn t;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => AppPage('Transaction Details', [
          Align(alignment: Alignment.centerLeft, child: Pill(tStatusInfo(t.status).$1, tStatusInfo(t.status).$2)),
          const SizedBox(height: 10),
          Panel(
              child: Column(children: [
            KV('Reference', t.ref),
            KV('Locker', '${t.comp.id} (${sizeLabel(t.comp.size)})'),
            KV('Item type', t.item),
            KV('Sender', t.sender),
            KV('Recipient', t.recipient),
            KV('Booked hours', '${t.hours} hrs'),
            KV('Amount paid', peso(t.fee + t.latePaid)),
            if (t.depositedAt != null) KV('Deposited', stamp(t.depositedAt!)),
            if (t.bookedUntil != null) KV('Booked until', stamp(t.bookedUntil!)),
            if (t.limitAt != null) KV('24-hr limit', stamp(t.limitAt!)),
          ])),
          if (t.status == TStatus.lostFound)
            const Panel(child: Text('Your item is now at the Lost and Found Office. Please claim it there. The locker is available for other users again.')),
          const SizedBox(height: 4),
          BigButton('Demo: advance clock +1 hour', () => app.advance(1), outline: true),
        ]),
      );
}
