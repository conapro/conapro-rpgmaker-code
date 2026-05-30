#==============================================================================
# ■ RGSS3 结束后行动 Ver1.20 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者
#------------------------------------------------------------------------------
# 【功能概述】
# 让角色或敌人可以通过备注在回合结束时或自身行动结束时自动发动技能。
# 支持按间隔回合/行动次数冷却、概率触发、单体目标智能选择、范围行动等。
#
# ● 回合结束行动：每经过一定回合数（可随机波动），在回合结束时自动发动。
# ● 行动结束后行动：拥有者自身每次行动结束时计数，满足条件后发动。
# 两种行动类型共用同一套目标选择与发动执行逻辑。
#------------------------------------------------------------------------------
# 【模块配置说明】
#
# ● TurnEndAction::WORD  = "回合结束行动"
#   用于识别“回合结束行动”特征的备注关键字，修改后需同步修改数据库备注。
#
# ● TurnEndAction::WORD2 = "行动结束后行动"
#   用于识别“行动结束后行动”特征的备注关键字。
#------------------------------------------------------------------------------
# 【备注标签一览】
#
# ● <回合结束行动:x,y,z,a,b>
#   写在角色/职业/武器/防具/状态的备注栏。
#   参数：
#     x = 行动者类型 （0=自己 1=所有队友（不含自己） 2=自己与所有队友）
#     y = 发动的技能ID
#     z = 基础间隔回合数
#     a = 间隔波动范围（实际间隔 = z + rand(0..a)），可省略，默认0
#     b = 发动概率（1~100），可省略，默认100
#   例：<回合结束行动:0,20,3,2,50>
#
# ● <行动结束后行动:x,y,z,a,b>
#   同上，但计时方式为“拥有者自身行动次数”，仅在自身行动结束时计数。
#------------------------------------------------------------------------------
# 【范例】
#
# 1. 角色每 3~5 回合结束时，50% 概率对自己使用技能 20（治疗等）：
#    角色备注：<回合结束行动:0,20,3,2,50>
#
# 2. 敌人的每次自身行动结束时，有 80% 概率让全体队友发动技能 25：
#    敌人备注：<行动结束后行动:1,25,1,0,80>
#
# 3. 装备了一件防具后，自己每次行动结束 2 次后，必定与队友一起发动技能 30：
#    防具备注：<行动结束后行动:2,30,2,0,100>
#
# 4. 若技能为单体目标，会自动选择该单位上次行动的目标；若无，
#    则选择敌方/友方队伍中索引最小的存活/死亡单位。
#==============================================================================

module TurnEndAction
  # 回合结束行动识别关键字
  WORD1 = "回合结束行动"
  # 行动结束后行动识别关键字
  WORD2 = "行动结束后行动"
end

class RPG::BaseItem

  #--------------------------------------------------------------------------
  # ● 获取回合结束行动特征列表
  #--------------------------------------------------------------------------
  def turn_end_actions
    result = []
    self.note.each_line do |l|
      memo = l.scan(/<#{TurnEndAction::WORD1}[：:](\S+)>/).flatten
      #数据正常时处理
      if memo != nil && !memo.empty?
        
        data = memo[0].split(/\s*,\s*/)
        
        x = data[0].to_i
        skill_id = data[1].to_i
        interval = data[2].to_i
        variance = data[3] ? data[3].to_i : 0
        prob = data[4] ? data[4].to_i : 100
        
        result.push([x, skill_id, interval, variance, prob])
        
        
      end
    end
    result
  end


  #--------------------------------------------------------------------------
  # ● 获取行动结束后行动特征列表
  #--------------------------------------------------------------------------
  def action_end_actions
    result = []
    self.note.each_line do |l|
      memo = l.scan(/<#{TurnEndAction::WORD2}[：:](\S+)>/).flatten
      #数据正常时处理
      if memo != nil && !memo.empty?
        
        data = memo[0].split(/\s*,\s*/)
        
        x = data[0].to_i
        skill_id = data[1].to_i
        interval = data[2].to_i
        variance = data[3] ? data[3].to_i : 0
        prob = data[4] ? data[4].to_i : 100
        
        result.push([x, skill_id, interval, variance, prob])
        
        
      end
    end
    result
  end
end

class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 汇总当前战斗者拥有的所有回合结束行动特征
  #--------------------------------------------------------------------------
  def turn_end_actions
    result = []
    feature_objects.each{|obj|
    result += obj.turn_end_actions
    }
    result
  end

  #--------------------------------------------------------------------------
  # ● 汇总当前战斗者拥有的所有行动结束后行动特征
  #--------------------------------------------------------------------------
  def action_end_actions
    result = []
    feature_objects.each{|obj|
    result += obj.action_end_actions
    }
    result
  end

  #--------------------------------------------------------------------------
  # ● 设置临时动作为指定技能，并可指定目标索引
  #--------------------------------------------------------------------------
  def set_turn_end_skill(skill_id, target_index = -1)
    @pre_turn_end_actions = @actions.clone
    @actions.clear
    action = Game_Action.new(self, true)
    action.set_skill(skill_id)
    action.target_index = target_index >= 0 ? target_index : -1
    @actions.push(action)
  end

  #--------------------------------------------------------------------------
  # ● 恢复原有的动作队列
  #--------------------------------------------------------------------------
  def after_turn_end_skill
    if movable?
      @actions = @pre_turn_end_actions.clone
    else
      @actions.clear
    end
    @pre_turn_end_actions = nil
  end
end

class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 战斗开始（初始化计数哈希与防递归标志）
  #--------------------------------------------------------------------------
  alias start_turnendaction start
  def start
    @turn_end_counts = {}          # 回合结束计数
    @action_end_counts = {}        # 行动结束计数
    @processing_action_end = false # 防止递归处理
    start_turnendaction
  end

  #--------------------------------------------------------------------------
  # ● 回合结束（处理回合结束行动）
  #--------------------------------------------------------------------------
  alias turn_end_turnendaction turn_end
  def turn_end
    process_turn_end_actions unless @turn_end_processing
    @turn_end_processing = true
    turn_end_turnendaction
    @turn_end_processing = false
  end

  #--------------------------------------------------------------------------
  # ● 处理所有回合结束行动
  #--------------------------------------------------------------------------
  def process_turn_end_actions
    @turn_end_counts ||= {}
    all_battlers = $game_party.battle_members + $game_troop.members
    all_battlers.each do |battler|
      next unless battler.alive?
      actions = battler.turn_end_actions
      next if actions.empty?

      # 获取或初始化计数数组，初始值等于各自的间隔值（含波动）
      counts = @turn_end_counts[battler]
      unless counts
        counts = actions.map { |a| a[2] + rand(a[3] + 1) }
      end

      # 同步长度：新增的特征也要给初始间隔
      if counts.size < actions.size
        (counts.size...actions.size).each do |i|
          counts[i] = actions[i][2] + rand(actions[i][3] + 1)
        end
      elsif counts.size > actions.size
        counts = counts[0, actions.size]
      end

      actions.each_with_index do |(x, skill_id, interval, variance, prob), i|
        counts[i] -= 1
        if counts[i] <= 0
          if prob >= 100 || rand(100) < prob
            execute_turn_end_action(battler, x, skill_id)
            @log_window.clear if @log_window
          end
          # 重置间隔
          counts[i] = interval + rand(variance + 1)
        end
      end
      @turn_end_counts[battler] = counts
    end
  end

  #--------------------------------------------------------------------------
  # ● 行动结束处理（新增行动结束后行动逻辑）
  #--------------------------------------------------------------------------
  alias process_action_end_act_end process_action_end
  def process_action_end
    unless @processing_action_end
      @processing_action_end = true
      process_action_end_actions if @subject && @subject.alive?
      @processing_action_end = false
    end
    process_action_end_act_end
  end

  #--------------------------------------------------------------------------
  # ● 处理当前行动者的行动结束后行动
  #--------------------------------------------------------------------------
  def process_action_end_actions
    battler = @subject
    actions = battler.action_end_actions
    return if actions.empty?

    @action_end_counts ||= {}
    counts = @action_end_counts[battler]
    unless counts
      counts = actions.map { |a| a[2] + rand(a[3] + 1) }
    end

    if counts.size < actions.size
      (counts.size...actions.size).each do |i|
        counts[i] = actions[i][2] + rand(actions[i][3] + 1)
      end
    elsif counts.size > actions.size
      counts = counts[0, actions.size]
    end

    actions.each_with_index do |(x, skill_id, interval, variance, prob), i|
      counts[i] -= 1
      if counts[i] <= 0
        if prob >= 100 || rand(100) < prob
          execute_turn_end_action(battler, x, skill_id)
          @log_window.clear if @log_window
        end
        counts[i] = interval + rand(variance + 1)
      end
    end
    @action_end_counts[battler] = counts
  end

  #--------------------------------------------------------------------------
  # ● 根据 x 的类型决定由谁发动技能
  #--------------------------------------------------------------------------
  def execute_turn_end_action(original, x, skill_id)
    return unless $data_skills[skill_id]
    case x
    when 0  # 自己行动
      perform_action_by(original, skill_id)
    when 1  # 所有队友行动（不包括自己）
      allies = original.friends_unit.alive_members.reject { |m| m == original }
      if allies.empty?
        perform_action_by(original, skill_id)
      else
        allies.each { |ally| perform_action_by(ally, skill_id) }
      end
    when 2  # 自己和所有队友一起行动
      allies = original.friends_unit.alive_members
      allies.each { |ally| perform_action_by(ally, skill_id) }
    end
  end

  #--------------------------------------------------------------------------
  # ● 让指定使用者发动一次技能，自动处理目标选择
  #--------------------------------------------------------------------------
  def perform_action_by(user, skill_id)
    return if user.dead?
    skill = $data_skills[skill_id]
    return unless skill
     return unless user.usable?(skill)   # 若使用者当前无法使用此技能则直接放弃

    target_index = -1
    if skill.for_one?                         # 需要指定单个目标
      if skill.for_opponent?                  # 敌单体
        last_idx = user.last_target_index
        if last_idx && last_idx >= 0
          last_target = user.opponents_unit.smooth_target(last_idx) rescue nil
          if last_target && last_target.alive? &&
             user.opponents_unit.members.include?(last_target)
            target_index = last_idx
          end
        end
        if target_index < 0
          opponent = user.opponents_unit.alive_members.min_by(&:index)
          target_index = opponent ? opponent.index : -1
        end

      elsif skill.for_dead_friend?            # 己方死亡单体
        last_idx = user.last_target_index
        if last_idx && last_idx >= 0
          last_target = user.friends_unit.smooth_target(last_idx) rescue nil
          if last_target && last_target.dead? &&
             user.friends_unit.members.include?(last_target)
            target_index = last_idx
          end
        end
        if target_index < 0
          dead = user.friends_unit.dead_members.min_by(&:index)
          target_index = dead ? dead.index : -1
        end

      elsif skill.for_friend?                 # 己方存活单体
        last_idx = user.last_target_index
        if last_idx && last_idx >= 0
          last_target = user.friends_unit.smooth_target(last_idx) rescue nil
          if last_target && last_target.alive? &&
             user.friends_unit.members.include?(last_target)
            target_index = last_idx
          end
        end
        if target_index < 0
          friend = user.friends_unit.alive_members.min_by(&:index)
          target_index = friend ? friend.index : -1
        end
      end

      return if target_index < 0              # 找不到有效目标就放弃行动
    end

    last_subject = @subject
    @subject = user
    user.set_turn_end_skill(skill_id, target_index)
    use_item
    user.after_turn_end_skill
    @subject = last_subject
  end
end