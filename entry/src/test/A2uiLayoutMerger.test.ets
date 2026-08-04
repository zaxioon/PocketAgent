import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  aiLogChunks,
  buildA2uiLayoutSystemPrompt,
  mergeA2uiLayout,
  mergeA2uiLayoutWithStatus,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';

const SURFACE_ID: string = 'surface-layout-test';
const BASELINE: string =
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-layout-test","root":"root","title":"酒店搜索"}}\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"results"},' +
  '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"}]}}\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/genericToolResults","value":[]}}\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{"text":"真实结果"}}}\n';

const VALID_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"column"},' +
  '{"id":"column","component":"Column","children":["title","results","actions"]},' +
  '{"id":"title","component":"Text","text":"酒店结果","variant":"h3"},' +
  '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"},' +
  '{"id":"actions","component":"ActionBar","actions":[{"offerId":"detail:1"}]}' +
  ']}}';

const LAB_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"lab-grid"},' +
  '{"id":"lab-grid","component":"MasonryGrid","dataPath":"/genericToolResults"}' +
  ']}}';

const BENTO_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"lab-grid"},' +
  '{"id":"lab-grid","component":"BentoGrid","dataPath":"/genericToolResults"}' +
  ']}}';

interface ComponentCatalogEntry {
  name: string;
}

const LAB_COMPONENT_NAMES: string[] = [
  'SurfaceRoot', 'Column', 'Row', 'Text', 'InfoRows', 'ActionBar', 'ErrorNotice', 'ThinkingStream',
  'ThinkingCard', 'ScheduleStack', 'SkeletonCard', 'ExpandableCard', 'MediaSlider', 'SceneTabs', 'MasonryGrid', 'List'
];

interface HotelIdArg {
  hotelId: number;
}

function offers(): ActionOffer[] {
  const args: HotelIdArg = { hotelId: 1 };
  const offer: ActionOffer = {
    offerId: 'detail:1',
    actionId: 'hotel.detail',
    label: '查看实时房型',
    variant: 'primary',
    args: args
  };
  return [offer];
}

export default function a2uiLayoutMergerTest() {
  describe('A2uiLayoutMerger', () => {
    it('replaces only components and resolves immutable offer references', 0, () => {
      const merged: string = mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      const baselineLines: string[] = BASELINE.trim().split('\n');
      const mergedLines: string[] = merged.trim().split('\n');
      expect(merged === BASELINE).assertFalse();
      expect(mergedLines[0]).assertEqual(baselineLines[0]);
      expect(mergedLines[2]).assertEqual(baselineLines[2]);
      expect(mergedLines[3]).assertEqual(baselineLines[3]);
      expect(mergedLines[1].includes('"id":"hotel.detail"')).assertTrue();
      expect(mergedLines[1].includes('"offerId"')).assertFalse();
      expect(mergedLines[1].includes('"hotelId":1')).assertTrue();
    });

    it('reports accepted and fallback merge outcomes without changing jsonl', 0, () => {
      const accepted = mergeA2uiLayoutWithStatus(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      const rejected = mergeA2uiLayoutWithStatus(BASELINE, '{}', SURFACE_ID, offers());
      expect(accepted.accepted).assertTrue();
      expect(accepted.reason).assertEqual('accepted');
      expect(accepted.jsonl).assertEqual(mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers()));
      expect(rejected.accepted).assertFalse();
      expect(rejected.reason).assertEqual('candidate_rejected');
      expect(rejected.jsonl).assertEqual(BASELINE);
    });

    it('splits complete log payloads into lossless ordered chunks', 0, () => {
      const source = 'x'.repeat(1001) + '\n中文' + 'y'.repeat(1002);
      const chunks = aiLogChunks(source);
      let rebuilt = '';
      for (let index = 0; index < chunks.length; index++) {
        expect(chunks[index].index).assertEqual(index + 1);
        expect(chunks[index].total).assertEqual(chunks.length);
        rebuilt += chunks[index].content;
      }
      expect(chunks.length).assertEqual(3);
      expect(rebuilt).assertEqual(source);
    });

    it('includes one complete generic A2UI protocol-shape example in the layout prompt', 0, () => {
      const prompt = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON);
      const example =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","project-list"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"project-list","component":"List","children":{"path":"/results/0/data/projects","componentId":"project-card"}},' +
        '{"id":"project-card","component":"ExpandableCard"}' +
        ']}}';
      expect(prompt.includes(example)).assertTrue();
      expect(prompt.includes('actual allowedDataPaths and component catalog')).assertTrue();
      expect(prompt.includes('Use "component", never "type"')).assertTrue();
      expect(prompt.includes('nested "props" object')).assertTrue();
      expect(prompt.includes('Prefer the narrowest allowed path')).assertTrue();
      expect(prompt.includes('current item scope')).assertTrue();
      expect(example.includes('"type"')).assertFalse();
      expect(example.includes('"props"')).assertFalse();
      expect(example.includes('餐馆')).assertFalse();
      expect(example.includes('food')).assertFalse();
    });

    it('keeps the business catalog as the default', 0, () => {
      const merged: string = mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"GenericToolResults"')).assertTrue();
    });

    it('accepts UI Lab components only when the UI Lab catalog is selected', 0, () => {
      const merged: string = mergeA2uiLayout(
        BASELINE,
        LAB_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"MasonryGrid"')).assertTrue();
      expect(mergeA2uiLayout(BASELINE, LAB_CANDIDATE, SURFACE_ID, [])).assertEqual(BASELINE);
    });

    it('keeps the UI Lab allowlist fixed at sixteen components without BentoGrid', 0, () => {
      const catalog = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON) as ComponentCatalogEntry[];
      expect(catalog.length).assertEqual(16);
      for (let index = 0; index < LAB_COMPONENT_NAMES.length; index++) {
        expect(catalog[index].name).assertEqual(LAB_COMPONENT_NAMES[index]);
      }
      expect(UI_AGENT_LAB_COMPONENT_CATALOG_JSON.includes('"name":"BentoGrid"')).assertFalse();
      expect(mergeA2uiLayout(
        BASELINE,
        BENTO_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('accepts an official List template and rejects unbound or invalid scoped layouts', 0, () => {
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"items"},' +
        '{"id":"items","component":"List","children":{"path":"/genericToolResults","componentId":"item-card"}},' +
        '{"id":"item-card","component":"ExpandableCard"}]}}';
      const unbound = valid.replace(
        '"children":{"path":"/genericToolResults","componentId":"item-card"}',
        '"children":["item-card"]'
      );
      const invalidPath = valid.replace('/genericToolResults', '/secret');
      const listAction = valid.replace(
        '"component":"List","children"',
        '"component":"List","actions":[],"children"'
      );
      const templateAction = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"ExpandableCard","actions":[]}'
      );
      const templateRootScope = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"ExpandableCard","dataPath":"/"}'
      );
      const nestedList = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"List","children":' +
        '{"path":"/genericToolResults","componentId":"nested-card"}},' +
        '{"id":"nested-card","component":"ExpandableCard"}'
      );
      const nestedTemplateAction = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"Column","children":["nested-action"]},' +
        '{"id":"nested-action","component":"ActionBar","actions":[]}'
      );
      const rootScope = valid.replace(
        '{"id":"root","component":"SurfaceRoot","child":"items"}',
        '{"id":"root","component":"SurfaceRoot","child":"items","dataPath":"/"}'
      );
      const scopeBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/","value":{}}}\n';
      const merged = mergeA2uiLayout(BASELINE, valid, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON);

      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"List"')).assertTrue();
      expect(merged.includes('"componentId":"item-card"')).assertTrue();
      expect(mergeA2uiLayout(BASELINE, unbound, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, invalidPath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, listAction, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, templateAction, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        templateRootScope,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === BASELINE).assertFalse();
      expect(mergeA2uiLayout(BASELINE, nestedList, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, nestedTemplateAction, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(scopeBaseline, rootScope, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(scopeBaseline);
    });

    it('rejects business components when the UI Lab catalog is selected', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE,
        SURFACE_ID,
        offers(),
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for wrong surface or extra envelopes', 0, () => {
      const wrongSurface = VALID_CANDIDATE.replace(SURFACE_ID, 'other-surface');
      const extra = VALID_CANDIDATE + '\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{}}}';
      expect(mergeA2uiLayout(BASELINE, wrongSurface, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, extra, SURFACE_ID, offers())).assertEqual(BASELINE);
    });

    it('falls back exactly for unknown components and data paths', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('GenericToolResults', 'UnknownCard'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('/genericToolResults', '/secret'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for literal actions and unknown offers', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('{"offerId":"detail:1"}', '{"id":"hotel.detail","args":{"hotelId":2}}'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('detail:1', 'detail:unknown'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for duplicate offers and disconnected trees', 0, () => {
      const duplicate = VALID_CANDIDATE.replace(
        '{"offerId":"detail:1"}',
        '{"offerId":"detail:1"},{"offerId":"detail:1"}'
      );
      const disconnected = VALID_CANDIDATE.replace(
        '"children":["title","results","actions"]',
        '"children":["title","results"]'
      );
      expect(mergeA2uiLayout(BASELINE, duplicate, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, disconnected, SURFACE_ID, offers())).assertEqual(BASELINE);
    });

    it('falls back exactly for cycles and unknown fields', 0, () => {
      const cycle = VALID_CANDIDATE.replace(
        '{"id":"title","component":"Text","text":"酒店结果","variant":"h3"}',
        '{"id":"title","component":"Text","child":"root","text":"酒店结果","variant":"h3"}'
      );
      const unknownField = VALID_CANDIDATE.replace(
        '"component":"Column"',
        '"component":"Column","onClick":"unsafe"'
      );
      expect(mergeA2uiLayout(BASELINE, cycle, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, unknownField, SURFACE_ID, offers())).assertEqual(BASELINE);
    });
  });
}
