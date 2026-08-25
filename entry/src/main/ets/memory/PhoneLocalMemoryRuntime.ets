import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  EmbeddingPort,
  aiLogError,
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryDraft,
  MemoryError,
  MemoryHit,
  MemoryWriteResult
} from '@loop/agent-core';
import { BertWordPieceTokenizer } from './BertWordPieceTokenizer';
import { BgeMindSporeEmbeddingPort } from './BgeMindSporeEmbeddingPort';
import { PhoneLocalMemoryProvider } from './PhoneLocalMemoryProvider';
import { ArkDataPhoneLocalMemoryStore, PhoneLocalMemoryStore } from './PhoneLocalMemoryStore';

export const PHONE_LOCAL_MEMORY_OWNER_ID: string = 'local-user-v1';
export const PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID: string = 'global';
export const PHONE_LOCAL_MEMORY_RECALL_TOP_K: number = 5;
export const PHONE_LOCAL_MEMORY_RECALL_TIMEOUT_MS: number = 2500;
export const PHONE_LOCAL_MEMORY_RECALL_FACT_LIMIT: number = 240;
export const PHONE_LOCAL_MEMORY_RECALL_TOTAL_LIMIT: number = 1200;
export const PHONE_LOCAL_MEMORY_SEED_MARKER: string = 'seed:persona-test-preferences:v1';

const MEMORY_RUNTIME_LOG_DOMAIN: number = 0x0000;
const MEMORY_RUNTIME_LOG_TAG: string = 'MemoryRuntime';
const MEMORY_RUNTIME_LOG_LIMIT: number = 160;

export interface PhoneLocalRecalledMemory {
  memoryId: string;
  fact: string;
  personaTag: string;
  authority: 'leader' | 'seed';
}

export interface PhoneLocalMemoryRuntimeLogger {
  warn(code: string, operation: string, errorMessage: string): void;
}

export interface PhoneLocalMemoryRuntimeOptions {
  storeFactory?: () => PhoneLocalMemoryStore;
  embedderFactory?: () => Promise<EmbeddingPort>;
  idFactory?: () => string;
  recallTimeoutMs?: number;
  logger?: PhoneLocalMemoryRuntimeLogger;
}

export interface PhoneLocalMemoryRuntimePort {
  recall(text: string): Promise<PhoneLocalRecalledMemory[]>;
  remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
  update(memoryId: string, fact: string, sourceTurnId: string,
    personaTag: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult>;
  forget(memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult>;
}

interface SeedMemoryFact {
  fact: string;
  personaTag: string;
}

const V1_SEED_FACTS: SeedMemoryFact[] = [
  { fact: '用户在工作日会用饮品提神。', personaTag: 'food_companion' },
  { fact: '用户选择附近饮品时优先考虑可自取。', personaTag: 'food_companion' },
  { fact: '用户出行时偏好少换乘。', personaTag: 'travel_companion' },
  { fact: '用户偏好时间安排可控的出行方案。', personaTag: 'travel_companion' },
  { fact: '用户偏好简洁的邮件。', personaTag: 'work_companion' },
  { fact: '用户偏好礼貌的邮件语气。', personaTag: 'work_companion' },
  { fact: '用户偏好工作邮件结论先行。', personaTag: 'work_companion' },
  { fact: '用户会把世界杯和足球内容作为晚间娱乐选择。', personaTag: 'entertainment_companion' }
];

class HilogPhoneLocalMemoryRuntimeLogger implements PhoneLocalMemoryRuntimeLogger {
  warn(code: string, operation: string, errorMessage: string): void {
    hilog.warn(MEMORY_RUNTIME_LOG_DOMAIN, MEMORY_RUNTIME_LOG_TAG,
      'code=%{public}s operation=%{public}s error=%{public}s', code, operation, errorMessage);
    aiLogError('[AIPhone][PhoneLocalMemoryRuntime] code=' + code +
      ' operation=' + operation + ' error=' + errorMessage);
  }
}

function boundedRuntimeError(error: Object): string {
  let message = error instanceof Error ? error.message : 'Unknown phone-local memory runtime failure.';
  message = message.replace(/[\r\n\t]+/g, ' ').trim();
  if (message.length === 0) message = 'Unknown phone-local memory runtime failure.';
  return message.substring(0, MEMORY_RUNTIME_LOG_LIMIT);
}

function runtimeMemoryError(code: string, message: string, retryable: boolean): MemoryError {
  return { code, message, retryable };
}

function unavailableWrite(error: MemoryError, inputIndex: number = 0): MemoryWriteResult {
  return { inputIndex, status: 'error', error };
}

function unavailableBatch(recordCount: number, error: MemoryError): MemoryBatchResult {
  const records: MemoryWriteResult[] = [];
  const count = Math.max(1, recordCount);
  for (let index = 0; index < count; index += 1) records.push(unavailableWrite(error, index));
  return {
    status: 'error', records, succeededCount: 0, failedCount: count, warnings: [], error
  };
}

function boundedFact(fact: string, remaining: number): string {
  const limit = Math.min(PHONE_LOCAL_MEMORY_RECALL_FACT_LIMIT, remaining);
  return fact.substring(0, Math.max(0, limit));
}

/**
 * Application-lifetime composition root for phone-local memory.
 * Recall is fail-open; mutations surface initialization/model/storage failures to the caller.
 */
export class PhoneLocalMemoryRuntime implements PhoneLocalMemoryRuntimePort {
  private context: common.Context | null;
  private options: PhoneLocalMemoryRuntimeOptions;
  private providerPromise: Promise<PhoneLocalMemoryProvider> | null = null;
  private logger: PhoneLocalMemoryRuntimeLogger;

  constructor(context: common.Context | null, options: PhoneLocalMemoryRuntimeOptions = {}) {
    this.context = context;
    this.options = options;
    this.logger = options.logger ?? new HilogPhoneLocalMemoryRuntimeLogger();
  }

  async recall(text: string): Promise<PhoneLocalRecalledMemory[]> {
    const query = text.trim();
    if (query.length === 0) return [];
    try {
      const hits = await this.withTimeout(this.search(query));
      const output: PhoneLocalRecalledMemory[] = [];
      let remaining = PHONE_LOCAL_MEMORY_RECALL_TOTAL_LIMIT;
      for (let index = 0; index < hits.length && remaining > 0; index += 1) {
        const fact = boundedFact(hits[index].record.fact, remaining);
        if (fact.length === 0) break;
        output.push({
          memoryId: hits[index].record.memoryId,
          fact,
          personaTag: hits[index].record.personaTag,
          authority: hits[index].record.authority
        });
        remaining -= fact.length;
      }
      return output;
    } catch (error) {
      this.log('memory_recall_unavailable', 'recall', error);
      return [];
    }
  }

  async remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    try {
      const provider = await this.provider();
      const records: MemoryDraft[] = [];
      for (let index = 0; index < facts.length; index += 1) {
        records.push({
          fact: facts[index],
          sceneId: PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
          personaTag: personaTag.length > 0 ? personaTag : PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
          authority: 'leader',
          sourceTurnId
        });
      }
      return await provider.remember({ ownerId: PHONE_LOCAL_MEMORY_OWNER_ID, records }, guard);
    } catch (error) {
      this.log('memory_runtime_unavailable', 'remember', error);
      return unavailableBatch(facts.length, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async update(memoryId: string, fact: string, sourceTurnId: string,
    personaTag: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    try {
      const provider = await this.provider();
      return await provider.update({
        ownerId: PHONE_LOCAL_MEMORY_OWNER_ID,
        memoryId,
        fact,
        personaTag: personaTag.length > 0 ? personaTag : PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        authority: 'leader',
        sourceTurnId
      }, guard);
    } catch (error) {
      this.log('memory_runtime_unavailable', 'update', error);
      return unavailableWrite(runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async forget(memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    try {
      const provider = await this.provider();
      return await provider.forget(PHONE_LOCAL_MEMORY_OWNER_ID, memoryId, guard);
    } catch (error) {
      this.log('memory_runtime_unavailable', 'forget', error);
      return unavailableWrite(runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  private provider(): Promise<PhoneLocalMemoryProvider> {
    if (this.providerPromise === null) this.providerPromise = this.createProvider();
    return this.providerPromise;
  }

  private async createProvider(): Promise<PhoneLocalMemoryProvider> {
    let store: PhoneLocalMemoryStore;
    if (this.options.storeFactory !== undefined) store = this.options.storeFactory();
    else {
      if (this.context === null) throw new Error('Phone-local memory requires an application context.');
      store = new ArkDataPhoneLocalMemoryStore(this.context);
    }
    await store.initialize();
    const embedder = this.options.embedderFactory !== undefined ?
      await this.options.embedderFactory() : await this.createDefaultEmbedder();
    // The runtime wrapper fixes every new write to global. Keep the provider compatible with
    // legacy records in another scene so an exact-id update/forget can still complete.
    const provider = new PhoneLocalMemoryProvider(store, embedder, {
      idFactory: this.options.idFactory
    });
    await this.ensureV1Seeds(store, provider);
    return provider;
  }

  private async search(query: string): Promise<MemoryHit[]> {
    const provider = await this.provider();
    return await provider.search({
      ownerId: PHONE_LOCAL_MEMORY_OWNER_ID,
      text: query,
      sceneIds: [],
      topK: PHONE_LOCAL_MEMORY_RECALL_TOP_K
    });
  }

  private async createDefaultEmbedder(): Promise<EmbeddingPort> {
    if (this.context === null) throw new Error('Phone-local memory requires an application context.');
    const tokenizer = await BertWordPieceTokenizer.fromRawfile(this.context);
    return await BgeMindSporeEmbeddingPort.fromRawfile(this.context, tokenizer);
  }

  private async ensureV1Seeds(store: PhoneLocalMemoryStore, provider: PhoneLocalMemoryProvider): Promise<void> {
    try {
      if (await store.getMetadata(PHONE_LOCAL_MEMORY_SEED_MARKER) !== null) return;
      let allSucceeded = true;
      for (let offset = 0; offset < V1_SEED_FACTS.length; offset += 5) {
        const records: MemoryDraft[] = [];
        const limit = Math.min(offset + 5, V1_SEED_FACTS.length);
        for (let index = offset; index < limit; index += 1) {
          records.push({
            fact: V1_SEED_FACTS[index].fact,
            sceneId: PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
            personaTag: V1_SEED_FACTS[index].personaTag,
            authority: 'seed',
            sourceTurnId: 'seed-v1-' + (index + 1).toString()
          });
        }
        const result = await provider.remember({ ownerId: PHONE_LOCAL_MEMORY_OWNER_ID, records });
        if (result.status !== 'success' || result.failedCount > 0) allSucceeded = false;
      }
      if (allSucceeded) await store.setMetadata(PHONE_LOCAL_MEMORY_SEED_MARKER, 'complete');
      else this.logger.warn('memory_seed_incomplete', 'seed', 'One or more seed records were not saved.');
    } catch (error) {
      this.log('memory_seed_incomplete', 'seed', error);
    }
  }

  private withTimeout<T>(task: Promise<T>): Promise<T> {
    const timeoutMs = Math.max(1, this.options.recallTimeoutMs ?? PHONE_LOCAL_MEMORY_RECALL_TIMEOUT_MS);
    return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void): void => {
      const timerId = setTimeout((): void => reject(new Error('Phone-local memory recall timed out.')), timeoutMs);
      task.then((value: T): void => {
        clearTimeout(timerId);
        resolve(value);
      }, (error: Object): void => {
        clearTimeout(timerId);
        reject(error instanceof Error ? error : new Error('Phone-local memory recall failed.'));
      });
    });
  }

  private log(code: string, operation: string, error: Object): void {
    this.logger.warn(code, operation, boundedRuntimeError(error));
  }
}
