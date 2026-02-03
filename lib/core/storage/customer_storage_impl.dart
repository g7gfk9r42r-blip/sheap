import 'src/customer_storage_stub.dart'
    if (dart.library.io) 'src/customer_storage_io.dart'
    if (dart.library.html) 'src/customer_storage_web.dart' as impl;

/// Conditional-import shim that always exposes a concrete class name.
class CustomerStorageImpl extends impl.CustomerStorageImpl {}


