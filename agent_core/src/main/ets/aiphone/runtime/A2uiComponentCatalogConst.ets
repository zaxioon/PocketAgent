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

export const UI_AGENT_LAB_COMPONENT_CATALOG_JSON: string =
  '[' +
    '{"name":"SurfaceRoot","role":"布局组件","usage":"UI Lab surface 唯一根节点，必须通过 child 或 children 指向真实存在的组件 id；可见 title 必须由组件 props 动态提供，renderer 不得内置设计稿文案；不绑定 dataPath，不承载 actions"},' +
    '{"name":"Column","role":"布局组件","usage":"纵向容器，只通过 children 排列真实存在的子组件 id；children 不得包含文本、数据值或 action，renderer 不得生成任何内置可见文案"},' +
    '{"name":"Row","role":"布局组件","usage":"横向容器，只通过 children 排列真实存在的子组件 id；children 不得包含文本、数据值或 action，renderer 不得生成任何内置可见文案"},' +
    '{"name":"Text","role":"内容组件","usage":"展示简短标题或说明；全部可见文案必须由 text、body、title props 或 dataPath 动态提供，renderer 不得内置设计稿文案；不使用 children 或 actions"},' +
    '{"name":"InfoRows","role":"内容组件","usage":"展示 label/value 信息行，全部可见 label 和 value 必须用 dataPath 绑定 Array<{label,value}> 动态提供；title 只能由 props 提供，renderer 不得内置文案；不使用 children"},' +
    '{"name":"ActionBar","role":"交互组件","usage":"展示一组操作，按钮及其可见 label 只能来自 actions 中已提供的 offerId，renderer 不得内置操作文案；不使用 child、children 或 dataPath"},' +
    '{"name":"ErrorNotice","role":"状态组件","usage":"展示需要阅读、重试或修改输入的错误；全部可见标题和正文必须由 title、body props 或 dataPath 动态提供，可选 actions 必须引用已提供的 offerId；renderer 不得内置错误文案"},' +
    '{"name":"ThinkingStream","role":"状态组件","usage":"展示渐进事件列表，全部可见内容必须用 dataPath 绑定 Array<{id,title,detail,status}> 动态提供；可见 title 只能由 props 提供，不使用 children 或 actions"},' +
    '{"name":"ThinkingCard","role":"状态组件","usage":"展示结构生成中的摘要、进度与事件；全部可见内容必须由 title、body、status props 或 dataPath 绑定 {label,progress,events} 动态提供，renderer 不得内置设计稿文案；不承载业务 actions"},' +
    '{"name":"ScheduleStack","role":"复合内容组件","usage":"展示多日或多段日程卡，全部可见日期、标题、条目和指标必须用 dataPath 绑定 Array<{id,label,title,entries,metric?,tone?}> 动态提供；renderer 不得内置行程文案，不使用 children"},' +
    '{"name":"SkeletonCard","role":"局部加载组件","usage":"仅在最终布局已经确定且局部数据未返回时使用，status 必须为 loading；如有可见标题只能由 title props 动态提供，renderer 不得内置加载文案；不使用 children、dataPath 或 actions"},' +
    '{"name":"ExpandableCard","role":"复合交互组件","usage":"展示可折叠摘要、可选方图、信息行与详情入口；全部可见内容必须用 dataPath 绑定 {eyebrow?,title,summary?,thumbnailAssetKey?,rows,expanded?} 动态提供；最多一个已提供的 action，renderer 不得内置文案，不使用 children"},' +
    '{"name":"MediaSlider","role":"复合媒体组件","usage":"展示可横向滑动的图片或视频卡组，全部可见标题和媒体描述必须用 dataPath 绑定 Array<{id,kind,title,assetKey,posterAssetKey?,alt}> 动态提供；媒体只能引用预登记 assetKey，actions 必须引用已提供的 offerId，renderer 不得内置文案，不使用 children"},' +
    '{"name":"SceneTabs","role":"复合导航组件","usage":"展示同一主题下的场景分页，全部可见 tab 标签、标题、正文和指标必须用 dataPath 绑定 Array<{id,icon,label,title,body,metrics}> 动态提供；tab 切换由客户端处理，renderer 不得内置场景文案，不使用 children 或 actions"},' +
    '{"name":"MasonryGrid","role":"复合布局组件","usage":"展示固定双列不等高信息卡，全部可见标题和正文必须用 dataPath 绑定 Array<{id,title,body,tone,height}> 动态提供；tone 仅允许 blue、peach、mint，height 仅允许 regular、tall，renderer 不得内置文案，不使用 children 或 actions"}' +
  ']';
