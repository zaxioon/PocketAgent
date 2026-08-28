import { describe, expect, it } from '@ohos/hypium';
import { EmbeddingPort, MemoryCommitGuard, MemoryHit, MemoryRecord } from '@loop/agent-core';
import {
  PHONE_LOCAL_MEMORY_BLOB_PROJECTION_FACTS_SQL,
  PHONE_LOCAL_MEMORY_BLOB_PROJECTION_INDEX_SQL,
  PHONE_LOCAL_MEMORY_BLOB_PROJECTION_STATS_SQL
} from '../main/ets/memory/PhoneLocalMemoryBlobFallbackPort';
import {
  PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL,
  PHONE_LOCAL_MEMORY_PROJECTION_STATS_SQL,
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats,
  PhoneLocalMemorySearchRequest,
  PhoneLocalMemoryStore
} from '../main/ets/memory/PhoneLocalMemoryStore';
import {
  PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
  PHONE_LOCAL_MEMORY_OWNER_ID,
  PhoneLocalMemoryMutationEvent,
  PhoneLocalMemoryRuntime
} from '../main/ets/memory/PhoneLocalMemoryRuntime';

function projectionRecord(memoryId: string, ownerId: string, sceneId: string,
  fact: string, updatedAt: number): MemoryRecord {
  const embedding: number[] = new Array<number>(512).fill(0);
  embedding[0] = 1;
  return {
    memoryId,
    ownerId,
    sceneId,
    personaTag: 'work_companion',
    authority: 'leader',
    fact,
    normalizedFact: fact,
    factHash: 'hash-' + memoryId,
    embedding,
    embeddingProfileId: 'projection-test',
    sourceTurnId: 'turn-' + memoryId,
    createdAt: updatedAt,
    updatedAt
  };
}

class ProjectionEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'projection-test';
  readonly dimension: number = 512;
  calls: number = 0;

  async embed(_text: string): Promise<number[]> {
    this.calls += 1;
    const embedding: number[] = new Array<number>(512).fill(0);
    embedding[0] = 1;
    return embedding;
  }
}

class ProjectionMemoryStore implements PhoneLocalMemoryStore {
  records: MemoryRecord[] = [];
  statsOwnerId: string = '';
  statsSceneId: string = '';
  factsOwnerId: string = '';
  factsSceneId: string = '';

  async initialize(): Promise<void> {}

  async findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId === ownerId && record.embeddingProfileId === embeddingProfileId &&
        record.factHash === factHash && record.normalizedFact === normalizedFact) return record;
    }
    return null;
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === memoryId) {
        return this.records[index];
      }
    }
    return null;
  }

  async list(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const output: MemoryRecord[] = [];
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId !== ownerId) continue;
      if (sceneIds.length > 0 && sceneIds.indexOf(record.sceneId) < 0) continue;
      output.push(record);
    }
    return output;
  }

  async getProjectionStats(ownerId: string, sceneId: string,
    basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats> {
    this.statsOwnerId = ownerId;
    this.statsSceneId = sceneId;
    const facts = await this.listProjectionFacts(ownerId, sceneId);
    let changedCount: number = 0;
    let oldestPendingUpdatedAt: number | null = null;
    for (let index = 0; index < facts.length; index += 1) {
      if (facts[index].updatedAt <= basedOnMemoryMutationAt) continue;
      changedCount += 1;
      oldestPendingUpdatedAt = oldestPendingUpdatedAt === null ? facts[index].updatedAt :
        Math.min(oldestPendingUpdatedAt, facts[index].updatedAt);
    }
    return { changedCount, oldestPendingUpdatedAt };
  }

  async listProjectionFacts(ownerId: string, sceneId: string): Promise<PhoneLocalMemoryProjectionFact[]> {
    this.factsOwnerId = ownerId;
    this.factsSceneId = sceneId;
    const output: PhoneLocalMemoryProjectionFact[] = [];
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId !== ownerId || record.sceneId !== sceneId || record.authority !== 'leader') continue;
      output.push({
        memoryId: record.memoryId,
        fact: record.fact,
        personaTag: record.personaTag,
        authority: record.authority,
        updatedAt: record.updatedAt
      });
    }
    return output;
  }

  async search(_request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    return [];
  }

  async insert(record: MemoryRecord, _guard?: MemoryCommitGuard): Promise<void> {
    this.records.push(record);
  }

  async replace(ownerId: string, record: MemoryRecord, _guard?: MemoryCommitGuard): Promise<void> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === record.memoryId) {
        this.records[index] = record;
        return;
      }
    }
    throw new Error('not found');
  }

  async remove(ownerId: string, memoryId: string,
    _guard?: MemoryCommitGuard): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId !== ownerId || this.records[index].memoryId !== memoryId) continue;
      const record = this.records[index];
      this.records.splice(index, 1);
      return record;
    }
    return null;
  }

  async removeAll(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const records = await this.list(ownerId, sceneIds);
    for (let index = 0; index < records.length; index += 1) {
      await this.remove(ownerId, records[index].memoryId);
    }
    return records;
  }

  async getMetadata(_key: string): Promise<string | null> {
    return null;
  }

  async setMetadata(_key: string, _value: string): Promise<void> {}
}

export default function phoneLocalMemoryProjectionSourceTest() {
  describe('PhoneLocalMemoryProjectionSource', () => {
    it('uses indexed scalar queries that never select embeddings', 0, () => {
      expect(PHONE_LOCAL_MEMORY_PROJECTION_STATS_SQL).assertContain(
        "owner_id = ? AND scene_id = ? AND authority = 'leader' AND updated_at > ?"
      );
      expect(PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL).assertContain(
        'memory_id, fact, persona_tag, authority, updated_at'
      );
      expect(PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL.indexOf('embedding')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_BLOB_PROJECTION_STATS_SQL).assertContain(
        "owner_id = ? AND scene_id = ? AND authority = 'leader' AND updated_at > ?"
      );
      expect(PHONE_LOCAL_MEMORY_BLOB_PROJECTION_FACTS_SQL.indexOf('embedding')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_BLOB_PROJECTION_INDEX_SQL).assertContain(
        'owner_id, scene_id, updated_at'
      );
    });

    it('reads only the fixed local owner and global scene without loading the embedder', 0, async () => {
      const store = new ProjectionMemoryStore();
      store.records.push(projectionRecord('old', PHONE_LOCAL_MEMORY_OWNER_ID,
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '用户喜欢人工智能。', 100));
      store.records.push(projectionRecord('new', PHONE_LOCAL_MEMORY_OWNER_ID,
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '用户喜欢编程。', 300));
      store.records.push(projectionRecord('legacy-scene', PHONE_LOCAL_MEMORY_OWNER_ID,
        'travel_companion', '用户偏好高铁。', 400));
      store.records.push(projectionRecord('other-owner', 'other-owner',
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '其他用户偏好。', 500));
      const legacySeed = projectionRecord('legacy-seed', PHONE_LOCAL_MEMORY_OWNER_ID,
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '旧测试种子偏好。', 600);
      legacySeed.authority = 'seed';
      store.records.push(legacySeed);
      const embedder = new ProjectionEmbeddingPort();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => embedder
      });

      const stats = await runtime.getProjectionStats(150);
      const facts = await runtime.listProjectionFacts();

      expect(stats.changedCount).assertEqual(1);
      expect(stats.oldestPendingUpdatedAt ?? 0).assertEqual(300);
      expect(facts.length).assertEqual(2);
      expect(store.statsOwnerId).assertEqual(PHONE_LOCAL_MEMORY_OWNER_ID);
      expect(store.statsSceneId).assertEqual(PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID);
      expect(store.factsOwnerId).assertEqual(PHONE_LOCAL_MEMORY_OWNER_ID);
      expect(store.factsSceneId).assertEqual(PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID);
      expect(embedder.calls).assertEqual(0);
    });

    it('reports successful mutations asynchronously without blocking memory results', 0, async () => {
      const store = new ProjectionMemoryStore();
      const events: PhoneLocalMemoryMutationEvent[] = [];
      const neverCompletes = new Promise<void>((_resolve: () => void): void => {});
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new ProjectionEmbeddingPort(),
        idFactory: (): string => 'memory-event',
        onMutationCommitted: async (event: PhoneLocalMemoryMutationEvent): Promise<void> => {
          events.push(event);
          await neverCompletes;
        }
      });

      const remembered = await runtime.remember(['用户喜欢人工智能。'], 'turn-event', 'work_companion');
      await Promise.resolve<void>(undefined);

      expect(remembered.status).assertEqual('success');
      expect(events.length).assertEqual(1);
      expect(events[0].operation).assertEqual('remember');
      expect(events[0].memoryIds[0]).assertEqual('memory-event');
      expect(events[0].committedAt > 0).assertTrue();
    });
  });
}
