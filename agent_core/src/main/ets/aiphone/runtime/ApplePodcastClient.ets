import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  AggregateSearchPolicy,
  AggregateSearchPost,
  AggregateSearchRowData,
  AggregateSearchSourceBatch,
  AggregateSearchSourceStatus
} from './AggregateSearchTypes';

const APPLE_PODCAST_SEARCH_URL: string = 'https://itunes.apple.com/search';
const APPLE_PODCAST_PROVIDER: string = 'Apple Podcasts';
const DEFAULT_RESULT_LIMIT: number = 10;
const MAX_RESULT_LIMIT: number = 50;

export type ApplePodcastsCountry = 'CN' | 'US';

interface ApplePodcastSearchPayload {
  resultCount?: number;
  results?: ApplePodcastSearchItem[];
}

interface ApplePodcastSearchItem {
  collectionId?: number;
  trackId?: number;
  artistName?: string;
  collectionName?: string;
  collectionViewUrl?: string;
  feedUrl?: string;
  artworkUrl600?: string;
  artworkUrl100?: string;
  primaryGenreName?: string;
  genres?: string[];
  releaseDate?: string;
  trackCount?: number;
  country?: string;
}

export interface ApplePodcastHttpResult {
  code: number;
  text: string;
}

function cleanText(value: string | undefined): string {
  return value === undefined ? '' : value.trim();
}

function positiveInteger(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return Math.floor(value);
}

function resultLimit(limit: number): number {
  if (!Number.isFinite(limit)) {
    return DEFAULT_RESULT_LIMIT;
  }
  return Math.max(1, Math.min(MAX_RESULT_LIMIT, Math.floor(limit)));
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  if (typeof result === 'number' || typeof result === 'boolean') {
    return result.toString();
  }
  return JSON.stringify(result);
}

/**
 * iTunes `country` selects a storefront rather than filtering content language.
 * Chinese-only aggregate mode uses the CN storefront as a relevance/availability bias;
 * multilingual mode uses the broader US storefront. No `lang` parameter is sent.
 */
export function applePodcastsCountryForPolicy(policy: AggregateSearchPolicy): ApplePodcastsCountry {
  return policy.multilingual ? 'US' : 'CN';
}

export function applePodcastsSearchUrl(
  query: string,
  limit: number = DEFAULT_RESULT_LIMIT,
  country: ApplePodcastsCountry = 'CN'
): string {
  const params: string[][] = [
    ['term', query.trim()],
    ['country', country],
    ['media', 'podcast'],
    ['entity', 'podcast'],
    ['limit', resultLimit(limit).toString()]
  ];
  return APPLE_PODCAST_SEARCH_URL + '?' + params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

function itemGenres(item: ApplePodcastSearchItem): string {
  if (item.genres !== undefined && Array.isArray(item.genres)) {
    const genres = item.genres.map((genre: string): string => genre.trim()).filter(
      (genre: string): boolean => genre.length > 0);
    if (genres.length > 0) {
      return genres.join(' / ');
    }
  }
  return cleanText(item.primaryGenreName);
}

function itemCover(item: ApplePodcastSearchItem): string {
  const large = cleanText(item.artworkUrl600);
  return large.length > 0 ? large : cleanText(item.artworkUrl100);
}

function itemId(item: ApplePodcastSearchItem, index: number): string {
  const collectionId = positiveInteger(item.collectionId);
  if (collectionId > 0) {
    return collectionId.toString();
  }
  const trackId = positiveInteger(item.trackId);
  return trackId > 0 ? trackId.toString() : index.toString();
}

function applePodcastPost(item: ApplePodcastSearchItem, index: number): AggregateSearchPost {
  const title = cleanText(item.collectionName);
  const author = cleanText(item.artistName);
  const appleUrl = cleanText(item.collectionViewUrl);
  const feedUrl = cleanText(item.feedUrl);
  const genre = itemGenres(item);
  const releaseDate = cleanText(item.releaseDate);
  const episodeCount = positiveInteger(item.trackCount);
  const rows: AggregateSearchRowData[] = [];
  const cover = itemCover(item);
  if (cover.length > 0) {
    rows.push({ label: 'Cover', value: cover });
  }
  if (feedUrl.length > 0) {
    rows.push({ label: 'Feed URL', value: feedUrl });
  }
  if (genre.length > 0) {
    rows.push({ label: 'Genre', value: genre });
  }
  if (releaseDate.length > 0) {
    rows.push({ label: 'Latest release', value: releaseDate });
  }
  if (episodeCount > 0) {
    rows.push({ label: 'Episodes', value: episodeCount.toString() });
  }
  const country = cleanText(item.country);
  if (country.length > 0) {
    rows.push({ label: 'Storefront', value: country });
  }
  const summaryParts: string[] = [];
  if (author.length > 0) {
    summaryParts.push(author);
  }
  if (genre.length > 0) {
    summaryParts.push(genre);
  }
  if (episodeCount > 0) {
    summaryParts.push(episodeCount.toString() + ' episodes');
  }
  return {
    id: 'applepodcasts-' + itemId(item, index),
    source: 'applepodcasts',
    provider: APPLE_PODCAST_PROVIDER,
    title: title,
    author: author,
    handle: '',
    text: summaryParts.join(' · '),
    url: appleUrl.length > 0 ? appleUrl : feedUrl,
    publishedAt: releaseDate,
    score: '',
    commentCount: '',
    status: 'success',
    rows: rows
  };
}

export function applePodcastPostsFromPayload(rawJson: string, limit: number = DEFAULT_RESULT_LIMIT): AggregateSearchPost[] {
  const payload = JSON.parse(rawJson) as ApplePodcastSearchPayload;
  if (payload.results === undefined || !Array.isArray(payload.results)) {
    return [];
  }
  const posts: AggregateSearchPost[] = [];
  const maxCount = resultLimit(limit);
  for (let index = 0; index < payload.results.length && posts.length < maxCount; index++) {
    const post = applePodcastPost(payload.results[index], index);
    if (post.title.length > 0 && post.url.length > 0) {
      posts.push(post);
    }
  }
  return posts;
}

function sourceStatus(status: 'success' | 'empty' | 'error', message: string, count: number): AggregateSearchSourceStatus {
  return {
    source: 'applepodcasts',
    label: APPLE_PODCAST_PROVIDER,
    status: status,
    message: message,
    count: count
  };
}

export function applePodcastBatchFromHttpResult(
  response: ApplePodcastHttpResult,
  limit: number = DEFAULT_RESULT_LIMIT
): AggregateSearchSourceBatch {
  if (response.code < 200 || response.code >= 300) {
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('error', 'Apple Podcasts HTTP ' + response.code.toString() + '。', 0),
      continuation: null
    };
  }
  try {
    const posts = applePodcastPostsFromPayload(response.text, limit);
    return {
      source: 'applepodcasts',
      videos: [],
      posts: posts,
      status: sourceStatus(posts.length > 0 ? 'success' : 'empty',
        'Apple Podcasts 返回 ' + posts.length.toString() + ' 条节目。', posts.length),
      continuation: null
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('error', 'Apple Podcasts 响应解析失败：' + message.substring(0, 160), 0),
      continuation: null
    };
  }
}

async function requestApplePodcasts(url: string): Promise<ApplePodcastHttpResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/json'
      },
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    return {
      code: response.responseCode,
      text: responseText(response.result)
    };
  } finally {
    request.destroy();
  }
}

export async function searchApplePodcasts(
  query: string,
  policy: AggregateSearchPolicy,
  limit: number = DEFAULT_RESULT_LIMIT
): Promise<AggregateSearchSourceBatch> {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length === 0) {
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('empty', 'Apple Podcasts 查询词为空。', 0),
      continuation: null
    };
  }
  try {
    const response = await requestApplePodcasts(applePodcastsSearchUrl(
      trimmedQuery, limit, applePodcastsCountryForPolicy(policy)));
    return applePodcastBatchFromHttpResult(response, limit);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('error', 'Apple Podcasts 调用失败：' + message.substring(0, 160), 0),
      continuation: null
    };
  }
}
