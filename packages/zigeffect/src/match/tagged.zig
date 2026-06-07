pub fn exhaustive(comptime Return: type, value: anytype, handlers: anytype) Return {
    _ = value;
    _ = handlers;
    @compileError("zigeffect match exhaustive is not implemented");
}

pub fn partial(comptime Return: type, value: anytype, handlers: anytype) ?Return {
    _ = value;
    _ = handlers;
    return null;
}

pub fn orElse(comptime Return: type, value: anytype, handlers: anytype, fallback: Return) Return {
    _ = value;
    _ = handlers;
    return fallback;
}

pub fn option(comptime Return: type, value: anytype, handlers: anytype) ?Return {
    return partial(Return, value, handlers);
}

pub fn either(comptime Return: type, comptime Error: type, value: anytype, handlers: anytype) Error!Return {
    _ = value;
    _ = handlers;
    return error.NoMatch;
}
