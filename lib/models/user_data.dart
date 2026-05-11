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
  final List<VirtualAccount> virtualAccounts;
  final ReferralData? referral;
  final Wallet? wallet;
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
    this.virtualAccounts = const [],
    this.referral,
    this.wallet,
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
      virtualAccounts: json['virtual_accounts'] is List
          ? (json['virtual_accounts'] as List)
              .map((e) => VirtualAccount.fromJson(e as Map<String, dynamic>))
              .toList()
          : (json['virtualAccounts'] is List 
              ? (json['virtualAccounts'] as List).map((e) => VirtualAccount.fromJson(e as Map<String, dynamic>)).toList() 
              : []),
      referral: json['referral'] != null ? ReferralData.fromJson(json['referral']) : null,
      wallet: json['wallet'] != null ? Wallet.fromJson(json['wallet']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
    );
  }
}

class VirtualAccount {
  final String? accountNumber;
  final String? accountName;
  final String? bankName;
  final String? reference;
  final String? provider;
  final bool isPrimary;
  final String status;

  VirtualAccount({
    this.accountNumber,
    this.accountName,
    this.bankName,
    this.reference,
    this.provider,
    this.isPrimary = false,
    this.status = 'ACTIVE',
  });

  factory VirtualAccount.fromJson(Map<String, dynamic> json) {
    return VirtualAccount(
      accountNumber: json['account_number'],
      accountName: json['account_name'],
      bankName: json['bank_name'],
      reference: json['reference'],
      provider: json['provider'],
      isPrimary: parseBool(json['is_primary']),
      status: json['status'] ?? 'ACTIVE',
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
      dt = DateTime.parse(dateStr).toLocal();
    } else {
      dt = DateTime.parse(dateStr);
      if (!dt.isUtc) {
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
