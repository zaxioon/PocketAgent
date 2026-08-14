import { http } from '@kit.NetworkKit';
import util from '@ohos.util';

const TWITCH_CHANNEL_SEARCH_URL: string = 'https://api.twitch.tv/helix/search/channels';
const DEFAULT_RESULT_LIMIT: number = 10;
const MAX_RESULT_LIMIT: number = 100;

type TwitchPayloadValue = Object | string | number | boolean | null | undefined;

interface TwitchChannelSearchPayload {
  data?: TwitchChannelPayload[];
  pagination?: TwitchPaginationPayload;
}

interface TwitchChannelPayload {
  broadcaster_language?: string;
  broadcaster_login?: string;
  display_name?: string;
  game_id?: string;
  game_name?: string;
  id?: string;
  is_live?: boolean;
  tags?: string[];
  thumbnail_url?: string;
  title?: string;
  started_at?: string;
}

interface TwitchPaginationPayload {
  cursor?: string;
}

/**
 * `appAccessToken` must be an application token minted with Twitch's
 * client_credentials flow. The client secret deliberately does not belong in
 * this mobile-side contract. Prefer injecting a short-lived app token from a
 * backend, or proxying Helix entirely server-side.
 */
export interface TwitchSearchConfig {
  clientId: string;
  appAccessToken: string;
}

export interface TwitchChannelSearchOptions {
  limit?: number;
  cursor?: string;
  liveOnly?: boolean;
}

export interface TwitchChannelSearchItem {
  id: string;
  broadcasterLogin: string;
  broadcasterName: string;
  title: string;
  gameId: string;
  gameName: string;
  language: string;
  isLive: boolean;
  thumbnailUrl: string;
  startedAt: string;
  url: string;
  tags: string[];
}

export type TwitchSearchStatus = 'success' | 'empty' | 'needs_auth' | 'unsupported' | 'error';
export type TwitchSearchReason = 'success' | 'empty' | 'disabled' | 'auth' | 'rate_limited' | 'provider_error';

export interface TwitchChannelSearchBatch {
  items: TwitchChannelSearchItem[];
  status: TwitchSearchStatus;
  reason: TwitchSearchReason;
  message: string;
  continuation: string | null;
  httpStatus: number;
  retryAfterSeconds?: number;
}

export interface TwitchHttpResult {
  code: number;
  text: string;
  retryAfterSeconds?: number;
}

export interface TwitchSearchTransport {
  get(url: string, clientId: string, appAccessToken: string): Promise<TwitchHttpResult>;
}

function textOf(value: TwitchPayloadValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function headerValue(headers: Object, key: string): string {
  const record = headers as Record<string, TwitchPayloadValue>;
  const lower = key.toLowerCase();
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (keys[index].toLowerCase() === lower) {
      return textOf(record[keys[index]]);
    }
  }
  return '';
}

function retryAfterSeconds(headers: Object): number | undefined {
  // Twitch documents Ratelimit-Reset as a Unix epoch timestamp. Retain the
  // conventional Retry-After fallback for gateways that normalize headers.
  const resetEpochSeconds = Number(headerValue(headers, 'Ratelimit-Reset').trim());
  if (Number.isFinite(resetEpochSeconds) && resetEpochSeconds > 0) {
    return Math.max(0, Math.ceil(resetEpochSeconds - Date.now() / 1000));
  }
  const retryAfter = Number(headerValue(headers, 'Retry-After').trim());
  return Number.isFinite(retryAfter) && retryAfter >= 0 ? Math.floor(retryAfter) : undefined;
}

function normalizedLimit(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value)) {
    return DEFAULT_RESULT_LIMIT;
  }
  return Math.max(1, Math.min(MAX_RESULT_LIMIT, Math.floor(value)));
}

export function twitchChannelSearchUrl(query: string, options: TwitchChannelSearchOptions = {}): string {
  const params: string[][] = [
    ['query', query.trim()],
    ['first', normalizedLimit(options.limit).toString()]
  ];
  if (options.liveOnly === true) {
    params.push(['live_only', 'true']);
  }
  const cursor = options.cursor === undefined ? '' : options.cursor.trim();
  if (cursor.length > 0) {
    params.push(['after', cursor]);
  }
  return TWITCH_CHANNEL_SEARCH_URL + '?' + params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

function twitchChannelUrl(login: string): string {
  return login.length > 0 ? 'https://www.twitch.tv/' + encodeURIComponent(login) : 'https://www.twitch.tv/';
}

function normalizedTags(value: string[] | undefined): string[] {
  if (value === undefined || !Array.isArray(value)) {
    return [];
  }
  const tags: string[] = [];
  value.forEach((tag: string): void => {
    const trimmed = tag.trim();
    if (trimmed.length > 0 && tags.indexOf(trimmed) < 0) {
      tags.push(trimmed);
    }
  });
  return tags;
}

function channelFromPayload(item: TwitchChannelPayload): TwitchChannelSearchItem | null {
  const id = textOf(item.id).trim();
  const login = textOf(item.broadcaster_login).trim();
  const displayName = textOf(item.display_name).trim();
  if (id.length === 0 || (login.length === 0 && displayName.length === 0)) {
    return null;
  }
  const isLive = item.is_live === true;
  return {
    id: id,
    broadcasterLogin: login,
    broadcasterName: displayName.length > 0 ? displayName : login,
    title: textOf(item.title).trim(),
    gameId: textOf(item.game_id).trim(),
    gameName: textOf(item.game_name).trim(),
    language: textOf(item.broadcaster_language).trim().toLowerCase(),
    isLive: isLive,
    thumbnailUrl: textOf(item.thumbnail_url).trim(),
    startedAt: isLive ? textOf(item.started_at).trim() : '',
    url: twitchChannelUrl(login),
    tags: normalizedTags(item.tags)
  };
}

export function twitchChannelsFromPayload(rawJson: string): TwitchChannelSearchBatch {
  try {
    const payload = JSON.parse(rawJson) as TwitchChannelSearchPayload;
    const rawItems = payload.data !== undefined && Array.isArray(payload.data) ? payload.data : [];
    const items: TwitchChannelSearchItem[] = [];
    rawItems.forEach((rawItem: TwitchChannelPayload): void => {
      const item = channelFromPayload(rawItem);
      if (item !== null) {
        items.push(item);
      }
    });
    const cursor = payload.pagination === undefined ? '' : textOf(payload.pagination.cursor).trim();
    return {
      items: items,
      status: items.length > 0 ? 'success' : 'empty',
      reason: items.length > 0 ? 'success' : 'empty',
      message: items.length > 0 ?
        'Twitch 返回 ' + items.length.toString() + ' 个匹配频道（包含直播与离线频道）。' :
        'Twitch 频道搜索成功，但没有返回匹配频道。',
      continuation: cursor.length > 0 ? cursor : null,
      httpStatus: 200
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return failedBatch('error', 'provider_error', 'Twitch 响应解析失败：' + message.substring(0, 160), 200);
  }
}

function failedBatch(
  status: TwitchSearchStatus,
  reason: TwitchSearchReason,
  message: string,
  httpStatus: number,
  retryAfter: number | undefined = undefined
): TwitchChannelSearchBatch {
  const batch: TwitchChannelSearchBatch = {
    items: [],
    status: status,
    reason: reason,
    message: message,
    continuation: null,
    httpStatus: httpStatus
  };
  if (retryAfter !== undefined) {
    batch.retryAfterSeconds = retryAfter;
  }
  return batch;
}

export function twitchBatchFromHttpResult(response: TwitchHttpResult): TwitchChannelSearchBatch {
  if (response.code === 401) {
    return failedBatch('needs_auth', 'auth',
      'Twitch 应用访问令牌无效、已过期，或与 Client-Id 不匹配。无需终端用户登录，请由服务端刷新 app access token。',
      response.code);
  }
  if (response.code === 429) {
    const suffix = response.retryAfterSeconds === undefined ? '' :
      '，建议 ' + response.retryAfterSeconds.toString() + ' 秒后重试';
    return failedBatch('error', 'rate_limited', 'Twitch Helix 请求达到速率限制' + suffix + '。',
      response.code, response.retryAfterSeconds);
  }
  if (response.code < 200 || response.code >= 300) {
    return failedBatch('error', 'provider_error',
      'Twitch Helix 返回 HTTP ' + response.code.toString() + '：' + response.text.substring(0, 160), response.code);
  }
  const batch = twitchChannelsFromPayload(response.text);
  batch.httpStatus = response.code;
  return batch;
}

class DefaultTwitchSearchTransport implements TwitchSearchTransport {
  async get(url: string, clientId: string, appAccessToken: string): Promise<TwitchHttpResult> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Client-Id': clientId,
          'Authorization': 'Bearer ' + appAccessToken
        },
        usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: 10000,
        readTimeout: 30000
      });
      return {
        code: response.responseCode,
        text: responseText(response.result),
        retryAfterSeconds: retryAfterSeconds(response.header)
      };
    } finally {
      request.destroy();
    }
  }
}

/**
 * Searches Twitch channels that have streamed in the last six months. This is
 * channel/live discovery, not full-text search across arbitrary VOD content.
 */
export async function searchTwitchChannels(
  config: TwitchSearchConfig,
  query: string,
  options: TwitchChannelSearchOptions = {},
  transport: TwitchSearchTransport = new DefaultTwitchSearchTransport()
): Promise<TwitchChannelSearchBatch> {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length === 0) {
    return failedBatch('empty', 'empty', 'Twitch 频道查询词为空。', 0);
  }
  const clientId = config.clientId.trim();
  const appAccessToken = config.appAccessToken.trim();
  if (clientId.length === 0 || appAccessToken.length === 0) {
    const missing: string[] = [];
    if (clientId.length === 0) {
      missing.push('TWITCH_CLIENT_ID');
    }
    if (appAccessToken.length === 0) {
      missing.push('TWITCH_APP_ACCESS_TOKEN');
    }
    return failedBatch('unsupported', 'disabled',
      'Twitch 来源已禁用：缺少 ' + missing.join(' / ') + '；未发起网络请求。' +
      ' app access token 应由服务端通过 client_credentials 获取。', 0);
  }
  try {
    const response = await transport.get(twitchChannelSearchUrl(trimmedQuery, options), clientId, appAccessToken);
    return twitchBatchFromHttpResult(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return failedBatch('error', 'provider_error', 'Twitch Helix 调用失败：' + message.substring(0, 160), 0);
  }
}
