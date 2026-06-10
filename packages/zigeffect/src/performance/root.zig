pub const domain = "performance";
pub const benchmark = @import("benchmark.zig");

pub const performance_benchmark_schema = benchmark.performance_benchmark_schema;
pub const performance_benchmark_schema_version = benchmark.performance_benchmark_schema_version;
pub const PerformanceThresholdViolationKind = benchmark.PerformanceThresholdViolationKind;
pub const PerformanceThresholdViolation = benchmark.PerformanceThresholdViolation;
pub const PerformanceThresholds = benchmark.PerformanceThresholds;
pub const PerformanceBenchmarkOptions = benchmark.PerformanceBenchmarkOptions;
pub const JournalBenchmarkReport = benchmark.JournalBenchmarkReport;
pub const MailboxBenchmarkReport = benchmark.MailboxBenchmarkReport;
pub const PerformanceBenchmarkReport = benchmark.PerformanceBenchmarkReport;
pub const runPerformanceBenchmarks = benchmark.runPerformanceBenchmarks;
pub const formatPerformanceBenchmarkText = benchmark.formatPerformanceBenchmarkText;
pub const formatPerformanceBenchmarkJson = benchmark.formatPerformanceBenchmarkJson;
