import http from '@ohos.net.http';
import { ChatMessage, ConversationContext } from '../agent/ConversationContext';
import { LlmProvider } from '../model/LlmProvider';
import { AIPHONE_COMPONENT_CATALOG_JSON } from '../aiphone/runtime/A2uiComponentCatalogConst';
import { aiLogInfoComplete } from '../aiphone/runtime/AiphoneLogger';
import { A2UI_VERSION } from './A2uiProtocol';
import { A2uiModel } from './A2uiModel';

interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
}

interface ChatChoice {
  message?: ChatMessage;
}

interface ChatResponse {
  choices?: ChatChoice[];
}

export function buildA2uiLayoutSystemPrompt(
  surfaceId: string,
  componentCatalogJson: string
): string {
  const isUiLabCatalog = componentCatalogJson.indexOf('"name":"HeroBanner"') >= 0;
  const outputExample = isUiLabCatalog ?
    `{"version":"${A2UI_VERSION}","updateComponents":{"surfaceId":"${surfaceId}","components":[` +
      '{"id":"root","component":"SurfaceRoot","child":"content"},' +
      '{"id":"content","component":"Column","children":["hero","info","result-list"]},' +
      '{"id":"hero","component":"HeroBanner",' +
      '"title":"REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS"},' +
      '{"id":"info","component":"InfoRows","dataPath":"/summary"},' +
      '{"id":"result-list","component":"List","children":' +
      '{"path":"/results","componentId":"result-card"}},' +
      '{"id":"result-card","component":"ExpandableCard"}' +
      ']}}' :
    `{"version":"${A2UI_VERSION}","updateComponents":{"surfaceId":"${surfaceId}","components":[` +
      '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
      '{"id":"summary","component":"Text","dataPath":"/summary/text"}' +
      ']}}';
  const uiLabRules = isUiLabCatalog ?
    '- For every normal non-error UI Lab result with displayable verified data, you MUST output exactly one ' +
      'HeroBanner. Do not fabricate a HeroBanner summary for an error or no-display-data baseline. HeroBanner is ' +
      'always the first visible element in the main content container. If any other visible component exists, ' +
      'SurfaceRoot.child must reference a Column and the HeroBanner id must be Column.children[0]. Never connect ' +
      'root only to HeroBanner while leaving sibling components disconnected. If HeroBanner is the only visible ' +
      'component, SurfaceRoot.child may reference it directly. HeroBanner requires title, uses text ' +
      'as its kicker and body as a natural synthesis of all verified results, and must not mechanically list toolId values.\n' +
      '- /summary/count and /summary/text describe how many DataResult sets were collected, never the total number ' +
      'of business entities. HeroBanner must not present either value as an entity total. Never infer a total from ' +
      'a sampled array length. A business count may appear only when result.data explicitly labels a scalar as count ' +
      'or total, or when result.data.summary text explicitly supports it.\n' +
      '- Choose chart fields only from each catalog schema. MetricGrid may use legacy dataPath or direct items; ' +
      'SegmentedRingChart may use legacy dataPath or direct segments. Other charts keep their declared legacy dataPath. ' +
      'Choose them from the meaning and shape of the data; output no SVG, path, points, rect, viewBox, coordinates, dimensions, arc ' +
      'geometry, stroke settings, or colors. The renderer owns all chart geometry and styling.\n' : '';
  const dataPathRules = isUiLabCatalog ?
    '- Derive every binding path only from the exact structure present in dataSnapshot in the user task. The host ' +
      'checks that each path exists in that sampled snapshot. Prefer the narrowest path whose value shape matches ' +
      'the component; never bind a whole result object when a relevant child value is available.\n' :
    '- Bind content only through exact paths explicitly listed in the user task. A listed parent path does not allow ' +
      'an unlisted descendant path. Prefer the narrowest allowed path whose value shape matches the component. Never ' +
      'bind a whole result object when a relevant child array is available.\n';
  return `You plan one constrained A2UI ${A2UI_VERSION} component layout for a mobile UI renderer.\n` +
    'Rules:\n' +
    '- Output exactly one compact JSON line. No markdown or explanation.\n' +
    `- The only envelope is updateComponents for surfaceId "${surfaceId}".\n` +
    '- Never output createSurface, updateDataModel, deleteSurface, provider facts, action IDs, or action args.\n' +
    '- The root component id must be "root" and all children must form one connected acyclic tree.\n' +
    dataPathRules +
    uiLabRules +
    '- For repeated array items, use the official A2UI v0.9 List shape ' +
    '{"children":{"path":"/allowed/array/path","componentId":"item-template"}}. The referenced template is one ' +
    'component rendered once per item. For repeated entity results, use List with one ExpandableCard template so ' +
    'each result gets its own card. The template may omit dataPath (or use "/") to read the current item scope. Do not ' +
    'replace this dynamic children object with a static children array.\n' +
    '- An action slot contains only {"offerId":"an offered id"}; never invent or alter an offer.\n' +
    '- The catalog schema is the only field and value-policy authority. Output only fields declared for that component. ' +
    'For valuePolicy "literal-or-path", output either a literal of the declared type or exactly {"path":"/an/exact/path"}. ' +
    'Never output a data path string as literal visible content. ' +
    'For "path-only", output only that exact one-key binding object: never output a numeric literal, numeric string, ' +
    'expression, FunctionCall, or binding with extra keys. For literal arrays and objects, follow their nested fields recursively.\n' +
    '- Component names and properties are direct members of each component object. Use "component", never "type", ' +
    'and never place properties inside a nested "props" or "properties" object.\n' +
    '- The following is a complete protocol-shape example only. In the UI Lab example, /summary and /results are ' +
    'stable protocol-level snapshot paths, not assumptions about a business schema. Copy only its protocol shape; choose any added ' +
    'components, properties, and dataPath values strictly from the actual dataSnapshot and component catalog ' +
    'in the current task. Every HeroBanner visible string must be rewritten from the current verified results; ' +
    'never copy the REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS placeholder into output:\n' +
    outputExample + '\n' +
    '- Keep at most 24 components. Use only this catalog:\n' +
    componentCatalogJson;
}

export class OpenAiA2uiModel implements A2uiModel {
  private provider: LlmProvider;
  private componentCatalogJson: string;

  constructor(provider: LlmProvider, componentCatalogJson: string = AIPHONE_COMPONENT_CATALOG_JSON) {
    this.provider = provider;
    this.componentCatalogJson = componentCatalogJson;
  }

  async generate(userTask: string, surfaceId: string, conversation?: ConversationContext): Promise<string> {
    if (!this.provider.isConfigured()) {
      throw new Error('LLM provider is not configured.');
    }

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(this.provider.chatCompletionsUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.provider.apiKey}`,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify(this.buildRequest(userTask, surfaceId, conversation)),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 120000
      });

      const statusCode = response.responseCode;
      const body = `${response.result ?? ''}`;
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`LLM request failed with HTTP ${statusCode}: ${body}`);
      }

      const content = this.parseContent(body);
      aiLogInfoComplete('[A2uiLayoutRaw] surface=' + surfaceId, content);
      return content.trim();
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      throw new Error(`A2UI LLM request failed: ${message}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private buildRequest(userTask: string, surfaceId: string, conversation?: ConversationContext): ChatRequest {
    const systemPrompt = buildA2uiLayoutSystemPrompt(surfaceId, this.componentCatalogJson);

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt }
    ];

    if (conversation !== undefined) {
      const history = conversation.toChatMessages();
      for (const turn of history) {
        messages.push(turn);
      }
    }

    messages.push({
      role: 'user',
      content: userTask
    });

    return {
      model: this.provider.model,
      messages,
      temperature: 0.2
    };
  }

  private parseContent(body: string): string {
    const json = JSON.parse(body) as ChatResponse;
    const choices = json.choices;
    if (choices === undefined || choices.length === 0) {
      throw new Error('No choices returned.');
    }

    const message = choices[0].message;
    if (message === undefined || message.content === undefined) {
      throw new Error('No message content returned.');
    }
    return message.content;
  }
}
