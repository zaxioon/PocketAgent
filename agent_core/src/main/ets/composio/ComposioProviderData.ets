type ProviderJsonValue = Object | string | number | boolean | null | undefined;
type ProviderRecord = Record<string, ProviderJsonValue>;

interface ProviderDataBudget {
  remaining: number;
}

export interface ComposioProviderArrayTruncation {
  path: string;
  originalCount: number;
  retainedCount: number;
}

export interface ComposioProviderDataMeta {
  truncated: boolean;
  originalChars: number;
  retainedChars: number;
  reason: string;
  arrays: ComposioProviderArrayTruncation[];
  redactedSecretFields: number;
  redactedBinaryFields: number;
}

export interface ComposioProviderDataExtraction {
  data: Object | null;
  meta: ComposioProviderDataMeta;
}

interface ProviderDataState {
  budget: ProviderDataBudget;
  meta: ComposioProviderDataMeta;
}

const PROVIDER_DATA_MAX_DEPTH: number = 12;
const PROVIDER_DATA_MAX_KEYS: number = 256;
const PROVIDER_DATA_MAX_ARRAY_ITEMS: number = 1000;
const PROVIDER_DATA_CONTENT_BUDGET: number = 190000;
const PROVIDER_DATA_MAX_JSON: number = 200000;

function normalizedSecretKey(key: string): string {
  return key.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function isSecretProviderKey(key: string): boolean {
  const normalized = normalizedSecretKey(key);
  const sensitiveTokenKey = normalized === 'token' || normalized === 'accesstoken' ||
    normalized === 'refreshtoken' || normalized === 'idtoken' || normalized === 'authtoken' ||
    normalized === 'sessiontoken' || normalized === 'csrftoken' || normalized === 'bearertoken';
  return sensitiveTokenKey || normalized.endsWith('apikey') || normalized === 'jwt' || normalized.endsWith('jwt') ||
    normalized === 'passwd' || normalized === 'privatekey' || normalized === 'secretkey' ||
    normalized === 'sessionid' || normalized === 'signature' ||
    normalized === 'signingkey' || normalized.indexOf('credential') >= 0 ||
    normalized.indexOf('secret') >= 0 || normalized.indexOf('password') >= 0 ||
    normalized.indexOf('cookie') >= 0 || normalized.indexOf('authorization') >= 0;
}

function isStructuredAuthObject(key: string, value: ProviderJsonValue): boolean {
  return normalizedSecretKey(key) === 'auth' && value !== null && value !== undefined &&
    typeof value === 'object' && !Array.isArray(value);
}

function isStringAuthField(key: string, value: ProviderJsonValue): boolean {
  const normalized = normalizedSecretKey(key);
  if (normalized !== 'auth' && normalized !== 'bearer') return false;
  if (isStructuredAuthObject(key, value)) return false;
  return true;
}

function isBearerCredentialString(value: ProviderJsonValue): boolean {
  return typeof value === 'string' && /^\s*Bearer\s+\S+/i.test(value);
}

function providerEnvelopeChild(value: ProviderJsonValue): ProviderJsonValue {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return value;
  }
  const record = value as ProviderRecord;
  const responseData = record['response_data'];
  if (responseData !== undefined && responseData !== null && typeof responseData === 'object') {
    if (!Array.isArray(responseData)) {
      const responseRecord = responseData as ProviderRecord;
      const nestedData = responseRecord['data'];
      if (nestedData !== undefined && nestedData !== null && typeof nestedData === 'object') {
        return nestedData;
      }
    }
    return responseData;
  }
  return value;
}

function preferredProviderData(payload: Object): ProviderJsonValue {
  const root = payload as ProviderRecord;
  let current: ProviderJsonValue = root['data'] === undefined ? payload : root['data'];
  for (let depth = 0; depth < 4; depth++) {
    const responseChild = providerEnvelopeChild(current);
    if (responseChild !== current) {
      current = responseChild;
      continue;
    }
    if (current === null || current === undefined || typeof current !== 'object' || Array.isArray(current)) {
      break;
    }
    const record = current as ProviderRecord;
    const keys = Object.keys(record);
    const data = record['data'];
    const envelopeLike = keys.length <= 5 &&
      keys.every((key: string): boolean =>
        key === 'data' || key === 'error' || key === 'log_id' || key === 'success' || key === 'successful'
      );
    if (envelopeLike && data !== undefined && data !== null && typeof data === 'object') {
      current = data;
      continue;
    }
    break;
  }
  return current;
}

function looksLikeBinaryString(value: string): boolean {
  const clean = value.trim();
  if (clean.length < 512) return false;
  if (clean.toLowerCase().indexOf('data:') === 0 && clean.indexOf(';base64,') > 0) return true;
  return /^[A-Za-z0-9+/=_-]+$/.test(clean) && clean.indexOf(' ') < 0;
}

function boundedProviderString(value: string, state: ProviderDataState): string | undefined {
  if (state.budget.remaining <= 0) return undefined;
  if (looksLikeBinaryString(value)) {
    const omitted = '[omitted binary data]';
    state.budget.remaining -= omitted.length;
    state.meta.redactedBinaryFields++;
    return omitted;
  }
  if (value.length > state.budget.remaining) {
    const remaining = state.budget.remaining;
    state.budget.remaining = 0;
    state.meta.truncated = true;
    if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_size_limit';
    return remaining <= 0 ? undefined : value.substring(0, remaining);
  }
  state.budget.remaining -= value.length;
  return value;
}

function boundedProviderValue(
  value: ProviderJsonValue,
  depth: number,
  path: string,
  state: ProviderDataState
): ProviderJsonValue {
  if (state.budget.remaining <= 0) return undefined;
  if (value === null || typeof value === 'number' || typeof value === 'boolean') {
    state.budget.remaining -= 8;
    return value;
  }
  if (typeof value === 'string') return boundedProviderString(value, state);
  if (value === undefined) return undefined;
  if (depth >= PROVIDER_DATA_MAX_DEPTH) {
    state.meta.truncated = true;
    if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_depth_limit';
    return undefined;
  }
  if (Array.isArray(value)) {
    const source = value as ProviderJsonValue[];
    const output: ProviderJsonValue[] = [];
    for (let index = 0; index < source.length && index < PROVIDER_DATA_MAX_ARRAY_ITEMS; index++) {
      const item = boundedProviderValue(source[index], depth + 1, path + '/' + index.toString(), state);
      if (item === undefined) {
        if (state.budget.remaining <= 0) break;
        continue;
      }
      output.push(item);
      state.budget.remaining -= 2;
      if (state.budget.remaining <= 0) break;
    }
    if (output.length < source.length) {
      state.meta.truncated = true;
      if (state.meta.reason.length === 0) state.meta.reason =
        source.length > PROVIDER_DATA_MAX_ARRAY_ITEMS ? 'provider_data_array_limit' : 'provider_data_size_limit';
      if (state.meta.arrays.length < 32) {
        state.meta.arrays.push({ path: path, originalCount: source.length, retainedCount: output.length });
      }
    }
    return output as Object;
  }
  const source = value as ProviderRecord;
  const output: ProviderRecord = {};
  const keys = Object.keys(source);
  if (keys.length > PROVIDER_DATA_MAX_KEYS) {
    state.meta.truncated = true;
    if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_key_limit';
  }
  let accepted = 0;
  for (let index = 0; index < keys.length && accepted < PROVIDER_DATA_MAX_KEYS; index++) {
    const key = keys[index];
    const sourceValue = source[key];
    if (isSecretProviderKey(key) || isStringAuthField(key, sourceValue) ||
      isBearerCredentialString(sourceValue)) {
      state.meta.redactedSecretFields++;
      continue;
    }
    if (key.length === 0 || key.length > 160 || key.length + 4 > state.budget.remaining) {
      if (key.length > 160 || key.length + 4 > state.budget.remaining) {
        state.meta.truncated = true;
        if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_size_limit';
      }
      continue;
    }
    state.budget.remaining -= key.length + 4;
    const child = boundedProviderValue(sourceValue, depth + 1, path + '/' + key, state);
    if (child === undefined) {
      if (state.budget.remaining <= 0) break;
      continue;
    }
    output[key] = child;
    accepted++;
    if (state.budget.remaining <= 0) break;
  }
  return output as Object;
}

function emptyMeta(originalChars: number): ComposioProviderDataMeta {
  return {
    truncated: false, originalChars: originalChars, retainedChars: 0, reason: '', arrays: [],
    redactedSecretFields: 0, redactedBinaryFields: 0
  };
}

export function extractComposioProviderData(observation: string): ComposioProviderDataExtraction {
  const meta = emptyMeta(observation.length);
  try {
    const payload = JSON.parse(observation) as Object;
    const preferred = preferredProviderData(payload);
    if (preferred === undefined || preferred === null || typeof preferred !== 'object') return { data: null, meta: meta };
    const state: ProviderDataState = { budget: { remaining: PROVIDER_DATA_CONTENT_BUDGET }, meta: meta };
    const bounded = boundedProviderValue(preferred, 0, '', state);
    if (bounded === undefined || bounded === null || typeof bounded !== 'object') return { data: null, meta: meta };
    const retainedChars = JSON.stringify(bounded).length;
    meta.retainedChars = retainedChars;
    if (retainedChars > PROVIDER_DATA_MAX_JSON) {
      meta.truncated = true;
      meta.reason = 'provider_data_size_limit';
      return { data: null, meta: meta };
    }
    return { data: bounded as Object, meta: meta };
  } catch (_error) {
    return { data: null, meta: meta };
  }
}

export function composioProviderDataFromObservation(observation: string): Object | null {
  return extractComposioProviderData(observation).data;
}
