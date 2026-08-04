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
  const outputExample =
    `{"version":"${A2UI_VERSION}","updateComponents":{"surfaceId":"${surfaceId}","components":[` +
    '{"id":"root","component":"SurfaceRoot","child":"content"},' +
    '{"id":"content","component":"Column","children":["summary","project-list"]},' +
    '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
    '{"id":"project-list","component":"List","children":{"path":"/results/0/data/projects","componentId":"project-card"}},' +
    '{"id":"project-card","component":"ExpandableCard"}' +
    ']}}';
  return `You plan one constrained A2UI ${A2UI_VERSION} component layout for a mobile UI renderer.\n` +
    'Rules:\n' +
    '- Output exactly one compact JSON line. No markdown or explanation.\n' +
    `- The only envelope is updateComponents for surfaceId "${surfaceId}".\n` +
    '- Never output createSurface, updateDataModel, deleteSurface, provider facts, action IDs, or action args.\n' +
    '- The root component id must be "root" and all children must form one connected acyclic tree.\n' +
    '- Bind content only through dataPath values explicitly listed in the user task.\n' +
    '- Prefer the narrowest allowed path whose value shape matches the component. Never bind a whole result object ' +
    'when a relevant child array is available.\n' +
    '- For repeated array items, use the official A2UI v0.9 List shape ' +
    '{"children":{"path":"/allowed/array/path","componentId":"item-template"}}. The referenced template is one ' +
    'component rendered once per item; it may omit dataPath (or use "/") to read the current item scope. Do not ' +
    'replace this dynamic children object with a static children array.\n' +
    '- An action slot contains only {"offerId":"an offered id"}; never invent or alter an offer.\n' +
    '- Component names and properties are direct members of each component object. Use "component", never "type", ' +
    'and never place properties inside a nested "props" object.\n' +
    '- The following is a complete protocol-shape example only. Copy only its protocol shape; choose any added ' +
    'components, properties, and dataPath values strictly from the actual allowedDataPaths and component catalog ' +
    'in the current task:\n' +
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
