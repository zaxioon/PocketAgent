import { describe, expect, it } from '@ohos/hypium';
import {
  TwitchHttpResult,
  TwitchSearchTransport,
  searchTwitchChannels,
  twitchBatchFromHttpResult,
  twitchChannelSearchUrl,
  twitchChannelsFromPayload
} from '@loop/agent-core';

interface TwitchChannelFixture {
  broadcaster_language: string;
  broadcaster_login: string;
  display_name: string;
  game_id?: string;
  game_name?: string;
  id: string;
  is_live: boolean;
  tags?: string[];
  thumbnail_url: string;
  title: string;
  started_at: string;
}

interface TwitchPaginationFixture {
  cursor: string;
}

interface TwitchChannelPayloadFixture {
  data: TwitchChannelFixture[];
  pagination: TwitchPaginationFixture;
}

const LIVE_CHANNEL_FIXTURE: TwitchChannelFixture = {
  broadcaster_language: 'EN',
  broadcaster_login: 'twitchdev',
  display_name: 'TwitchDev',
  game_id: '509670',
  game_name: 'Science & Technology',
  id: '141981764',
  is_live: true,
  tags: ['English', 'SoftwareDevelopment', 'English'],
  thumbnail_url: 'https://static-cdn.example/twitchdev-300.png',
  title: 'Twitch API live coding',
  started_at: '2026-08-14T08:30:00Z'
};

const OFFLINE_CHANNEL_FIXTURE: TwitchChannelFixture = {
  broadcaster_language: 'zh',
  broadcaster_login: 'offline_dev',
  display_name: 'Offline Dev',
  id: '2',
  is_live: false,
  thumbnail_url: 'https://static-cdn.example/offline.png',
  title: 'Previous stream',
  started_at: '2026-08-01T00:00:00Z'
};

const PAGINATION_FIXTURE: TwitchPaginationFixture = { cursor: 'next-cursor==' };
const CHANNEL_PAYLOAD_FIXTURE: TwitchChannelPayloadFixture = {
  data: [LIVE_CHANNEL_FIXTURE, OFFLINE_CHANNEL_FIXTURE],
  pagination: PAGINATION_FIXTURE
};
const CHANNEL_PAYLOAD: string = JSON.stringify(CHANNEL_PAYLOAD_FIXTURE);

class RecordingTransport implements TwitchSearchTransport {
  calls: number = 0;
  result: TwitchHttpResult;

  constructor(result: TwitchHttpResult) {
    this.result = result;
  }

  async get(_url: string, _clientId: string, _appAccessToken: string): Promise<TwitchHttpResult> {
    this.calls += 1;
    return this.result;
  }
}

export default function twitchSearchClientTest(): void {
  describe('twitchSearchClient', () => {
    it('builds the official Helix channel-search URL with live and cursor controls', 0, () => {
      const url = twitchChannelSearchUrl('Codex 中文', { limit: 999, liveOnly: true, cursor: 'next==' });
      expect(url).assertEqual('https://api.twitch.tv/helix/search/channels?' +
        'query=Codex%20%E4%B8%AD%E6%96%87&first=100&live_only=true&after=next%3D%3D');
    });

    it('normalizes broadcaster, live, language, game, thumbnail and cursor fields', 0, () => {
      const batch = twitchChannelsFromPayload(CHANNEL_PAYLOAD);
      expect(batch.status).assertEqual('success');
      expect(batch.items.length).assertEqual(2);
      expect(batch.continuation).assertEqual('next-cursor==');
      expect(batch.items[0].broadcasterLogin).assertEqual('twitchdev');
      expect(batch.items[0].broadcasterName).assertEqual('TwitchDev');
      expect(batch.items[0].title).assertEqual('Twitch API live coding');
      expect(batch.items[0].gameName).assertEqual('Science & Technology');
      expect(batch.items[0].language).assertEqual('en');
      expect(batch.items[0].isLive).assertTrue();
      expect(batch.items[0].startedAt).assertEqual('2026-08-14T08:30:00Z');
      expect(batch.items[0].thumbnailUrl).assertEqual('https://static-cdn.example/twitchdev-300.png');
      expect(batch.items[0].url).assertEqual('https://www.twitch.tv/twitchdev');
      expect(batch.items[0].tags.join(',')).assertEqual('English,SoftwareDevelopment');
      expect(batch.items[1].isLive).assertFalse();
      expect(batch.items[1].startedAt).assertEqual('');
    });

    it('does not call the network when deployment credentials are missing', 0, async () => {
      const transport = new RecordingTransport({ code: 200, text: CHANNEL_PAYLOAD });
      const batch = await searchTwitchChannels({ clientId: '', appAccessToken: '' }, 'codex', {}, transport);
      expect(transport.calls).assertEqual(0);
      expect(batch.status).assertEqual('unsupported');
      expect(batch.reason).assertEqual('disabled');
      expect(batch.message.indexOf('未发起网络请求') >= 0).assertTrue();
      expect(batch.message.indexOf('client_credentials') >= 0).assertTrue();
    });

    it('distinguishes auth failure, rate limiting, empty results and malformed payloads', 0, () => {
      const auth = twitchBatchFromHttpResult({ code: 401, text: 'Unauthorized' });
      const limited = twitchBatchFromHttpResult({ code: 429, text: 'Too Many Requests', retryAfterSeconds: 30 });
      const empty = twitchBatchFromHttpResult({ code: 200, text: '{"data":[],"pagination":{}}' });
      const malformed = twitchBatchFromHttpResult({ code: 200, text: '{bad json' });
      expect(auth.status).assertEqual('needs_auth');
      expect(auth.reason).assertEqual('auth');
      expect(auth.message.indexOf('无需终端用户登录') >= 0).assertTrue();
      expect(limited.status).assertEqual('error');
      expect(limited.reason).assertEqual('rate_limited');
      expect(limited.retryAfterSeconds).assertEqual(30);
      expect(empty.status).assertEqual('empty');
      expect(empty.reason).assertEqual('empty');
      expect(malformed.status).assertEqual('error');
      expect(malformed.reason).assertEqual('provider_error');
    });

    it('uses the injected transport and preserves the provider cursor', 0, async () => {
      const transport = new RecordingTransport({ code: 200, text: CHANNEL_PAYLOAD });
      const batch = await searchTwitchChannels({ clientId: 'client-id', appAccessToken: 'app-token' },
        'twitchdev', { liveOnly: false }, transport);
      expect(transport.calls).assertEqual(1);
      expect(batch.items.length).assertEqual(2);
      expect(batch.continuation).assertEqual('next-cursor==');
    });
  });
}
