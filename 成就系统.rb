#==============================================================================
# ■ RGSS3 成就系统 Ver1.46 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
# 本成就系统脚本为本人独立开发，并保留所有相关权利
#【非强制性小建议】
#   如果可以，在游戏开始时设一个自动解锁的成就吧。
#   叫啥你定，长啥样你画，不设也行。
#   就当是帮这个系统在玩家面前混个脸熟。
# 【商业用途警告】
# 任何在RM VX商业游戏中出现与本脚本功能及代码逻辑高度相似且无法提供独立开发证据者，
# 本人保留采取包括但不限于平台下架投诉及法律维权在内的所有权利
#------------------------------------------------------------------------------
# 【功能概述】
#   - 管理成就的解锁状态，并将状态保存到外部文件 champion.rvdata2 中。
#   - 解锁成就时会在屏幕底部弹出一个原生窗口皮肤的通知窗口，滑入后停留再滑出。
#   - 支持多个成就连续解锁时自动排队显示，不会互相覆盖。
#   - 提供成就重置功能。
#------------------------------------------------------------------------------
# 【如何添加新成就】
#   在Graphics中新建一个文件夹，命名为Champion，存放成就相关图片
#   在 Champion 模块的 Default 哈希表里添加新条目。
#   这是哈希嵌套哈希的结构，每个成就条目之间必须用逗号分隔！！！
#
#   格式如下：
#
#     成就符号: {
#       name:               "成就名称",
#       description:        "成就描述文字",
#       icon:               "图片文件名",     # 图标存放于 Graphics/Champion 下，不含扩展名
#       locked_name:        "未解锁时成就名称",
#       locked_description: "未解锁时成就描述文字",
#       locked_icon:        "未解锁时图片文件名",
#       se:                 [SE 名称, 音量, 音高],  # 可写 nil 不播放
#       animation_id:        数字,            # 解锁成就时播放的动画，可不填          
#       type:               "成就类型",       # 所属分类
#       type_priority:      数字,             # 该成就所属类型的排序优先级（越小越靠前）
#       progress:           成就所需进度,      # 该成就集满所需进度数，可不填
#       level:              数字   ,        # 该成就的品质等级(数字越小品质等级越高)
#       level_edge:         "图片文件名",    # 成就品质展示边框图片
#       level_name:         "品质名字",      # 该成就的品质名字，可不填
#       level_color:        数字,             # 该成就的品质显示颜色，可不填
#       common_event_id:    数字 ,          # 成就解锁后调用公共事件的id，可不填
#       hidde:              true ,      #  写true时表示该成就隐藏，可不填
#       unlocked:           false,           # 初始必须为 false
#       points:           数字,         # 成就解锁时增加的点数，可不填
#     }
#
#   类型排序规则：
#     - 系统会取同一类型下所有成就中最小的 type_priority 作为该类型的排序值。
#     - 数字小的类型排在前面，数字相同的按类型名称的字母序排列。
#     - 警告：如果忘写type，代码将会自动处理成0的优先级
#
#   示例：
#     full_hp: {
#       name: "无伤传说",
#       description: "以满HP状态通关任意关卡",
#       icon: "cham1",
#       locked_name: "???",
#       locked_description: "如果过于强大……",
#       locked_icon: "question",
#       se: ["Saint4",80,100],
#       type: "战斗",
#       type_priority: 2,
#       level: 2
#       level_name: "普通"
#       level_color: 0
#       unlocked: false,
#     },
#     treasure_hunter: {
#       name: "宝箱猎人",
#       description: "累计开启100个宝箱",
#       icon: "cham1",
#       locked_name: "寻宝新手",
#       locked_description: "多翻翻草丛和墙角吧",
#       locked_icon: "question",
#       se: nil,
#       type: "探索",
#       type_priority: 1,          # “探索”类整体排在“战斗”前面
#       progress: 100,
#       level: 1
#       level_name: "稀有"
#       level_color: 0
#       unlocked: false,
#     },
#     welcome: {
#       name: "初入江湖",
#       description: "开始游戏",
#       icon: "cham1",
#       locked_name: "初入江湖",
#       locked_description: "开始游戏",
#       locked_icon: "cham1",
#       se: nil,
#       type: "基础",
#       type_priority: 0,          # “基础”类优先级最高，排在最前面
#       level: 0
#       level_name: "传说"
#       level_color: 10
#       unlocked: false,
#     }
#
#   注意：
#     - type_priority 不是必填，但建议每个成就都写，不写默认按 0 处理。
#     - 每个成就条目末尾必须有逗号（最后一个除外），否则直接报错。
#------------------------------------------------------------------------------
# 【如何解锁成就】
#   在事件脚本中调用：
#
#     unlock_achievement(:成就符号)
#
#   例如：解锁示例中的成就
#     unlock_achievement(:full_hp)
#     将解锁"无伤传说"的成就
#
#   注意：如果成就已解锁，重复调用不会再次弹窗。
#   
#   在事件脚本中调用：
#
#     add_achievement_progress(:成就符号,要增加的进度)
#   
#
#   比如：add_achievement_progress(:treasure_100,1)
#         让:treasure_100进度+1
#   当该成就进度条满后就会自动解锁，无需多余代码
#------------------------------------------------------------------------------
#   【如何查询成就状态】
#
#     unlocked_achievement?(:成就符号)
#     → 返回 true（已解锁）或 false（未解锁）
#
#     achievement_current_progress(:成就符号)
#     → 返回当前进度值（无进度条则返回0）
#
#   示例：
#     ◆如果：脚本：unlocked_achievement?(:full_hp)
#       ◆文本：你已解锁隐藏道路！
#       ◆场所移动：隐藏关卡
#     ◆结束
#------------------------------------------------------------------------------
# 【如何重置所有成就】
#   在事件脚本中调用：
#
#     reset_achievement
#
#   效果：所有成就变为未解锁状态，并立刻保存到文件。同时会清空当前未播放完的弹窗。
#------------------------------------------------------------------------------
# 【弹窗行为说明】
#   - 窗口从屏幕底部下方滑入，停留约 3 秒（180 帧，可在WaitTime中改），再向下滑出。
#   - 位置：紧贴屏幕最底部，宽 300 像素，高 随会根据窗口的需求动态调整。
#   - 图标：绘制在左侧 (10,窗口中间的位置)，文件取自 Graphics/System。
#   - 文字：名称用红色，描述用白色(颜色可在配置区修改)，字号 20(可修改)。
#   - 队列：有多个成就排队时，上一个滑出后下一个才开始滑入。
#------------------------------------------------------------------------------
# 【成就商店配置】
#     在GOODS写入哈希表，格式为{ type: 货物类型,   id: 货物id, price: 价格 }
#     其中type需要填入的格式为:item,:weapon,:armor，分别表示物品，武器和护甲
#     id填入的是在该货物的分类中的数据库的id
#------------------------------------------------------------------------------
# 【注意事项】
#   - 成就数据文件 champion.rvdata2 默认创建在游戏根目录。
#   - 重置成就时请确保玩家已了解后果，该操作不可逆（除非有备份文件）。
#   - 本脚本兼容默认 RGSS3，不使用任何外部 DLL。
#==============================================================================
# ver 1.00
# 依旧首先只是实现最基本功能，其他的之后再加吧
# 现在只是实现了能创建一个文件来存储你的成就而已
#------------------------------------------------------------------------------
# ver 1.01
# 增加了弹窗，提示你完成了成就
#------------------------------------------------------------------------------
# ver 1.02
# 修改弹窗效果，使之能支持不同长度的介绍
#------------------------------------------------------------------------------
# ver 1.10
# 增加菜单中成就框，可以在菜单中查看成就
#------------------------------------------------------------------------------
# ver 1.12
# 增加开始界面的成就框，可以在标题中查看成就
#------------------------------------------------------------------------------
# ver 1.13
# 可以更改成就中的字体的颜色了
#------------------------------------------------------------------------------
# ver 1.14
# 可以自定义成就在菜单和标题里的显示与否了
#------------------------------------------------------------------------------
# ver 1.17
# 新增了可以在获得成就时播放音频的选择，并给出配置SE入口
#------------------------------------------------------------------------------
# ver 1.18
# 新增了成就进度条
#------------------------------------------------------------------------------
# ver 1.19
# 新增了各种配置
#------------------------------------------------------------------------------
# ver 1.22
# 新增了成就未解锁时显示的名称和描述
#------------------------------------------------------------------------------
# ver 1.23
# 新增了各成就独自声效
#------------------------------------------------------------------------------
# ver 1.24
# 增加PopPos常量，让你可以设置成就窗口出现位置
#------------------------------------------------------------------------------
# ver 1.26
# 增加了成就分类，能让成就以你想要的方式分类
#------------------------------------------------------------------------------
# ver 1.27
# 成就分类可以单独查看其对应进度了
#------------------------------------------------------------------------------
# ver 1.28
# 优化成就分类的显示逻辑，现在可以自定义成就分类的显示优先级了
#------------------------------------------------------------------------------
# ver 1.29
# 修改成就显示排序逻辑，改为未解锁和已解锁的分为一块再显示
# 按住shift键即可转化排序的方向（已解锁在前 ⇄ 已解锁在后）
#------------------------------------------------------------------------------
# ver 1.30
# 成就拥有了时间戳
#------------------------------------------------------------------------------
# ver 1.31
# 让用户可以自由调整弹窗宽度、成就描述的字体大小
#------------------------------------------------------------------------------
# ver 1.32
# 增加成就进度机制，完善相关显示
#------------------------------------------------------------------------------
# ver 1.33
# 增加品质设定，现在的成就将可以写入品质
# 增加成就显示里关于品质等级的优先排布选择
#------------------------------------------------------------------------------
# ver 1.34
# 增加公共事件调用，解锁成就可以调用某个公共事件，从而触发奖励
#------------------------------------------------------------------------------
# ver 1.35
# 某个成就可以完全隐藏
#------------------------------------------------------------------------------
# ver 1.36
# 解锁时间纳入排布优先的选择选项中
#------------------------------------------------------------------------------
# ver 1.37
# 让长期成就一次性增加的进度数量可自由设置
#------------------------------------------------------------------------------
# ver 1.38
# 让成就目前的状态可供查询
#------------------------------------------------------------------------------
# ver 1.39
# 增加成就追踪窗口，按住D键可以追踪/不追踪该成就
#------------------------------------------------------------------------------
# ver 1.40
# 增加成就动画播放选择
#------------------------------------------------------------------------------
# ver 1.41
# 增加成就边框配置选择
#------------------------------------------------------------------------------
# ver 1.43
# 增加成就商店,可以进行配置
#------------------------------------------------------------------------------
# ver 1.44
# 对成就追踪功能进行了优化，提高玩家友好度
#------------------------------------------------------------------------------
# ver 1.45
# 增加了成就追踪功能的开关
#------------------------------------------------------------------------------
# ver 1.46
# 修复关闭成就商店后查看具体成就后窗口显示bug
#==============================================================================


# 本行以下是配置区！！！是你唯一能改的地方！！！
module Champion
  
  # 成就配置
  Default = {
    full_hp: {
      name: "无伤传说",
      description: "以满HP状态通关任意关卡",
      icon: "cham1",
      locked_name: "???",
      locked_description: "如果过于强大……",
      locked_icon: "question",
      se: ["Saint4",80,100],
      animation_id: 42,
      type: "战斗",
      type_priority: 2,
      level_edge: "001",
      level_name: "普通",
      common_event_id: 139,
      hidden: false,
      unlocked: false,
    }, #每个配置间必须加逗号！！！不然就会报错！！！
    treasure_100: {
      name: "宝箱猎人",
      description: "累计开启100个宝箱",
      icon: "cham1",
      locked_name: "宝箱猎人",
      locked_description: "累计开启100个宝箱",
      locked_icon: "cham1",
      se: nil,
      type: "探索",
      type_priority: 1,
      progress: 100,
      level: 1,
      level_name: "稀有",
      unlocked: false,
    },
    genshin_start: {
      name: "原神启动",
      description: "开始游戏",
      icon: "cham1",
      locked_name: "原神启动",
      locked_description: "开始游戏",
      locked_icon: "cham1",
      se: nil,
      type: "基础",
      type_priority: 0,
      level: 0,
      level_name: "传说",
      level_color: 10,
      unlocked: false,
    },
  # 这下面的花括号不要覆盖了！！！注意！！！这是Default的哈希表括号！！！
  }
  
  # 是否开启成就商店
  ShopFlag = true
  
  # 成就商店
  GOODS =  [
    { type: :item,   id: 1, price: 100 },  # 物品1，价格100点
    { type: :weapon, id: 2, price: 200 },  # 武器2，价格200点
    { type: :armor,  id: 3, price: 150 },  # 护甲3，价格150点
  ]
    
  # 成就窗口的位置(0右下，1右上，2左上，3左下)
  PopPos = 0
  
  # 成就窗口的大小
  Width = 300
  
  # 弹窗字号大小
  PopFontSize = 20
  
  # 成就弹窗的滑入滑出速度
  MoveSpeed = 5
  
  # 成就弹窗的滞留时间(以帧为单位，60帧为1秒)
  WaitTime = 180
  
  # 成就名字的字体颜色的RGSS3系统编号
  NameColor = 18 # 18是红色的编号
  
  # 成就描述的字体颜色的系统编号
  DescripColor = 0 # 0是白色的编号
  
  # 成就查看的名称字体大小
  ListNameSize = 22 
  
  # 成就查看的描述字体大小
  ListDescripSize = 18 
  
  # 成就查看的时间戳字体大小
  ListTimeSize = 16 

  # 成就列表中品质字体大小
  ListLevelSize = 20
  
  # 成就列表中品质的默认颜色
  ListLevelColor = 0
  
  # 是否启用成就追踪
  TrackFlag = true
  
  # 成就查看时的进度字体颜色(“成就进度：5 / 20 ”)的系统编号
  ProgressColor = 0# 0是白色的编号
  
  # 成就查看时的评价字体颜色的系统编号
  RankColor = 10 # 10是红色的编号
  
  # 成就查看时的评价语段
  # 严格按照从大到小的顺序写数字，每个数字代表到达这个评价所需最低百分比下限
  RankHash = {
  100 => "wdf,你真牛福",
  80 => "骨灰级玩家",
  30 => "你已经超过1h无法退款了！",
  0 => "菜就多练"
  }
  
  # 成就查看时的百分比字体颜色的系统编号
  PercentColor = 0# 0是白色的编号
  
  # 成就查看时的进度条充满颜色的系统编号
  ForegroundColor = 29# 29是绿色的编号
  
  # 是否可以在开始界面查看成就，true为可以，false为不可以
  Title = true
  
  # 是否可以在菜单界面查看成就，true为可以，false为不可以
  Menu = true
  
  # 成就默认播放的动画id
  Animation_ID = 42
  
  # 获取成就时播放的se文件
  # 指定顺序为 [SE 名称, 音量, 音高]。
  
  SE       = ["Saint7",80,100]

  
end


module Vocab
  
  # 成就框的显示字符
  Champion = "成就"
  
end

# 到了本行配置区结束！！！下面的东西不要改了！！！

#==============================================================================
# ■ DataManager (成就数据控制)
#==============================================================================
class << DataManager
  #--------------------------------------------------------------------------
  # ● 初始化模块
  #--------------------------------------------------------------------------
  alias champion_init init
  def init
    champion_init
    setup_achievements
  end
  
  #--------------------------------------------------------------------------
  # ● 初始化成就系统
  #--------------------------------------------------------------------------
  def setup_achievements
    $game_achievements = default_achievements          # 先拿到默认结构
    $game_achievements[:champion_points] = 0
    if File.exist?("champion.rvdata2")
      saved = load_achievements rescue nil
      # 读取成就的点数
      $game_achievements[:champion_points] = saved[:champion_points] || 0
      if saved.is_a?(Hash)
        # 将已保存的成就状态合并到默认结构中
        saved.each do |key, value|
          next unless $game_achievements.key?(key)     # 只合并已知成就
          next if key == :champion_points
          $game_achievements[key][:unlocked] = value[:unlocked] if value[:unlocked]
          $game_achievements[key][:time] = value[:time] if value[:time] != ""
          $game_achievements[key][:current] = value[:current] ? value[:current] : 0
        end
      end
    end
    save_achievements   # 保存一份结构始终与当前 Champion::Default 同步的文件
  end
  #--------------------------------------------------------------------------
  # ● 保存成就
  #--------------------------------------------------------------------------
  def save_achievements
    File.open("champion.rvdata2", "wb") do |file|
      Marshal.dump($game_achievements, file)
    end
  end
  #--------------------------------------------------------------------------
  # ● 成就初始设置
  #--------------------------------------------------------------------------
  def default_achievements
    Champion::Default
  end
  #--------------------------------------------------------------------------
  # ● 加载成就
  #--------------------------------------------------------------------------
  def load_achievements
    File.open("champion.rvdata2", "rb") do |file|
      return Marshal.load(file)
    end
  end
  #--------------------------------------------------------------------------
  # ● 创建保存内容
  #--------------------------------------------------------------------------
  alias tracking_make_save_contents make_save_contents 
  def make_save_contents
    contents = tracking_make_save_contents
     # 保存 $achievement_tracking 的状态
    contents[:achievement_tracking] = $achievement_tracking.dup
    contents
  end
  #--------------------------------------------------------------------------
  # ● 展开保存内容
  #--------------------------------------------------------------------------
  alias tracking_extract_save_contents extract_save_contents 
  def extract_save_contents(contents)
    tracking_extract_save_contents(contents)
    # 从存档中恢复追踪状态，如果存档中没有该数据（旧存档），则使用默认值
    if Champion::TrackFlag
      $achievement_tracking = contents[:achievement_tracking] || []
    end
  end
end

#==============================================================================
# ■ Cache (管理成就相关图片)
#==============================================================================
module Cache
  #--------------------------------------------------------------------------
  # ● 获取成就图像
  #--------------------------------------------------------------------------
  def self.champion(filename)
    load_bitmap("Graphics/Champion/", filename)
  end
end

# 为了让这些方法哪里都可以调用，我决定还是裸奔吧
#--------------------------------------------------------------------------
# ● 成就解锁
#--------------------------------------------------------------------------
def unlock_achievement(id)
  return if $game_achievements[id].nil?               # 无效ID
  return if $game_achievements[id][:unlocked]         # 已解锁则跳过
  $game_achievements[id][:unlocked] = true
  $game_achievements[id][:time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")  # 记录解锁时间戳
  $game_achievements[:champion_points] = 0 if $game_achievements[:champion_points].nil?
  $game_achievements[:champion_points] += $game_achievements[id][:points] unless $game_achievements[id][:points].nil?
  DataManager.save_achievements                       # 立即写入文件
  if $game_achievements[id][:common_event_id]
    $game_temp.reserve_common_event($game_achievements[id][:common_event_id])
  end
  # 创造弹窗，丢进队列
  popup = Window_AchievementPopup.new($game_achievements[id])
  $achievement_queue.push(popup)
end
#--------------------------------------------------------------------------
# ● 长期成就更改进度
#--------------------------------------------------------------------------
def add_achievement_progress(id,progress)
  return if $game_achievements[id].nil?               # 无效ID
  $game_achievements[id][:current] += progress
  DataManager.save_achievements                       # 立即写入文件
  # 如果当前进度大于所需进度，尝试解锁成就
  if  $game_achievements[id][:current] >= $game_achievements[id][:progress]
    unlock_achievement(id) 
  end
end
#--------------------------------------------------------------------------
# ● 重置成就
#--------------------------------------------------------------------------
def reset_achievement
  $game_achievements.each_value{|ach| 
  next unless ach.is_a?(Hash)
  ach[:unlocked] = false 
  ach[:current] = 0
  }
  $game_achievements[:champion_points] = 0
  DataManager.save_achievements
  # 顺便清空可能存在的弹窗队列，防止画面残留
  $achievement_queue.each { |popup| popup.dispose if popup }
  $achievement_queue.clear
end


# 用来处理同时获得多个成就的显示的队列
$achievement_queue = []

#==============================================================================
# ■ Game_Interpreter (用来给用户提供判断接口)
#==============================================================================
class Game_Interpreter
  #--------------------------------------------------------------------------
  # ● 获取成就是否解锁
  #--------------------------------------------------------------------------
  def unlocked_achievement?(id)
    return true if $game_achievements[id][:unlocked]
    false
  end
  #--------------------------------------------------------------------------
  # ● 获取当前成就进度
  #--------------------------------------------------------------------------
  def achievement_current_progress(id)
    return 0 if $game_achievements[id][:progress].nil?
    return $game_achievements[id][:current]
  end
end


# 全局追踪数组（存放成就符号）
$achievement_tracking = []
#--------------------------------------------------------------------------
# ● 开始追踪某成就
#--------------------------------------------------------------------------
def track_achievement(id)
  return if $game_achievements[id].nil?          # 无效成就
  return if $game_achievements[id][:unlocked]    # 已解锁的不追踪
  return unless Champion::TrackFlag              # 只有追踪功能开启时才追踪
  unless $achievement_tracking.include?(id)
    $achievement_tracking.push(id)
  end
end
#--------------------------------------------------------------------------
# ● 停止追踪某成就
#--------------------------------------------------------------------------
def untrack_achievement(id)
  $achievement_tracking.delete(id)
end

#==============================================================================
# ■ Window_AchievementTracker (成就追踪)
#==============================================================================
class Window_AchievementTracker < Window_Base
  # 最大同时显示条数
  MAX_VISIBLE = 2
  # 每条高度
  ITEM_HEIGHT = 56
  # 窗口整体透明度
  WINDOW_ALPHA = 200

  def initialize
    # 计算合适的高度（至少能容纳一行，避免高度为0）
    h = [ITEM_HEIGHT * MAX_VISIBLE, ITEM_HEIGHT].max
    # 放置在画面左上角（与成就弹窗错开）
    super(0, 0, 280, h)
    self.opacity = WINDOW_ALPHA
    self.contents_opacity = 255
    # 用于脏标记：记录上次各成就的进度值
    @last_progress = {}
    @tracking_keys = []
    refresh
  end

  #--------------------------------------------------------------------------
  # ● 更新画面
  #--------------------------------------------------------------------------
  def update
    super
    # 检查是否有进度变化或列表变化
    if need_refresh?
      refresh
    end
  end

  #--------------------------------------------------------------------------
  # ● 判断是否需要重绘
  #--------------------------------------------------------------------------
  def need_refresh?
    # 追踪列表变化
    return true if @tracking_keys != $achievement_tracking.first(MAX_VISIBLE)
    # 进度数值变化
    $achievement_tracking.first(MAX_VISIBLE).any? do |key|
      ach = $game_achievements[key]
      next false if ach.nil?
      (@last_progress[key] || -1) != ach[:current]
    end
  end

  #--------------------------------------------------------------------------
  # ● 刷新内容
  #--------------------------------------------------------------------------
  def refresh
    # 清理已解锁的成就
    $achievement_tracking.reject! do |key|
      $game_achievements[key] && $game_achievements[key][:unlocked]
    end

    # 获取当前要显示的成就（最多MAX_VISIBLE个）
    @tracking_keys = $achievement_tracking.first(MAX_VISIBLE)
    
    # 更新位图尺寸
    h = [@tracking_keys.size, 1].max * ITEM_HEIGHT
    self.height = h
    create_contents

    # 绘制每个追踪条目
    @tracking_keys.each_with_index do |key, index|
      draw_tracking_item(index, $game_achievements[key])
      @last_progress[key] = $game_achievements[key][:current]
    end
  end

  #--------------------------------------------------------------------------
  # ● 绘制单个追踪条目
  #--------------------------------------------------------------------------
  def draw_tracking_item(index, ach)
    return if ach.nil?
    y = index * ITEM_HEIGHT
    x = 4
    w = contents.width - 8
    
     # === 绘制品质边框 ===
    if ach[:level_edge]
      edge_bitmap = Cache.champion(ach[:level_edge]) rescue nil
      if edge_bitmap
        # 边框包裹整个条目区域
        edge_rect = Rect.new(x, y, w, ITEM_HEIGHT)
        contents.stretch_blt(edge_rect, edge_bitmap, edge_bitmap.rect)
      end
    end

    # 图标（取未解锁图标，因为追踪时通常未解锁）
    icon_name = ach[:locked_icon] || ach[:icon]
    icon_bitmap = Cache.champion(icon_name) rescue nil
    if icon_bitmap
      dest_rect = Rect.new(x, y + (ITEM_HEIGHT - 50) / 2, 32, 32)
      contents.stretch_blt(dest_rect, icon_bitmap, icon_bitmap.rect)
    end

    # 成就名称
    name = ach[:unlocked] ? ach[:name] : ach[:locked_name]
    change_color(text_color(Champion::NameColor))
    contents.font.size = 18
    contents.draw_text(x + 40, y, w - 40, 20, name)

    # 进度数字
    if ach[:progress]
      current = ach[:current] || 0
      total = ach[:progress]
      progress_text = "#{current}/#{total}"
      contents.font.size = 14
      contents.draw_text(x + 40, y + 20, w - 40, 16, progress_text, 2) # 右对齐

      # 进度条背景
      bar_y = y + 38
      bar_h = 6
      bg_color = Color.new(80, 80, 80, 180)
      contents.fill_rect(x + 40, bar_y - 20, w - 40, bar_h, bg_color)

      # 进度条前景
      fill_w = [(w - 40) * current / total, 0].max.to_i
      fg_color = text_color(Champion::ForegroundColor)
      contents.fill_rect(x + 40, bar_y - 20, fill_w, bar_h, fg_color)
    end
  end

  #--------------------------------------------------------------------------
  # ● 释放
  #--------------------------------------------------------------------------
  def dispose
    super
  end
end

class Scene_Map
  alias champion_tracker_start start
  def start
    champion_tracker_start
    @tracker = Window_AchievementTracker.new
    if $achievement_tracking.empty?
      @tracker.dispose
      @tracker = nil  # 添加这行
    end
  end

  alias champion_tracker_update update
  def update
    champion_tracker_update
    if @tracker 
      if $achievement_tracking.empty?
        @tracker.dispose 
        @tracker = nil 
      else
        @tracker.update
      end
    end
    
  end

  alias champion_tracker_terminate terminate
  def terminate
    champion_tracker_terminate
    @tracker.dispose if @tracker
  end
end

#==============================================================================
# ■ Window_AchievementPopup (成就弹窗)
#==============================================================================
class Window_AchievementPopup < Window_Base
  #--------------------------------------------------------------------------
  # ● 常量设置（可根据需要调整）
  #--------------------------------------------------------------------------
  WINDOW_WIDTH  = Champion::Width            # 窗口总宽
  ICON_X        = 10                         # 图标左上角 X
  ICON_Y        = 10                         # 图标左上角 Y
  TEXT_START_X  = 100                        # 文字起始 X（原脚本设定）
  TEXT_WIDTH    = 160                        # 文字最大宽度
  FONT_SIZE     = Champion::PopFontSize      # 字号
  LINE_HEIGHT   = 24                         # 行高
  PADDING       = 10                         # 窗口上下的留白
  TEXT_START_Y  = 0

  #--------------------------------------------------------------------------
  # ● 初始化对象
  #--------------------------------------------------------------------------
  def initialize(achievement_data)
    @achievement_data = achievement_data  # 保存数据
    @ani_sprite = nil                     # 动画精灵占位
    # 临时位图，仅用于测量文字尺寸
    temp_bitmap = Bitmap.new(1, 1)
    temp_bitmap.font.size = FONT_SIZE

    # 获取图标及其尺寸
    icon_bitmap = Cache.champion(achievement_data[:icon])
    icon_w = icon_bitmap.width
    icon_h = icon_bitmap.height

    # 计算可用文字宽度（尊重原脚本 80 起始和 200 宽，也可用相对计算）
    text_w = TEXT_WIDTH

    # 将名称和描述分别换行
    display_name = achievement_data[:name].to_s
    
    # 如果有品质加上品质
    if achievement_data[:level_name] && !achievement_data[:level_name].empty?
      display_name = "#{display_name} [ #{achievement_data[:level_name]} ]"
    end
    
    # 如果是隐藏成就特殊展示
    display_name = "#{display_name} [ 隐藏成就 ]" if achievement_data[:hidden]
    
    name_lines = wrap_text(temp_bitmap, display_name, text_w)
    desc_lines  = wrap_text(temp_bitmap, achievement_data[:description], text_w)

    # 计算总行数（名称和描述之间无额外空行）
    total_lines = name_lines.size + desc_lines.size
    total_lines = 1 if total_lines < 1   # 确保至少有 1 行

    # 计算需要的窗口高度：图标区域和文字区域取最大值，并加上上下留白
    text_height = total_lines * LINE_HEIGHT
    min_height  = [icon_h + PADDING * 2, text_height + PADDING * 2].max
    height = min_height

    temp_bitmap.dispose  # 不再需要临时位图

    # 初始位置：屏幕底部外下方
    super(Graphics.width - WINDOW_WIDTH, Graphics.height, WINDOW_WIDTH, height)
    self.opacity = 255
    self.contents_opacity = 255

    # 创建正式内容位图
    create_contents
    
    # 绘制品质边框（如果存在 level_edge）
    if achievement_data[:level_edge]
      edge_bitmap = Cache.champion(achievement_data[:level_edge]) rescue nil
      if edge_bitmap
        # 边框区域：略小于 contents，保留一点窗口皮肤边缘（可选）
        edge_rect = Rect.new(0, 0, contents.width, contents.height)
        contents.stretch_blt(edge_rect, edge_bitmap, edge_bitmap.rect)
      end
    end
    contents.font.size = FONT_SIZE

    # 绘制图标（左中位置）
    pos_y = (height/2-icon_h/2).to_i
    contents.blt(ICON_X,pos_y-ICON_Y, icon_bitmap, icon_bitmap.rect)

    # 绘制名称行
    change_color(text_color(Champion::NameColor), achievement_data[:unlocked])
    y = TEXT_START_Y
    name_lines.each do |line|
      contents.draw_text(TEXT_START_X, y, text_w, LINE_HEIGHT, line)
      y += LINE_HEIGHT
    end

    # 绘制描述行
    change_color(text_color(Champion::DescripColor), achievement_data[:unlocked])
    desc_lines.each do |line|
      contents.draw_text(TEXT_START_X, y, text_w, LINE_HEIGHT, line)
      y += LINE_HEIGHT
    end
    
    # 准备 SE 的数组。有特定se就用特定的，没有则用默认的
      
    array = achievement_data[:se] ? achievement_data[:se] : Champion::SE
    
    # 播放 SE
    
    RPG::SE.new(array[0],array[1],array[2]).play

    case Champion::PopPos
    when 0  # 右下
      @hidden_y = Graphics.height
      @target_y = Graphics.height - height
      self.x = Graphics.width - WINDOW_WIDTH
    when 1  # 右上
      @hidden_y = -height
      @target_y = 0
      self.x = Graphics.width - WINDOW_WIDTH
    when 2  # 左上
      @hidden_y = -height
      @target_y = 0
      self.x = 0
    when 3  # 左下
      @hidden_y = Graphics.height
      @target_y = Graphics.height - height
      self.x = 0
    end
    self.y = @hidden_y
    
    @state = :slide_in
  end

  #--------------------------------------------------------------------------
  # ● 将字符串按最大宽度分行
  #--------------------------------------------------------------------------
  def wrap_text(bitmap, text, max_width)
    return [] if text.nil? || text.empty?
    lines = []
    current_line = ""
    text.each_char do |ch|
      test_line = current_line + ch
      if bitmap.text_size(test_line).width > max_width && !current_line.empty?
        lines << current_line
        current_line = ch
      else
        current_line = test_line
      end
    end
    lines << current_line unless current_line.empty?
    lines
  end
  #--------------------------------------------------------------------------
  # ● 更新画面
  #--------------------------------------------------------------------------
  def update
    super
     # 更新并自动释放庆祝动画精灵
    if @ani_sprite
      @ani_sprite.update
      unless @ani_sprite.animation?     # 动画播放完毕？
        @ani_sprite.dispose
        @ani_sprite = nil
      end
    end

    case @state
    when :slide_in
      dir = @target_y > @hidden_y ? 1 : -1          # 向下滑为正，向上滑为负
      self.y += dir * Champion::MoveSpeed
      if (dir > 0 && self.y >= @target_y) ||
         (dir < 0 && self.y <= @target_y)
        self.y = @target_y
        @state = :wait
        @wait_count = Champion::WaitTime
        start_celebration_animation    # 此时播放一次庆祝动画
      end
    when :wait
      @wait_count -= 1
      @state = :slide_out if @wait_count <= 0
    when :slide_out
      dir = @hidden_y > @target_y ? 1 : -1          # 回到隐藏位置的方向
      self.y += dir * Champion::MoveSpeed
      if (dir > 0 && self.y >= @hidden_y) ||
         (dir < 0 && self.y <= @hidden_y)
        return false                                # 完全移出屏幕，通知队列移除
      end
    end
    return true
  end
  


  def start_celebration_animation
    # 优先使用成就自己的动画 ID，否则使用全局默认
    ani_id = @achievement_data[:animation_id] || Champion::Animation_ID
    return if ani_id.nil? || ani_id == 0
    return if $data_animations[ani_id].nil?

    # 创建一个临时精灵，位于窗口中心
    @ani_sprite = Sprite_Base.new
    @ani_sprite.x = self.x + self.width / 2
    @ani_sprite.y = self.y + self.height / 2
    @ani_sprite.z = self.z + 350          # 比窗口高，确保可见
    @ani_sprite.start_animation($data_animations[ani_id])
  end
  #--------------------------------------------------------------------------
  # ● 释放
  #--------------------------------------------------------------------------
  def dispose
    if @ani_sprite
      @ani_sprite.dispose
      @ani_sprite = nil
    end
    super
  end
end


  


#==============================================================================
# ■ Scene_Base (画面处理)
#==============================================================================
class Scene_Base
  #--------------------------------------------------------------------------
  # ● 更新画面
  #--------------------------------------------------------------------------
  alias champion_update update
  def update
    champion_update
    process_achievement_queue
  end
  #--------------------------------------------------------------------------
  # ● 处理成就队列
  #--------------------------------------------------------------------------
  def process_achievement_queue
    if $achievement_queue && !$achievement_queue.empty?
      current = $achievement_queue[0]
      unless current.update
        current.dispose
        $achievement_queue.shift
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● 结束处理(只是为了防止图片残留bug才写的)
  #--------------------------------------------------------------------------
  alias champion_terminate terminate
  def terminate
    champion_terminate
    $achievement_queue.each { |popup| popup.dispose if popup } if $achievement_queue
    $achievement_queue.clear if $achievement_queue
  end
end

#==============================================================================
# ■ Window_AchievementType（成就类型窗口）
#==============================================================================
class Window_AchievementType < Window_Selectable
  def initialize(x, y, width, height)
    super
    refresh
    self.index = 0
  end

  # 刷新类型列表（从所有成就中提取 :type 并去重排序）
  def refresh
    # 计算每个 type 的优先级：取该 type 下所有成就中最小的 type_priority
    type_priority_map = {}
    $game_achievements.each_value do |ach|
      next if ach.is_a?(Integer)
      next if ach[:hidden] && !ach[:unlocked]
      t = ach[:type]
      p = ach[:type_priority] || 0   # 如果个别成就漏了 type_priority，默认当 0 处理
      if type_priority_map.key?(t)
        type_priority_map[t] = p if p < type_priority_map[t]
      else
        type_priority_map[t] = p
      end
    end

    # 排序：优先级小的在前，优先级相同再按类型字符串的字母序
    @types = type_priority_map.keys.sort_by { |type| [type_priority_map[type], type] }

    contents.clear
    @types.each_with_index do |type, i|
      rect = item_rect(i)
      draw_text(rect, type, 1)
    end
  end

  def item_max
    @types ? @types.size : 0
  end

  # 当前选中的类型字符串
  def current_type
    @types[@index] if @types
  end

  def item_rect(index)
    rect = Rect.new(0, 0, contents_width, line_height)
    rect.y = index * line_height
    rect
  end
end


#==============================================================================
# ■ Window_AchievementList(用来显示具体成就)
#==============================================================================
class Window_AchievementList < Window_Selectable
  ITEM_HEIGHT = 64
  SORT_TYPE = ["已解锁在前","未解锁在前","高品质在前","低品质在前",
                "解锁时间早在前","解锁时间晚在前"]
  attr_accessor :filter_type       # 当前过滤类型

  def initialize(x, y, width, height)
    super
    @filter_type = nil
    @data = []
    # 0为已解锁优先，1为未解锁优先，2为高品质优先，3为低品质优先
    # 4为解锁时间早的在前，5为解锁时间晚的在前
    @sort_type = 0   
    @type_max = 6
    self.index = 0
    refresh
  end
  
  # 新增：头部高度，用于显示排序信息
  def header_height
    40
  end
  
  

  # 根据 filter_type 更新内部数据数组 @data
  def update_data
    raw_data = if @filter_type.nil?
                 $game_achievements.select { |_, v| v.is_a?(Hash) }.to_a
               else
                 $game_achievements.select { |_, ach|   ach.is_a?(Hash) && ach[:type] == @filter_type}.to_a
               end
    # 过滤隐藏成就
    raw_data.reject! { |_, ach| ach[:hidden] && !ach[:unlocked] }

    @data = raw_data.sort_by do |_, ach|
      case @sort_type
      when 0
        # 已解锁优先（解锁的排前面）
        ach[:unlocked] ? 0 : 1
      when 1
        # 未解锁优先
        ach[:unlocked] ? 1 : 0
      when 2
        # 高品质优先（level 数值越小品质越高，nil 排最后）
        ach[:level] || Float::INFINITY
      when 3
        # 低品质优先（level 数值越大品质越低，nil 排最后）
        ach[:level] ? -ach[:level] : Float::INFINITY
      when 4
        # 解锁时间早的在前，未解锁在后
        if ach[:unlocked] && ach[:time] && !ach[:time].empty?
          [0, parse_time_str(ach[:time]).to_i]
        else
          [1, Float::INFINITY]
        end
      when 5
        # 解锁时间晚的在前，未解锁在后
        if ach[:unlocked] && ach[:time] && !ach[:time].empty?
          [0, -parse_time_str(ach[:time]).to_i]
        else
          [1, Float::INFINITY]
        end
      end
    end
  end
  
  def update
    super
    # 按下shift键，转化成就排序方式
    if Input.trigger?(:SHIFT)
      @sort_type = (@sort_type + 1) % @type_max
      refresh
      self.index = 0
    end
    # 按下空格键且该成就未被解锁则进入分支判断
    if Input.trigger?(:Z) 
      key = current_key
      if key && !$game_achievements[key][:unlocked]
        if $achievement_tracking.include?(key)
          untrack_achievement(key)
        else
          track_achievement(key)
        end
      end
      refresh
    end
  end

  # 在类的 private 区域添加时间解析方法（如果没有 private 区域就直接放在类里）
  def parse_time_str(str)
    # 解析 "YYYY-MM-DD HH:MM:SS" 格式的字符串
    parts = str.scan(/\d+/).map(&:to_i)
    Time.local(*parts)  # parts: [年, 月, 日, 时, 分, 秒]
  rescue
    Time.local(2000, 1, 1)  # 解析失败时返回一个较早的时间，避免崩溃
  end
  
  # 项目最大数（基于过滤后的数据）
  def item_max
    return 0 if @data.nil?
    @data.size
  end

  # 告诉父类行高为 64
  def line_height
    ITEM_HEIGHT
  end

  # 当前成就的键（基于 @data）
  def current_key
    @data[@index] ? @data[@index][0] : nil
  end

  # 当前成就的数据（基于 @data）
  def current_data
    @data[@index] ? @data[@index][1] : nil
  end

  # 刷新绘制
  def refresh
    return unless $game_achievements
    update_data
    # 总高度 = 头部高度 + 所有项目高度
    total_height = header_height + item_max * line_height
    # 确保至少和窗口可视区域一样大，以便背景填充
    total_height = [total_height, self.height - standard_padding * 2].max
    self.contents = Bitmap.new(contents_width, total_height)

    # 绘制排序提示
    draw_sort_header

    @data.each_with_index do |(key, data), i|
      draw_achievement_item(i,key ,data)
    end
  end
  
  def draw_sort_header
    # 背景区域填充
    header_rect = Rect.new(0, 0, contents_width, header_height / 2)
    # 可选绘制背景色，比如暗灰色
    contents.fill_rect(header_rect, Color.new(0, 0, 0, 160))

    # 设置字体
    contents.font.size = 18  # 略小
    contents.font.color = text_color(Champion::DescripColor)
    sort_text = SORT_TYPE[@sort_type] || "未知排序"
    # 居中绘制
    contents.draw_text(header_rect, sort_text, 1)

    # 可以绘制提示语 "按Shift切换"
    right_rect = Rect.new(contents_width - 150, 0, 150, header_height / 2)
    contents.font.size = 14
    contents.draw_text(right_rect, "Shift切换排序", 2)
    
    if Champion::TrackFlag
      # 可以绘制提示语 "按Shift切换"
      track_rect = Rect.new(0, header_height / 2, contents_width, header_height / 2)
      contents.font.size = 18
      contents.draw_text(track_rect, "按D键可追踪/不追踪成就", 1)
    end

    # 恢复默认字体大小，后续绘制可能会覆盖，但每个draw_achievement_item会设置字体大小
  end

  # 绘制单个成就项
  def draw_achievement_item(index, key,data)
    rect = item_rect(index)
    x = rect.x + 4
    y = rect.y
    w = rect.width - 8
    h = rect.height
    
    # 绘制品质边框（如果存在 level_edge） 
    if data[:level_edge]
      edge_bitmap = Cache.champion(data[:level_edge]) rescue nil
      if edge_bitmap
        # 定义边框区域：略微向外扩展，形成边框效果
        edge_rect = Rect.new(x - 2, y - 2, w + 4, h + 4)
        # 使用 stretch_blt 拉伸绘制，保证边框贴合区域
        contents.stretch_blt(edge_rect, edge_bitmap, edge_bitmap.rect)
      end
    end

    # 获取icon的图标
    if data[:unlocked]
      icon_bitmap = Cache.champion(data[:icon]) rescue nil
    else
      icon_bitmap = Cache.champion(data[:locked_icon]) rescue nil
    end

    if icon_bitmap
      dest_rect = Rect.new(x, y + (h - 48) / 2, 48, 48)
      contents.stretch_blt(dest_rect, icon_bitmap, icon_bitmap.rect)
    end

    # 重新分配水平空间：图标后是名称、描述、时间
    name_x = x + 56
    name_w = 100                        # 名称稍微缩减，给时间让路
    time_w = 120                        # 时间列宽 120 像素，够显示完整时间戳
    desc_w = w - name_w - time_w - 12   # 剩余给描述，留点间隔
    desc_x = name_x + name_w + 4
    time_x = desc_x + desc_w + 4

    # 确保不超出窗口
    time_x = [time_x, contents.width - time_w].min

    # 绘制名称
    change_color(text_color(Champion::NameColor), data[:unlocked])
    contents.font.size = Champion::ListNameSize
    contents.draw_text(name_x, y, name_w, h, data[:unlocked] ? data[:name] : data[:locked_name])

    # 绘制描述
    change_color(text_color(Champion::DescripColor), data[:unlocked])
    contents.font.size = Champion::ListDescripSize
    text1 = data[:unlocked] ? data[:description] : data[:locked_description]
    text2 = sprintf("  进度%s / %s",data[:current],data[:progress]) if data[:progress]
    text = text2 ? text1 + text2 : text1
    contents.draw_text(desc_x, y, desc_w, h, text)
    
    # 绘制进度条（仅在未解锁且有 progress 字段时）
    if data[:progress] && !data[:unlocked]
      current = data[:current] || 0
      progress = data[:progress]
      bar_width = (w * current / progress).to_i
      bar_height = 4
      bar_y = y + h - bar_height - 2  # 距离底部2像素
      # 背景灰色
      contents.fill_rect(x, bar_y, w, bar_height, Color.new(80,80,80,200))
      # 前景绿色
      contents.fill_rect(x, bar_y, bar_width, bar_height, text_color(Champion::ForegroundColor))
    end

    

    # 绘制时间（已解锁才画，未解锁留白）
    if data[:unlocked] && data[:time] && !data[:time].empty?
      change_color(text_color(Champion::DescripColor))   # 用描述色或自己换
      contents.font.size = Champion::ListTimeSize
      contents.draw_text(time_x, y, time_w, h, data[:time], 0)  # 右对齐比较好看
    end
    
    # 绘制品质
    if data[:level_name]
      level_color = data[:level_color] ? data[:level_color] : Champion::ListLevelColor
      change_color(text_color(level_color))
      contents.font.size = Champion::ListLevelSize
      contents.draw_text(rect.x/2, y - 20, time_w, h, data[:level_name], 0)
    end
    
    # 在左下角绘制追踪标记
    if !data[:unlocked] && $achievement_tracking.include?(key)
      rect = item_rect(index)
      # 使用系统默认颜色（0号色，白色）
      change_color(text_color(0))
      # 字体大小设为系统默认（例如 16 像素），不提供配置
      contents.font.size = 16
      # 绘制位置：左下角，离左边缘 4 像素，离底边 4 像素
      text = "追踪中"
      text_width = contents.text_size(text).width
      x = rect.x + 4
      y = rect.y + rect.height - contents.font.size - 2
      contents.draw_text(x, y, text_width, contents.font.size, text)
    end
  
  end
  
  


  # 固定高度，索引决定位置
  def item_rect(index)
    rect = Rect.new(0, 0, contents_width, line_height)
    rect.y = index * line_height + header_height
    rect
  end

  def standard_padding
    12
  end

  # 更新帮助窗口
  def update_help
    @help_window.refresh if @help_window
  end
end
#==============================================================================
# ■ Window_AchievementCommand (成就入口命令窗口)
#==============================================================================
class Window_AchievementCommand < Window_Command
  def initialize
    # 先计算窗口大小，再根据大小居中
    w = 200
    h = fitting_height(2)
    x = (Graphics.width - w) / 2
    y = (Graphics.height - h) / 2
    super(x, y)
    self.width = w
    self.height = h
    create_contents
    refresh
  end

  def make_command_list
    add_command("查看成就", :view)
    add_command("成就商店", :shop) if Champion::ShopFlag
  end
end
#==============================================================================
# ■ Scene_Achievement (展示成就和成就商店)
#==============================================================================
class Scene_Achievement < Scene_MenuBase
  def start
    super
    create_background
    
    if Champion::ShopFlag
      # 命令窗口
      @command_window = Window_AchievementCommand.new
      @command_window.set_handler(:view, method(:command_view))
      @command_window.set_handler(:shop, method(:command_shop)) 
      @command_window.set_handler(:cancel, method(:return_scene))
    end

    # 帮助窗口
    @help_window = Window_AchievementHelp.new
    @help_window.visible = false

    # 类型窗口
    @type_window = Window_AchievementType.new(
      0, @help_window.height,
      Graphics.width, Graphics.height - @help_window.height
    )
    @type_window.visible = false
    @type_window.set_handler(:ok, method(:on_type_ok))
    @type_window.set_handler(:cancel, method(:return_scene)) 
    @type_window.set_handler(:cancel, method(:on_type_cancel)) if Champion::ShopFlag
    

    # 成就列表窗口
    @list_window = Window_AchievementList.new(
      0, @help_window.height,
      Graphics.width, Graphics.height - @help_window.height
    )
    @list_window.help_window = @help_window
    @list_window.visible = false

    if Champion::ShopFlag
      @command_window.activate
    else
      # 直接进入查看成就界面
      @help_window.visible = true
      @help_window.category = nil
      @help_window.refresh
      @type_window.visible = true
      @type_window.activate
      # 重设取消为直接返回场景
      
    end
  end

  # 选择“查看成就”
  def command_view
    @command_window.deactivate
    @command_window.visible = false

    @help_window.visible = true
    @help_window.category = nil       # 显示全部成就进度
    @help_window.refresh

    @type_window.visible = true
    @type_window.activate
  end

  # 选择“成就商店”
  def command_shop
    # 呼叫商店
    SceneManager.call(Scene_AchievementShop)
  end


  # 从类型窗口按取消，返回命令窗口
  def on_type_cancel
    @type_window.deactivate
    @type_window.visible = false
    @help_window.visible = false
    
    if Champion::ShopFlag
      @command_window.activate
      @command_window.visible = true
    end
  end

  # 选择某个成就类型
  def on_type_ok
    type = @type_window.current_type
    return unless type

    @help_window.category = type
    @help_window.refresh

    @list_window.filter_type = type
    @list_window.refresh
    @list_window.index = 0
    @list_window.activate
    @list_window.visible = true

    @type_window.deactivate
    @type_window.visible = false
    @list_window.set_handler(:cancel, method(:on_list_cancel))
  end

  # 从成就列表返回类型选择
  def on_list_cancel
    @help_window.category = nil
    @help_window.refresh

    @list_window.deactivate
    @list_window.visible = false

    @type_window.activate
    @type_window.visible = true
    if Champion::ShopFlag
      # 确保类型窗口取消时返回命令窗口
      @type_window.set_handler(:cancel, method(:on_type_cancel))
    else
      @type_window.set_handler(:cancel, method(:return_scene)) 
    end
  end

  def terminate
    super
    @command_window.dispose if @command_window
    @list_window.dispose
    @type_window.dispose if @type_window
    @help_window.dispose if @help_window
  end
end

#==============================================================================
# ■ Scene_Menu (菜单中可查看成就成就)
#==============================================================================
class Scene_Menu < Scene_MenuBase
  #--------------------------------------------------------------------------
  # ● 生成指令窗口
  #--------------------------------------------------------------------------
  alias champion_create_command_window create_command_window
  def create_command_window
    champion_create_command_window
    @command_window.set_handler(:achievement, method(:command_achievement))
  end

  def command_achievement
    SceneManager.call(Scene_Achievement)
  end
end

#==============================================================================
# ■ Window_MenuCommand (菜单中可查看成就成就)
#==============================================================================
class Window_MenuCommand < Window_Command
  #--------------------------------------------------------------------------
  # ● 独自添加指令用
  #--------------------------------------------------------------------------
  alias champion_add_original_commands add_original_commands
  def add_original_commands
    add_command(Vocab::Champion, :achievement, champion_enabled) if Champion::Menu
  end
  #--------------------------------------------------------------------------
  # ● 获取成就的有效状态
  #--------------------------------------------------------------------------
  def champion_enabled
    # 先写个东西作为占位符再说
    $game_party.exists
  end
end

#==============================================================================
# ■ Scene_Title (标题中可查看成就成就)
#==============================================================================
class Scene_Title < Scene_Base
  #--------------------------------------------------------------------------
  # ● 生成指令窗口
  #--------------------------------------------------------------------------
  alias champion_create_command_window create_command_window
  def create_command_window
    champion_create_command_window
    @command_window.set_handler(:achievement, method(:command_achievement))
  end

  def command_achievement
    SceneManager.call(Scene_Achievement)
  end
end
#==============================================================================
# ■ Window_TitleCommand (标题中可查看成就成就)
#==============================================================================
class Window_TitleCommand < Window_Command
  #--------------------------------------------------------------------------
  # ● 生成指令窗口
  #--------------------------------------------------------------------------
  alias champion_make_command_list make_command_list
  def make_command_list
    champion_make_command_list
    add_command(Vocab::Champion, :achievement) if Champion::Title
  end
end

#==============================================================================
# ■ Window_AchievementHelp 成就帮助窗口（显示进度条） 
#==============================================================================
class Window_AchievementHelp < Window_Selectable
  attr_accessor :category   # 当前的分类


  #--------------------------------------------------------------------------
  # ● 初始化
  #--------------------------------------------------------------------------
  def initialize
    super(0, 0, Graphics.width, fitting_height(4))   # 高度可容纳三行文字
    @category = nil
    refresh
  end

  #--------------------------------------------------------------------------
  # ● 刷新（计算并绘制）
  #--------------------------------------------------------------------------
  def refresh
    contents.clear
    return unless $game_achievements
    
    target_achievements = if @category.nil?
                        $game_achievements.select { |_, v| v.is_a?(Hash) }  # 只要哈希类型（成就条目）
                      else
                        $game_achievements.select { |_, v| v.is_a?(Hash) && v[:type] == @category }
                      end
    # ↓↓↓ 新增：过滤隐藏成就 ↓↓↓
    target_achievements.reject! { |_, ach| ach[:hidden] && !ach[:unlocked] }
    # ↑↑↑ 如果成就设了hidden且没解锁，就从列表中移除 ↑↑↑

    total = target_achievements.size
    unlocked = target_achievements.count { |_k, v| v[:unlocked] }
    per = total <= 0 ? 0 :(unlocked*100/total).round
    
    change_color(text_color(0))
    
    # 文字也跟着变
    type_name = @category ? @category : "全部"
    # 绘制文字如：“全部成就进度：5 / 20 ”
    text = sprintf("%s进度：%d / %d   ", type_name, unlocked, total)
    
    change_color(text_color(Champion::ProgressColor))
    draw_text(0, 0, contents.width, line_height, text, 1)   # 居中显示
    
     # 绘制评价（在第二行）
    y = line_height
    text = sprintf("%s", champion_rank(per) )
    
    change_color(text_color(Champion::RankColor))
    draw_text(0, y, contents.width, line_height, text, 1)
    
    # 绘制百分比（在第三行）
    y = line_height * 2
    if Champion::ShopFlag
      text = sprintf("已完成 %d %%       成就点数 %d ", per ,$game_achievements[:champion_points])
    else
      text = sprintf("已完成 %d %% ", per )
    end
  
    change_color(text_color(Champion::PercentColor))
    draw_text(0, y, contents.width, line_height, text, 1)
    
    # 绘制进度条（在第四行）
    y = line_height * 3
    bar_width = contents.width - 20
    bar_height = line_height - 8
    filled_width = (bar_width * unlocked / [total, 1].max).to_i

    # 背景（灰色）
    contents.fill_rect(10, y + 2, bar_width, bar_height, Color.new(80, 80, 80, 200))
    # 前景（绿色）
    contents.fill_rect(10, y + 2, filled_width, bar_height, text_color(Champion::ForegroundColor))   # 使用游戏默认绿色
  end

  #--------------------------------------------------------------------------
  # ● 获取评价
  #--------------------------------------------------------------------------
  def champion_rank(per)
    Champion::RankHash.each_key{|k|
    return Champion::RankHash[k] if per >= k
    }
  end
end


#==============================================================================
# ■ Window_AchievementShopCategory（成就商店分类窗口）
#==============================================================================
class Window_AchievementShopCategory < Window_HorzCommand
  def initialize
    super(0, 0)
    activate
    select(0)
  end

  def window_width; Graphics.width; end
  def col_max; 3; end

  def make_command_list
    add_command("物品", :item)
    add_command("武器", :weapon)
    add_command("护甲", :armor)
  end
end

#==============================================================================
# ■ Window_AchievementShopBuy（成就商店购买列表）
#==============================================================================
class Window_AchievementShopBuy < Window_Selectable
  attr_reader :goods

  def initialize(x, y, width, height)
    @category = :item
    @data = []          # ★ 提前初始化，防止 nil
    super
    refresh
  end

  # 切换分类
  def category=(category)
    return if @category == category
    @category = category
    refresh
    self.index = 0
  end

  def item_max; @data.size; end

  # 返回当前选中商品 { item: 物品对象, price: 单价 }
  def item
    @data[self.index]
  end

  # 生成商品列表（只包含对应分类且有数据库条目的商品）
  def make_item_list
    @data = []
    Champion::GOODS.each do |goods|
      next unless goods[:type] == @category
      case @category
      when :item
        item = $data_items[goods[:id]]
      when :weapon
        item = $data_weapons[goods[:id]]
      when :armor
        item = $data_armors[goods[:id]]
      end
      next unless item
      @data.push({:item => item, :price => goods[:price]})
    end
  end

  def refresh
    make_item_list
    create_contents
    draw_all_items
  end

  def draw_item(index)
    data = @data[index]
    item = data[:item]
    price = data[:price]
    rect = item_rect(index)
    rect.width -= 4
    # 绘制物品图标、名字
    draw_item_name(item, rect.x, rect.y, true, rect.width - 80)
    # 绘制价格
    change_color(points_color, $game_achievements[:champion_points] >= price)
    draw_text(rect, price.to_s, 2)
    change_color(normal_color)
  end

  def points_color
    text_color(3)  # 系统 3 号色（默认为绿色）
  end

  def update_help
    @help_window.set_item(item ? item[:item] : nil)
  end
end

#==============================================================================
# ■ Window_AchievementShopNumber（成就商店数量输入）
#==============================================================================
class Window_AchievementShopNumber < Window_ShopNumber      
  attr_reader :number
  attr_reader :item
  attr_reader :price                # 暴露单价给外部
  # 直接复用 Window_ShopNumber，仅覆盖货币显示
  def currency_unit
    "成就点"
  end

  # 覆盖绘制总价的方法，改为显示成就点数与总价
  def draw_total_price
    rect = Rect.new(cursor_x - 28, 152, 200, contents.font.size)
    draw_currency_value($game_achievements[:champion_points], @price, rect.x + 80, rect.y, rect.width - 80)
  end
end

#==============================================================================
# ■ Scene_AchievementShop（成就商店场景）
#==============================================================================
class Scene_AchievementShop < Scene_MenuBase
  def start
    super
    create_help_window
    create_points_window
    create_category_window
    create_buy_window
    create_number_window
    create_status_window
    # 初始只显示分类窗口和点数，隐藏购买列表
    @buy_window.hide
    @number_window.hide
    @status_window.hide
  end

  # 成就点数窗口
  def create_points_window
    @points_window = Window_Base.new(0, @help_window.height, Graphics.width, 56)
    @points_window.draw_text(0, 0, @points_window.contents_width, 24, "持有成就点：#{points}", 2)
  end

  def points
    $game_achievements[:champion_points] || 0
  end

  # 分类窗口
  def create_category_window
    @category_window = Window_AchievementShopCategory.new
    @category_window.y = @points_window.y + @points_window.height
    @category_window.set_handler(:item,    method(:on_category_ok))
    @category_window.set_handler(:weapon,  method(:on_category_ok))
    @category_window.set_handler(:armor,   method(:on_category_ok))
    @category_window.set_handler(:cancel,  method(:return_scene))
  end

  # 购买列表窗口（左半边）
  def create_buy_window
    wy = @category_window.y + @category_window.height
    wh = Graphics.height - wy
    @buy_window = Window_AchievementShopBuy.new(0, wy, Graphics.width / 2, wh)
    @buy_window.help_window = @help_window
    @buy_window.set_handler(:ok,     method(:on_buy_ok))
    @buy_window.set_handler(:cancel, method(:on_buy_cancel))
  end

  # 数量输入窗口（覆盖在购买列表上，宽度与购买列表相同）
  def create_number_window
    @number_window = Window_AchievementShopNumber.new(0, @buy_window.y, @buy_window.width)
    @number_window.set_handler(:ok,     method(:on_number_ok))
    @number_window.set_handler(:cancel, method(:on_number_cancel))
  end

  # 状态窗口（右半边）
  def create_status_window
    wx = @buy_window.width
    ww = Graphics.width - wx
    @status_window = Window_ShopStatus.new(wx, @buy_window.y, ww, @buy_window.height)
    @status_window.viewport = @viewport
  end

  # 选择分类后，显示购买列表和状态窗口
  def on_category_ok
    @category_window.deactivate
    @buy_window.category = @category_window.current_symbol
    @buy_window.show.activate
    @status_window.show
    @status_window.item = @buy_window.item ? @buy_window.item[:item] : nil
  end

  # 购买列表取消 → 返回分类窗口
  def on_buy_cancel
    @buy_window.hide
    @status_window.hide
    @category_window.activate
  end

  # 购买确定 → 弹出数量输入
  def on_buy_ok
    @item_data = @buy_window.item
    item = @item_data[:item]
    price = @item_data[:price]
    max = max_buy(item, price)
    # ★ 如果可购买数量为 0，直接阻止，不进入数量窗口
    if points < price
      Sound.play_buzzer
      @buy_window.activate
    else
      @buy_window.hide
      @status_window.show
      @status_window.item = item
      @number_window.set(item, max, price, "成就点")
      @number_window.show.activate
    end
    
    
  end

  # 计算最大可购买数量（考虑点数上限和物品持有上限）
  def max_buy(item, price)
    item_max = $game_party.max_item_number(item)
    current = $game_party.item_number(item)
    can_carry = item_max - current
    price > 0 ? [can_carry, points / price].min : can_carry
  end

  # 数量确认 → 执行购买
  def on_number_ok
    quantity = @number_window.number
    price = @number_window.price * quantity
    return Sound.play_buzzer if points < price
    
    Sound.play_shop
    
    $game_achievements[:champion_points] -= price
    $game_party.gain_item(@number_window.item, quantity)
    DataManager.save_achievements

    # 刷新商店界面
    @points_window.contents.clear
    @points_window.draw_text(0, 0, @points_window.contents_width, 24, "持有成就点：#{points}", 2)
    @number_window.hide.deactivate
    @buy_window.refresh
    @buy_window.show.activate
    @status_window.item = @buy_window.item ? @buy_window.item[:item] : nil
  end

  # 数量取消 → 返回购买列表
  def on_number_cancel
    @number_window.hide.deactivate
    @buy_window.show.activate
    @status_window.item = @buy_window.item ? @buy_window.item[:item] : nil
  end
end