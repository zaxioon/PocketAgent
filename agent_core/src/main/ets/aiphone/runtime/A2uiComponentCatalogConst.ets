export const AIPHONE_COMPONENT_CATALOG_JSON: string =
  '[' +
    '{"name":"SurfaceRoot","role":"布局组件","usage":"surface 根节点，通过 child 或 children 指向真实存在的组件 id"},' +
    '{"name":"Column","role":"布局组件","usage":"纵向容器，通过 children 排列真实存在的子组件 id"},' +
    '{"name":"Row","role":"布局组件","usage":"横向容器，通过 children 排列真实存在的子组件 id，不要把按钮文案或数据值直接写进 children"},' +
    '{"name":"Text","role":"内容组件","usage":"展示简短文本说明，使用 text 或 body 承载内容"},' +
    '{"name":"InfoRows","role":"内容组件","usage":"展示 label/value 信息行，使用 dataPath 绑定 rows 数据"},' +
    '{"name":"ActionBar","role":"交互组件","usage":"展示一组可点击操作，按钮必须写入 actions，不要使用 children"},' +
    '{"name":"ErrorNotice","role":"内容组件","usage":"展示错误、限制或无法执行的提示"},' +
    '{"name":"ThinkingStream","role":"状态组件","usage":"展示工具调用或处理中状态，通常绑定 /thoughts"},' +
    '{"name":"ThinkingCard","role":"状态组件","usage":"展示处理中摘要卡片，通常由客户端状态补齐"},' +
    '{"name":"TravelOptions","role":"业务组件","usage":"展示工具返回的综合出行方案，只能绑定 /travelOptions"},' +
    '{"name":"TrainOptions","role":"业务组件","usage":"展示工具返回的车次结果，只能绑定 /trains"},' +
    '{"name":"FlightBoard","role":"业务组件","usage":"展示工具返回的航班结果，只能绑定 /flights"},' +
    '{"name":"FoodChoices","role":"业务组件","usage":"展示工具返回的餐饮结果，只能绑定 /foods"},' +
    '{"name":"SocialHub","role":"业务组件","usage":"展示社交聚合数据，只能绑定 /socialHub/items、/socialHub/selected、/socialHub/draft 或 /socialHub/connections"},' +
    '{"name":"StripeReceivingAccountCard","role":"支付组件","usage":"展示当前 agent 的 Stripe Connect 收款账户创建、认证和收款状态，只能绑定 /stripeReceivingAccount"},' +
    '{"name":"ToolConnectCard","role":"动态工具接入组件","usage":"展示远程 MCP/API 工具接入状态、认证字段、来源和测试/启用操作，只能绑定 /dynamicToolConnect"},' +
    '{"name":"GenericToolResults","role":"动态工具结果组件","usage":"展示通用 MCP tools/call 真实返回摘要，只能绑定 /genericToolResults"},' +
    '{"name":"ConfirmPanel","role":"兼容占位组件","usage":"当前 renderer 不展示，模型不要主动生成"}' +
  ']';

const UI_AGENT_LAB_COMPONENT_CATALOG_BASE_JSON: string =
  '[' +
    '{"name":"SurfaceRoot","role":"布局组件","usage":"UI Lab surface 唯一根节点，必须通过 child 或 children 指向真实存在的组件 id；renderer 不得内置设计稿文案；不绑定 dataPath，不承载 actions"},' +
    '{"name":"Column","role":"布局组件","usage":"纵向容器，只通过 children 排列真实存在的子组件 id；children 不得包含文本、数据值或 action，renderer 不得生成任何内置可见文案"},' +
    '{"name":"Row","role":"布局组件","usage":"横向容器，只通过 children 排列真实存在的子组件 id；children 不得包含文本、数据值或 action，renderer 不得生成任何内置可见文案"},' +
    '{"name":"Text","role":"内容组件","usage":"展示简短标题或说明；全部可见文案必须由 direct text、body、title fields 或 legacy dataPath 动态提供，renderer 不得内置设计稿文案；不使用 children 或 actions"},' +
    '{"name":"InfoRows","role":"内容组件","usage":"展示 presentation-ready 信息行；必须用 legacy dataPath 绑定 Array<{label,value,time?}>，全部可见 label、value 和可选 time 均由该数组动态提供；存在这种已清洗 rows 时优先于 List 或 ExpandableCard；title 只能由 direct title field 提供；不使用 children"},' +
    '{"name":"ActionBar","role":"交互组件","usage":"展示一组操作，按钮及其可见 label 只能来自 actions 中已提供的 offerId，renderer 不得内置操作文案；不使用 child、children 或 dataPath"},' +
    '{"name":"ErrorNotice","role":"状态组件","usage":"展示需要阅读、重试或修改输入的错误；全部可见标题和正文必须由 direct title、body fields 或 legacy dataPath 动态提供，可选 actions 必须引用已提供的 offerId"},' +
    '{"name":"ThinkingStream","role":"状态组件","usage":"展示渐进事件列表，全部可见内容必须用 legacy dataPath 绑定 Array<{id,title,detail,status}> 动态提供；可见 title 只能由 direct title field 提供，不使用 children 或 actions"},' +
    '{"name":"ThinkingCard","role":"状态组件","usage":"展示结构生成中的摘要、进度与事件；全部可见内容必须由 direct title、body、status fields 或 legacy dataPath 绑定 {label,progress,events} 动态提供；不承载业务 actions"},' +
    '{"name":"ScheduleStack","role":"复合内容组件","usage":"展示多日或多段日程卡，全部可见日期、标题、条目和指标必须用 dataPath 绑定 Array<{id,label,title,entries,metric?,tone?}> 动态提供；renderer 不得内置行程文案，不使用 children"},' +
    '{"name":"SkeletonCard","role":"局部加载组件","usage":"仅在最终布局已经确定且局部数据未返回时使用，status 必须为 loading；如有可见标题只能由 direct title field 提供；不使用 children、dataPath 或 actions"},' +
    '{"name":"ExpandableCard","role":"复合交互组件","usage":"仅在一条数据除摘要外还有值得展开的额外详情，或需要承载已提供的 action 时使用；作为 List 的 item 模板时可省略 dataPath（或使用 /）以读取当前 item scope；summary 或 description 已足够时改用只绑定该字段的 compact Text；不得绑定整个 provider object 来暴露原始字段；最多一个已提供的 action，renderer 不得内置业务文案，不使用 children"},' +
    '{"name":"MediaSlider","role":"复合媒体组件","usage":"展示可横向滑动的图片或视频卡组，全部可见标题和媒体描述必须用 dataPath 绑定 Array<{id,kind,title,assetKey,posterAssetKey?,alt}> 动态提供；媒体只能引用预登记 assetKey，actions 必须引用已提供的 offerId，renderer 不得内置文案，不使用 children"},' +
    '{"name":"SceneTabs","role":"复合导航组件","usage":"展示同一主题下的场景分页，全部可见 tab 标签、标题、正文和指标必须用 dataPath 绑定 Array<{id,icon,label,title,body,metrics}> 动态提供；tab 切换由客户端处理，renderer 不得内置场景文案，不使用 children 或 actions"},' +
    '{"name":"MasonryGrid","role":"复合布局组件","usage":"展示固定双列不等高信息卡，全部可见标题和正文必须用 dataPath 绑定 Array<{id,title,body,tone,height}> 动态提供；tone 仅允许 blue、peach、mint，height 仅允许 regular、tall，renderer 不得内置文案，不使用 children 或 actions"},' +
    '{"name":"List","role":"动态布局组件","usage":"对数组逐项重复一个模板组件；必须使用 A2UI v0.9 官方 children 对象 {path:ARRAY_PATH,componentId:TEMPLATE_ID}，其中 path 是允许的最窄数组路径，componentId 是真实模板组件 id；不得改写为静态 children 数组或自行添加 dataPath/child；模板组件从当前 item scope 取值并选择能表达数据的最简单组件；summary 或 description 足够时使用只绑定该字段的 compact Text，只有额外详情或已提供 action 时才使用 ExpandableCard；最多渲染有限项，不承载 actions 或可见业务文案"},' +
    '{"name":"HeroBanner","role":"首屏概览组件","usage":"UI Lab 的正常、非错误且有可展示真实数据的布局必须且只能生成一个 HeroBanner；错误或无可展示数据的 baseline 不得强造 HeroBanner 概述；HeroBanner 必须是主内容容器中的第一个可见元素；若还有其他可见组件，SurfaceRoot.child 必须指向 Column，HeroBanner 的 id 必须是 Column.children[0]，不得让 root 只连接 HeroBanner 而留下孤立组件；若 HeroBanner 是唯一可见组件，SurfaceRoot.child 可直接指向它；UI Agent 直接用 text 提供 kicker、title 提供必填主标题、body 自然概括全部已验证结果；不得绑定 dataPath，不得包含 actions、child、children 或 path；/summary/count 与 /summary/text 只表示 DataResult 结果集数量，绝不能当业务实体总数；不得把采样数组长度当总数、机械罗列 toolId，业务数量只能来自 result.data 中明确标注的 count/total scalar 或 result.data.summary 文字"},' +
    '{"name":"MetricGrid","role":"通用指标图表","usage":"兼容 legacy dataPath，也可使用 direct items 数组；items 的 label/unit/deltaLabel 遵循 catalog literal-or-path，业务 value/delta 严格 path-only；不承载 actions、child、children 或图形几何"},' +
    '{"name":"SegmentedRingChart","role":"通用占比图表","usage":"当数据包含已验证的占比、ratio 或类别构成信息时可以使用；兼容 legacy dataPath，也可使用 direct segments 数组；segments 的 label 遵循 catalog literal-or-path，业务 value 严格 path-only；不承载 actions、child、children 或图形几何"},' +
    '{"name":"MultiSeriesLineChart","role":"通用趋势图表","usage":"必须用 dataPath 绑定 {xLabels:string[]|labels:string[],series:Array<{id?,label,values:number[]}>,unitLabel?}；每条 values 必须与标签等长；text/title/body 可动态提供 kicker、标题和说明；renderer 负责缩放、折线、标记、坐标轴、图例与配色，UI Agent 不得输出 SVG、path、points、坐标或颜色；不承载 actions、child 或 children"},' +
    '{"name":"MatrixHeatmap","role":"通用矩阵热力图","usage":"必须用 dataPath 绑定 {columnLabels:string[]|weekLabels:string[],rowLabels:string[]|dayLabels:string[],values:number[][]|weeks:number[][],unitLabel?}；矩阵维度必须与标签一致；text/title/body 可动态提供 kicker、标题和说明；renderer 保证等宽等高方格并计算灰蓝色阶、提示和可访问标签，UI Agent 不得输出 SVG、path、rect、坐标、尺寸或颜色；不承载 actions、child 或 children"}' +
  ']';

const LAB_ID_COMPONENT_FIELDS: string =
  '"id":{"type":"string","valuePolicy":"literal","required":true,"minLength":1},' +
  '"component":{"type":"string","valuePolicy":"literal","required":true,"minLength":1}';
const LAB_LITERAL_STRING: string = '{"type":"string","valuePolicy":"literal"}';
const LAB_LITERAL_OR_PATH_STRING: string = '{"type":"string","valuePolicy":"literal-or-path"}';
const LAB_DATA_PATH: string = '{"type":"string","valuePolicy":"legacy-data-path"}';
const LAB_CHILD: string = '"child":' + LAB_LITERAL_STRING;
const LAB_CHILDREN: string = '"children":{"type":"array","valuePolicy":"literal","items":' +
  LAB_LITERAL_STRING + '}';
const LAB_TEXT_FIELDS: string =
  '"text":' + LAB_LITERAL_OR_PATH_STRING + ',"title":' + LAB_LITERAL_OR_PATH_STRING +
  ',"body":' + LAB_LITERAL_OR_PATH_STRING;
const LAB_DATA_PATH_FIELD: string = '"dataPath":' + LAB_DATA_PATH;
const LAB_ACTIONS_FIELD: string =
  '"actions":{"type":"array","valuePolicy":"literal","items":{"type":"object",' +
  '"valuePolicy":"literal","fields":{"offerId":{"type":"string","valuePolicy":"literal",' +
  '"required":true,"minLength":1}}}}';

function labSchema(fields: string, requireAnyJson: string = '', exactlyOneJson: string = ''): string {
  const requireAny = requireAnyJson.length > 0 ? ',"requireAny":' + requireAnyJson : '';
  const exactlyOne = exactlyOneJson.length > 0 ? ',"exactlyOne":' + exactlyOneJson : '';
  return '{"fields":{' + LAB_ID_COMPONENT_FIELDS + (fields.length > 0 ? ',' + fields : '') + '}' +
    requireAny + exactlyOne + '}';
}

const LAB_METRIC_ITEMS_FIELD: string =
  '"items":{"type":"array","valuePolicy":"literal","minItems":1,"maxItems":6,' +
  '"items":{"type":"object","valuePolicy":"literal","fields":{' +
  '"id":' + LAB_LITERAL_STRING + ',' +
  '"label":{"type":"string","valuePolicy":"literal-or-path","required":true},' +
  '"value":{"type":"number","valuePolicy":"path-only","required":true},' +
  '"unit":' + LAB_LITERAL_OR_PATH_STRING + ',' +
  '"delta":{"type":"number","valuePolicy":"path-only"},' +
  '"deltaLabel":' + LAB_LITERAL_OR_PATH_STRING + '}}}';
const LAB_RING_SEGMENTS_FIELD: string =
  '"segments":{"type":"array","valuePolicy":"literal","minItems":1,"maxItems":8,' +
  '"items":{"type":"object","valuePolicy":"literal","fields":{' +
  '"id":' + LAB_LITERAL_STRING + ',' +
  '"label":{"type":"string","valuePolicy":"literal-or-path","required":true},' +
  '"value":{"type":"number","valuePolicy":"path-only","required":true}}}}';

const UI_AGENT_LAB_COMPONENT_SCHEMAS_JSON: string =
  '{' +
    '"SurfaceRoot":' + labSchema(LAB_CHILD + ',' + LAB_CHILDREN) + ',' +
    '"Column":' + labSchema(LAB_CHILDREN) + ',' +
    '"Row":' + labSchema(LAB_CHILDREN) + ',' +
    '"Text":' + labSchema(LAB_TEXT_FIELDS + ',' + LAB_DATA_PATH_FIELD + ',"variant":' +
      LAB_LITERAL_STRING + ',"tone":' + LAB_LITERAL_STRING) + ',' +
    '"InfoRows":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD) + ',' +
    '"ActionBar":' + labSchema(LAB_ACTIONS_FIELD) + ',' +
    '"ErrorNotice":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',"body":' +
      LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD + ',' + LAB_ACTIONS_FIELD +
      ',"status":' + LAB_LITERAL_STRING + ',"tone":' + LAB_LITERAL_STRING) + ',' +
    '"ThinkingStream":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD) + ',' +
    '"ThinkingCard":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',"body":' +
      LAB_LITERAL_OR_PATH_STRING + ',"status":' + LAB_LITERAL_STRING + ',' + LAB_DATA_PATH_FIELD) + ',' +
    '"ScheduleStack":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD) + ',' +
    '"SkeletonCard":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',"status":' +
      LAB_LITERAL_STRING) + ',' +
    '"ExpandableCard":' + labSchema(LAB_TEXT_FIELDS + ',' + LAB_DATA_PATH_FIELD + ',' + LAB_ACTIONS_FIELD +
      ',"status":' + LAB_LITERAL_STRING + ',"tone":' + LAB_LITERAL_STRING) + ',' +
    '"MediaSlider":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD + ',' +
      LAB_ACTIONS_FIELD) + ',' +
    '"SceneTabs":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD) + ',' +
    '"MasonryGrid":' + labSchema('"title":' + LAB_LITERAL_OR_PATH_STRING + ',"body":' +
      LAB_LITERAL_OR_PATH_STRING + ',' + LAB_DATA_PATH_FIELD) + ',' +
    '"List":' + labSchema('"children":{"type":"object","valuePolicy":"literal","required":true,' +
      '"fields":{"path":{"type":"string","valuePolicy":"legacy-data-path","required":true},' +
      '"componentId":{"type":"string","valuePolicy":"literal","required":true,"minLength":1}}}') + ',' +
    '"HeroBanner":' + labSchema('"text":' + LAB_LITERAL_OR_PATH_STRING +
      ',"title":{"type":"string","valuePolicy":"literal-or-path","required":true,"minLength":1},' +
      '"body":' + LAB_LITERAL_OR_PATH_STRING) + ',' +
    '"MetricGrid":' + labSchema(LAB_TEXT_FIELDS + ',' + LAB_DATA_PATH_FIELD + ',' +
      LAB_METRIC_ITEMS_FIELD, '[["dataPath","items"]]', '[["dataPath","items"]]') + ',' +
    '"SegmentedRingChart":' + labSchema(LAB_TEXT_FIELDS + ',' + LAB_DATA_PATH_FIELD + ',' +
      LAB_RING_SEGMENTS_FIELD, '[["dataPath","segments"]]', '[["dataPath","segments"]]') + ',' +
    '"MultiSeriesLineChart":' + labSchema(LAB_TEXT_FIELDS +
      ',"dataPath":{"type":"string","valuePolicy":"legacy-data-path","required":true}') + ',' +
    '"MatrixHeatmap":' + labSchema(LAB_TEXT_FIELDS +
      ',"dataPath":{"type":"string","valuePolicy":"legacy-data-path","required":true}') +
  '}';

function buildUiAgentLabComponentCatalogJson(): string {
  const entries = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_BASE_JSON) as Record<string, Object | string>[];
  const schemas = JSON.parse(UI_AGENT_LAB_COMPONENT_SCHEMAS_JSON) as Record<string, Object>;
  for (let index = 0; index < entries.length; index++) {
    const name = entries[index]['name'];
    if (typeof name !== 'string' || schemas[name] === undefined) {
      return '[]';
    }
    entries[index]['schema'] = schemas[name];
  }
  return JSON.stringify(entries);
}

export const UI_AGENT_LAB_COMPONENT_CATALOG_JSON: string = buildUiAgentLabComponentCatalogJson();
