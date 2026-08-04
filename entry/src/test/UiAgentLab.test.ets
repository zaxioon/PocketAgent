import { describe, it, expect } from '@ohos/hypium';
import {
  ActionOffer,
  A2uiSurfaceStore,
  CreateUiTaskPayload,
  DataResult,
  LocalModelSettings,
  defaultLocalModelSettings,
  mergeA2uiLayoutWithStatus,
  parseA2uiEnvelope,
  parseA2uiJsonl,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';
import {
  createUiAgentLabHtmlShell,
  resolveUiAgentLabDataPath,
  uiAgentLabSurfaceScript,
  uiAgentLabStatusScript
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabHtml';
import {
  clearUiLabModelSettings,
  configureUiLabModelSettings,
  uiLabModelSettings
} from '../main/ets/pages/A2uiHome/lab/UiLabRuntimeConfig';
import {
  buildUiAgentLabSnapshot,
  hydrateUiAgentLabMergedJsonl,
  hydrateUiAgentLabSnapshotForMergedLayout,
  uiAgentLabDataJsonl,
  uiAgentLabDataPaths,
  uiAgentLabLayoutPrompt,
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabHarness';

interface UiLabHydrationShop {
  name: string;
  rank: number;
}

interface UiLabHydrationNote {
  label: string;
  value: number;
}

interface UiLabHydrationData {
  shops: UiLabHydrationShop[];
  notes: UiLabHydrationNote[];
}

interface UiLabDashboardHeader {
  kicker?: string;
  title: string;
  description?: string;
  ariaLabel: string;
}

interface UiLabDashboardMetric {
  label: string;
  value: number;
  unit: string;
  delta: number;
  deltaLabel: string;
}

interface UiLabDashboardMetrics {
  header: UiLabDashboardHeader;
  items: UiLabDashboardMetric[];
}

interface UiLabDashboardSegment {
  label: string;
  bytes: number;
}

interface UiLabDashboardRing {
  header: UiLabDashboardHeader;
  centerLabel: string;
  unitLabel: string;
  segments: UiLabDashboardSegment[];
}

interface UiLabDashboardSeries {
  label: string;
  values: number[];
}

interface UiLabDashboardLine {
  xLabels: string[];
  series: UiLabDashboardSeries[];
}

interface UiLabDashboardHeatmap {
  weekLabels: string[];
  dayLabels: string[];
  values: number[][];
}

interface UiLabDashboardModel {
  metrics: UiLabDashboardMetrics;
  ring: UiLabDashboardRing;
  line: UiLabDashboardLine;
  heatmap: UiLabDashboardHeatmap;
}

function settings(): LocalModelSettings {
  return {
    provider: 'test-provider',
    baseUrl: 'https://example.test/v1/chat/completions',
    model: 'test-model',
    apiKey: 'test-secret',
    customParametersJson: '{"temperature":0}',
    ignoreToolSurfaceUpdates: true
  };
}

export default function uiAgentLabTest() {
  describe('uiAgentLab', () => {
    it('builds one interactive HTML shell with the allowlisted bridge', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('UiAgentLabBridge.postMessage');
      expect(html).assertContain("type:'back'");
      expect(html).assertContain("type:'submit'");
      expect(html).assertContain('id="status"');
      expect(html).assertContain('等待 UI Agent 生成 Lab 组件');
      expect(html).assertContain('id="composer"');
      expect(html).assertContain('id="toast"');
      expect(html).assertContain('window.__applyUiAgentLabSurface');
    });

    it('encodes status payload before building executable JavaScript', 0, () => {
      const marker = "x');window.__RAW_STATUS_EXECUTED=true;//";
      const script = uiAgentLabStatusScript({
        state: 'error',
        message: marker,
        responseChars: 0
      });
      expect(script).assertContain('window.__applyUiAgentLabStatus(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script).assertContain('\\u007b');
    });

    it('encodes a complete surface before injecting it into ArkWeb JavaScript', 0, () => {
      const marker = "</script><script>window.__RAW_SURFACE_EXECUTED=true</script>";
      const surfaceJson = '{"surfaceId":"surface-lab","rootId":"root","components":[' +
        '{"id":"root","component":"Text","text":' + JSON.stringify(marker) + '}],"dataModelJson":"{}"}';
      const script = uiAgentLabSurfaceScript(surfaceJson);
      expect(script).assertContain('window.__applyUiAgentLabSurface(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script.indexOf('</script>')).assertEqual(-1);
      expect(script).assertContain('\\u007b');
      expect(script).assertContain('\\u003c');
    });

    it('registers only the fixed UI Lab catalog and uses safe DOM text APIs', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const componentNames: string[] = [
        'SurfaceRoot', 'Column', 'Row', 'Text', 'InfoRows', 'ActionBar',
        'ErrorNotice', 'ThinkingStream', 'ThinkingCard', 'ScheduleStack',
        'SkeletonCard', 'ExpandableCard', 'MediaSlider', 'SceneTabs',
        'MasonryGrid', 'List', 'HeroBanner', 'MetricGrid',
        'SegmentedRingChart', 'MultiSeriesLineChart', 'MatrixHeatmap'
      ];
      componentNames.forEach((name: string) => {
        expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.' + name + '=');
      });
      const businessComponents: string[] = [
        'TravelOptions', 'TrainOptions', 'FlightBoard', 'FoodChoices',
        'SocialHub', 'StripeReceivingAccountCard', 'ToolConnectCard',
        'GenericToolResults', 'AggregateSearch', 'MultiTaskBoard'
      ];
      businessComponents.forEach((name: string) => {
        expect(html.indexOf('UI_AGENT_LAB_COMPONENT_REGISTRY.' + name + '=')).assertEqual(-1);
      });
      expect(html.indexOf('UI_AGENT_LAB_COMPONENT_REGISTRY.BentoGrid=')).assertEqual(-1);
      expect(html.indexOf('.bento-grid')).assertEqual(-1);
      expect(html).assertContain('.textContent=');
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
      expect(html).assertContain("return safeError('不支持的组件'");
    });

    it('renders dynamic dashboard components with bounded renderer-owned geometry', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.HeroBanner=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.MetricGrid=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.SegmentedRingChart=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.MultiSeriesLineChart=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.MatrixHeatmap=');
      expect(html).assertContain("document.createElementNS('http://www.w3.org/2000/svg',tag)");
      expect(html).assertContain("var CHART_PALETTE=['#d9dee6'");
      expect(html).assertContain("var HEATMAP_PALETTE=['#dfe3e8'");
      expect(html).assertContain("if(copy.endsWith('.0'))copy=copy.slice(0,-2)");
      expect(html).assertContain("function formattedBytes(value)");
      expect(html).assertContain("units=['B','KB','MB','GB','TB']");
      expect(html).assertContain("if(field.kind==='bytes')return formattedBytes(field.value)");
      expect(html.indexOf("if(field.kind==='bytes')return copy+'B'")).assertEqual(-1);
      expect(html).assertContain("items.slice(0,6).forEach");
      expect(html).assertContain("itemArray(value,'segments')");
      expect(html).assertContain("list(source.series).slice(0,4)");
      expect(html).assertContain("var rawValues=list(itemRecord.values)");
      expect(html).assertContain("rawValues.slice(0,24)");
      expect(html).assertContain("list(source.values).slice(0,12)");
      expect(html).assertContain("list(source.weeks).slice(0,24)");
      expect(html).assertContain("componentValue(component,context)");
      expect(html).assertContain("raw=source?source.header:undefined,header=record(raw)");
      expect(html).assertContain("nonEmptyText(component.text,fields.kicker)");
      expect(html).assertContain("nonEmptyText(component.title,fields.title)");
      expect(html).assertContain("nonEmptyText(component.body,fields.description)");
      expect(html).assertContain("parent.setAttribute('aria-label',fields.ariaLabel)");
      expect(html).assertContain("ranks.sort(function(left,right){return left-right;})");
      expect(html).assertContain("segment.paletteIndex=ranks.length===1?CHART_PALETTE.length-1");
      expect(html).assertContain("track.setAttribute('stroke-width','8')");
      expect(html).assertContain("arc.setAttribute('stroke-width','8')");
      expect(html).assertContain("compactNumber(segment.field.value/total*100)+'%'");
      expect(html).assertContain("source?nonEmptyText(source.centerLabel):''");
      expect(html).assertContain("centerValue.textContent=compactNumber(total)");
      expect(html).assertContain("centerUnit.textContent=unitLabel");
      expect(html).assertContain("ringAria=nonEmptyText(ringFields.ariaLabel,ringSummary)");
      expect(html).assertContain("svg.setAttribute('aria-label',ringAria)");
      expect(html).assertContain("ringTitle.textContent=ringAria");
      expect(html).assertContain("rawValues.length!==rawXLabels.length");
      expect(html).assertContain("lineAria=nonEmptyText(lineFields.ariaLabel,lineSummary)");
      expect(html).assertContain("svg.setAttribute('aria-label',lineAria)");
      expect(html).assertContain("lineTitle.textContent=lineAria");
      expect(html).assertContain("wrapper.appendChild(node('p','sr-only',lineSummary))");
      expect(html).assertContain('.sr-only { position:absolute!important;');
      expect(html).assertContain("node('small','metric-unit',unit)");
      expect(html).assertContain("nonEmptyText(source.deltaLabel");
      expect(html).assertContain("metric-delta'+(deltaValue");
      expect(html).assertContain("cell.style.background=HEATMAP_PALETTE[level]");
      expect(html).assertContain("grid.setAttribute('role','grid')");
      expect(html).assertContain("cell.setAttribute('role','gridcell')");
      expect(html).assertContain("cell.setAttribute('aria-label',cellLabel)");
      expect(html).assertContain("arc.setAttribute('stroke',CHART_PALETTE");
      expect(html.indexOf('source.color')).assertEqual(-1);
      expect(html.indexOf('source.svg')).assertEqual(-1);
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
    });

    it('encodes dashboard component props and dynamic data without embedding raw text', 0, () => {
      const marker = '<svg onload="window.__DASHBOARD_INJECTED=true">';
      const model: UiLabDashboardModel = {
        metrics: {
          header: { kicker: '统计', title: '动态指标', description: '指标说明', ariaLabel: '指标区' },
          items: [{ label: '仓库', value: 24, unit: '个', delta: 3, deltaLabel: '增加 3' }]
        },
        ring: {
          header: { title: '语言分布', ariaLabel: '语言占比图' }, centerLabel: '总量', unitLabel: 'bytes',
          segments: [{ label: 'TypeScript', bytes: 123456 }, { label: 'ArkTS', bytes: 456789 }]
        },
        line: { xLabels: ['一月', '二月'], series: [{ label: '提交', values: [3, 8] }] },
        heatmap: { weekLabels: ['W1', 'W2'], dayLabels: ['一', '二'], values: [[0, 5], [2, 9]] }
      };
      const modelJson = JSON.stringify(model);
      const surfaceJson = '{"surfaceId":"surface-dashboard","rootId":"root","components":[' +
        '{"id":"root","component":"Column","children":["hero","metrics","ring","line","heatmap"]},' +
        '{"id":"hero","component":"HeroBanner","text":"概览","title":' + JSON.stringify(marker) + ',"body":"动态正文"},' +
        '{"id":"metrics","component":"MetricGrid","dataPath":"/metrics"},' +
        '{"id":"ring","component":"SegmentedRingChart","dataPath":"/ring"},' +
        '{"id":"line","component":"MultiSeriesLineChart","dataPath":"/line"},' +
        '{"id":"heatmap","component":"MatrixHeatmap","dataPath":"/heatmap"}],' +
        '"dataModelJson":' + JSON.stringify(modelJson) + '}';
      const script = uiAgentLabSurfaceScript(surfaceJson);

      expect(script).assertContain('window.__applyUiAgentLabSurface(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script.indexOf('动态指标')).assertEqual(-1);
      expect(script.indexOf('TypeScript')).assertEqual(-1);
      expect(script).assertContain('\\u003c');
      expect(script).assertContain('\\u52a8');
    });

    it('renders a paged List by appending every template item in stable item scope', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.List=');
      expect(html).assertContain('var LIST_PAGE_SIZE=8');
      expect(html).assertContain('items.slice(visibleCount,nextCount).forEach');
      expect(html).assertContain("more.addEventListener('click',appendPage)");
      expect(html).assertContain("status.textContent='已显示 '+String(visibleCount)+' / '+String(items.length)");
      expect(html).assertContain('more.disabled=visibleCount>=items.length');
      expect(html).assertContain('hasItemScope:true,itemScope:item');
      expect(html).assertContain("component.dataPath==='/'");
      expect(html).assertContain('return context.itemScope');
      expect(html).assertContain("node('p','lab-card-copy','暂无内容')");
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
    });

    it('renders visible text and lists from component props or data paths', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const modelJson = '{"headline":"动态标题","days":[{"label":"动态日期",' +
        '"title":"动态列表","entries":[{"time":"08:30","title":"动态事项"}]}]}';
      const surfaceJson = '{"surfaceId":"surface-dynamic","rootId":"root","components":[' +
        '{"id":"root","component":"Column","children":["headline","schedule"]},' +
        '{"id":"headline","component":"Text","dataPath":"/headline"},' +
        '{"id":"schedule","component":"ScheduleStack","dataPath":"/days"}],' +
        '"dataModelJson":' + JSON.stringify(modelJson) + '}';
      const script = uiAgentLabSurfaceScript(surfaceJson);
      expect(script.indexOf('动态标题')).assertEqual(-1);
      expect(script.indexOf('动态列表')).assertEqual(-1);
      expect(script).assertContain('\\u52a8');
      expect(script).assertContain('\\u5217');
      expect(html).assertContain('componentValue(component,context)');
      expect(html).assertContain("itemArray(dayRecord,'entries')");
      expect(html).assertContain('text(dayRecord.title');
      expect(html).assertContain('text(eventRecord.title');
      expect(html.indexOf('西湖边喝咖啡')).assertEqual(-1);
      expect(html.indexOf('北山街')).assertEqual(-1);
    });

    it('renders bounded generic expandable data and falls back from an empty parser title', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const marker = '<img src=x onerror="window.__EXPANDABLE_INJECTED=true">';
      const modelJson = '{"title":"季度概览","summary":"保持增长",' +
        '"rows":[{"label":"当前值","value":"可见"}],"groups":[' +
        '{"name":"Alpha","metrics":[{"label":"完成率","value":87},' +
        '{"label":"稳定状态","value":true}],"note":' + JSON.stringify(marker) + '}]}';
      const surfaceJson = '{"surfaceId":"surface-expandable","rootId":"detail","components":[' +
        '{"id":"detail","component":"ExpandableCard","title":"","dataPath":"/payload"}],' +
        '"dataModelJson":' + JSON.stringify('{"payload":' + modelJson + '}') + '}';
      const script = uiAgentLabSurfaceScript(surfaceJson);

      expect(html).assertContain('var title=nonEmptyText(component.title');
      expect(html).assertContain("nonEmptyText(valueRecord?valueRecord.title:undefined");
      expect(html).assertContain('appendExpandableValue(panelInner,value');
      expect(html).assertContain('appendExpandableValue(itemHost,itemRecord');
      expect(html).assertContain("appendExpandableField(objectSection,key,child,budget)");
      expect(html).assertContain('EXPANDABLE_MAX_DEPTH=4');
      expect(html).assertContain('EXPANDABLE_MAX_NODES=72');
      expect(html).assertContain('EXPANDABLE_MAX_ARRAY_ITEMS=12');
      expect(html).assertContain('EXPANDABLE_MAX_OBJECT_FIELDS=16');
      expect(html).assertContain('{remaining:EXPANDABLE_MAX_NODES,notified:false}');
      expect(html).assertContain("key==='title'||key==='name'||key==='label'");
      expect(html).assertContain('.textContent=');
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
      expect(html.indexOf('[object Object]')).assertEqual(-1);
      expect(script.indexOf('季度概览')).assertEqual(-1);
      expect(script.indexOf('完成率')).assertEqual(-1);
      expect(script.indexOf('当前值')).assertEqual(-1);
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script).assertContain('\\u5b8c');
      expect(script).assertContain('\\u003c');
    });

    it('resolves flat, nested, array and escaped UI Lab data paths', 0, () => {
      const model = JSON.parse('{"headline":"单层值","results":[{"facts":[{"value":"数组嵌套值"}]}],' +
        '"escaped":{"slash/key":{"til~de":"转义值"}}}') as Object;

      expect(resolveUiAgentLabDataPath(model, '/headline')).assertEqual('单层值');
      expect(resolveUiAgentLabDataPath(model, '/results/0/facts/0/value')).assertEqual('数组嵌套值');
      expect(resolveUiAgentLabDataPath(model, '/escaped/slash~1key/til~0de')).assertEqual('转义值');
      expect(resolveUiAgentLabDataPath(model, '/results/1/facts') === undefined).assertTrue();
      expect(resolveUiAgentLabDataPath(model, '/results/00') === undefined).assertTrue();
    });

    it('keeps exact nested allowlist paths and finishes with one generic root data model', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-nested',
        dataTaskIds: ['data-nested'],
        skillId: 'dynamic',
        intent: '展示嵌套结果',
        expectedOutputSchema: 'custom.v1'
      };
      const data: DataResult = {
        toolId: 'time',
        outputSchema: 'custom.v1',
        status: 'success',
        sources: [],
        warnings: [],
        data: JSON.parse('{"title":"动态标题","details":{"items":[{"label":"第一项"}]},' +
          '"slash/key":{"til~de":"保留转义键"}}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const parsed = parseA2uiJsonl(uiAgentLabDataJsonl('surface-nested', snapshot));
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope(
        '{"createSurface":{"surfaceId":"surface-nested","root":"root","sendDataModel":true}}'
      ));
      parsed.envelopes.forEach(envelope => store.apply(envelope));
      const model = JSON.parse(store.getSurface().dataModelJson) as Record<string, Object>;
      const results = model['results'] as Object[];
      const first = results[0] as Record<string, Object>;
      const nestedData = first['data'] as Record<string, Object>;

      expect(parsed.error).assertEqual('');
      const paths: string[] = [];
      parsed.envelopes.forEach(envelope => {
        if (envelope.updateDataModel !== undefined) paths.push(envelope.updateDataModel.path);
      });
      expect(paths.indexOf('/results/0/facts') >= 0).assertTrue();
      expect(paths.indexOf('/results/0/data/details/items/0/label') >= 0).assertTrue();
      expect(paths.indexOf('/results/0/data/slash~1key/til~0de') >= 0).assertTrue();
      expect(paths[paths.length - 1]).assertEqual('/');
      const summary = model['summary'] as Record<string, Object>;
      expect(summary['text']).assertEqual('已获取 1 组真实数据。');
      expect(summary['dataLabel']).assertEqual('uiLabResultSets');
      expect((nestedData['details'] as Record<string, Object>)['items'] !== undefined).assertTrue();
      expect((nestedData['slash/key'] as Record<string, Object>)['til~de']).assertEqual('保留转义键');

      const baseline =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-nested","root":"root",' +
        '"title":"UI Agent Lab","intent":"ui_lab","status":"ready","sendDataModel":true}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-nested","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","facts"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"facts","component":"InfoRows","dataPath":"/results/0/facts"}' +
        ']}}\n' + uiAgentLabDataJsonl('surface-nested', snapshot);
      const candidate = '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-nested",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","facts","item-list"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"facts","component":"InfoRows","dataPath":"/results/0/facts"},' +
        '{"id":"item-list","component":"List","children":' +
        '{"path":"/results/0/data/details/items","componentId":"item-card"}},' +
        '{"id":"item-card","component":"ExpandableCard"}]}}';
      const merged = mergeA2uiLayoutWithStatus(
        baseline,
        candidate,
        'surface-nested',
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      const mergedParsed = parseA2uiJsonl(merged.jsonl);
      const mergedStore = new A2uiSurfaceStore();
      mergedParsed.envelopes.forEach(envelope => mergedStore.apply(envelope));
      const mergedModel = JSON.parse(mergedStore.getSurface().dataModelJson) as Record<string, Object>;

      expect(merged.accepted).assertTrue();
      expect(mergedParsed.error).assertEqual('');
      expect((mergedModel['results'] as Object[]).length).assertEqual(1);
      const mergedComponents = mergedStore.getSurface().components;
      expect(mergedComponents[4].component).assertEqual('List');
      expect(mergedComponents[4].dataPath).assertEqual('/results/0/data/details/items');
      expect(mergedComponents[4].child).assertEqual('item-card');
    });

    it('plans with eight samples but hydrates only an accepted List path from full data', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-full-list',
        dataTaskIds: ['data-full-list'],
        skillId: 'dynamic',
        intent: '展示完整列表',
        expectedOutputSchema: 'custom.v1'
      };
      const shops: UiLabHydrationShop[] = [];
      const notes: UiLabHydrationNote[] = [];
      for (let index = 0; index < 24; index++) {
        shops.push({ name: '项目 ' + index.toString(), rank: index });
        notes.push({ label: '备注 ' + index.toString(), value: index });
      }
      const hydrationData: UiLabHydrationData = { shops, notes };
      const data: DataResult = {
        toolId: 'time',
        outputSchema: 'custom.v1',
        status: 'success',
        sources: [],
        warnings: [],
        data: hydrationData as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const sampledData = snapshot.results[0].data as Record<string, Object>;
      expect((sampledData['shops'] as Object[]).length).assertEqual(8);
      expect((sampledData['notes'] as Object[]).length).assertEqual(8);

      const baseline =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-full-list","root":"root",' +
        '"title":"UI Agent Lab","intent":"ui_lab","status":"ready","sendDataModel":true}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-full-list","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}' +
        ']}}\n' + uiAgentLabDataJsonl('surface-full-list', snapshot);
      const candidate = '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-full-list",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","shop-list","notes"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"shop-list","component":"List","children":' +
        '{"path":"/results/0/data/shops","componentId":"shop-card"}},' +
        '{"id":"shop-card","component":"ExpandableCard"},' +
        '{"id":"notes","component":"InfoRows","dataPath":"/results/0/data/notes"}]}}';
      const merged = mergeA2uiLayoutWithStatus(
        baseline,
        candidate,
        'surface-full-list',
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged.accepted).assertTrue();

      const hydrated = hydrateUiAgentLabSnapshotForMergedLayout(
        snapshot,
        [data],
        merged.jsonl,
        'surface-full-list'
      );
      const hydratedData = hydrated.results[0].data as Record<string, Object>;
      expect((hydratedData['shops'] as Object[]).length).assertEqual(24);
      expect((hydratedData['notes'] as Object[]).length).assertEqual(24);

      const hydratedJsonl = hydrateUiAgentLabMergedJsonl(
        merged.jsonl,
        'surface-full-list',
        snapshot,
        [data]
      );
      const hydratedParsed = parseA2uiJsonl(hydratedJsonl);
      const hydratedStore = new A2uiSurfaceStore();
      hydratedParsed.envelopes.forEach(envelope => hydratedStore.apply(envelope));
      const hydratedModel = JSON.parse(hydratedStore.getSurface().dataModelJson) as Record<string, Object>;
      const hydratedResults = hydratedModel['results'] as Object[];
      const firstHydrated = hydratedResults[0] as Record<string, Object>;
      const finalData = firstHydrated['data'] as Record<string, Object>;
      expect(hydratedParsed.error).assertEqual('');
      expect((finalData['shops'] as Object[]).length).assertEqual(24);
      expect((finalData['notes'] as Object[]).length).assertEqual(24);
    });

    it('prefers providerData paths and hydrates the selected provider array without generic rows', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-provider-data',
        dataTaskIds: ['data-provider-data'],
        skillId: 'dynamic',
        intent: '展示 GitHub 活动',
        expectedOutputSchema: 'dynamicToolConnect'
      };
      const events: Object[] = [];
      const xLabels: string[] = [];
      const chartValues: number[] = [];
      for (let index = 0; index < 20; index++) {
        events.push(JSON.parse('{"type":"PushEvent","created_at":"2026-08-04T00:00:00Z",' +
          '"repo":{"name":"repo-' + index.toString() + '"},' +
          '"actor":{"login":"developer"}}') as Object);
        xLabels.push('D' + index.toString());
        chartValues.push(index);
      }
      const data: DataResult = {
        toolId: 'dynamic.search',
        outputSchema: 'dynamicToolConnect',
        status: 'success',
        sources: [],
        warnings: [],
        data: JSON.parse('{"providerData":{"events":' + JSON.stringify(events) + ',' +
          '"chart":{"xLabels":' + JSON.stringify(xLabels) + ',"series":[{"label":"Commits",' +
          '"values":' + JSON.stringify(chartValues) + '}]}},' +
          '"results":[{"rows":[{"label":"结果 1","value":""}],"rawPreview":"legacy"}],' +
          '"registration":{"provider":"Composio"}}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const visible = snapshot.results[0].data as Record<string, Object>;
      const sampledProvider = visible['providerData'] as Record<string, Object>;
      const paths = uiAgentLabDataPaths(snapshot);
      const prompt = uiAgentLabLayoutPrompt(task, snapshot, [] as ActionOffer[]);

      expect(Object.keys(visible).length).assertEqual(1);
      expect(visible['results'] === undefined).assertTrue();
      expect((sampledProvider['events'] as Object[]).length).assertEqual(8);
      const sampledChart = sampledProvider['chart'] as Record<string, Object>;
      const sampledSeries = sampledChart['series'] as Object[];
      const sampledFirstSeries = sampledSeries[0] as Record<string, Object>;
      expect((sampledFirstSeries['values'] as number[]).length).assertEqual(8);
      expect(paths.indexOf('/results/0/data/providerData/events') >= 0).assertTrue();
      expect(paths.indexOf('/results/0/data/results') >= 0).assertFalse();
      expect(prompt).assertContain('Prefer paths below providerData');
      expect(prompt.indexOf('结果 1')).assertEqual(-1);

      const mergedJsonl = '{"version":"v0.9.1","updateComponents":{' +
        '"surfaceId":"surface-provider-data","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","event-list","chart"]},' +
        '{"id":"hero","component":"HeroBanner","title":"活动概览"},' +
        '{"id":"event-list","component":"List","children":{' +
        '"path":"/results/0/data/providerData/events","componentId":"event-card"}},' +
        '{"id":"event-card","component":"ExpandableCard"},' +
        '{"id":"chart","component":"MultiSeriesLineChart",' +
        '"dataPath":"/results/0/data/providerData/chart"}]}}\n' +
        uiAgentLabDataJsonl('surface-provider-data', snapshot);
      const hydrated = hydrateUiAgentLabSnapshotForMergedLayout(
        snapshot, [data], mergedJsonl, 'surface-provider-data'
      );
      const hydratedVisible = hydrated.results[0].data as Record<string, Object>;
      const hydratedProvider = hydratedVisible['providerData'] as Record<string, Object>;
      const hydratedChart = hydratedProvider['chart'] as Record<string, Object>;
      const hydratedSeries = hydratedChart['series'] as Object[];
      const hydratedFirstSeries = hydratedSeries[0] as Record<string, Object>;
      expect((hydratedProvider['events'] as Object[]).length).assertEqual(20);
      expect((hydratedChart['xLabels'] as string[]).length).assertEqual(20);
      expect((hydratedFirstSeries['values'] as number[]).length).assertEqual(20);
    });

    it('builds a bounded generic snapshot and lets UI Agent choose presentation', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-1',
        dataTaskIds: ['data-1'],
        skillId: 'dynamic',
        intent: '展示真实结果',
        expectedOutputSchema: 'custom.v1'
      };
      const data: DataResult = {
        toolId: 'time',
        outputSchema: 'custom.v1',
        status: 'success',
        sources: [],
        warnings: [],
        data: JSON.parse('{"headline":"动态标题","count":3,"rows":[{"name":"第一项"}]}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const prompt = uiAgentLabLayoutPrompt(task, snapshot, [] as ActionOffer[]);
      expect(prompt).assertContain('intent="展示真实结果"');
      expect(prompt).assertContain('/results/0/data/headline');
      expect(prompt).assertContain('动态标题');
      expect(prompt).assertContain('Choose presentation by the meaning and shape');
      expect(prompt).assertContain('do not prescribe a chart type');
      expect(prompt).assertContain('MUST output exactly one HeroBanner');
      expect(prompt).assertContain('Do not fabricate a HeroBanner summary for an error or no-display-data baseline');
      expect(prompt).assertContain('always the first visible element in the main content container');
      expect(prompt).assertContain('SurfaceRoot.child must reference a Column');
      expect(prompt).assertContain('HeroBanner id must be Column.children[0]');
      expect(prompt).assertContain('leaving sibling components disconnected');
      expect(prompt).assertContain('/summary/count and /summary/text describe the number of DataResult sets');
      expect(prompt).assertContain('not the number of business entities');
      expect(prompt).assertContain('result.data explicitly labels a scalar as count or total');
      expect(prompt).assertContain('result.data.summary text explicitly supports it');
      expect(prompt.indexOf('mock.travel')).assertEqual(-1);
      expect(uiAgentLabDataPaths(snapshot).indexOf('/results/0/data/count') >= 0).assertTrue();
    });

    it('keeps every prompt JSON section parseable under long paths and a near-budget snapshot', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-prompt-budget', dataTaskIds: ['data-prompt-budget'], skillId: 'dynamic',
        intent: '验证完整 JSON section', expectedOutputSchema: 'custom.v1'
      };
      const data: DataResult = {
        toolId: 'time', outputSchema: 'custom.v1', status: 'success', sources: [], warnings: [],
        data: JSON.parse('{"seed":true}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const longData = JSON.parse('{}') as Record<string, Object | string>;
      for (let index = 0; index < 96; index++) {
        longData['long_provider_path_' + index.toString().padStart(3, '0') + '_' + 'segment'.repeat(8)] = 'v';
      }
      longData['zz_payload'] = 'p'.repeat(11000);
      snapshot.results[0].data = longData as Object;
      const prompt = uiAgentLabLayoutPrompt(task, snapshot, [] as ActionOffer[]);
      const pathsPrefix = 'allowedDataPaths=';
      const pathsStart = prompt.indexOf(pathsPrefix) + pathsPrefix.length;
      const pathsEnd = prompt.indexOf('\n', pathsStart);
      const snapshotPrefix = 'dataSnapshot=';
      const snapshotStart = prompt.indexOf(snapshotPrefix) + snapshotPrefix.length;
      const completeMarker = '\ndataSnapshotComplete=true';
      const snapshotEnd = prompt.indexOf(completeMarker, snapshotStart);
      const parsedPaths = JSON.parse(prompt.substring(pathsStart, pathsEnd)) as string[];
      const parsedSnapshot = JSON.parse(prompt.substring(snapshotStart, snapshotEnd)) as Object;

      expect(prompt.length).assertLess(24001);
      expect(pathsStart).assertLarger(pathsPrefix.length - 1);
      expect(parsedPaths.length).assertLarger(0);
      expect(snapshotEnd).assertLarger(snapshotStart);
      expect(parsedSnapshot === null).assertFalse();
      expect(prompt.endsWith('dataSnapshotComplete=true')).assertTrue();
    });

    it('sends only component identity and action index through ArkWeb', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain("bridge({type:'action',componentId:text(component.id),actionIndex:index})");
      expect(html.indexOf("bridge({type:'action',args:")).assertEqual(-1);
    });

    it('keeps compact capsule chrome and animates expandable content without max-height', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('grid-template-rows:auto minmax(0,1fr) auto; gap:0;');
      expect(html).assertContain('.lab-header { min-height:52px; margin-bottom:12px; border-radius:999px;');
      expect(html).assertContain('.composer { border-radius:999px; padding:6px 6px 6px 16px;');
      expect(html).assertContain('.send { width:40px; height:40px; flex:0 0 40px;');
      expect(html).assertContain('.status { min-height:24px; padding:4px 8px;');
      expect(html).assertContain('line-height:16px; display:flex; justify-content:space-between; align-items:center;');
      expect(html).assertContain('.status>span { min-height:16px; display:flex; align-items:center; }');
      expect(html.indexOf('grid-template-rows:auto minmax(0,1fr) auto; gap:12px;')).assertEqual(-1);
      expect(html).assertContain('.expandable-panel { display:grid; grid-template-rows:0fr; opacity:0; transform:translateY(-6px);');
      expect(html).assertContain('cubic-bezier(.22,1,.36,1)');
      expect(html).assertContain('.expandable-panel-inner { min-height:0; overflow:hidden;');
      expect(html.indexOf('.expandable-panel { max-height:')).assertEqual(-1);
    });

    it('clones and clears the in-memory model settings snapshot', 0, () => {
      clearUiLabModelSettings();
      const source = settings();
      configureUiLabModelSettings(source);
      source.model = 'mutated-source';
      source.apiKey = 'mutated-source-secret';
      const first = uiLabModelSettings();
      first.model = 'mutated';
      first.apiKey = 'mutated-secret';
      const second = uiLabModelSettings();
      expect(second.model).assertEqual('test-model');
      expect(second.apiKey).assertEqual('test-secret');

      clearUiLabModelSettings();
      const cleared = uiLabModelSettings();
      expect(cleared.model).assertEqual(defaultLocalModelSettings().model);
      expect(cleared.model === 'test-model').assertFalse();
    });
  });
}
