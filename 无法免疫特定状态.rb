#==============================================================================
# ■ RGSS3 特定状态无法免疫 Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
#   惩罚机制，让单位无法免疫某一状态的附加
#
# 【使用方法】
#   1. 在角色/职业/武器/防具/状态/敌人栏里写入<状态无抗性:x> x为该状态id
#==============================================================================

module NonResistState
  
  WORD1 = "状态无抗性"
  
end

class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 应用“附加状态”效果
  #--------------------------------------------------------------------------
  alias non_resist_state_item_effect_add_state item_effect_add_state
  def item_effect_add_state(user, item, effect)
    non_resist_ids = feature_objects.flat_map(&:non_resist_state)
    # 如果附加状态在id组里，直接生效
    if non_resist_ids.include?(effect.data_id)
      add_state(effect.data_id)
      @result.success = true
      # 终止进程
      return 
    end
    non_resist_state_item_effect_add_state(user, item, effect)
  end
  #--------------------------------------------------------------------------
  # ● 附加状态
  #--------------------------------------------------------------------------
  alias non_resist_state_state_addable? state_addable?
  def state_addable?(state_id)
    # 取出无抗性列表
    non_resist_ids = feature_objects.flat_map(&:non_resist_state)
    # 如果该状态在列表中，则忽略 resist 检查（只保留其他条件）
    if non_resist_ids.include?(state_id)
      return alive? && $data_states[state_id] &&
             !state_removed?(state_id) && !state_restrict?(state_id)
    end
    non_resist_state_state_addable?(state_id)
  end
end

class RPG::BaseItem
  #--------------------------------------------------------------------------
  # ● 获取无抗性的状态ID
  # 从当前物品（角色、职业、武器、防具、状态等）的备注栏中解析 <状态无抗性:ID>
  #--------------------------------------------------------------------------
  def non_resist_state
    
    # 如果已经解析过，直接返回缓存的值
    return @non_resist_state_ids if @non_resist_state_ids != nil
    
    @non_resist_state_ids = []
    
    self.note.each_line{|l|
    # 从备注中匹配模式（支持中英文冒号）
    memo = l.scan(/<#{NonResistState::WORD1}[：:](\S+)>/).flatten
    # 匹配到了则转为整数，否则为 0
    @non_resist_state_ids.push(memo[0].to_i) if (memo != nil && !memo.empty?) 
    }
    
    
    return @non_resist_state_ids
  end
end
