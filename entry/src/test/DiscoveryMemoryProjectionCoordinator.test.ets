import { describe, expect, it } from '@ohos/hypium';
import { LocalModel } from '@loop/agent-core';
import {
  DiscoveryMemoryProjectionCoordinator,
  DiscoveryMemoryProjectionCoordinatorOptions
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjectionCoordinator';
import {
  DiscoveryMemoryProjectionStorePort
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjectionStore';
import {
  DiscoveryMemoryPreferenceProjection,
  DiscoveryMemoryProjectionModelOutput,
  DiscoveryMemoryProjectionModelSignal,
  emptyDiscoveryMemoryPreferenceProjection
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjection';
import {
  PhoneLocalMemoryMutationEvent,
  PhoneLocalMemoryProjectionSourcePort
} from '../main/ets/memory/PhoneLocalMemoryRuntime';
import {
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats
} from '../main/ets/memory/PhoneLocalMemoryStore';

class ProjectionSource implements PhoneLocalMemoryProjectionSourcePort {
  stats: PhoneLocalMemoryProjectionStats = { changedCount: 0, oldestPendingUpdatedAt: null };
  facts: PhoneLocalMemoryProjectionFact[] = [];
  statsCalls: number = 0;
  listCalls: number = 0;

  getProjectionStats(_watermark: number): Promise<PhoneLocalMemoryProjectionStats> {
    this.statsCalls++;
    return Promise.resolve(this.stats);
  }

  listProjectionFacts(): Promise<PhoneLocalMemoryProjectionFact[]> {
    this.listCalls++;
    return Promise.resolve(this.facts.map((fact: PhoneLocalMemoryProjectionFact): PhoneLocalMemoryProjectionFact => ({
      memoryId: fact.memoryId,
      fact: fact.fact,
      personaTag: fact.personaTag,
      authority: fact.authority,
      updatedAt: fact.updatedAt
    })));
  }
}

class ProjectionStore implements DiscoveryMemoryProjectionStorePort {
  projection: DiscoveryMemoryPreferenceProjection = emptyDiscoveryMemoryPreferenceProjection();
  saveCalls: number = 0;

  load(): DiscoveryMemoryPreferenceProjection {
    return this.projection;
  }

  save(value: DiscoveryMemoryPreferenceProjection): DiscoveryMemoryPreferenceProjection | null {
    this.saveCalls++;
    this.projection = value;
    return value;
  }
}

class ProjectionModel implements LocalModel {
  calls: number = 0;

  complete(_prompt: string): Promise<string> {
    this.calls++;
    const signals: DiscoveryMemoryProjectionModelSignal[] = [{
      dimension: 'topic',
      key: '人工智能',
      polarity: 'positive',
      strength: 'strong',
      evidenceMemoryIds: ['memory-ai']
    }];
    const output: DiscoveryMemoryProjectionModelOutput = { signals };
    return Promise.resolve(JSON.stringify(output));
  }
}

function settleProjection(): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, 20);
  });
}

export default function discoveryMemoryProjectionCoordinatorTest() {
  describe('discoveryMemoryProjectionCoordinator', () => {
    it('does not call the model below both pending thresholds', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      source.stats = { changedCount: 1, oldestPendingUpdatedAt: 9999 };
      const options: DiscoveryMemoryProjectionCoordinatorOptions = {
        source,
        store,
        modelProvider: (): LocalModel => model,
        now: (): number => 10000
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator(options);
      coordinator.requestRefresh();
      await settleProjection();
      expect(source.statsCalls).assertEqual(1);
      expect(source.listCalls).assertEqual(0);
      expect(model.calls).assertEqual(0);
      expect(store.saveCalls).assertEqual(0);
    });

    it('rebuilds a threshold batch and advances to the included memory timestamp', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      source.stats = { changedCount: 8, oldestPendingUpdatedAt: 1000 };
      source.facts = [{
        memoryId: 'memory-ai',
        fact: '用户喜欢人工智能内容',
        personaTag: 'entertainment_companion',
        authority: 'leader',
        updatedAt: 12345
      }];
      let published: DiscoveryMemoryPreferenceProjection = emptyDiscoveryMemoryPreferenceProjection();
      let publishedCalled: boolean = false;
      const options: DiscoveryMemoryProjectionCoordinatorOptions = {
        source,
        store,
        modelProvider: (): LocalModel => model,
        onProjection: (value: DiscoveryMemoryPreferenceProjection): void => {
          published = value;
          publishedCalled = true;
        }
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator(options);
      coordinator.requestRefresh();
      await settleProjection();
      expect(model.calls).assertEqual(1);
      expect(store.projection.basedOnMemoryMutationAt).assertEqual(12345);
      expect(store.projection.signals.length).assertEqual(1);
      expect(publishedCalled).assertTrue();
      expect(published.signals[0].key).assertEqual('人工智能');
    });

    it('forces forget rebuilding and advances an empty snapshot to commit time', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      store.projection = {
        basedOnMemoryMutationAt: 40000,
        signals: [{
          dimension: 'topic', key: '人工智能', polarity: 'positive', strength: 'strong',
          evidenceMemoryIds: ['forgotten'], baseWeight: 4.5, lastSupportedAt: 40000
        }]
      };
      const options: DiscoveryMemoryProjectionCoordinatorOptions = {
        source,
        store,
        modelProvider: (): LocalModel => model
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator(options);
      const event: PhoneLocalMemoryMutationEvent = {
        operation: 'forget', committedAt: 45678, memoryIds: ['forgotten']
      };
      coordinator.notify(event);
      expect(coordinator.current().signals.length).assertEqual(0);
      await settleProjection();
      expect(source.listCalls).assertEqual(1);
      expect(model.calls).assertEqual(0);
      expect(store.projection.basedOnMemoryMutationAt).assertEqual(45678);
      expect(store.projection.signals.length).assertEqual(0);
    });
  });
}
