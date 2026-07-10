type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

const secretKey = /^(api[_-]?key|x-api-key|token|password|secret|session(?:_id)?|sid)$/i;

export function redactLocalDevText(value: string): string {
  const json = redactJsonDocument(value);
  return json ?? redactPlainText(value);
}

function redactJsonDocument(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) {
    return null;
  }
  try {
    const parsed = JSON.parse(trimmed) as unknown;
    if (!isJsonContainer(parsed)) return null;
    return JSON.stringify(redactJsonValue(parsed));
  } catch {
    return null;
  }
}

function redactJsonValue(value: JsonValue): JsonValue {
  if (typeof value === "string") {
    return redactPlainText(value);
  }
  if (Array.isArray(value)) {
    return value.map(redactJsonValue);
  }
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, nested]) => [
        key,
        secretKey.test(key) ? "<redacted>" : redactJsonValue(nested),
      ]),
    );
  }
  return value;
}

function redactPlainText(value: string): string {
  return value
    .replace(/\b([a-z][a-z0-9+.-]*:\/\/)[^/?#\s:@]+:[^/?#\s@]+@/gi, "$1<redacted>@")
    .replace(/\b(authorization|proxy-authorization)\s*:\s*(bearer|basic)\s+[^;\s,]+/gi, "$1: $2 <redacted>")
    .replace(/\bcookie\s*:\s*[^,\n\r]+/gi, "Cookie: <redacted>")
    .replace(
      /\b(api[_-]?key|x-api-key|token|password|secret|session(?:_id)?|sid)\b\s*[:=]\s*("[^"]*"|'[^']*'|[^;\s,}\]]+)/gi,
      "$1=<redacted>",
    );
}

function isJsonContainer(value: unknown): value is JsonValue[] | { [key: string]: JsonValue } {
  return Array.isArray(value) || (typeof value === "object" && value !== null);
}
