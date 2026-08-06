import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  AIPHONE_COMPONENT_CATALOG_JSON,
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
  usage: string;
  schema: ComponentWireSchema;
}

interface ComponentFieldSchema {
  type: string;
  valuePolicy: string;
  required?: boolean;
  maxItems?: number;
  fields?: Record<string, ComponentFieldSchema>;
  items?: ComponentFieldSchema;
}

interface ComponentWireSchema {
  fields: Record<string, ComponentFieldSchema>;
  requireAny?: string[][];
  exactlyOne?: string[][];
}

const LAB_COMPONENT_NAMES: string[] = [
  'SurfaceRoot', 'Column', 'Row', 'Text', 'InfoRows', 'ActionBar', 'ErrorNotice', 'ThinkingStream',
  'ThinkingCard', 'ScheduleStack', 'SkeletonCard', 'ExpandableCard', 'MediaSlider', 'SceneTabs', 'MasonryGrid', 'List',
  'HeroBanner', 'MetricGrid', 'SegmentedRingChart', 'MultiSeriesLineChart', 'MatrixHeatmap'
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

    it('gives UI Lab only the envelope skeleton while retaining the generic renderer example', 0, () => {
      const prompt = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON);
      const genericPrompt = buildA2uiLayoutSystemPrompt(SURFACE_ID, AIPHONE_COMPONENT_CATALOG_JSON);
      const uiLabSkeleton =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[...]}}';
      const genericExample =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}' +
        ']}}';
      const example =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","info","result-list"]},' +
        '{"id":"hero","component":"HeroBanner",' +
        '"title":"REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS"},' +
        '{"id":"info","component":"InfoRows","dataPath":"/summary"},' +
        '{"id":"result-list","component":"List","children":{"path":"/results","componentId":"result-card"}},' +
        '{"id":"result-card","component":"ExpandableCard"}' +
        ']}}';
      const uiLabBaseline =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-layout-test","root":"root"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{}}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/results","value":[]}}\n';
      expect(prompt.includes(example)).assertFalse();
      expect(prompt.includes(uiLabSkeleton)).assertTrue();
      expect(prompt.includes('never output the ellipsis literally')).assertTrue();
      expect(prompt.includes('The following is a complete protocol-shape example only')).assertFalse();
      expect(prompt.includes('REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS')).assertFalse();
      expect(prompt.includes('For repeated array items')).assertTrue();
      expect(prompt.includes('official A2UI v0.9 List shape')).assertTrue();
      expect(prompt.includes('compact Text template bound only to that field')).assertTrue();
      expect(prompt.includes('Use ExpandableCard only when each item has additional details')).assertTrue();
      expect(prompt.includes('offered action to carry')).assertTrue();
      expect(prompt.includes('Never bind a whole provider object')).assertTrue();
      expect(prompt.includes('prefer one InfoRows binding over List or ExpandableCard')).assertTrue();
      expect(prompt.includes('Array<{label,value,time?}>')).assertTrue();
      expect(prompt.includes('make charts the main body of the layout')).assertTrue();
      expect(prompt.includes('use as many different chart component types as the data can meaningfully support')).assertTrue();
      expect(prompt.includes('Every chart must add a distinct view')).assertTrue();
      expect(prompt.includes('Do not repeat the same metric, invent or calculate values')).assertTrue();
      expect(prompt.includes('force a specific chart type')).assertTrue();
      expect(genericPrompt.includes(genericExample)).assertTrue();
      expect(genericPrompt.includes('The following is a complete protocol-shape example only')).assertTrue();
      expect(genericPrompt.includes('For repeated array items')).assertTrue();
      expect(genericPrompt.includes('List with one ExpandableCard')).assertTrue();
      expect(genericPrompt.includes('compact Text template bound only to that field')).assertFalse();
      expect(genericPrompt.includes('make charts the main body of the layout')).assertFalse();
      expect(prompt.includes('Use "component", never "type"')).assertTrue();
      expect(prompt.includes('nested "props" or "properties" object')).assertTrue();
      expect(prompt.includes('Derive every binding path only from the exact structure present in dataSnapshot')).assertTrue();
      expect(prompt.includes('checks that each path exists in that sampled snapshot')).assertTrue();
      expect(prompt.includes('Never output a data path string as literal visible content')).assertTrue();
      expect(prompt.includes('valuePolicy "literal-or-path"')).assertTrue();
      expect(prompt.includes('For "path-only"')).assertTrue();
      expect(prompt.includes('never output a numeric literal, numeric string')).assertTrue();
      expect(prompt.includes('MetricGrid may use legacy dataPath or direct items')).assertTrue();
      expect(prompt.includes('rendered once per item')).assertTrue();
      expect(prompt.includes('MUST output exactly one HeroBanner')).assertTrue();
      expect(prompt.includes('Do not fabricate a HeroBanner summary for an error or no-display-data baseline')).assertTrue();
      expect(prompt.includes('always the first visible element in the main content container')).assertTrue();
      expect(prompt.includes('SurfaceRoot.child must reference a Column')).assertTrue();
      expect(prompt.includes('HeroBanner id must be Column.children[0]')).assertTrue();
      expect(prompt.includes('leaving sibling components disconnected')).assertTrue();
      expect(prompt.includes('Every HeroBanner visible string must be rewritten from the current verified results')).assertFalse();
      expect(prompt.includes('never copy the REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS placeholder')).assertFalse();
      expect(prompt.includes('sampled array length')).assertTrue();
      expect(prompt.includes('/summary/count and /summary/text describe how many DataResult sets')).assertTrue();
      expect(prompt.includes('result.data explicitly labels a scalar as count or total')).assertTrue();
      expect(prompt.includes('result.data.summary text explicitly supports it')).assertTrue();
      expect(prompt.includes('must not mechanically list toolId')).assertTrue();
      expect(prompt.includes('each result gets its own card')).assertFalse();
      expect(prompt.includes('output no SVG')).assertTrue();
      expect(prompt.includes('renderer owns all chart geometry and styling')).assertTrue();
      expect(example.includes('"type"')).assertFalse();
      expect(example.includes('"props"')).assertFalse();
      expect(example.includes('"child":"content"')).assertTrue();
      expect(example.includes('"children":["hero","info","result-list"]')).assertTrue();
      expect(example.includes('"title":"REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS"')).assertTrue();
      expect(example.includes('"text"')).assertFalse();
      expect(example.includes('"body"')).assertFalse();
      expect(example.includes('"path":"/results","componentId":"result-card"')).assertTrue();
      expect(example.includes('"id":"result-card","component":"ExpandableCard"')).assertTrue();
      expect(example.includes('餐馆')).assertFalse();
      expect(example.includes('food')).assertFalse();
      expect(example.includes('GitHub')).assertFalse();
      expect(mergeA2uiLayout(
        uiLabBaseline,
        example,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === uiLabBaseline).assertFalse();
    });

    it('adds bounded presentation decision notes only for the enabled UI Lab mode', 0, () => {
      const disabled = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON);
      const enabled = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON, true);
      const genericEnabled = buildA2uiLayoutSystemPrompt(SURFACE_ID, AIPHONE_COMPONENT_CATALOG_JSON, true);
      expect(disabled.includes('Output exactly one compact JSON line')).assertTrue();
      expect(disabled.includes('uiDecisionNotes')).assertFalse();
      expect(enabled.includes('Output exactly two compact JSON lines')).assertTrue();
      expect(enabled.includes('The second line must be the single A2UI updateComponents protocol envelope')).assertTrue();
      expect(enabled.includes('"plannedComponents"')).assertTrue();
      expect(enabled.includes('plannedComponents lists the planned components the layout intends to use')).assertTrue();
      expect(enabled.includes('plannedComponents lists only non-container components')).assertFalse();
      expect(enabled.includes('"omittedData"')).assertTrue();
      expect(enabled.includes('DataResult paths not presented')).assertTrue();
      expect(enabled.includes('Never list a path in omittedData when an output component uses that exact dataPath')).assertTrue();
      expect(enabled.includes('duplicate, irrelevant, raw_or_unreadable, unsupported_component')).assertTrue();
      expect(enabled.includes('mobile_space')).assertTrue();
      expect(enabled.includes('at most 12 entries in each array')).assertTrue();
      expect(enabled.includes('at most 2400 characters for the complete first line')).assertTrue();
      expect(enabled.includes('bounded presentation summary only')).assertTrue();
      expect(enabled.includes('Never provide hidden reasoning, chain-of-thought')).assertTrue();
      expect(enabled.includes('step-by-step analysis')).assertTrue();
      expect(genericEnabled.includes('Output exactly one compact JSON line')).assertTrue();
      expect(genericEnabled.includes('uiDecisionNotes')).assertFalse();
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

    it('keeps the UI Lab allowlist fixed at twenty-one components without BentoGrid', 0, () => {
      const catalog = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON) as ComponentCatalogEntry[];
      expect(catalog.length).assertEqual(21);
      for (let index = 0; index < LAB_COMPONENT_NAMES.length; index++) {
        expect(catalog[index].name).assertEqual(LAB_COMPONENT_NAMES[index]);
      }
      let heroUsage: string = '';
      for (let index = 0; index < catalog.length; index++) {
        expect(Object.keys(catalog[index].schema.fields).length > 1).assertTrue();
        if (catalog[index].name === 'HeroBanner') heroUsage = catalog[index].usage;
      }
      const infoRowsUsage = catalog[4].usage;
      const expandableUsage = catalog[11].usage;
      const listUsage = catalog[15].usage;
      expect(infoRowsUsage.includes('Array<{label,value,time?}>')).assertTrue();
      expect(infoRowsUsage.includes('优先于 List 或 ExpandableCard')).assertTrue();
      expect(expandableUsage.includes('额外详情')).assertTrue();
      expect(expandableUsage.includes('summary 或 description 已足够时改用')).assertTrue();
      expect(expandableUsage.includes('不得绑定整个 provider object')).assertTrue();
      expect(listUsage.includes('{path:ARRAY_PATH,componentId:TEMPLATE_ID}')).assertTrue();
      expect(listUsage.includes('最简单组件')).assertTrue();
      expect(heroUsage.includes('主内容容器中的第一个可见元素')).assertTrue();
      expect(heroUsage.includes('必须且只能生成一个 HeroBanner')).assertTrue();
      expect(heroUsage.includes('错误或无可展示数据的 baseline 不得强造 HeroBanner 概述')).assertTrue();
      expect(heroUsage.includes('SurfaceRoot.child 必须指向 Column')).assertTrue();
      expect(heroUsage.includes('Column.children[0]')).assertTrue();
      expect(heroUsage.includes('不得让 root 只连接 HeroBanner 而留下孤立组件')).assertTrue();
      expect(UI_AGENT_LAB_COMPONENT_CATALOG_JSON.includes('"name":"BentoGrid"')).assertFalse();
      const metric = catalog[17].schema;
      const metricItems = metric.fields['items'];
      const metricItemFields = metricItems.items?.fields;
      const ringSegments = catalog[18].schema.fields['segments'];
      const ringItemFields = ringSegments.items?.fields;
      expect(metric.requireAny?.[0].join(',')).assertEqual('dataPath,items');
      expect(metric.exactlyOne?.[0].join(',')).assertEqual('dataPath,items');
      expect(metricItems.maxItems).assertEqual(6);
      expect(metricItems.valuePolicy).assertEqual('literal');
      expect(metricItemFields?.['label'].valuePolicy).assertEqual('literal-or-path');
      expect(metricItemFields?.['value'].type).assertEqual('number');
      expect(metricItemFields?.['value'].valuePolicy).assertEqual('path-only');
      expect(ringItemFields?.['label'].valuePolicy).assertEqual('literal-or-path');
      expect(ringItemFields?.['value'].valuePolicy).assertEqual('path-only');
      expect(catalog[18].usage.includes('已验证的占比、ratio 或类别构成信息')).assertTrue();
      expect(catalog[18].schema.exactlyOne?.[0].join(',')).assertEqual('dataPath,segments');
      expect(ringSegments.maxItems).assertEqual(8);
      for (let index = 16; index < LAB_COMPONENT_NAMES.length; index++) {
        expect(AIPHONE_COMPONENT_CATALOG_JSON.includes('"name":"' + LAB_COMPONENT_NAMES[index] + '"')).assertFalse();
      }
      expect(mergeA2uiLayout(
        BASELINE,
        BENTO_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('accepts constrained UI Lab presentation components and rejects unsafe shapes', 0, () => {
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","metrics","ring","line","heat"]},' +
        '{"id":"hero","component":"HeroBanner","text":"OVERVIEW","title":"Summary","body":"Verified results."},' +
        '{"id":"metrics","component":"MetricGrid","title":"Metrics","dataPath":"/genericToolResults"},' +
        '{"id":"ring","component":"SegmentedRingChart","dataPath":"/genericToolResults"},' +
        '{"id":"line","component":"MultiSeriesLineChart","dataPath":"/genericToolResults"},' +
        '{"id":"heat","component":"MatrixHeatmap","body":"Activity","dataPath":"/genericToolResults"}' +
        ']}}';
      const duplicateHero = valid.replace(
        '"children":["hero","metrics","ring","line","heat"]',
        '"children":["hero","hero-2","metrics","ring","line","heat"]'
      ).replace(
        '{"id":"metrics"',
        '{"id":"hero-2","component":"HeroBanner","title":"Second"},{"id":"metrics"'
      );
      const invalid: string[] = [
        valid.replace(',"title":"Summary"', ''),
        valid.replace('"title":"Summary"', '"title":"Summary","dataPath":"/summary"'),
        duplicateHero,
        valid.replace('"title":"Metrics","dataPath":"/genericToolResults"', '"title":"Metrics"'),
        valid.replace('"component":"SegmentedRingChart","dataPath"', '"component":"SegmentedRingChart","actions":[],"dataPath"'),
        valid.replace('"component":"MultiSeriesLineChart","dataPath"', '"component":"MultiSeriesLineChart","children":[],"dataPath"'),
        valid.replace('"component":"MatrixHeatmap","body"', '"component":"MatrixHeatmap","path":"M0 0","body"')
      ];

      expect(mergeA2uiLayout(
        BASELINE,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === BASELINE).assertFalse();
      expect(mergeA2uiLayout(BASELINE, valid, SURFACE_ID, [])).assertEqual(BASELINE);
      for (let index = 0; index < invalid.length; index++) {
        expect(mergeA2uiLayout(
          BASELINE,
          invalid[index],
          SURFACE_ID,
          [],
          UI_AGENT_LAB_COMPONENT_CATALOG_JSON
        )).assertEqual(BASELINE);
      }
    });

    it('validates direct chart fields recursively from the catalog and exact host paths', 0, () => {
      const bindingBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary/text","value":"Verified"}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/metrics/followers","value":42}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/metrics/stars","value":7}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/metrics/starLabel","value":"Stars"}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/typescript","value":80}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","metrics","ring"]},' +
        '{"id":"hero","component":"HeroBanner","title":{"path":"/summary/text"}},' +
        '{"id":"metrics","component":"MetricGrid","title":"Repository metrics","items":[' +
        '{"id":"followers","label":"Followers","value":{"path":"/metrics/followers"}},' +
        '{"id":"stars","label":{"path":"/metrics/starLabel"},"value":{"path":"/metrics/stars"}}]},' +
        '{"id":"ring","component":"SegmentedRingChart","segments":[' +
        '{"id":"typescript","label":"TypeScript","value":{"path":"/languages/typescript"}}]}' +
        ']}}';
      const merged = mergeA2uiLayout(
        bindingBaseline,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === bindingBaseline).assertFalse();
      expect(merged.includes('"items"')).assertTrue();
      expect(merged.includes('"segments"')).assertTrue();
      expect(merged.includes('"title":{"path":"/summary/text"}')).assertTrue();
      expect(merged.includes('"properties"')).assertFalse();

      const invalid: string[] = [
        valid.replace('{"path":"/metrics/followers"}', '42'),
        valid.replace('{"path":"/metrics/followers"}', '"42"'),
        valid.replace('{"path":"/metrics/followers"}', '{"expression":"metrics.followers"}'),
        valid.replace('{"path":"/metrics/followers"}', '{"FunctionCall":{"name":"read"}}'),
        valid.replace('{"path":"/metrics/followers"}', '{"path":"/metrics/followers","fallback":0}'),
        valid.replace('"label":"Followers"', '"label":12'),
        valid.replace('"label":"Followers"', '"label":"Followers","color":"red"'),
        valid.replace('"component":"MetricGrid","title"',
          '"component":"MetricGrid","dataPath":"/genericToolResults","title"'),
        valid.replace('"component":"SegmentedRingChart","segments"',
          '"component":"SegmentedRingChart","dataPath":"/genericToolResults","segments"'),
        valid.replace('{"path":"/summary/text"}', '{"path":"/summary/private"}'),
        valid.replace('"component":"MetricGrid","title"', '"component":"MetricGrid","properties":{},"title"')
      ];
      for (let index = 0; index < invalid.length; index++) {
        expect(mergeA2uiLayout(
          bindingBaseline,
          invalid[index],
          SURFACE_ID,
          [],
          UI_AGENT_LAB_COMPONENT_CATALOG_JSON
        )).assertEqual(bindingBaseline);
      }
      const dataModelCandidate =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test",' +
        '"path":"/metrics/followers","value":42}}';
      expect(mergeA2uiLayout(
        bindingBaseline,
        dataModelCandidate,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(bindingBaseline);
    });

    it('derives exact binding paths recursively from parent data values', 0, () => {
      const parentValueBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test",' +
        '"path":"/results","value":[{"data":{"profile":{"name":"Octocat"},' +
        '"slash/key":{"til~de":"escaped"}}}]}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"hero"},' +
        '{"id":"hero","component":"HeroBanner",' +
        '"title":{"path":"/results/0/data/slash~1key/til~0de"}}]}}';
      const missingSibling = valid.replace(
        '/results/0/data/slash~1key/til~0de',
        '/results/0/data/profile/missing'
      );
      const componentOnlyBaseline = parentValueBaseline.replace(
        '"dataPath":"/genericToolResults"',
        '"dataPath":"/component-only"'
      );
      const componentOnlyPath = valid.replace(
        '/results/0/data/slash~1key/til~0de',
        '/component-only'
      );

      expect(mergeA2uiLayout(
        parentValueBaseline,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === parentValueBaseline).assertFalse();
      expect(mergeA2uiLayout(
        parentValueBaseline,
        missingSibling,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(parentValueBaseline);
      expect(mergeA2uiLayout(
        componentOnlyBaseline,
        componentOnlyPath,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(componentOnlyBaseline);
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
      const heroTemplate = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"HeroBanner","title":"Repeated summary"}'
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
      expect(mergeA2uiLayout(BASELINE, heroTemplate, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
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

    it('validates List template catalog bindings against each array item scope', 0, () => {
      const itemBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/","value":' +
        '{"summary":{"text":"Recent activity"},"results":[{"data":{"providerData":{"recentActivity":[' +
        '{"kind":"PushEvent","summary":"Pushed commits"},' +
        '{"kind":"IssueEvent","summary":"Opened issue"}]}}}]}}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"items"},' +
        '{"id":"items","component":"List","children":{' +
        '"path":"/results/0/data/providerData/recentActivity","componentId":"item-column"}},' +
        '{"id":"item-column","component":"Column","children":["item-card"]},' +
        '{"id":"item-card","component":"ExpandableCard",' +
        '"title":{"path":"/kind"},"body":{"path":"/summary"}}]}}';
      const missing = valid.replace('{"path":"/summary"}', '{"path":"/missing"}');
      const absoluteInItem = valid.replace('{"path":"/kind"}',
        '{"path":"/results/0/data/providerData/recentActivity/0/kind"}');

      const merged = mergeA2uiLayout(
        itemBaseline, valid, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === itemBaseline).assertFalse();
      expect(merged).assertContain('"title":{"path":"/kind"}');
      expect(mergeA2uiLayout(
        itemBaseline, missing, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, absoluteInItem, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
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
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('/genericToolResults', '/genericToolResults/private'),
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
