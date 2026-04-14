import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/masters.dart';

// ─── Events ───────────────────────────────────────────────────────────────────
abstract class MastersEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAllMasters extends MastersEvent {}
class LoadCustomers extends MastersEvent {
  final String? search;
  LoadCustomers({this.search});
}
class LoadSuppliers extends MastersEvent {
  final String? search;
  LoadSuppliers({this.search});
}

class AddBrand extends MastersEvent {
  final String name;
  final String? desc;
  AddBrand(this.name, {this.desc});
}

class DeleteBrand extends MastersEvent {
  final int id;
  DeleteBrand(this.id);
}

class AddUnit extends MastersEvent {
  final UomUnit unit;
  AddUnit(this.unit);
}

class DeleteUnit extends MastersEvent {
  final int id;
  DeleteUnit(this.id);
}

class AddCustomer extends MastersEvent {
  final Customer customer;
  AddCustomer(this.customer);
}

class UpdateCustomer extends MastersEvent {
  final Customer customer;
  UpdateCustomer(this.customer);
}

class DeleteCustomer extends MastersEvent {
  final int id;
  DeleteCustomer(this.id);
}

class AddSupplier extends MastersEvent {
  final Supplier supplier;
  AddSupplier(this.supplier);
}

class UpdateSupplier extends MastersEvent {
  final Supplier supplier;
  UpdateSupplier(this.supplier);
}

class DeleteSupplier extends MastersEvent {
  final int id;
  DeleteSupplier(this.id);
}

// ─── States ───────────────────────────────────────────────────────────────────
class MastersState extends Equatable {
  final List<Brand> brands;
  final List<UomUnit> units;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final bool isLoading;
  final String? error;

  const MastersState({
    this.brands = const [],
    this.units = const [],
    this.customers = const [],
    this.suppliers = const [],
    this.isLoading = false,
    this.error,
  });

  MastersState copyWith({
    List<Brand>? brands,
    List<UomUnit>? units,
    List<Customer>? customers,
    List<Supplier>? suppliers,
    bool? isLoading,
    String? error,
  }) =>
      MastersState(
        brands: brands ?? this.brands,
        units: units ?? this.units,
        customers: customers ?? this.customers,
        suppliers: suppliers ?? this.suppliers,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  @override
  List<Object?> get props => [brands, units, customers, suppliers, isLoading, error];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────
class MastersBloc extends Bloc<MastersEvent, MastersState> {
  final MastersRepository _repo;

  MastersBloc(this._repo) : super(const MastersState()) {
    on<LoadAllMasters>(_onLoadAll);
    on<LoadCustomers>(_onLoadCustomers);
    on<LoadSuppliers>(_onLoadSuppliers);
    on<AddBrand>(_onAddBrand);
    on<DeleteBrand>(_onDeleteBrand);
    on<AddUnit>(_onAddUnit);
    on<DeleteUnit>(_onDeleteUnit);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
    on<AddSupplier>(_onAddSupplier);
    on<UpdateSupplier>(_onUpdateSupplier);
    on<DeleteSupplier>(_onDeleteSupplier);
  }

  Future<void> _onLoadAll(LoadAllMasters e, Emitter<MastersState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final results = await Future.wait([
        _repo.getAllBrands(),
        _repo.getAllUnits(),
        _repo.getAllCustomers(),
        _repo.getAllSuppliers(),
      ]);
      emit(state.copyWith(
        brands: results[0] as List<Brand>,
        units: results[1] as List<UomUnit>,
        customers: results[2] as List<Customer>,
        suppliers: results[3] as List<Supplier>,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadCustomers(LoadCustomers e, Emitter<MastersState> emit) async {
    try {
      final customers = await _repo.getAllCustomers(search: e.search);
      emit(state.copyWith(customers: customers));
    } catch (_) {}
  }

  Future<void> _onLoadSuppliers(LoadSuppliers e, Emitter<MastersState> emit) async {
    try {
      final suppliers = await _repo.getAllSuppliers(search: e.search);
      emit(state.copyWith(suppliers: suppliers));
    } catch (_) {}
  }

  Future<void> _onAddBrand(AddBrand e, Emitter<MastersState> emit) async {
    try {
      await _repo.addBrand(e.name, description: e.desc);
      add(LoadAllMasters());
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onDeleteBrand(DeleteBrand e, Emitter<MastersState> emit) async {
    await _repo.deleteBrand(e.id);
    add(LoadAllMasters());
  }

  Future<void> _onAddUnit(AddUnit e, Emitter<MastersState> emit) async {
    await _repo.addUnit(e.unit);
    add(LoadAllMasters());
  }

  Future<void> _onDeleteUnit(DeleteUnit e, Emitter<MastersState> emit) async {
    await _repo.deleteUnit(e.id);
    add(LoadAllMasters());
  }

  Future<void> _onAddCustomer(AddCustomer e, Emitter<MastersState> emit) async {
    await _repo.addCustomer(e.customer);
    add(LoadAllMasters());
  }

  Future<void> _onUpdateCustomer(UpdateCustomer e, Emitter<MastersState> emit) async {
    await _repo.updateCustomer(e.customer);
    add(LoadAllMasters());
  }

  Future<void> _onDeleteCustomer(DeleteCustomer e, Emitter<MastersState> emit) async {
    await _repo.deleteCustomer(e.id);
    add(LoadAllMasters());
  }

  Future<void> _onAddSupplier(AddSupplier e, Emitter<MastersState> emit) async {
    await _repo.addSupplier(e.supplier);
    add(LoadAllMasters());
  }

  Future<void> _onUpdateSupplier(UpdateSupplier e, Emitter<MastersState> emit) async {
    await _repo.updateSupplier(e.supplier);
    add(LoadAllMasters());
  }

  Future<void> _onDeleteSupplier(DeleteSupplier e, Emitter<MastersState> emit) async {
    await _repo.deleteSupplier(e.id);
    add(LoadAllMasters());
  }
}

extension MastersBlocRepo on MastersBloc {
  MastersRepository get repository => _repo;
}