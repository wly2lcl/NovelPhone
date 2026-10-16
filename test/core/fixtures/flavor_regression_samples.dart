/// AI 感检查回归集（M4-05 v1）。
///
/// 样本为人工标注的段落级样本：`aiFlavored = true` 为正样本（带明显 AI 味，
/// 典型机写中文网文腔），`false` 为负样本（人类作者口吻、具体细节、无套话）。
/// 判定口径见 `isFlavorFlagged`（是否存在可定位的"中"及以上问题）。
///
/// 使用方式：每版本跑 `test/core/flavor_regression_test.dart`，核对召回 ≥ 80%、
/// 误报 ≤ 20%（PRD 6.3）。当前为 v1 基线，后续用真实章节标注样本持续扩充。
library;

class FlavorSample {
  const FlavorSample({required this.text, required this.aiFlavored, this.note});

  final String text;
  final bool aiFlavored;
  final String? note;
}

const List<FlavorSample> flavorRegressionSamples = <FlavorSample>[
  // ---------- 正样本：AI 味段落 ----------
  FlavorSample(
    aiFlavored: true,
    note: '强套话密集',
    text:
        '她不禁愣了一下，仿佛整个世界都安静了。心中涌起一股难以言喻的情绪，五味杂陈。'
        '她深吸一口气，缓缓开口：“我明白了。”',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '模式化对话标签',
    text: '“你不必解释。”他淡淡地说道，目光深邃，眼底闪过一丝复杂的情绪。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '段尾强行升华',
    text: '他们并肩走过长街，路灯把影子拉得很长。或许，成长就是学会一个人走完这段路。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '翻译腔 + 模板神态',
    text: '对于他来说，这个消息难以接受。他难以置信地抬起头，脸上浮现出一抹苦笑。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '弱化副词堆叠',
    text: '她微微皱眉，轻轻叹息，缓缓站起身，走到窗边。空气中仿佛弥漫着一丝凉意。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '连续同结构段落',
    text: '他的手指停在半空。\n他的声音有些发抖。\n他的眼神躲闪了一下。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '对话标签 + 复合套话',
    text: '他抿了抿唇，语气平静地说：“我知道了。”同时在心里默默叹了口气，神色复杂。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '感官套话连用',
    text: '时间仿佛静止，空气仿佛凝固。她心脏猛地一缩，瞳孔骤缩，指尖微颤。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '对话 + 感悟收尾',
    text:
        '他缓缓说道：“有些事情，总要有人去做。”说完，他意味深长地看了她一眼，转身离去。'
        '也许，这就是命运。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '套话 + 情绪模板',
    text: '她不由自主地后退一步，脸色一变。脑海中一片空白，只剩下难以置信。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '情绪爆发模板',
    text: '他猛地站起身，青筋暴起，一字一顿地说：“你说什么？”愤怒瞬间涌上心头。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '惊悚模板',
    text:
        '就在这时，一道身影如同鬼魅般出现。他下意识地屏住呼吸，心跳漏了一拍，'
        '冷汗瞬间浸湿后背。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '神态套路组合',
    text:
        '他挑了挑眉，嘴角勾起一抹意味不明的弧度，似笑非笑地看着她。'
        '她莫名其妙地感到一阵寒意。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '段尾感悟句',
    text: '她静静地看着窗外，思绪万千。不知不觉，眼泪滑落。有些孤独，终究要学会放下。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '低声 + 沉默模板',
    text:
        '他低声道：“对不起。”声音里带着一丝颤抖。沉默片刻后，他缓缓转身，'
        '消失在夜色中。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '冲突模板',
    text: '“够了！”他冷冷地说，目光闪烁着复杂的光。气氛瞬间凝固，剑拔弩张。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '压抑情绪模板',
    text:
        '她深吸一口气，压下心中的慌乱，尽量让自己的语气平静：“我没事。”'
        '然而指尖依旧微微发抖。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '结尾说教',
    text:
        '这是一个关于选择的故事。人生就是这样，总要面对无数的岔路。'
        '或许，答案早已写在时间里。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '转折模板',
    text: '他心念电转，迅速做出判断。电光火石之间，他做出了选择。恍惚中，他感到如释重负。',
  ),
  FlavorSample(
    aiFlavored: true,
    note: '夜色 + 孤独升华',
    text:
        '她轻轻点头，却没有说话。那一刻，她忽然明白，有些孤独只能自己承受。'
        '夜风拂过，带着几分凉意。',
  ),

  // ---------- 负样本：人类作者口吻 ----------
  FlavorSample(
    aiFlavored: false,
    text: '老周把烟摁灭在搪瓷缸沿上，起身去后院拎水。井绳磨得发亮，一圈一圈勒进他掌心的老茧里。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '面馆里的电视开着，声音压得很低。老板娘一边擦桌子一边数落儿子，孩子把脸埋进碗里，吃得飞快。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '火车在凌晨三点停靠一个小站，没人下车，也没人上来。站台上只有一盏灯，灯下站着穿蓝制服的值班员。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '他把自行车靠在墙边，锁没锁好，链条响了两次才安静下来。巷子里飘着煤炉和炸带鱼的味道。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '“你说这雨什么时候停？”“不知道。”两个人蹲在屋檐下，看着水从瓦缝里连成一线落下来。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '母亲把晒干的梅干菜收进坛子，坛口用塑料袋扎紧，再压上一块青砖。她说这样能放一年。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '手术室外的走廊很长，灯管有一根在闪。父亲坐在塑料椅上，指节一下一下地敲着膝盖。',
  ),
  FlavorSample(aiFlavored: false, text: '田埂上的草被露水压弯了，他赤脚踩过去，凉意从脚底一直窜到小腿。'),
  FlavorSample(
    aiFlavored: false,
    text: '拆迁办的牌子挂在巷口，红底白字，边角卷了起来。卖豆腐的老王每天路过都要抬头看一眼。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '他把儿子的旧书包洗了，晾在阳台上。蓝色的帆布褪成了灰白，肩带上的补丁是去年缝的。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '楼道里的声控灯坏了半个月，物业一直没修。每晚回家，她都数着台阶上到六楼，数到八十七级。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '父亲修表的时候不说话，镊子在齿轮间挪，呼吸都放得很轻。桌上摊着一块洗得发白的绒布。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '早市收摊时下起小雨，卖鱼的女人把剩下的两条鲫鱼装进塑料袋，塞给旁边卖菜的老太太。',
  ),
  FlavorSample(aiFlavored: false, text: '工地的探照灯亮起来，塔吊的影子铺过半个村子。狗叫了两声，又趴下了。'),
  FlavorSample(aiFlavored: false, text: '他把药盒倒扣在桌上，数了数剩下的片数，又按日期一排排码回去。'),
  FlavorSample(
    aiFlavored: false,
    text: '教室里最后一排放着两盆绿萝，叶子被暖气烤得发黄。值日生用矿泉水瓶给它们浇了水。',
  ),
  FlavorSample(
    aiFlavored: false,
    text: '山路的雾还没散，摩托车的远光灯只能照出四五米。他放慢速度，跟着前面的尾灯走。',
  ),
  FlavorSample(aiFlavored: false, text: '她把手写的稿子摊在膝上，用铅笔在行间改字，橡皮屑落在裤子上，她随手掸掉。'),
  FlavorSample(aiFlavored: false, text: '灶膛里的柴烧得噼啪响，锅盖边缘冒出白气。奶奶揭开盖子，用筷子戳了戳馒头。'),
  FlavorSample(
    aiFlavored: false,
    text: '楼道口贴了张寻猫启事，复印件上猫的眼睛被墨点糊住了一半。下面又有人添了一行小字：找到了，谢谢。',
  ),
];
