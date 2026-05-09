bool parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

class User {
  final int id;
  final String fullname;
  final String email;
  final String phone;
  final String status;
  final String tier;
  final String? picture;
  final bool isVerified;
  final String? ipAddress;
  final String? device;
  final bool hasPin;
  final UserSetting? userSettings;
  final VirtualAccount? virtualAccount;
  final ReferralData? referral;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.fullname,
    required this.email,
    required this.phone,
    required this.status,
    required this.tier,
    this.picture,
    required this.isVerified,
    this.ipAddress,
    this.device,
    required this.hasPin,
    this.userSettings,
    this.virtualAccount,
    this.referral,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      tier: json['tier'] ?? 'BASIC',
      picture: json['picture'],
      isVerified: json['isVerified'] ?? false,
      ipAddress: json['ipAddress'],
      device: json['device'],
      hasPin: json['hasPin'] ?? false,
      userSettings: (json['userSettings'] ?? json['user_settings']) != null 
          ? UserSetting.fromJson(json['userSettings'] ?? json['user_settings']) 
          : null,
      virtualAccount: (json['virtualAccount'] ?? json['virtual_account']) != null
          ? VirtualAccount.fromJson(json['virtualAccount'] ?? json['virtual_account'])
          : null,
      referral: json['referral'] != null ? ReferralData.fromJson(json['referral']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
    );
  }
}

class VirtualAccount {
  final String? accountNumber;
  final String? accountName;
  final String? bankName;
  final String? reference;

  VirtualAccount({this.accountNumber, this.accountName, this.bankName, this.reference});

  factory VirtualAccount.fromJson(Map<String, dynamic> json) {
    return VirtualAccount(
      accountNumber: json['account_number'],
      accountName: json['account_name'],
      bankName: json['bank_name'],
      reference: json['reference'],
    );
  }
}

class Wallet {
  final int id;
  final double balance;
  final String currency;

  Wallet({required this.id, required this.balance, required this.currency});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'],
      balance: double.tryParse(json['balance'].toString()) ?? 0.0,
      currency: json['currency'] ?? 'NGN',
    );
  }
}

class UserSetting {
  final int id;
  final bool pinFingerprint;
  final bool passwordFingerprint;

  UserSetting({required this.id, required this.pinFingerprint, required this.passwordFingerprint});

  factory UserSetting.fromJson(Map<String, dynamic> json) {
    return UserSetting(
      id: json['id'] ?? 0,
      pinFingerprint: parseBool(json['pin_fingerprint']),
      passwordFingerprint: parseBool(json['password_fingerprint']),
    );
  }
}

class Transaction {
  final int id;
  final String type;
  final String serviceType;
  final double amount;
  final String reference;
  final String status;
  final bool isCredit;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.type,
    required this.serviceType,
    required this.amount,
    required this.reference,
    required this.status,
    required this.isCredit,
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    String dateStr = json['created_at'];
    DateTime dt;
    if (dateStr.contains('Z') || dateStr.contains('+') || (dateStr.length > 19 && dateStr.contains('-', 19))) {
      // String has timezone info
      dt = DateTime.parse(dateStr).toLocal();
    } else {
      // String has NO timezone info (typical for Laravel with local timezone)
      // If it's 1 hour late, it means it's UTC but treated as local, OR it's local but missing Z.
      // We assume the server sends Lagos time (+1) but without offset.
      // To fix "1 hour late", we can explicitly add 1 hour if we suspect it's UTC.
      // HOWEVER, if Laravel APP_TIMEZONE is Lagos, created_at is ALREADY Lagos time.
      // If the phone is also Lagos, DateTime.parse(dateStr) is correct.
      // If the user says it's 1 hour late, maybe the DB IS UTC.
      dt = DateTime.parse(dateStr);
      // Force WAT (+1) if it looks like UTC was intended
      if (!dt.isUtc) {
         // If parsed as local, and it's late, maybe we should treat it as UTC and convert to local?
         // If 18:00 UTC is real time 19:00 Lagos.
         // parse("18:00") -> 18:00 Local. (1 hour late).
         // So we treat as UTC: DateTime.parse("18:00" + "Z").toLocal() -> 19:00 Lagos.
         dt = DateTime.parse("${dateStr.replaceFirst(' ', 'T')}Z").toLocal();
      }
    }

    return Transaction(
      id: json['id'],
      type: json['type'] ?? '',
      serviceType: json['service_type'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      reference: json['reference'] ?? '',
      status: json['status'] ?? '',
      isCredit: json['is_credit'] ?? false,
      description: json['description'] ?? '',
      metadata: json['metadata'],
      createdAt: dt,
    );
  }
}

class ReferralData {
  final String code;
  final int totalReferrals;
  final double totalEarned;

  ReferralData({
    required this.code,
    required this.totalReferrals,
    required this.totalEarned,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    return ReferralData(
      code: json['code'] ?? '',
      totalReferrals: json['total_referrals'] ?? 0,
      totalEarned: double.tryParse(json['total_earned'].toString()) ?? 0.0,
    );
  }
}
