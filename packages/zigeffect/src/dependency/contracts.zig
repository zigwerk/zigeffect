pub fn assertEffectEnvironment(comptime api: []const u8, comptime ExpectedEnv: type, effect: anytype) void {
    const EffectType = @TypeOf(effect);

    if (!@hasDecl(EffectType, "EnvType")) {
        @compileError(
            "zigeffect environment mismatch\n\n" ++
                "api: " ++ api ++ "\n\n" ++
                "Expected an effect-like value with an EnvType declaration.",
        );
    }

    if (EffectType.EnvType != ExpectedEnv) {
        @compileError(
            "zigeffect environment mismatch\n\n" ++
                "api: " ++ api ++ "\n" ++
                "expected environment: " ++ @typeName(ExpectedEnv) ++ "\n" ++
                "effect environment: " ++ @typeName(EffectType.EnvType) ++ "\n\n" ++
                "Run the effect with a matching layer/runtime, or adapt the effect to the target environment.",
        );
    }
}
