// Shared by the user app and the locker display app.
// Firestore collections: compartments, transactions, qrSessions, users, config/demo.
// Prototype only: checks run in the apps (no Cloud Functions) and Firestore is in test mode.
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const navy = Color(0xFF12284C);
const teal = Color(0xFF1ABC9C);
const gcash = Color(0xFF1A6FE0);
const amber = Color(0xFFE8A33D);
const purple = Color(0xFF7C5CC4);
const green = Color(0xFF2E9E6B);
const red = Color(0xFFD64545);
const bg = Color(0xFFF1F5F9);

enum LockerSize { small, medium, large }
enum CStatus { available, reserved, occupied, overdue }
enum TStatus { awaitingPayment, booked, deposited, overdue, completed, lostFound, expired }

const itemTypes = ['Food', 'Package', 'Document', 'School Material', 'Other'];
const recipientTypes = ['Student', 'Faculty', 'Staff', 'Parent', 'Visitor'];
const lateRate = 10, limitHours = 24, graceMinutes = 15, qrSeconds = 60;

int? rateOf(LockerSize s) => s == LockerSize.small ? 15 : s == LockerSize.medium ? 25 : null; // large: TBD
String sizeLabel(LockerSize s) => s.name[0].toUpperCase() + s.name.substring(1);
String peso(int n) => '₱$n';
String digits(String s) => s.replaceAll(RegExp(r'\D'), '');
String normMobile(String s) {
  var d = digits(s);
  if (d.startsWith('63')) {
    d = '0${d.substring(2)}';
  } else if (d.length == 10 && d.startsWith('9')) {
    d = '0$d';
  }
  return d;
}

String _two(int n) => n.toString().padLeft(2, '0');
String clock(DateTime d) => '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${_two(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
String stamp(DateTime d) => '${d.month}/${d.day}, ${clock(d)}';
String dur(Duration d) => d.isNegative ? '0m' : d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes}m';

(String, Color) cStatusInfo(CStatus s) => switch (s) {
      CStatus.available => ('Available', green),
      CStatus.reserved => ('Reserved', amber),
      CStatus.occupied => ('Occupied', Colors.blueGrey),
      CStatus.overdue => ('Overdue', red),
    };
(String, Color) tStatusInfo(TStatus s) => switch (s) {
      TStatus.awaitingPayment => ('Awaiting Payment', amber),
      TStatus.booked => ('Booked', gcash),
      TStatus.deposited => ('Ready for Pickup', green),
      TStatus.overdue => ('Overdue', red),
      TStatus.completed => ('Completed', green),
      TStatus.lostFound => ('Moved to Lost & Found', purple),
      TStatus.expired => ('Expired', Colors.blueGrey),
    };

/// Shared (demo-skewed) clock, set by Hub.
DateTime Function() clockNow = DateTime.now;

class Compartment {
  Compartment(this.id, this.size);
  final String id;
  final LockerSize size;
  CStatus raw = CStatus.available;
  String? txnRef;
  bool overdue = false;
  CStatus get status => raw == CStatus.occupied && overdue ? CStatus.overdue : raw;
}

class Txn {
  Txn({required this.ref, required this.comp, required this.item, required this.sender, required this.senderMobile,
      required this.recipient, required this.mobile, required this.rType, this.sr = '', required this.hours,
      required this.fee, required this.created});
  factory Txn.fromMap(String ref, Compartment c, Map<String, dynamic> m) => Txn(
      ref: ref, comp: c, item: m['item'] ?? '', sender: m['sender'] ?? '', senderMobile: m['senderMobile'] ?? '',
      recipient: m['recipient'] ?? '', mobile: m['mobile'] ?? '', rType: m['rType'] ?? '', sr: m['sr'] ?? '',
      hours: (m['hours'] as num).toInt(), fee: (m['fee'] as num).toInt(),
      created: DateTime.fromMillisecondsSinceEpoch((m['created'] as num).toInt()));

  final String ref, item, sender, senderMobile, recipient, mobile, rType, sr;
  final Compartment comp;
  final int hours, fee;
  final DateTime created;
  TStatus raw = TStatus.awaitingPayment;
  String dropPin = '', pickupPin = '';
  DateTime? paidAt, depositedAt, retrievedAt;
  int latePaid = 0;

  static DateTime? _t(dynamic v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
  void apply(Map<String, dynamic> m) {
    raw = TStatus.values.byName(m['status'] ?? 'awaitingPayment');
    dropPin = m['dropPin'] ?? '';
    pickupPin = m['pickupPin'] ?? '';
    paidAt = _t(m['paidAt']);
    depositedAt = _t(m['depositedAt']);
    retrievedAt = _t(m['retrievedAt']);
    latePaid = ((m['latePaid'] ?? 0) as num).toInt();
  }

  DateTime? get bookedUntil => depositedAt?.add(Duration(hours: hours));
  DateTime? get limitAt => depositedAt?.add(const Duration(hours: limitHours));

  /// Status derived from the stored status + time (expired / overdue / lost & found).
  TStatus get status {
    final n = clockNow();
    const grace = Duration(minutes: graceMinutes);
    if (raw == TStatus.awaitingPayment && n.isAfter(created.add(grace))) return TStatus.expired;
    if (raw == TStatus.booked && paidAt != null && n.isAfter(paidAt!.add(grace))) return TStatus.expired;
    if (raw == TStatus.deposited && depositedAt != null) {
      if (!n.isBefore(limitAt!)) return TStatus.lostFound;
      if (n.isAfter(bookedUntil!)) return TStatus.overdue;
    }
    return raw;
  }

  bool get ready => status == TStatus.deposited || status == TStatus.overdue;
  bool get active => ready || status == TStatus.awaitingPayment || status == TStatus.booked;
}

class Hub extends ChangeNotifier {
  Hub() {
    clockNow = () => now;
  }
  FirebaseFirestore get db => FirebaseFirestore.instance;
  final comps = <Compartment>[
    Compartment('S-01', LockerSize.small), Compartment('S-02', LockerSize.small),
    Compartment('M-01', LockerSize.medium), Compartment('M-02', LockerSize.medium),
    Compartment('L-01', LockerSize.large),
  ];
  final _txns = <String, Txn>{};
  List<Txn> get txns => _txns.values.toList()..sort((a, b) => b.created.compareTo(a.created));
  Compartment? comp(String id) => comps.where((c) => c.id == id).firstOrNull;

  Duration skew = Duration.zero; // shared demo clock (config/demo)
  DateTime get now => DateTime.now().add(skew);
  final _r = Random();
  String _pin() => List.generate(6, (_) => _r.nextInt(10)).join();

  Future<void> start() async {
    final col = db.collection('compartments');
    if ((await col.limit(1).get()).docs.isEmpty) {
      final b = db.batch();
      for (final c in comps) {
        b.set(col.doc(c.id), {'size': c.size.name, 'status': 'available', 'txn': null});
      }
      await b.commit();
    }
    col.snapshots().listen((s) {
      for (final d in s.docs) {
        final c = comp(d.id);
        if (c == null) continue;
        final m = d.data();
        c.raw = CStatus.values.byName(m['status'] ?? 'available');
        c.txnRef = m['txn'];
      }
      _changed();
    });
    db.collection('transactions').snapshots().listen((s) {
      for (final d in s.docs) {
        final m = d.data();
        final c = comp(m['comp'] ?? '');
        if (c == null) continue;
        _txns.putIfAbsent(d.id, () => Txn.fromMap(d.id, c, m)).apply(m);
      }
      _changed();
    });
    db.doc('config/demo').snapshots().listen((d) {
      skew = Duration(hours: ((d.data()?['skewHours'] ?? 0) as num).toInt());
      _changed();
    });
    Timer.periodic(const Duration(seconds: 20), (_) {
      _changed();
      maintain();
    });
  }

  void _changed() {
    for (final c in comps) {
      c.overdue = _txns[c.txnRef]?.status == TStatus.overdue;
    }
    notifyListeners();
  }

  /// Frees compartments of expired bookings and items moved to Lost & Found.
  Future<void> maintain() async {
    for (final t in _txns.values.toList()) {
      final s = t.status;
      if ((s == TStatus.expired || s == TStatus.lostFound) && t.raw != s) {
        t.raw = s;
        final b = db.batch();
        b.update(db.doc('transactions/${t.ref}'), {'status': s.name});
        if (t.comp.txnRef == t.ref) b.update(db.doc('compartments/${t.comp.id}'), {'status': 'available', 'txn': null});
        try {
          await b.commit();
        } catch (_) {}
      }
    }
    _changed();
  }

  int lateHours(Txn t) =>
      t.status != TStatus.overdue ? 0 : max(1, (now.difference(t.bookedUntil!).inSeconds / 3600).ceil());
  int lateFee(Txn t) => lateHours(t) * lateRate;

  // ── user app actions ──
  Future<Txn> book(Compartment c, String item, String rName, String rMobile, String rType, String sr, int hours,
      String sender, String senderMobile) async {
    final ref = 'DB-${now.millisecondsSinceEpoch % 100000}-001';
    final t = Txn(ref: ref, comp: c, item: item, sender: sender, senderMobile: senderMobile, recipient: rName,
        mobile: rMobile, rType: rType, sr: sr, hours: hours, fee: hours * rateOf(c.size)!, created: now);
    _txns[ref] = t;
    c.raw = CStatus.reserved;
    c.txnRef = ref;
    _changed();
    final b = db.batch();
    b.set(db.doc('transactions/$ref'), {
      'comp': c.id, 'item': item, 'sender': sender, 'senderMobile': senderMobile, 'recipient': rName,
      'mobile': rMobile, 'rType': rType, 'sr': sr, 'hours': hours, 'fee': t.fee,
      'created': t.created.millisecondsSinceEpoch, 'status': 'awaitingPayment', 'dropPin': '', 'pickupPin': '',
      'paidAt': null, 'depositedAt': null, 'retrievedAt': null, 'latePaid': 0,
    });
    b.update(db.doc('compartments/${c.id}'), {'status': 'reserved', 'txn': ref});
    await b.commit();
    return t;
  }

  Future<void> pay(Txn t) async {
    if (t.status != TStatus.awaitingPayment) return;
    t.raw = TStatus.booked;
    t.paidAt = now;
    t.dropPin = _pin();
    _changed();
    await db.doc('transactions/${t.ref}').update(
        {'status': 'booked', 'paidAt': t.paidAt!.millisecondsSinceEpoch, 'dropPin': t.dropPin});
  }

  Future<void> advance(int h) =>
      db.doc('config/demo').set({'skewHours': FieldValue.increment(h)}, SetOptions(merge: true));

  /// Checks the locker's QR session against the signed-in account. Returns an error message or null.
  Future<String?> approveSession(String code, String userMobile) async {
    final ref = db.doc('qrSessions/${code.trim().toUpperCase()}');
    final d = await ref.get();
    if (!d.exists) return 'Invalid QR code.';
    final m = d.data()!;
    if (DateTime.now().millisecondsSinceEpoch > (m['expiresAt'] as num)) return 'This QR code has expired.';
    if (m['state'] != 'pending') return 'This QR code was already used.';
    final t = _txns[m['txn']];
    if (t == null) return 'Transaction not found.';
    final drop = m['action'] == 'dropoff';
    if (normMobile(drop ? t.senderMobile : t.mobile) != normMobile(userMobile)) {
      return 'This code is not for your account.';
    }
    await ref.update({'state': 'approved', 'by': userMobile, 'latePaid': drop ? 0 : lateFee(t)});
    return null;
  }

  // ── locker display actions ──
  Txn? findByPin(String pin, String action) => _txns.values
      .where((t) => action == 'dropoff' ? (t.status == TStatus.booked && t.dropPin == pin) : (t.ready && t.pickupPin == pin))
      .firstOrNull;

  Future<String> startSession(Txn t, String action) async {
    final code = 'LK-${List.generate(8, (_) => '0123456789ABCDEF'[_r.nextInt(16)]).join()}';
    await db.doc('qrSessions/$code').set({
      'txn': t.ref, 'comp': t.comp.id, 'action': action, 'state': 'pending', 'latePaid': 0,
      'expiresAt': DateTime.now().millisecondsSinceEpoch + qrSeconds * 1000,
    });
    return code;
  }

  Stream<Map<String, dynamic>?> sessionStream(String code) => db.doc('qrSessions/$code').snapshots().map((d) => d.data());
  Future<void> finishSession(String code) => db.doc('qrSessions/$code').update({'state': 'done'});

  /// "Door sensor": the locker confirms the item is inside and the door is locked.
  Future<void> confirmDeposit(Txn t) async {
    final pin = _pin();
    t.raw = TStatus.deposited;
    t.depositedAt = now;
    t.pickupPin = pin;
    t.comp.raw = CStatus.occupied;
    _changed();
    final b = db.batch();
    b.update(db.doc('transactions/${t.ref}'),
        {'status': 'deposited', 'depositedAt': t.depositedAt!.millisecondsSinceEpoch, 'pickupPin': pin});
    b.update(db.doc('compartments/${t.comp.id}'), {'status': 'occupied'});
    await b.commit();
  }

  Future<void> confirmRetrieval(Txn t, int latePaid) async {
    t.raw = TStatus.completed;
    t.retrievedAt = now;
    t.latePaid = latePaid;
    t.comp.raw = CStatus.available;
    t.comp.txnRef = null;
    _changed();
    final b = db.batch();
    b.update(db.doc('transactions/${t.ref}'),
        {'status': 'completed', 'retrievedAt': t.retrievedAt!.millisecondsSinceEpoch, 'latePaid': latePaid});
    b.update(db.doc('compartments/${t.comp.id}'), {'status': 'available', 'txn': null});
    await b.commit();
  }
}
