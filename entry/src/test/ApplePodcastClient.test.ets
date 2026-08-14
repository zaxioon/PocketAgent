import { describe, expect, it } from '@ohos/hypium';
import {
  AggregateSearchPolicy,
  AggregateSearchRowData,
  ApplePodcastHttpResult,
  aggregateMediaCandidates,
  applePodcastBatchFromHttpResult,
  applePodcastPostsFromPayload,
  applePodcastsCountryForPolicy,
  applePodcastsSearchUrl
} from '@loop/agent-core';

const CHINESE_POLICY: AggregateSearchPolicy = { domesticOnly: false, multilingual: false };
const MULTILINGUAL_POLICY: AggregateSearchPolicy = { domesticOnly: false, multilingual: true };

interface ApplePodcastFixtureItem {
  collectionId: number;
  artistName: string;
  collectionName: string;
  collectionViewUrl?: string;
  feedUrl?: string;
  artworkUrl600?: string;
  primaryGenreName?: string;
  genres?: string[];
  releaseDate?: string;
  trackCount?: number;
  country?: string;
}

interface ApplePodcastFixturePayload {
  resultCount: number;
  results: ApplePodcastFixtureItem[];
}

const PODCAST_FIXTURE: ApplePodcastFixturePayload = {
  resultCount: 2,
  results: [{
    collectionId: 1531947193,
    artistName: 'Lex Fridman',
    collectionName: 'Lex Fridman Podcast',
    collectionViewUrl: 'https://podcasts.apple.com/us/podcast/id1531947193',
    feedUrl: 'https://lexfridman.com/feed/podcast/',
    artworkUrl600: 'https://example.test/lex-600.jpg',
    primaryGenreName: 'Technology',
    genres: ['Technology', 'Science'],
    releaseDate: '2026-08-12T12:00:00Z',
    trackCount: 501,
    country: 'USA'
  }, {
    collectionId: 2,
    artistName: 'Missing URL',
    collectionName: 'Dropped result'
  }]
};
const PODCAST_PAYLOAD: string = JSON.stringify(PODCAST_FIXTURE);

const EMPTY_RESPONSE: ApplePodcastHttpResult = {
  code: 200,
  text: '{"resultCount":0,"results":[]}'
};
const UNAVAILABLE_RESPONSE: ApplePodcastHttpResult = {
  code: 503,
  text: 'unavailable'
};
const MALFORMED_RESPONSE: ApplePodcastHttpResult = {
  code: 200,
  text: '{bad json'
};

function rowValue(rows: AggregateSearchRowData[], label: string): string {
  for (let index = 0; index < rows.length; index++) {
    if (rows[index].label === label) {
      return rows[index].value;
    }
  }
  return '';
}

export default function applePodcastClientTest(): void {
  describe('applePodcastClient', () => {
    it('builds an anonymous podcast search URL without treating lang as content language', 0, () => {
      const url = applePodcastsSearchUrl('AI 中文', 999, 'CN');
      expect(url).assertEqual('https://itunes.apple.com/search?term=AI%20%E4%B8%AD%E6%96%87&country=CN&media=podcast&entity=podcast&limit=50');
      expect(url.indexOf('lang=')).assertEqual(-1);
      expect(applePodcastsCountryForPolicy(CHINESE_POLICY)).assertEqual('CN');
      expect(applePodcastsCountryForPolicy(MULTILINGUAL_POLICY)).assertEqual('US');
    });

    it('maps show metadata and artwork to an aggregate image-text post', 0, () => {
      const posts = applePodcastPostsFromPayload(PODCAST_PAYLOAD, 10);
      expect(posts.length).assertEqual(1);
      expect(posts[0].id).assertEqual('applepodcasts-1531947193');
      expect(posts[0].source).assertEqual('applepodcasts');
      expect(posts[0].title).assertEqual('Lex Fridman Podcast');
      expect(posts[0].author).assertEqual('Lex Fridman');
      expect(posts[0].url).assertEqual('https://podcasts.apple.com/us/podcast/id1531947193');
      expect(posts[0].publishedAt).assertEqual('2026-08-12T12:00:00Z');
      expect(rowValue(posts[0].rows, 'Cover')).assertEqual('https://example.test/lex-600.jpg');
      expect(rowValue(posts[0].rows, 'Feed URL')).assertEqual('https://lexfridman.com/feed/podcast/');
      expect(rowValue(posts[0].rows, 'Genre')).assertEqual('Technology / Science');
      expect(rowValue(posts[0].rows, 'Episodes')).assertEqual('501');
      const candidates = aggregateMediaCandidates([], posts, 0, 'AI');
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].mediaType).assertEqual('image_text');
      expect(candidates[0].coverUrl).assertEqual('https://example.test/lex-600.jpg');
    });

    it('turns empty, HTTP, and malformed responses into terminal source statuses', 0, () => {
      const empty = applePodcastBatchFromHttpResult(EMPTY_RESPONSE, 10);
      const unavailable = applePodcastBatchFromHttpResult(UNAVAILABLE_RESPONSE, 10);
      const malformed = applePodcastBatchFromHttpResult(MALFORMED_RESPONSE, 10);
      expect(empty.status.status).assertEqual('empty');
      expect(empty.continuation === null).assertTrue();
      expect(unavailable.status.status).assertEqual('error');
      expect(unavailable.status.message.indexOf('503') >= 0).assertTrue();
      expect(malformed.status.status).assertEqual('error');
      expect(malformed.status.message.indexOf('解析失败') >= 0).assertTrue();
    });
  });
}
