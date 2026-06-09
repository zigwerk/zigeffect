pub const domain = "workflow";
pub const journal = @import("journal.zig");

pub const workflow_journal_event_schema = journal.workflow_journal_event_schema;
pub const workflow_journal_event_schema_version = journal.workflow_journal_event_schema_version;
pub const WorkflowId = journal.WorkflowId;
pub const ExecutionId = journal.ExecutionId;
pub const ActivityId = journal.ActivityId;
pub const TimerId = journal.TimerId;
pub const DeferredId = journal.DeferredId;
pub const QueueId = journal.QueueId;
pub const JournalSequence = journal.JournalSequence;
pub const WorkflowEventKind = journal.WorkflowEventKind;
pub const WorkflowEvent = journal.WorkflowEvent;
pub const workflowEventKindName = journal.workflowEventKindName;
pub const formatWorkflowEventJson = journal.formatWorkflowEventJson;
pub const formatWorkflowEventText = journal.formatWorkflowEventText;
