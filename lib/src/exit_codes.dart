class ExitCodes {
  static const int success = 0;
  static const int usage = 2;
  static const int unknown = 1;

  static const int registryNotFound = 10;
  static const int schemaInvalid = 20;
  static const int componentMissing = 30;
  static const int fileMissing = 31;
  static const int networkError = 40;
  static const int offlineUnavailable = 41;
  static const int validationFailed = 50;
  static const int configInvalid = 60;
  static const int ioError = 70;
}

class ExitCodeLabels {
  static const registryNotFound = 'registry_not_found';
  static const schemaInvalid = 'schema_invalid';
  static const componentMissing = 'component_missing';
  static const fileMissing = 'file_missing';
  static const networkError = 'network_error';
  static const offlineUnavailable = 'offline_unavailable';
  static const validationFailed = 'validation_failed';
  static const configInvalid = 'config_invalid';
  static const ioError = 'io_error';
  static const usage = 'usage_error';
  static const unknown = 'unknown_error';
}
