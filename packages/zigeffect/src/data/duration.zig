pub const Duration = union(enum) {
    finite: i128,
    infinity,
};
