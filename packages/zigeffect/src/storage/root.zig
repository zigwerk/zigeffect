pub const domain = "storage";
pub const schema = @import("schema.zig");

pub const storage_catalog_schema = schema.storage_catalog_schema;
pub const storage_catalog_schema_version = schema.storage_catalog_schema_version;
pub const StorageAdapterKind = schema.StorageAdapterKind;
pub const StorageRecordKind = schema.StorageRecordKind;
pub const StorageSchemaDescriptor = schema.StorageSchemaDescriptor;
pub const StorageSchemaCompatibility = schema.StorageSchemaCompatibility;
pub const StorageSchemaCompatibilityReport = schema.StorageSchemaCompatibilityReport;
pub const StorageSchemaCatalog = schema.StorageSchemaCatalog;
pub const storageSchemaCatalog = schema.storageSchemaCatalog;
pub const findStorageSchema = schema.findStorageSchema;
pub const classifyStorageSchema = schema.classifyStorageSchema;
pub const formatStorageSchemaCatalogText = schema.formatStorageSchemaCatalogText;
pub const formatStorageSchemaCatalogJson = schema.formatStorageSchemaCatalogJson;
