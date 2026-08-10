import { describe, it, expect } from '@ohos/hypium';
import {
  ActionOffer,
  CreateUiTaskPayload,
  DataResult,
  LocalModelSettings,
  defaultLocalModelSettings
} from '@loop/agent-core';
import {
  createUiAgentLabHtmlShell,
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
  uiAgentLabDataPaths,
  uiAgentLabLayoutPrompt,
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabHarness';

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
        'MasonryGrid'
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
      expect(prompt.indexOf('mock.travel')).assertEqual(-1);
      expect(uiAgentLabDataPaths(snapshot).indexOf('/results/0/data/count') >= 0).assertTrue();
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
