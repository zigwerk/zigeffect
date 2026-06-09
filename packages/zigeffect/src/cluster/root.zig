pub const domain = "cluster";

pub const identity = @import("identity.zig");
pub const mailbox = @import("mailbox.zig");
pub const entity = struct {};

pub const EntityType = identity.EntityType;
pub const EntityId = identity.EntityId;
pub const EntityAddress = identity.EntityAddress;
pub const entityId = identity.entityId;
pub const entityAddress = identity.entityAddress;
pub const EntityMessageId = mailbox.EntityMessageId;
pub const EntityCorrelationId = mailbox.EntityCorrelationId;
pub const EntityMessageSequence = mailbox.EntityMessageSequence;
pub const EntityEnvelopeKind = mailbox.EntityEnvelopeKind;
pub const EntityEnvelope = mailbox.EntityEnvelope;
pub const EntityAsk = mailbox.EntityAsk;
pub const EntityMailboxError = mailbox.EntityMailboxError;
pub const LocalMailboxStore = mailbox.LocalMailboxStore;
pub const cloneEntityAddress = mailbox.cloneEntityAddress;
pub const deinitEntityAddress = mailbox.deinitEntityAddress;
pub const cloneEntityEnvelope = mailbox.cloneEntityEnvelope;
pub const deinitEntityEnvelope = mailbox.deinitEntityEnvelope;
