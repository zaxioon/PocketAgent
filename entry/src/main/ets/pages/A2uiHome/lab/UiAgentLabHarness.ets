import {
  ActionOffer,
  A2uiAction,
  A2uiAgentRunner,
  A2uiComponent,
  A2uiSurfaceState,
  CreateUiTaskPayload,
  DataResult,
  LlmProvider,
  LocalModelSettings,
  OpenAiA2uiModel,
  OpenAiCompatibleModel,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON,
  UiLayoutPlanner,
  UiRenderResult,
  UiTaskRenderer,
  UserInputPayload,
  mergeA2uiLayout,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { MultiAgentCanaryRuntime, MultiAgentCanaryOptions } from '../agent/MultiAgentCanaryRuntime';
import { SystemUriOpener } from '../agent/AiphoneRegisteredActionExecutor';
import { HtmlHomeAction, HtmlHomeBlock, HtmlHomeDocument } from '../html/HtmlHomeTypes';

const UI_LAB_LAYOUT_TIMEOUT_MS: number = 60000;
const UI_LAB_SNAPSHOT_LIMIT: number = 12000;
const UI_LAB_PATH_LIMIT: number = 96;

type UiLabJsonValue = Object | string | number | boolean | null | undefined;
export type UiLabRecord = Record<string, UiLabJsonValue>;

interface UiLabFact {
  label: string;
  value: string;
}

interface UiLabResultSnapshot {
  dataTaskId: string;
  toolId: string;
  outputSchema: string;
  status: string;
  warnings: string[];
  facts: UiLabFact[];
  data: Object;
}

interface UiLabSummary {
  text: string;
  toolName: string;
  dataLabel: string;
  count: number;
}

interface UiLabSnapshot {
  summary: UiLabSummary;
  results: UiLabResultSnapshot[];
}

interface UiLabPathValue {
  path: string;
  value: UiLabJsonValue;
}

interface UiLabUpdateComponents {
  surfaceId: string;
  components: A2uiComponent[];
}

interface UiLabEnvelope {
  updateComponents?: UiLabUpdateComponents;
}

interface UiLabCreateSurface {
  surfaceId: string;
  root: string;
  title: string;
  intent: string;
  status: string;
  sendDataModel: boolean;
}

interface UiLabCreateEnvelope {
  version: string;
  createSurface: UiLabCreateSurface;
}

interface UiLabComponentsEnvelope {
  version: string;
  updateComponents: UiLabUpdateComponents;
}

interface UiLabUpdateDataModel {
  surfaceId: string;
  path: string;
  value: UiLabJsonValue;
}

interface UiLabDataEnvelope {
  version: string;
  updateDataModel: UiLabUpdateDataModel;
}

interface UiLabOmittedData {
  omittedDueToPromptBudget: boolean;
}

interface UiLabPromptOffer {
  offerId: string;
  label: string;
  variant: string;
}

export interface UiAgentLabSurfaceEvent {
  turnId: string;
  surface: A2uiSurfaceState;
}

export interface UiAgentLabSubmitOutcome {
  ok: boolean;
  status: string;
  message: string;
}

export type UiAgentLabSurfaceListener = (event: UiAgentLabSurfaceEvent) => void;

class RejectUiLabUriOpener implements SystemUriOpener {
  async open(_uri: string): Promise<boolean> {
    return false;
  }
}

function cloneSurface(surface: A2uiSurfaceState): A2uiSurfaceState {
  return JSON.parse(JSON.stringify(surface)) as A2uiSurfaceState;
}

function currentLocalDate(): string {
  const now = new Date();
  const month = (now.getMonth() + 1).toString().padStart(2, '0');
  const day = now.getDate().toString().padStart(2, '0');
  return now.getFullYear().toString() + '-' + month + '-' + day;
}

function recordOf(value: UiLabJsonValue): UiLabRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as UiLabRecord;
}

function scalarText(value: UiLabJsonValue): string {
  if (typeof value === 'string') return value.substring(0, 240);
  if (typeof value === 'number' || typeof value === 'boolean') return value.toString();
  return '';
}

function factsOf(data: Object): UiLabFact[] {
  const source = recordOf(data);
  const facts: UiLabFact[] = [];
  if (source === null) return facts;
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length && facts.length < 16; index++) {
    const value = scalarText(source[keys[index]]);
    if (value.length > 0) facts.push({ label: keys[index], value });
  }
  return facts;
}

function sampled(value: UiLabJsonValue, depth: number = 0): UiLabJsonValue {
  if (typeof value === 'string') return value.substring(0, 1200);
  if (value === null || value === undefined || typeof value === 'number' || typeof value === 'boolean') return value;
  if (depth >= 5) return '[bounded]';
  if (Array.isArray(value)) {
    const source = value as UiLabJsonValue[];
    const result: UiLabJsonValue[] = [];
    for (let index = 0; index < source.length && index < 8; index++) result.push(sampled(source[index], depth + 1));
    return result as Object;
  }
  const source = value as UiLabRecord;
  const result: UiLabRecord = {};
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length && index < 40; index++) {
    result[keys[index]] = sampled(source[keys[index]], depth + 1);
  }
  return result as Object;
}

export function buildUiAgentLabSnapshot(task: CreateUiTaskPayload, data: DataResult[]): UiLabSnapshot {
  const results: UiLabResultSnapshot[] = [];
  for (let index = 0; index < data.length; index++) {
    results.push({
      dataTaskId: index < task.dataTaskIds.length ? task.dataTaskIds[index] : 'data-' + index.toString(),
      toolId: data[index].toolId,
      outputSchema: data[index].outputSchema,
      status: data[index].status,
      warnings: data[index].warnings.slice(0, 8),
      facts: factsOf(data[index].data),
      data: sampled(data[index].data) as Object
    });
  }
  let snapshot: UiLabSnapshot = {
    summary: {
      text: '已获取 ' + data.length.toString() + ' 项真实结果。',
      toolName: data.length === 1 ? data[0].toolId : 'multi-agent',
      dataLabel: 'uiLab',
      count: data.length
    },
    results
  };
  if (JSON.stringify(snapshot).length > UI_LAB_SNAPSHOT_LIMIT) {
    snapshot = {
      summary: snapshot.summary,
      results: results.map((item: UiLabResultSnapshot): UiLabResultSnapshot => {
        const omitted: UiLabOmittedData = { omittedDueToPromptBudget: true };
        return {
          dataTaskId: item.dataTaskId,
          toolId: item.toolId,
          outputSchema: item.outputSchema,
          status: item.status,
          warnings: item.warnings,
          facts: item.facts,
          data: omitted
        };
      })
    };
  }
  return snapshot;
}

function pointerToken(value: string): string {
  return value.split('~').join('~0').split('/').join('~1');
}

function collectPaths(value: UiLabJsonValue, path: string, output: UiLabPathValue[]): void {
  if (output.length >= UI_LAB_PATH_LIMIT) return;
  output.push({ path, value });
  if (value === null || value === undefined || typeof value !== 'object') return;
  if (Array.isArray(value)) {
    const values = value as UiLabJsonValue[];
    for (let index = 0; index < values.length && output.length < UI_LAB_PATH_LIMIT; index++) {
      collectPaths(values[index], path + '/' + index.toString(), output);
    }
    return;
  }
  const source = value as UiLabRecord;
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length && output.length < UI_LAB_PATH_LIMIT; index++) {
    collectPaths(source[keys[index]], path + '/' + pointerToken(keys[index]), output);
  }
}

export function uiAgentLabDataPaths(snapshot: UiLabSnapshot): string[] {
  const values: UiLabPathValue[] = [];
  collectPaths(snapshot.summary as Object, '/summary', values);
  collectPaths(snapshot.results as Object, '/results', values);
  return values.map((value: UiLabPathValue): string => value.path);
}

function envelopeLine(value: Object): string {
  return JSON.stringify(value) + '\n';
}

function surfaceShell(surfaceId: string, status: string, components: A2uiComponent[]): string {
  const createBody: UiLabCreateSurface = {
    surfaceId,
    root: 'root',
    title: 'UI Agent Lab',
    intent: 'ui_lab',
    status,
    sendDataModel: true
  };
  const create: UiLabCreateEnvelope = {
    version: 'v0.9.1',
    createSurface: createBody
  };
  const updateBody: UiLabUpdateComponents = { surfaceId, components };
  const update: UiLabComponentsEnvelope = { version: 'v0.9.1', updateComponents: updateBody };
  return envelopeLine(create) + envelopeLine(update);
}

function dataLines(surfaceId: string, snapshot: UiLabSnapshot): string {
  const values: UiLabPathValue[] = [];
  collectPaths(snapshot.summary as Object, '/summary', values);
  collectPaths(snapshot.results as Object, '/results', values);
  let jsonl = '';
  for (let index = 0; index < values.length; index++) {
    const update: UiLabUpdateDataModel = {
      surfaceId,
      path: values[index].path,
      value: values[index].value
    };
    const envelope: UiLabDataEnvelope = {
      version: 'v0.9.1',
      updateDataModel: update
    };
    jsonl += envelopeLine(envelope);
  }
  return jsonl;
}

function offerSourceToolId(offer: ActionOffer, data: DataResult[]): string {
  let matched = '';
  for (let index = 0; index < data.length; index++) {
    const definition = toolDefinitionForToolId(data[index].toolId);
    if (definition === null || definition.actions.indexOf(offer.actionId) < 0) continue;
    if (matched.length > 0 && matched !== data[index].toolId) return '';
    matched = data[index].toolId;
  }
  if (matched.length === 0 && data.length === 1) return data[0].toolId;
  return matched;
}

function actionOf(offer: ActionOffer, sourceToolId: string): A2uiAction {
  const action: A2uiAction = {
    id: offer.actionId,
    label: offer.label,
    prompt: offer.label,
    variant: offer.variant,
    kind: 'prompt',
    args: JSON.parse(JSON.stringify(offer.args)) as Object
  };
  if (sourceToolId.length > 0) action.sourceSectionId = sourceToolId;
  return action;
}

function baselineComponents(data: DataResult[], offers: ActionOffer[]): A2uiComponent[] {
  const children: string[] = ['summary'];
  const components: A2uiComponent[] = [
    { id: 'root', component: 'SurfaceRoot', child: 'content', title: 'UI Agent Lab', status: 'ready' },
    { id: 'content', component: 'Column', children },
    { id: 'summary', component: 'Text', dataPath: '/summary/text' }
  ];
  for (let index = 0; index < data.length; index++) {
    const id = 'result-' + index.toString();
    children.push(id);
    components.push({ id, component: 'InfoRows', title: data[index].toolId, dataPath: '/results/' + index.toString() + '/facts' });
  }
  if (offers.length > 0) {
    const actions: A2uiAction[] = [];
    for (let index = 0; index < offers.length; index++) {
      actions.push(actionOf(offers[index], offerSourceToolId(offers[index], data)));
    }
    children.push('actions');
    components.push({ id: 'actions', component: 'ActionBar', actions });
  }
  return components;
}

function annotateActionSources(jsonl: string, data: DataResult[], offers: ActionOffer[]): string {
  const sourceByAction: Map<string, string> = new Map<string, string>();
  for (let index = 0; index < offers.length; index++) {
    const source = offerSourceToolId(offers[index], data);
    const key = offers[index].actionId + '\n' + JSON.stringify(offers[index].args);
    if (source.length > 0) sourceByAction.set(key, source);
  }
  const lines = jsonl.trim().split(/\r?\n/);
  const output: string[] = [];
  for (let index = 0; index < lines.length; index++) {
    const envelope = JSON.parse(lines[index]) as UiLabEnvelope;
    const components = envelope.updateComponents?.components;
    if (components !== undefined) {
      for (let componentIndex = 0; componentIndex < components.length; componentIndex++) {
        const actions = components[componentIndex].actions;
        if (actions === undefined) continue;
        for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
          if (actions[actionIndex].args === undefined) continue;
          const key = actions[actionIndex].id + '\n' + JSON.stringify(actions[actionIndex].args);
          const source = sourceByAction.get(key);
          if (source !== undefined) actions[actionIndex].sourceSectionId = source;
        }
      }
    }
    output.push(JSON.stringify(envelope));
  }
  return output.join('\n') + '\n';
}

export function uiAgentLabLayoutPrompt(
  task: CreateUiTaskPayload,
  snapshot: UiLabSnapshot,
  offers: ActionOffer[]
): string {
  const promptOffers: UiLabPromptOffer[] = offers.slice(0, 24).map(
    (offer: ActionOffer): UiLabPromptOffer => {
      return { offerId: offer.offerId, label: offer.label, variant: offer.variant };
    }
  );
  return ('Lay out a useful mobile UI from all verified DataResult values.\n' +
    'Choose presentation by the meaning and shape of the actual values. Do not assume a business schema and do not prescribe a chart type.\n' +
    'Use only the UI Lab component catalog.\n' +
    'Use only exact allowedDataPaths. Actions may contain only an offered offerId; never output action arguments.\n' +
    'intent=' + JSON.stringify(task.intent) + '\n' +
    'allowedDataPaths=' + JSON.stringify(uiAgentLabDataPaths(snapshot)) + '\n' +
    'verifiedOffers=' + JSON.stringify(promptOffers) + '\n' +
    'dataSnapshot=' + JSON.stringify(snapshot)).substring(0, 24000);
}

class UiAgentLabRenderer implements UiTaskRenderer {
  private readonly planner: UiLayoutPlanner;

  constructor(planner: UiLayoutPlanner) {
    this.planner = planner;
  }

  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const rendered: UiRenderResult = {
      jsonl: surfaceShell(surfaceId, 'calling_tool', [
        { id: 'root', component: 'SurfaceRoot', child: 'thinking', status: 'calling_tool' },
        { id: 'thinking', component: 'ThinkingCard', title: '正在获取真实数据', body: task.intent, status: 'calling_tool' }
      ])
    };
    return Promise.resolve(rendered);
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult> {
    const snapshot = buildUiAgentLabSnapshot(task, data);
    const baseline = surfaceShell(surfaceId, 'ready', baselineComponents(data, offers)) + dataLines(surfaceId, snapshot);
    let timerId: number = -1;
    const timeout = new Promise<string | null>((resolve: (value: string | null) => void): void => {
      timerId = setTimeout((): void => resolve(null), UI_LAB_LAYOUT_TIMEOUT_MS);
    });
    try {
      const candidate = await Promise.race<string | null>([
        this.planner.plan(uiAgentLabLayoutPrompt(task, snapshot, offers), surfaceId),
        timeout
      ]);
      if (candidate === null) return { jsonl: baseline };
      return {
        jsonl: annotateActionSources(
          mergeA2uiLayout(baseline, candidate, surfaceId, offers, UI_AGENT_LAB_COMPONENT_CATALOG_JSON),
          data,
          offers
        )
      };
    } finally {
      if (timerId >= 0) clearTimeout(timerId);
    }
  }

  error(_task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult> {
    const rendered: UiRenderResult = {
      jsonl: surfaceShell(surfaceId, 'error', [
        { id: 'root', component: 'SurfaceRoot', child: 'error', status: 'error' },
        { id: 'error', component: 'ErrorNotice', title: '请求未完成', body: message.substring(0, 300), status: 'error' }
      ])
    };
    return Promise.resolve(rendered);
  }

  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const source = payload as UiLabRecord;
    const message = typeof source['message'] === 'string' ? source['message'] as string :
      (typeof source['status'] === 'string' ? '操作状态：' + source['status'] as string : '操作状态已更新。');
    const summary: UiLabSummary = {
      text: message.substring(0, 300),
      toolName: typeof source['actionId'] === 'string' ? source['actionId'] as string : 'action',
      dataLabel: 'actionStatus',
      count: 0
    };
    const update: UiLabUpdateDataModel = { surfaceId, path: '/summary', value: summary as Object };
    const envelope: UiLabDataEnvelope = { version: 'v0.9.1', updateDataModel: update };
    const rendered: UiRenderResult = { jsonl: envelopeLine(envelope) };
    return Promise.resolve(rendered);
  }
}

function actionFrom(component: A2uiComponent, action: A2uiAction): HtmlHomeAction {
  const projected: HtmlHomeAction = {
    id: action.id,
    label: action.label,
    prompt: action.prompt,
    variant: action.variant,
    kind: action.kind,
    sourceComponentId: component.id
  };
  if (action.args !== undefined) projected.args = action.args;
  if (action.sourceSectionId !== undefined) projected.sourceToolId = action.sourceSectionId;
  return projected;
}

export function projectUiAgentLabSurface(surface: A2uiSurfaceState): HtmlHomeDocument {
  const actions: HtmlHomeAction[] = [];
  for (let index = 0; index < surface.components.length; index++) {
    const values = surface.components[index].actions;
    if (values === undefined) continue;
    for (let actionIndex = 0; actionIndex < values.length; actionIndex++) {
      actions.push(actionFrom(surface.components[index], values[actionIndex]));
    }
  }
  const blocks: HtmlHomeBlock[] = [];
  return {
    version: 1,
    surfaceId: surface.surfaceId,
    source: 'model',
    kind: 'generic',
    title: surface.title,
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks,
    actions,
    history: [],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: new Date().toISOString()
  };
}

export class UiAgentLabHarness {
  private readonly runtime: MultiAgentCanaryRuntime;
  private active: boolean = true;
  private generation: number = 0;
  private currentSurface: A2uiSurfaceState | null = null;

  constructor(settings: LocalModelSettings, listener: UiAgentLabSurfaceListener) {
    const provider = new LlmProvider(
      settings.provider,
      settings.apiKey,
      settings.baseUrl,
      settings.model,
      settings.customParametersJson
    );
    const planner = new A2uiAgentRunner(
      new OpenAiA2uiModel(provider, UI_AGENT_LAB_COMPONENT_CATALOG_JSON)
    );
    const options: MultiAgentCanaryOptions = {
      model: new OpenAiCompatibleModel(provider),
      opener: new RejectUiLabUriOpener(),
      uiRenderer: new UiAgentLabRenderer(planner),
      surfaceDocumentProjector: projectUiAgentLabSurface,
      currentHostSurface: (): A2uiSurfaceState | null =>
        this.currentSurface === null ? null : cloneSurface(this.currentSurface),
      currentHostGeneration: (): number => this.generation,
      currentLocalDate,
      onSurface: (surface: A2uiSurfaceState, generation: number): boolean => {
        if (!this.active || generation !== this.generation) return false;
        this.currentSurface = cloneSurface(surface);
        listener({ turnId: 'ui-agent-lab-' + generation.toString(), surface: cloneSurface(surface) });
        return true;
      },
      onMemoryUpdate: (): void => {},
      submitTimeoutMs: 120000,
      actionTimeoutMs: 45000,
      settingsFingerprint: 'ui-lab|' + settings.provider + '|' + settings.baseUrl + '|' + settings.model
    };
    this.runtime = new MultiAgentCanaryRuntime(options);
  }

  async submit(prompt: string): Promise<UiAgentLabSubmitOutcome> {
    const bounded = prompt.trim().substring(0, 4000);
    if (!this.active || bounded.length === 0) {
      return { ok: false, status: 'canceled', message: 'UI Lab runtime 不可用。' };
    }
    this.runtime.cancelActiveTurn('superseded');
    this.generation++;
    const generation = this.generation;
    const input: UserInputPayload = { text: bounded, recentMessages: [] };
    const outcome = await this.runtime.submit(bounded, input, generation);
    return { ok: outcome.ok, status: outcome.status, message: outcome.message };
  }

  async runAction(action: A2uiAction): Promise<boolean> {
    if (!this.active || action.args === undefined) return false;
    const context = this.runtime.currentActionContext(action);
    if (context === null) return false;
    return await this.runtime.runAction(action, context);
  }

  cancel(reason: string): void {
    if (this.active) this.runtime.cancelActiveTurn(reason);
  }

  stop(): void {
    if (!this.active) return;
    this.active = false;
    this.generation++;
    this.runtime.cancelActiveTurn('ui-lab-disposed');
    this.runtime.dispose();
    this.currentSurface = null;
  }
}
