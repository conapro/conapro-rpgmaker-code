#==============================================================================
# ■ RGSS3 身体互换 Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
#   让战斗中敌人可以发动类似夺舍的技能
#
# 【使用方法】
#   1. 在技能里添加备注<swap_body>即可
#==============================================================================

class Game_Temp
  #--------------------------------------------------------------------------
  # ● 生成身体互换数据
  #--------------------------------------------------------------------------
  def body_swap_data
    @body_swap_data ||= {}
  end
end

class Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 互换身体的属性应用
  #--------------------------------------------------------------------------
  alias body_swap_param param
  def param(pid)
    if body_data_managed?
      return $game_temp.body_swap_data[self][:param][pid]
    end
    body_swap_param(pid)
  end
  #--------------------------------------------------------------------------
  # ● 是否拥有身体互换数据?
  #--------------------------------------------------------------------------
  def body_data_managed?
    $game_temp && $game_temp.body_swap_data.key?(self)
  end
end

class Game_Actor < Game_Battler
  #--------------------------------------------------------------------------
  # ● 特征修正
  #--------------------------------------------------------------------------
  alias body_swap_feature_objects feature_objects
  def feature_objects
    if body_data_managed?
      return $game_temp.body_swap_data[self][:features] 
    end
    body_swap_feature_objects
  end
  #--------------------------------------------------------------------------
  # ● 技能列表（使用 alias 保留原始逻辑）
  #--------------------------------------------------------------------------
  alias body_swap_skills skills
  def skills
    if body_data_managed?
      return $game_temp.body_swap_data[self][:skills].map { |id| $data_skills[id] }.compact
    end
    body_swap_skills
  end
  
  #--------------------------------------------------------------------------
  # ● 名字交换（使用 alias 保留原始逻辑）
  #--------------------------------------------------------------------------
  alias body_swap_name name
  def name
    if body_data_managed?
      return $game_temp.body_swap_data[self][:name]
    end
    body_swap_name
  end
  
end

class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 特征修正
  #--------------------------------------------------------------------------
  alias body_swap_feature_objects feature_objects
  def feature_objects
    if body_data_managed?
      return $game_temp.body_swap_data[self][:features] 
    end
    body_swap_feature_objects
  end
   # ★ 重写 make_actions，身体交换后使用角色的技能池
  alias body_swap_make_actions make_actions
  def make_actions
    if body_data_managed?
      # 先执行原版逻辑（初始化空行动数组等）
      super
      # 拿到交换后的技能 ID 列表
      skill_ids = $game_temp.body_swap_data[self][:skills]
      # 转为技能对象，并只保留当前可用的技能
      usable_skills = skill_ids.map { |id| $data_skills[id] }.compact.select { |sk| usable?(sk) }
      if usable_skills.empty?
        # 没技能可用就用普通攻击
        @actions.each { |a| a.set_attack }
      else
        # 为每个行动槽随机选择一个可用技能（原版逻辑是每个槽独立选择）
        @actions.each do |action|
          skill = usable_skills.sample
          action.set_skill(skill.id)
        end
      end
    else
      # 非交换状态，完全走原版
      body_swap_make_actions
    end
  end
  
  #--------------------------------------------------------------------------
  # ● 名字交换（使用 alias 保留原始逻辑）
  #--------------------------------------------------------------------------
  alias body_swap_name name
  def name
    if body_data_managed?
      return $game_temp.body_swap_data[self][:name]
    end
    body_swap_name
  end
end

class Game_Battler < Game_BattlerBase

  #--------------------------------------------------------------------------
  # ● 交换身体
  #--------------------------------------------------------------------------
  def swap_body_with(target)
    
    
    # 先保存数据
    if !body_data_managed?
      $game_temp.body_swap_data[self]   = capture_body_data
    end
    
    if !target.body_data_managed?
      $game_temp.body_swap_data[target] = target.capture_body_data
    end
    # 双方都已有数据，直接交换
    
    # 交换状态（直接操作内部数据）
    self_states = @states.dup
    self_turns = @state_turns.dup
    self_steps = @state_steps.dup
    
    target_states = target.instance_variable_get(:@states).dup
    target_state_turns = target.instance_variable_get(:@state_turns).dup
    target_state_steps = target.instance_variable_get(:@state_steps).dup
    
    # 交换能力强化/弱化（buff）
    self_buffs = @buffs.dup
    self_buff_turns = @buff_turns.dup

    target_buffs = target.instance_variable_get(:@buffs).dup
    target_buff_turns = target.instance_variable_get(:@buff_turns).dup
    
    # 存当前双方的血蓝比例
    self_hp_rate  = self.hp.to_f / self.mhp
    self_mp_rate  = self.mp.to_f / self.mmp
    target_hp_rate = target.hp.to_f / target.mhp
    target_mp_rate = target.mp.to_f / target.mmp

    # 数据交换不动
    $game_temp.body_swap_data[self], $game_temp.body_swap_data[target] =
      $game_temp.body_swap_data[target], $game_temp.body_swap_data[self]

    # 按比例映射到新身体
    self.hp  = (target_hp_rate * self.mhp).to_i
    self.mp  = (target_mp_rate * self.mmp).to_i
    target.hp = (self_hp_rate * target.mhp).to_i
    target.mp = (self_mp_rate * target.mmp).to_i

    
    
    # 应用交换状态
    @states = target_states
    @state_turns = target_state_turns
    @state_steps = target_state_steps

    target.instance_variable_set(:@states, self_states)
    target.instance_variable_set(:@state_turns, self_turns)
    target.instance_variable_set(:@state_steps, self_steps)
    
    # 应用交换buff
    @buffs = target_buffs
    @buff_turns = target_buff_turns

    target.instance_variable_set(:@buffs, self_buffs)
    target.instance_variable_set(:@buff_turns, self_buff_turns)

    # 刷新双方，让免疫等特性生效（可能会移除部分状态）
    self.refresh
    target.refresh
  end
  
  #--------------------------------------------------------------------------
  # ● 捕获完整身体数据
  #--------------------------------------------------------------------------
  def capture_body_data
    if self.is_a?(Game_Actor)
      skill_ids = skills.map(&:id)
      feature_objs = [$data_actors[@actor_id], $data_classes[@class_id]] + equips.compact
    else
      skill_ids = enemy.actions.select { |a| a.skill_id > 0 }.map(&:skill_id).uniq
      feature_objs = [$data_enemies[@enemy_id]]
    end

    {
      name:     self.name,
      param:    (0..7).map { |i| param(i) },
      skills:   skill_ids,
      features: feature_objs,   # 存储对象，不是扁平特征
      hp:       hp,
      mp:       mp
    }
  end
end


#==============================================================================
# 技能标签
#==============================================================================
class RPG::UsableItem < RPG::BaseItem
  def swap_body?
    @swap_body ||= note =~ /<swap_body>/i
  end
end


class Scene_Battle
  alias body_swap_apply_item_effects apply_item_effects
  def apply_item_effects(target, item)
    # 先执行原版效果应用
    body_swap_apply_item_effects(target, item)
    # 再检查是否需要交换身体
    if item.is_a?(RPG::UsableItem) && item.swap_body?
      if (@subject.is_a?(Game_Actor) && target.is_a?(Game_Enemy)) ||
         (@subject.is_a?(Game_Enemy) && target.is_a?(Game_Actor))
        @subject.swap_body_with(target)
        @log_window.add_text("身体被交换了！") if @log_window
        @log_window.wait
        refresh_status
      end
    end
  end

  def compatible_swap?(a, b)
    (a.is_a?(Game_Actor) && b.is_a?(Game_Enemy)) ||
    (a.is_a?(Game_Enemy) && b.is_a?(Game_Actor))
  end
end

# 战斗结束时清除所有身体交换数据，自动恢复原状
class << BattleManager
  alias body_swap_battle_end battle_end
  def battle_end(result)
    body_swap_battle_end(result)
    if $game_temp
      $game_temp.body_swap_data.clear
      # 刷新所有队伍成员，使 HP/MP 回归新身体的最大值范围
      $game_party.members.each { |actor| actor.refresh }
    end
  end
end