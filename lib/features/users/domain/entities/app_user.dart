import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/database/database_helper.dart';

// ─── User Roles ────────────────────────────────────────────────────────────────
enum UserRole { admin, user }

extension UserRoleExt on UserRole {
  String get value => name;
  String get label => name == 'admin' ? 'Admin' : 'User';
  String get emoji => name == 'admin' ? '👑' : '👤';
}

// ─── User Permissions ─────────────────────────────────────────────────────────
class UserPermissions extends Equatable {
  final bool canBill;
  final bool canViewReports;
  final bool canManageProducts;
  final bool canManageMasters;
  final bool canViewExpenses;
  final bool canManagePurchase;
  final bool canViewDashboard;

  const UserPermissions({
    this.canBill = true,
    this.canViewReports = false,
    this.canManageProducts = false,
    this.canManageMasters = false,
    this.canViewExpenses = false,
    this.canManagePurchase = false,
    this.canViewDashboard = true,
  });

  // Admin gets all permissions
  factory UserPermissions.admin() => const UserPermissions(
    canBill: true, canViewReports: true, canManageProducts: true,
    canManageMasters: true, canViewExpenses: true,
    canManagePurchase: true, canViewDashboard: true,
  );

  // Default user — billing only
  factory UserPermissions.defaultUser() => const UserPermissions(
    canBill: true, canViewDashboard: true,
  );

  factory UserPermissions.fromMap(Map<String, dynamic> m) => UserPermissions(
    canBill: (m['can_bill'] as int? ?? 1) == 1,
    canViewReports: (m['can_view_reports'] as int? ?? 0) == 1,
    canManageProducts: (m['can_manage_products'] as int? ?? 0) == 1,
    canManageMasters: (m['can_manage_masters'] as int? ?? 0) == 1,
    canViewExpenses: (m['can_view_expenses'] as int? ?? 0) == 1,
    canManagePurchase: (m['can_manage_purchase'] as int? ?? 0) == 1,
    canViewDashboard: (m['can_view_dashboard'] as int? ?? 1) == 1,
  );

  Map<String, int> toMap() => {
    'can_bill': canBill ? 1 : 0,
    'can_view_reports': canViewReports ? 1 : 0,
    'can_manage_products': canManageProducts ? 1 : 0,
    'can_manage_masters': canManageMasters ? 1 : 0,
    'can_view_expenses': canViewExpenses ? 1 : 0,
    'can_manage_purchase': canManagePurchase ? 1 : 0,
    'can_view_dashboard': canViewDashboard ? 1 : 0,
  };

  UserPermissions copyWith({
    bool? canBill, bool? canViewReports, bool? canManageProducts,
    bool? canManageMasters, bool? canViewExpenses,
    bool? canManagePurchase, bool? canViewDashboard,
  }) => UserPermissions(
    canBill: canBill ?? this.canBill,
    canViewReports: canViewReports ?? this.canViewReports,
    canManageProducts: canManageProducts ?? this.canManageProducts,
    canManageMasters: canManageMasters ?? this.canManageMasters,
    canViewExpenses: canViewExpenses ?? this.canViewExpenses,
    canManagePurchase: canManagePurchase ?? this.canManagePurchase,
    canViewDashboard: canViewDashboard ?? this.canViewDashboard,
  );

  @override
  List<Object?> get props => [canBill, canViewReports, canManageProducts,
    canManageMasters, canViewExpenses, canManagePurchase, canViewDashboard];
}

// ─── App User Entity ───────────────────────────────────────────────────────────
class AppUser extends Equatable {
  final int? id;
  final String username;
  final String pin;
  final UserRole role;
  final UserPermissions permissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    this.id,
    required this.username,
    required this.pin,
    required this.role,
    required this.permissions,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromMap(Map<String, dynamic> m) {
    final role = m['role'] == 'admin' ? UserRole.admin : UserRole.user;
    return AppUser(
      id: m['id'] as int?,
      username: m['username'] as String,
      pin: m['pin'] as String,
      role: role,
      permissions: role == UserRole.admin
          ? UserPermissions.admin()
          : UserPermissions.fromMap(m),
      isActive: (m['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'username': username,
    'pin': pin,
    'role': role.value,
    ...permissions.toMap(),
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  AppUser copyWith({
    String? username, String? pin, UserRole? role,
    UserPermissions? permissions, bool? isActive,
  }) => AppUser(
    id: id,
    username: username ?? this.username,
    pin: pin ?? this.pin,
    role: role ?? this.role,
    permissions: permissions ?? this.permissions,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  @override
  List<Object?> get props => [id, username, role];
}

// ─── User Repository ───────────────────────────────────────────────────────────
class UserRepository {
  final DatabaseHelper _db;
  UserRepository(this._db);

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<List<AppUser>> getAllUsers() async {
    final db = await _db.database;
    final rows = await db.query('app_users', orderBy: 'role DESC, username ASC');
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<AppUser?> verifyPin(String username, String pin) async {
    final db = await _db.database;
    final rows = await db.query('app_users',
        where: 'username = ? AND pin = ? AND is_active = 1',
        whereArgs: [username, _hashPin(pin)]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<bool> hasAnyAdmin() async {
    final db = await _db.database;
    final rows = await db.query('app_users',
        where: "role = 'admin' AND is_active = 1", limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> createUser(AppUser user) async {
    final db = await _db.database;
    final map = user.toMap();
    map['pin'] = _hashPin(user.pin);
    return await db.insert('app_users', map);
  }

  Future<bool> updateUser(AppUser user) async {
    final db = await _db.database;
    return (await db.update('app_users', user.toMap(),
        where: 'id = ?', whereArgs: [user.id])) > 0;
  }

  Future<bool> toggleActive(int id, bool isActive) async {
    final db = await _db.database;
    return (await db.update('app_users',
        {'is_active': isActive ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id])) > 0;
  }

  Future<bool> deleteUser(int id) async {
    final db = await _db.database;
    return (await db.delete('app_users', where: 'id = ?', whereArgs: [id])) > 0;
  }

  Future<bool> changePin(int userId, String newPin) async {
    final db = await _db.database;
    return (await db.update('app_users',
        {'pin': _hashPin(newPin), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [userId])) > 0;
  }
}

// ─── Events ────────────────────────────────────────────────────────────────────
abstract class UserEvent extends Equatable {
  @override List<Object?> get props => [];
}
class LoadUsers extends UserEvent {}
class CreateUser extends UserEvent {
  final AppUser user; CreateUser(this.user);
  @override List<Object?> get props => [user.username];
}
class UpdateUser extends UserEvent {
  final AppUser user; UpdateUser(this.user);
  @override List<Object?> get props => [user.id];
}
class DeleteUserEvent extends UserEvent {
  final int id; DeleteUserEvent(this.id);
  @override List<Object?> get props => [id];
}
class ToggleUserActive extends UserEvent {
  final int id; final bool isActive;
  ToggleUserActive(this.id, this.isActive);
  @override List<Object?> get props => [id, isActive];
}
class LoginUser extends UserEvent {
  final String username; final String pin;
  LoginUser(this.username, this.pin);
  @override List<Object?> get props => [username];
}
class LogoutUser extends UserEvent {}

// ─── States ────────────────────────────────────────────────────────────────────
abstract class UserState extends Equatable {
  @override List<Object?> get props => [];
}
class UserInitial extends UserState {}
class UserLoading extends UserState {}
class UserListLoaded extends UserState {
  final List<AppUser> users;
   UserListLoaded(this.users);
  @override List<Object?> get props => [users];
}
class UserLoggedIn extends UserState {
  final AppUser user;
   UserLoggedIn(this.user);
  @override List<Object?> get props => [user];
}
class UserLoginFailed extends UserState {
  final String message;
   UserLoginFailed(this.message);
  @override List<Object?> get props => [message];
}
class UserLoggedOut extends UserState {}
class UserError extends UserState {
  final String message;
   UserError(this.message);
  @override List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────────
class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _repo;

  // Currently logged in user — accessible globally
  AppUser? currentUser;

  UserBloc(this._repo) : super(UserInitial()) {
    on<LoadUsers>(_onLoad);
    on<CreateUser>(_onCreate);
    on<UpdateUser>(_onUpdate);
    on<DeleteUserEvent>(_onDelete);
    on<ToggleUserActive>(_onToggle);
    on<LoginUser>(_onLogin);
    on<LogoutUser>(_onLogout);
  }

  Future<void> _onLoad(LoadUsers e, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final users = await _repo.getAllUsers();
      emit(UserListLoaded(users));
    } catch (err) { emit(UserError(err.toString())); }
  }

  Future<void> _onCreate(CreateUser e, Emitter<UserState> emit) async {
    try {
      await _repo.createUser(e.user);
      add(LoadUsers());
    } catch (err) { emit(UserError(err.toString())); }
  }

  Future<void> _onUpdate(UpdateUser e, Emitter<UserState> emit) async {
    try {
      await _repo.updateUser(e.user);
      add(LoadUsers());
    } catch (err) { emit(UserError(err.toString())); }
  }

  Future<void> _onDelete(DeleteUserEvent e, Emitter<UserState> emit) async {
    try { await _repo.deleteUser(e.id); add(LoadUsers()); }
    catch (err) { emit(UserError(err.toString())); }
  }

  Future<void> _onToggle(ToggleUserActive e, Emitter<UserState> emit) async {
    try { await _repo.toggleActive(e.id, e.isActive); add(LoadUsers()); }
    catch (err) { emit(UserError(err.toString())); }
  }

  Future<void> _onLogin(LoginUser e, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await _repo.verifyPin(e.username, e.pin);
      if (user == null) {
        emit( UserLoginFailed('Wrong PIN. Try again.'));
      } else {
        currentUser = user;
        emit(UserLoggedIn(user));
      }
    } catch (err) { emit(UserError(err.toString())); }
  }

  Future<void> _onLogout(LogoutUser e, Emitter<UserState> emit) async {
    currentUser = null;
    emit(UserLoggedOut());
  }
}

// Convenience: expose repo for change PIN in UI
extension UserBlocExt on UserBloc {
  UserRepository get repo => _repo;
}