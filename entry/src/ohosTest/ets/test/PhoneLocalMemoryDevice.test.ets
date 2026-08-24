import { application, common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { EmbeddingPort } from '@loop/agent-core';
import { BertWordPieceTokenizer } from '../../../main/ets/memory/BertWordPieceTokenizer';
import {
  BGE_SMALL_ZH_EMBEDDING_DIMENSION,
  BgeMindSporeEmbeddingPort
} from '../../../main/ets/memory/BgeMindSporeEmbeddingPort';
import { PhoneLocalMemoryProvider } from '../../../main/ets/memory/PhoneLocalMemoryProvider';
import { ArkDataPhoneLocalMemoryStore } from '../../../main/ets/memory/PhoneLocalMemoryStore';

const VECTOR_OWNER_ID: string = 'phone-local-vector-regression-owner';
const OTHER_OWNER_ID: string = 'phone-local-vector-regression-other-owner';
const TARGET_SCENE_ID: string = 'vector_target_scene';
const OTHER_SCENE_ID: string = 'vector_other_scene';
const VECTOR_PROFILE_ID: string = 'bge-small-zh-v1.5:device-vector-regression';

const QUERY_TEXT: string = 'vector-query-e0';
const BEST_FACT: string = 'vector-best-e0';
const SECOND_FACT: string = 'vector-second-near-e0';
const ORTHOGONAL_FACT: string = 'vector-orthogonal-e1';
const WRONG_OWNER_FACT: string = 'vector-wrong-owner-exact-e0';
const WRONG_SCENE_FACT: string = 'vector-wrong-scene-exact-e0';

async function testAbilityContext(): Promise<common.Context> {
  const testAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
  return application.createModuleContext(testAbility.context, 'entry');
}

function unitVector(first: number, second: number): number[] {
  const vector: number[] = new Array<number>(BGE_SMALL_ZH_EMBEDDING_DIMENSION).fill(0);
  vector[0] = first;
  vector[1] = second;
  return vector;
}

class ControlledEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = VECTOR_PROFILE_ID;
  readonly dimension: number = BGE_SMALL_ZH_EMBEDDING_DIMENSION;

  async embed(text: string): Promise<number[]> {
    if (text === SECOND_FACT) return unitVector(0.98, 0.2);
    if (text === ORTHOGONAL_FACT) return unitVector(0, 1);
    return unitVector(1, 0);
  }
}

function allFinite(values: number[]): boolean {
  for (let index = 0; index < values.length; index += 1) {
    if (!Number.isFinite(values[index])) return false;
  }
  return true;
}

export default function phoneLocalMemoryDeviceTest() {
  describe('PhoneLocalMemoryDevice', () => {
    it('satisfies the cosine index query contract for scoped database top-k', 0, async () => {
      const context = await testAbilityContext();
      const store = new ArkDataPhoneLocalMemoryStore(context);
      let initialized: boolean = false;
      try {
        // initialize() proves the FLOATVECTOR table and COSINE GSDISKANN DDL are accepted.
        await store.initialize();
        initialized = true;
        await store.removeAll(VECTOR_OWNER_ID, []);
        await store.removeAll(OTHER_OWNER_ID, []);

        let nextId: number = 0;
        const memory = new PhoneLocalMemoryProvider(store, new ControlledEmbeddingPort(), {
          allowedSceneIds: [TARGET_SCENE_ID, OTHER_SCENE_ID],
          idFactory: (): string => 'vector-device-memory-' + nextId++
        });

        const scopedRecords = await memory.remember({
          ownerId: VECTOR_OWNER_ID,
          records: [
            { fact: BEST_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-best' },
            { fact: SECOND_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-second' },
            { fact: ORTHOGONAL_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-orthogonal' },
            { fact: WRONG_SCENE_FACT, sceneId: OTHER_SCENE_ID, sourceTurnId: 'vector-turn-other-scene' }
          ]
        });
        expect(scopedRecords.status).assertEqual('success');
        expect(scopedRecords.succeededCount).assertEqual(4);

        const otherOwnerRecord = await memory.remember({
          ownerId: OTHER_OWNER_ID,
          records: [
            { fact: WRONG_OWNER_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-other-owner' }
          ]
        });
        expect(otherOwnerRecord.status).assertEqual('success');
        expect(otherOwnerRecord.succeededCount).assertEqual(1);

        const hits = await memory.search({
          ownerId: VECTOR_OWNER_ID,
          text: QUERY_TEXT,
          sceneIds: [TARGET_SCENE_ID],
          topK: 2
        });

        expect(hits.length).assertEqual(2);
        expect(hits[0].record.fact).assertEqual(BEST_FACT);
        expect(hits[1].record.fact).assertEqual(SECOND_FACT);
        expect(hits[0].score > hits[1].score).assertTrue();
        expect(hits[0].record.ownerId).assertEqual(VECTOR_OWNER_ID);
        expect(hits[1].record.ownerId).assertEqual(VECTOR_OWNER_ID);
        expect(hits[0].record.sceneId).assertEqual(TARGET_SCENE_ID);
        expect(hits[1].record.sceneId).assertEqual(TARGET_SCENE_ID);
      } finally {
        if (initialized) {
          await store.removeAll(VECTOR_OWNER_ID, []);
          await store.removeAll(OTHER_OWNER_ID, []);
        }
      }
    });

    it('loads the packaged BGE model and produces one finite 512-dimensional embedding', 0, async () => {
      const context = await testAbilityContext();
      const tokenizer = await BertWordPieceTokenizer.fromRawfile(context);
      const embedder = await BgeMindSporeEmbeddingPort.fromRawfile(context, tokenizer);
      const embedding = await embedder.embed('本地记忆模型真机冒烟测试');

      expect(embedding.length).assertEqual(BGE_SMALL_ZH_EMBEDDING_DIMENSION);
      expect(allFinite(embedding)).assertTrue();
    });
  });
}
