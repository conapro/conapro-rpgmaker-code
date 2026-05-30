#==============================================================================
# ★ 敌人属性加成（最后攻击目标属性累加） ★
#==============================================================================
# 在角色或敌人的备注栏填写 <敌人属性加成> 即可获得能力：
# 攻击一个敌对目标后，获得该目标的所有基础能力（HP、MP、攻击、防御等）的累加值，
# 直到下次攻击另一个目标时替换为新目标的加成（一次只生效一个）。
#==============================================================================



#==============================================================================
# ★ Game_Battler 扩展：记录最后攻击的敌人及累加属性
#==============================================================================
class Game_Battler


  #--------------------------------------------------------------------------
  # ● 设置特性标志
  #--------------------------------------------------------------------------
  alias enemy_buff_initialize initialize
  def initialize
    enemy_buff_initialize
    @last_attacked_enemy = nil
    @enemy_buff_values = [0,0,0,0,0,0,0,0]   # 8个基本能力 param_id 0~7
  end

  def check_enemy_buff_feature
    feature_objects.each{|obj|
    return true if obj.note.include?("<敌人属性加成>")
    }
    return false
  end
  #--------------------------------------------------------------------------
  # ● 获取原始基本能力（未被此脚本修改的值）
  #--------------------------------------------------------------------------
  alias enemy_buff_param param
  def param(param_id)
    value = enemy_buff_param(param_id)   # 原始计算
    if check_enemy_buff_feature
      value += @enemy_buff_values[param_id] if @enemy_buff_values[param_id]
    end
    value
  end

  #--------------------------------------------------------------------------
  # ● 更新最后攻击的敌人（在造成伤害时调用）
  #--------------------------------------------------------------------------
  def update_last_enemy_buff(target)
    return unless check_enemy_buff_feature
    return if @last_attacked_target == target  # 同一个敌人无需重复累加

    # 清除旧加成
    if @last_attacked_enemy
      @enemy_buff_values = [0,0,0,0,0,0,0,0]
    end

    # 记录新敌人，并累加其所有基本能力
    @last_attacked_enemy = target
    8.times do |pid|
      @enemy_buff_values[pid] = target.param(pid)
    end
  end

  #--------------------------------------------------------------------------
  # ● 别名：执行伤害（在命中后触发更新）
  #--------------------------------------------------------------------------
  alias enemy_buff_execute_damage execute_damage
  def execute_damage(user)
    # 先执行原有的伤害计算（包括伤害值、HP减少等）
    enemy_buff_execute_damage(user)
    # 如果本次攻击者跟目标是敌对关系状态,应用加成
    if opposite?(user)
      user.update_last_enemy_buff(self)
    end
  end
  #--------------------------------------------------------------------------
  # ● 清空敌人属性加成
  #--------------------------------------------------------------------------
  def clear_enemy_attribute_buff
    return unless check_enemy_buff_feature
    @last_attacked_enemy = nil
    @enemy_buff_values = [0,0,0,0,0,0,0,0]
  end
end

class << BattleManager
  alias enemy_buff_battle_end battle_end
  def battle_end(result)
    # 清空所有加成
    $game_party.members.each do |actor|
      actor.clear_enemy_attribute_buff if actor.respond_to?(:clear_enemy_attribute_buff)
    end
    $game_troop.members.each do |enemy|
      enemy.clear_enemy_attribute_buff if enemy.respond_to?(:clear_enemy_attribute_buff)
    end
    enemy_buff_battle_end(result)
  end
end