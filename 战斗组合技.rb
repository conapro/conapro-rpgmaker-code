#==============================================================================
# ■ RGSS3 战斗组合技 Ver1.07 by conapro （重构版）
#------------------------------------------------------------------------------
# 让单位能释放组合技能
# 在相应技能中填入<组合技发动所需人数:N> N为所需要的组合技能人数
# 即可以实现技能需要多人联动才能释放的效果
#
# 重构要点：
#  - 将敌我双方的组合技数据合并到 BattleManager.team_skills 中
#  - 使用 :party 和 :troop 符号区分阵营，消除冗余方法
#------------------------------------------------------------------------------
# ver 1.01
# 在deepseek的帮助下，成功重构代码并且将组合技伤害计算公式改为全人员共同属性计算
#------------------------------------------------------------------------------
# ver 1.02
# 增加了敌人反击时会反击所有发动组合技能的单位，而非单个单位，而且伤害会分担
#------------------------------------------------------------------------------
# ver 1.03
# 魔法反射伤害也会被正常分担了
#------------------------------------------------------------------------------
# ver 1.04
# 增加了组合技判定，单位将有异常状态检查，并分为严格模式和宽松模式
#------------------------------------------------------------------------------
# ver 1.05
# 增加了组合技释放模式，分为单组合技释放（一次只能放一个组合技能）和多组合技释放（允
# 许一次性参加多个组合技能释放）
#------------------------------------------------------------------------------
# ver 1.06
# 增加了组合技能判定，正在发动的组合技不再允许释放，且会绘制提示文字
#------------------------------------------------------------------------------
# ver 1.07
# 解决了与我的特殊反击插件的兼容性问题
#==============================================================================

module TeamSkill
  # 组合技判定模式：
  #   true  = 严格模式：只要单位在准备过程中进入过异常状态，立刻被踢出组合技队列。
  #   false = 宽松模式：只在最终释放前一刻进行全员状态检查，中间过程不计较。
  STRICT_CHECK = true # 默认推荐宽松模式，更符合一般游戏体验
  
  # 组合技能释放模式：
  #   true = 单个组合：单位只能参加一个组合技能的释放
  #   false = 多个组合：单位可以同时参加多个组合技能的释放
  SINGLE_TEAM_SKILL = true
end

class << BattleManager
  attr_accessor :current_team_skill_item
  attr_accessor :current_team_skill_user
  attr_accessor :counter_share_flag
  attr_accessor :counter_share_count
  attr_accessor :team_skill_flag
  #--------------------------------------------------------------------------
  # 返回统一存储的组合技数据 Hash
  # 结构：{ 技能对象 => { party: [actor, ...], troop: [enemy, ...] } }
  #--------------------------------------------------------------------------
  def team_skills
    @team_skills ||= {}
  end

  #--------------------------------------------------------------------------
  # ● 成员变量的初始化（别名）
  #--------------------------------------------------------------------------
  alias team_skill_init_members init_members
  def init_members
    team_skill_init_members
    @team_skills = {}
    @team_skill_flag = false
    @current_team_skill_item = nil
    @current_team_skill_user = nil
    @counter_share_flag = false
    @counter_share_count = 0
  end

  #--------------------------------------------------------------------------
  # ● 更新组合技参与单位，并返回是否满足人数要求
  #--------------------------------------------------------------------------
  def update_team_skills(item, man_need, user)
    # 根据阵营确定使用的键
    key = user.actor? ? :party : :troop

    # 初始化技能对应的数据表
    team_skills[item] ||= { party: [], troop: [] }
    participants = team_skills[item][key]
    
    
    # 单组合模式：如果用户已经在其他队列，直接返回（不加入）
    if TeamSkill::SINGLE_TEAM_SKILL
      already_in_other = team_skills.any? do |other_item, parts|
        other_item != item && parts[key].include?(user)
      end
      return if already_in_other
    end
    
    
    if TeamSkill::STRICT_CHECK
      # 【严格模式】每次有单位尝试参与组合技时，全面清洗所有参与者，
      # 任何状态不合格的人会被直接踢出，再无机会。
      participants.select! { |u| team_skill_member_valid?(u, item) }
    end

    
    # 如果当前行动者通过检查，才允许加入
    if !user.dead? && !participants.include?(user)
      # 在严格模式下，这里再做一次检查
      if TeamSkill::STRICT_CHECK
        participants << user if team_skill_member_valid?(user, item)
      else
        participants << user
      end
    end

    # 判断是否达到发动人数
    @team_skill_flag = participants.size >= man_need
  end

  #--------------------------------------------------------------------------
  # ● 重置已经发动过的组合技参与列表（按阵营）
  #--------------------------------------------------------------------------
  def reset_used_team_skill(item, user)
    key = user.actor? ? :party : :troop
    if team_skills[item]
      team_skills[item][key].clear
    end
  end
  #--------------------------------------------------------------------------
  # 检查组合技参与者是否处于有效状态（抽出为独立方法，方便复用）
  #--------------------------------------------------------------------------
  def team_skill_member_valid?(unit, item)
    !unit.dead? &&                     # 没死
    !unit.confusion? &&                # 没混乱（不分敌我地乱打）
    unit.movable? &&                   # 能行动（排除睡眠、眩晕、麻痹等）
    !unit.skill_type_sealed?(item.stype_id) # 组合技的技能类型没被封
  end
  #--------------------------------------------------------------------------
  # ● 即时清洗所有组合技队列中的无效成员（严格模式专用）
  #    返回 [被踢出单位, 对应技能] 的数组
  #--------------------------------------------------------------------------
  def purge_invalid_team_members
    purged = []
    @team_skills.each do |item, participants|
      [:party, :troop].each do |key|
        next if participants[key].empty?
        original = participants[key].dup
        participants[key].select! { |u| team_skill_member_valid?(u, item) }
        (original - participants[key]).each { |u| purged << [u, item] }
      end
    end
    purged
  end
end

class Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 检查技能的使用条件
  #--------------------------------------------------------------------------
  alias team_skill_skill_conditions_met? skill_conditions_met?
  def skill_conditions_met?(skill)
    if skill.is_a?(RPG::Skill) && skill.note =~ /<组合技发动所需人数:\d+>/
      # 基础检查：本技能是否已经加入过
      return false if team_skill_already_joined?(skill)
      # 单组合模式检查：是否已经加入了其他组合技
      if TeamSkill::SINGLE_TEAM_SKILL
        return false if team_skill_any_other_joined?(skill)
      end
    end
    team_skill_skill_conditions_met?(skill)
  end

  #--------------------------------------------------------------------------
  # ● 检查本单位是否已在指定组合技的队列中
  #--------------------------------------------------------------------------
  def team_skill_already_joined?(skill)
    participants = BattleManager.team_skills[skill]
    return false unless participants
    key = actor? ? :party : :troop
    participants[key].include?(self)
  end
  #--------------------------------------------------------------------------
  # ● 检查是否已经加入了除当前技能外的其他组合技
  #--------------------------------------------------------------------------
  def team_skill_any_other_joined?(skill)
    BattleManager.team_skills.each do |other_skill, participants|
      next if other_skill == skill  # 跳过自己
      key = actor? ? :party : :troop
      return true if participants[key].include?(self)
    end
    false
  end
end

class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 应用技能／物品的效果
  #--------------------------------------------------------------------------
  alias team_skill_item_apply item_apply
  def item_apply(user, item)
    if BattleManager.counter_share_flag && BattleManager.counter_share_count > 0
      damage = item.damage
      orig_formula = damage.formula.dup
      # 将公式修改为 "(原公式) / 人数"
      damage.formula = "(#{orig_formula}).to_f / #{BattleManager.counter_share_count}"

      team_skill_item_apply(user, item)
      # 恢复原公式
      damage.formula = orig_formula

    else
      team_skill_item_apply(user, item)
    end
  end
end

class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 使用技能／物品
  #--------------------------------------------------------------------------
  alias team_skill_use_item use_item
  def use_item
    if @subject.current_action
      item = @subject.current_action.item
      if item.note =~ /<组合技发动所需人数:(\d+)>/ && item.is_a?(RPG::Skill)
        man_need = $1.to_i
        BattleManager.update_team_skills(item, man_need, @subject)

        unless BattleManager.team_skill_flag
          key = @subject.actor? ? :party : :troop
          participants = BattleManager.team_skills[item] ? (BattleManager.team_skills[item][key] || []) : []
          ready_names = participants.map(&:name).join("、")
          @log_window.display_use_item(@subject, item)
          3.times { @log_window.wait }
          @log_window.add_text(sprintf("已准备：%s", ready_names)) unless ready_names.empty?
          3.times { @log_window.wait }
          @log_window.add_text(sprintf("%s组合技人数不足，暂时无法发动（还需%d人）", item.name, man_need-participants.size))
          10.times { @log_window.wait }
          return
        end



        # ----- 组合技发动：属性合计化处理 -----
        key = @subject.actor? ? :party : :troop
        participants = BattleManager.team_skills[item][key]
        original_participants = participants.dup

        # 过滤出当前有效的参与者
        participants.select! { |u| BattleManager.team_skill_member_valid?(u, item) }

        # 显示被踢出者的信息（如有）
        (original_participants - participants).each do |u|
          camp = u.actor? ? "我方" : "敌方"
          @log_window.add_text(sprintf("%s【%s】因状态异常退出组合技【%s】！", camp, u.name, item.name))
          2.times { @log_window.wait }
        end

        # 如果过滤后人数不够，直接失败
        if participants.size < man_need
          ready_names = participants.map(&:name).join("、")
          @log_window.display_use_item(@subject, item)
          2.times { @log_window.wait }
          @log_window.add_text(sprintf("已准备：%s", ready_names)) unless ready_names.empty?
          2.times { @log_window.wait }
          @log_window.add_text(sprintf("%s组合技人数不足，暂时无法发动（还需%d人）", item.name, man_need - participants.size))
          6.times { @log_window.wait }
          return
        end
        
        # ----- 人数足够，正式开始属性合计化处理 -----
        battler = @subject
        # 备份原始方法（用于稍后恢复）
        orig_atk = battler.method(:atk)
        orig_def = battler.method(:def)
        orig_mat = battler.method(:mat)
        orig_mdf = battler.method(:mdf)
        orig_agi = battler.method(:agi)
        orig_luk = battler.method(:luk)

        # 先计算总和（此时方法尚未被修改，安全）
        total_atk = participants.inject(0) { |s, u| s + u.atk }
        total_def = participants.inject(0) { |s, u| s + u.def }
        total_mat = participants.inject(0) { |s, u| s + u.mat }
        total_mdf = participants.inject(0) { |s, u| s + u.mdf }
        total_agi = participants.inject(0) { |s, u| s + u.agi }
        total_luk = participants.inject(0) { |s, u| s + u.luk }

        # 重写为返回预计算的总和（无递归风险）
        battler.define_singleton_method(:atk) { total_atk }
        battler.define_singleton_method(:def) { total_def }
        battler.define_singleton_method(:mat) { total_mat }
        battler.define_singleton_method(:mdf) { total_mdf }
        battler.define_singleton_method(:agi) { total_agi }
        battler.define_singleton_method(:luk) { total_luk }

        BattleManager.current_team_skill_item = item
        BattleManager.current_team_skill_user = @subject

        # 执行原始技能处理
        team_skill_use_item

        # 恢复原始方法
        battler.define_singleton_method(:atk) { orig_atk.call }
        battler.define_singleton_method(:def) { orig_def.call }
        battler.define_singleton_method(:mat) { orig_mat.call }
        battler.define_singleton_method(:mdf) { orig_mdf.call }
        battler.define_singleton_method(:agi) { orig_agi.call }
        battler.define_singleton_method(:luk) { orig_luk.call }

        return
      end
    end
    team_skill_use_item
  end

  #--------------------------------------------------------------------------
  # ● 发动反击
  #--------------------------------------------------------------------------
  alias team_skill_invoke_counter_attack invoke_counter_attack
  def invoke_counter_attack(target, item)
    if BattleManager.team_skill_flag
      user = BattleManager.current_team_skill_user
      if user
        key = user.actor? ? :party : :troop
        participants = BattleManager.team_skills[BattleManager.current_team_skill_item][key]
        participants = participants.select { |u| !u.dead? } if participants

        if participants && participants.size > 1
          # ─── 安全获取特殊反击技能 ───
          if target.respond_to?(:counter_attack_flag=)
            target.counter_attack_flag = true
            attack_skill = $data_skills[target.attack_skill_id]
            target.counter_attack_flag = false
          else
            attack_skill = $data_skills[target.attack_skill_id]
          end

          # 显示反击信息（只显示一次）
          @log_window.display_counter(target, item)

          # 设置分摊标志，使伤害公式除以参与人数
          BattleManager.counter_share_flag = true
          BattleManager.counter_share_count = participants.size

          # 对每个存活参与者，由敌人(target)发动反击攻击
          participants.each do |participant|
            next if participant.dead?
            attack_skill.repeats.times do 
              participant.item_apply(target, attack_skill) 
              @counter_target = participant if target.respond_to?(:counter_attack_flag=)
              refresh_status
              @log_window.display_action_results(participant, attack_skill)
              break if participant.dead?
            end
          end

          # 清除分摊标志
          BattleManager.counter_share_flag = false
          BattleManager.counter_share_count = 0
          return
        end
      end
    end
    # 默认流程（非组合技或只有1人）
    team_skill_invoke_counter_attack(target, item)
  end
  
  #--------------------------------------------------------------------------
  # ● 反射魔法攻击
  #--------------------------------------------------------------------------
  alias team_skill_invoke_magic_reflection invoke_magic_reflection
  def invoke_magic_reflection(target, item)
    if BattleManager.team_skill_flag
      user = BattleManager.current_team_skill_user
      if user
        key = user.actor? ? :party : :troop
        participants = BattleManager.team_skills[BattleManager.current_team_skill_item][key]
        participants = participants.select { |u| !u.dead? } if participants

        if participants && participants.size > 1
          # 显示反射信息（只显示一次）
          @log_window.display_reflection(target, item)

          # 设置分摊标志，使伤害公式除以参与人数
          BattleManager.counter_share_flag = true
          BattleManager.counter_share_count = participants.size

          # 对每个存活参与者应用反射技能的效果（攻击者是原 @subject，技能不变）
          participants.each do |participant|
            next if participant.dead?
            apply_item_effects(participant, item)
          end

          # 清除分摊标志
          BattleManager.counter_share_flag = false
          BattleManager.counter_share_count = 0
          return
        end
      end
    end
    # 非组合技或只有1人时，执行原反射逻辑
    team_skill_invoke_magic_reflection(target, item)
  end


  #--------------------------------------------------------------------------
  # ● 战斗行动结束时的处理
  #--------------------------------------------------------------------------
  alias team_skill_process_action_end process_action_end
  def process_action_end
    team_skill_process_action_end
    # 严格模式：每次有人行动完，立刻清洗所有组合技队列
    if TeamSkill::STRICT_CHECK
      purged = BattleManager.purge_invalid_team_members
      purged.each do |unit, item|
        camp = unit.actor? ? "我方" : "敌方"
        @log_window.add_text(sprintf("%s【%s】因状态异常退出组合技【%s】！", camp, unit.name, item.name))
        7.times { @log_window.wait }
      end
    end
  
    # 如果刚刚发动了组合技，在动作彻底结束时进行清理
    if BattleManager.team_skill_flag
      item = BattleManager.current_team_skill_item
      user = BattleManager.current_team_skill_user
      if item && user
        BattleManager.reset_used_team_skill(item, user)
      end
      BattleManager.team_skill_flag = false
      BattleManager.current_team_skill_item = nil
      BattleManager.current_team_skill_user = nil
    end
  end
end


class Window_BattleLog < Window_Selectable
  #--------------------------------------------------------------------------
  # ● 显示使用技能／物品（别名）
  #--------------------------------------------------------------------------
  alias team_skill_display_use_item display_use_item
  def display_use_item(subject, item)
    if BattleManager.team_skill_flag
      # 根据阵营取出参与者名称
      key = subject.actor? ? :party : :troop
      participants = BattleManager.team_skills[item] && BattleManager.team_skills[item][key]
      all_name = participants.map(&:name).join("、") if participants

      add_text(all_name + "联合" + item.message1)
      wait

      # 重置已不再此处进行
      return
    end
    team_skill_display_use_item(subject, item)
  end
end

class Window_BattleSkill < Window_SkillList
  #--------------------------------------------------------------------------
  # ● 绘制技能消耗（别名）—— 增加组合技“发动中”显示
  #--------------------------------------------------------------------------
  alias team_skill_draw_skill_cost draw_skill_cost
  def draw_skill_cost(rect, skill)
    # 如果这个技能是组合技，并且当前角色已经加入等待队列，则显示“发动中”
    if skill.is_a?(RPG::Skill) && skill.note =~ /<组合技发动所需人数:\d+>/
      if @actor.team_skill_already_joined?(skill)
        draw_team_skill_waiting_text(rect)
        return
      end
    end
    # 否则走原版（包含冷却脚本自己的显示逻辑，如果有的话）
    team_skill_draw_skill_cost(rect, skill)
  end

  #--------------------------------------------------------------------------
  # ● 绘制“发动中”文本
  #--------------------------------------------------------------------------
  def draw_team_skill_waiting_text(rect)
    change_color(text_color(17))  # 17号色是系统色里的淡黄色，也可以用 crisis_color 等
    draw_text(rect, "发动中", 2)
  end
end