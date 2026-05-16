#==============================================================================
# ■ RGSS3 领域光环 Ver1.18 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
# 本插件可以让你在战斗开始。队友入队、阵亡单位复活、敌人变身时附加特定状态，
# 以此来达到类似于领域生效的效果
# 只有存活和已经出现的单位才可以展开他的领域
# 作为领域的状态建议要在战斗结束时解除，并且解除时间设定为无
#==============================================================================
#  使用说明：
# 【自定义关键字（可选）】
#   标签里的字词可以改成你喜欢的语言。
#   打开脚本最上方的 Domain 模块，修改下面四个常量即可：
#
#   WORD  = "生效领域"   # 标签的识别关键词
#   SELF  = "自"         # 代表使用者自身
#   PARTY = "队"         # 代表己方其他成员（自己除外）
#   TROOP = "敌"       # 代表敌方全体
#
#   示例（改成英文）：
#   SELF  = "Self"
#   PARTY = "Party"
#   TROOP = "Enemy"
#
#   注意：
#   - 关键字不要包含 <、> 或 :，否则会识别错误。
#   - 如果修改，确保较长的关键字不会被较短的关键字抢先匹配。
#     默认已按长度降序排列，可以参考保留。
#
# 【标签格式】
#   在角色、职业、武器、防具、敌人、状态的“备注”栏里写入：
#
#   <修饰符自定义词:状态ID>
#
#   - 修饰符：就是上面 SELF、PARTY、TROOP 中定义的字（可多个组合使用）
#   - 状态ID：数据库里的状态编号，多个用半角逗号分隔
#   - 全角冒号或半角冒号都行
#
# 【参数对应规则】
#   状态ID 从左到右，一一分配给每一个修饰符。
#   状态ID 填 0 则该位置跳过（不执行任何操作）。
#
# 【使用示例】
#   （假设使用默认关键字）
#
#   <自生效领域:4>                → 自己获得 4 号状态
#   <队生效领域:10>               → 除自己外的队友获得 10 号状态
#   <敌生效领域:6>              → 敌方全员获得 6 号状态
#   <敌队生效领域:5,7>          → 敌人得5号状态，队友得7号状态
#   <自自生效领域:11,12>          → 自己同时获得 11、12 号状态
#   <自队敌生效领域:1,2,3>      → 自己得1号，队友得2号，敌人得3号
#
# 【触发时机】
#   - 仅在战斗开始时发动一次，回合结束不会重复发动。
#   - 只要备注栏所在的特性被战斗者持有（装备、状态等），就会生效。
#
# 【注意事项】
#   - 一行写一个标签，多个效果建议分多行。
#   - 状态最终是否能附加，仍取决于目标对该状态的“有效度”设置。
#   - 已战斗不能的单位不会被选为目标（敌方/己方队伍只取存活成员）
#==============================================================================
# ■ 领域介绍（Domain Intro）使用说明
#==============================================================================
# 通过配置 Domain::INTRO 常量，可以为特定“领域名字”设置战斗开始时弹出的介绍文字。
# 介绍会在拥有该领域名字的单位首次触发领域时自动显示一次（整场战斗仅一次）。
#
# 【配置 INTRO 常量】
#   在 Domain 模块内的 INTRO 散列中添加条目，键为领域名字（字符串），
#   值为包含以下键的散列：
#   :name  → 领域名称（可包含 \C[n] 等控制符）
#   :line1 → 第一行说明文字（可包含 \C[n] 等控制符）
#   :line2 → 第二行说明文字（无内容请留空字符串 ""）
#   :line3 → 第三行说明文字（无内容请留空字符串 ""）
#   所有键均为可选，但建议至少包含 :name 与一行文字。
#
# 【绑定到单位】
#   在角色、职业、武器、防具、敌人、状态的“备注”栏里写入：
#   <领域名字:领域名称>
#   例如：<领域名字:怀表枪火>
#   多个领域可写多行，它们会逐个弹出介绍。
#
# 【显示效果】
#   - 战斗开始时，系统会遍历所有存活单位，依次弹出他们拥有的每个领域介绍。
#   - 介绍文字中可以使用 \C[n] 改变颜色（n 为 0~31），\C[0] 恢复默认。
#   - 窗口背景和位置由 Domain::Background 和 Domain::Position 控制。
#
# 【示例配置】
#   INTRO = {
#     "怀表枪火" => {
#       :name  => '白之领域"怀表枪火"',
#       :line1 => '- 敌人无限多动症',
#       :line2 => '',
#       :line3 => '',
#     },
#     "黑之领域" => {
#       :name  => '黑之领域"无限斩击"',
#       :line1 => '- 去死吧',
#       :line2 => '',
#       :line3 => '',
#     },
#   }
#
#   对应备注写法：
#   <领域名字:怀表枪火>
#   <领域名字:黑之领域>
#
# 【注意】
#   - 领域名字必须与 INTRO 中的键完全一致（区分大小写）。
#   - 如果同一个角色或敌人有多个领域名字，介绍将分开弹出。
#   - 如果不想弹出任何介绍，只需不配置 INTRO 或不添加 <领域名字> 标签。
#==============================================================================
# ver 1.00
# 让状态可以附加到指定目标身上，并且可以自由配置生效领域作用范围
#------------------------------------------------------------------------------
# ver 1.01
# 完善领域生效机制，让这个状态不会因为奇怪原因无法生效
#------------------------------------------------------------------------------
# ver 1.10
# 增加领域显示选项，让领域可以在第一次生效时展示
#------------------------------------------------------------------------------
# ver 1.11
# 增加领域介绍选项
#------------------------------------------------------------------------------
# ver 1.13
# 增加窗口配置，可以更改领域生效是否需要单位存活
#------------------------------------------------------------------------------
# ver 1.16
# 增加战斗后一键清除所有领域状态的选择
#------------------------------------------------------------------------------
# ver 1.17
# 增加敌人变身后会重新应用领域的功能
#------------------------------------------------------------------------------
# ver 1.18
# 推翻重写了领域展示模块
#==============================================================================



#----------------------------以下是配置区--------------------------------------
module Domain
  
  WORD = "生效领域"
  
  SELF = "自"
  
  PARTY = "队"
  
  TROOP = "敌"
  
  # 按长度降序排列，保证扫描时优先尝试“敌人”而不是先匹配到“敌”
  MOD_KEYS = [SELF, PARTY, TROOP].sort_by { |k| -k.length }
  MOD_PATTERN = MOD_KEYS.map { |k| Regexp.escape(k) }.join('|')
  
  INTRO = { 
    "怀表枪火" => {
      name:  '白之领域"怀表枪火"',
      line1: '-敌人无限多动症',
      line2: '',
      line3: '',
    },
    "黑之领域" => {
      name:  '黑之领域"无限斩击"',
      line1: '-去死吧',
      line2: '',
      line3: '',
    },
  }
  # 领域触发时播放的se文件
  # 指定顺序为 [SE 名称, 音量, 音高]。
  
  SE       = ["Saint7",80,100]
  
  # 决定是否需要活着才能生效领域
  # true: 单位死亡时移除其领域效果，复活时重新附加
  # false: 领域一旦激活就不受持有者生死影响，仅在战斗结束时清除
  Live = true
  
  # 决定是否战斗结束自动移除领域
  # true: 战斗结束移除所有领域
  # false: 战斗结束不移除，供你自己选择
  RemoveBattleEnd = true
  
  # 领域介绍窗口背景的颜色（0普通 1暗色 2透明）
  Background = 1
  
  # 领域介绍窗口的位置（0上 1中 2下）
  Position = 1
  
end
#----------------------------配置区结束--------------------------------------


class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 定义实例变量
  #--------------------------------------------------------------------------
  attr_accessor :domain_show          # 领域是否已经展示过
  #--------------------------------------------------------------------------
  # ● 初始化对象
  #--------------------------------------------------------------------------
  alias domain_initialize initialize
  def initialize
    domain_initialize
    @domain_show = false
  end
  #--------------------------------------------------------------------------
  # ● 战斗开始处理
  #--------------------------------------------------------------------------
  alias domain_on_battle_start on_battle_start
  def on_battle_start
    domain_on_battle_start
    # 战斗开始时一定展示领域，所以得先将领域展示与否给重置了
    @domain_show = false
  end
  #--------------------------------------------------------------------------
  # ● 战斗结束处理
  #--------------------------------------------------------------------------
  alias domain_on_battle_end on_battle_end
  def on_battle_end
    domain_on_battle_end
    # 战斗结束后也要重置领域展示，防止意外
    @domain_show = false
  end
  #--------------------------------------------------------------------------
  # ● 附加领域
  #--------------------------------------------------------------------------
  def domain_add
     ($game_party.alive_members + $game_troop.alive_members).each do |battler|
      battler.feature_objects.each { |obj| battler.domain_apply(obj) }
    end
  end
  #--------------------------------------------------------------------------
  # ● 解除领域
  #--------------------------------------------------------------------------
  def domain_remove
    feature_objects.each { |obj| domain_erase(obj) }
  end
  #--------------------------------------------------------------------------
  # ● 附加状态
  #--------------------------------------------------------------------------
  alias domain_add_state add_state
  def add_state(state_id)
    domain_add_state(state_id)
    #死了得移除他生效的领域
    if state_id == death_state_id && SceneManager.scene_is?(Scene_Battle) && Domain::Live
      domain_remove
    end
  end
  #--------------------------------------------------------------------------
  # ● 解除状态
  #--------------------------------------------------------------------------
  alias domain_remove_state remove_state
  def remove_state(state_id)
    domain_remove_state(state_id)
    #复活了生效领域  $game_troop.turn_count != 0是为了防止初期展示时直接生效领域的
    if state_id == death_state_id && SceneManager.scene_is?(Scene_Battle) && $game_troop.turn_count != 0
      domain_add
    end
  end
  #--------------------------------------------------------------------------
  # ● 解析特征对象的领域备注
  #    返回数组:  [ [modifiers, params], [modifiers, params], ... ]
  #--------------------------------------------------------------------------
  def domain_parse_note(obj)
    result = []
    obj.note.each_line do |line|
      m = line.match(/<((?:#{Domain::MOD_PATTERN})+)#{Regexp.escape(Domain::WORD)}[：:]([^>]+)>/)
      next unless m
      modifiers = m[1].scan(/#{Domain::MOD_PATTERN}/)
      params    = m[2].split(',')
      result << [modifiers, params]
    end
    result
  end
  #--------------------------------------------------------------------------
  # ● 领域生效
  #--------------------------------------------------------------------------
  def domain_apply(obj)
    domain_parse_note(obj).each do |modifiers, params|
      show_domain
      apply_domain_effect(modifiers, params)
    end
  end
  #--------------------------------------------------------------------------
  # ● 领域消除
  #--------------------------------------------------------------------------
  def domain_erase(obj)
    domain_parse_note(obj).each do |modifiers, params|
      erase_domain_effect(modifiers, params)
    end
  end
  #--------------------------------------------------------------------------
  # ● 展示领域（仅第一次触发时显示介绍）
  #--------------------------------------------------------------------------
  def show_domain
    return if @domain_show
    
    # 准备 SE
    array = Domain::SE
    # 播放 SE
    RPG::SE.new(array[0],array[1],array[2]).play

    show_domain_text(get_intro_keys)

    @domain_show = true
  end
  #--------------------------------------------------------------------------
  # ● 展示领域实际生效
  #--------------------------------------------------------------------------
  def show_domain_text(intro_keys)
    intro_keys.each{|intro_key|
      lines = domain_intro_text(intro_key)
      if lines && !lines.empty?
        $game_message.face_name  = ""    # 无脸图
        $game_message.face_index = 0
        $game_message.background = Domain::Background     # 背景（0普通 1暗色 2透明）
        $game_message.position   = Domain::Position    # 位置（0上 1中 2下）
        lines.each { |line| $game_message.add(line) }
      end
      BattleManager.wait_for_message
    }
  end
  #--------------------------------------------------------------------------
  # ● 获取领域介绍文本（数组，可包含 \C[2] 等控制符）
  #--------------------------------------------------------------------------
  def domain_intro_text(intro_key)
    intro = Domain::INTRO[intro_key]
    
    if intro
      lines = []
      lines << intro[:name] if intro[:name]
      lines << intro[:line1] if intro[:line1] && !intro[:line1].empty?
      lines << intro[:line2] if intro[:line2] && !intro[:line2].empty?
      lines << intro[:line3] if intro[:line3] && !intro[:line3].empty?
      return lines unless lines.empty?
    end
    # 默认无介绍，不弹窗
    nil
  end
  #--------------------------------------------------------------------------
  # ● 获取领域键
  #--------------------------------------------------------------------------
  def get_intro_keys
    intro_keys = []
    feature_objects.each{|obj|
      obj.note.each_line{|l|
        memo = l.scan(/<领域名字[：:](\S+)>/).flatten
        if memo and !memo.empty?
          intro_keys << memo[0]
        end
      }
    }
    intro_keys
  end
  #--------------------------------------------------------------------------
  # ● 领域生效效果
  #--------------------------------------------------------------------------
  def apply_domain_effect(modifiers, params)
    modifiers.each_with_index do |mod, i|
      state_id = params[i].to_i
      next if state_id == 0
      targets = case mod
                when Domain::SELF then [self]
                when Domain::TROOP then opponent_team
                when Domain::PARTY then my_team.reject { |m| m == self }
                end
      targets.each { |t| t.add_state(state_id) } if targets
    end
  end
  #--------------------------------------------------------------------------
  # ● 领域擦除效果
  #--------------------------------------------------------------------------
  def erase_domain_effect(modifiers, params)
    modifiers.each_with_index do |mod, i|
      state_id = params[i].to_i
      next if state_id == 0
      targets = case mod
                when Domain::SELF then [self]
                when Domain::TROOP then opponent_team
                when Domain::PARTY then my_team.reject { |m| m == self }
                end
      targets.each { |t| t.remove_state(state_id) } if targets
    end
  end
  #--------------------------------------------------------------------------
  # ● 己方队伍
  #--------------------------------------------------------------------------
  def my_team
    if enemy?
      $game_troop.alive_members
    else
      $game_party.alive_members
    end
  end
  #--------------------------------------------------------------------------
  # ● 敌方队伍
  #--------------------------------------------------------------------------
  def opponent_team
    if enemy?
      $game_party.alive_members
    else
      $game_troop.alive_members
    end
  end
end

class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 变身(敌人变身要重应用领域)
  #--------------------------------------------------------------------------
  alias domain_transform transform
  def transform(enemy_id)
    domain_remove
    domain_transform(enemy_id)
    # 敌人变身重新展示一遍领域
    @domain_show = false
    domain_add
  end
end    

class Game_Party
  #--------------------------------------------------------------------------
  # ● 角色入队
  #--------------------------------------------------------------------------
  alias domain_add_actor add_actor
  def add_actor(actor_id)
    # 执行原方法
    domain_add_actor(actor_id)
    # 战斗中则刷新领域（通过第一个存活成员调用实例方法）
    if SceneManager.scene_is?(Scene_Battle) 
      battler = $game_party.alive_members.first
      battler.domain_add if battler
    end
  end

end    


class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 处理事件
  #--------------------------------------------------------------------------
  alias domain_process_event process_event
  def process_event
    domain_process_event
    # 仅在战斗开始时执行
    if $game_troop.turn_count == 0
      # 1. 逐个弹出每个单位的每个领域介绍
      ($game_party.alive_members + $game_troop.alive_members).each do |battler|
        battler.get_intro_keys.each do |key|
          lines = battler.domain_intro_text(key)
          if lines && !lines.empty?
            $game_message.face_name   = ""
            $game_message.face_index  = 0
            $game_message.background  = Domain::Background
            $game_message.position    = Domain::Position
            lines.each { |line| $game_message.add(line) }
            
            # 准备 SE
            array = Domain::SE
            # 播放 SE
            RPG::SE.new(array[0],array[1],array[2]).play
            
            wait_for_message          # 每个领域名称介绍完等待关闭
          end
        end
        battler.domain_show = true    # 标记该单位已经展示过，防止重复
      end

      # 2. 所有介绍弹完后，一次性附加所有领域状态
      battler = $game_party.alive_members.first
      battler.domain_add if battler
    end
  end
end

class << BattleManager
  #--------------------------------------------------------------------------
  # ● 战斗结束
  #     result : 结果（0:胜利 1:撤退 2:全灭）
  #--------------------------------------------------------------------------
  alias domain_battle_end battle_end
  def battle_end(result)
    if Domain::RemoveBattleEnd
      ($game_party.members + $game_troop.members).each do |battler|
        battler.domain_remove
      end
    end
    domain_battle_end(result)
  end
end