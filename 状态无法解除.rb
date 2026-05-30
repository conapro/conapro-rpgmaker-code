#==============================================================================
# ■ RGSS3 状态锁定（无法解除）Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
#   让指定的状态在特定条件下无法被解除，仅保留角色死亡、战斗结束等强制移除。
#   通过备注标签定义受保护的状态列表，拥有该特征的单位身上对应的状态将免疫：
#     - 回合/行动结束自动解除
#     - 受到伤害时概率解除
#     - 步数解除
#     - 技能或道具的“状态解除”效果
#
#------------------------------------------------------------------------------
# 【使用方法】
#   在角色、职业、武器、防具、敌人、状态的备注栏中写入：
#
#   <无法解除状态:状态ID1,状态ID2,...>
#
#   多个状态ID使用半角逗号分隔。只要单位拥有该特征，所列状态就不会被上述
#   途径解除。其他未列出的状态不受影响。
#
#   示例：
#     <无法解除状态:6,9>
#       → 6号（中毒）和9号（混乱）无法被技能、道具、回合结束、伤害或步数移除。
#       → 死亡或战斗结束时仍会正常清除。
#
#------------------------------------------------------------------------------
# 【注意事项】
#   - 该特征可以写在多个地方（角色+装备），列表合并。
#   - 状态仍然可以被附加，只是指定的解除途径无效。
#   - 强制解除（如死亡、战斗结束、事件脚本调用 remove_state）不受限制。
#   - 本插件不改变状态的附加条件，仅限制解除。
#==============================================================================
class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 判断某状态是否被保护（不可解除）
  #--------------------------------------------------------------------------
  def remove_banned?(state_id)
    feature_objects.each do |obj|
      obj.note.each_line do |line|
        if line =~ /<无法解除状态:(\d+(?:,\d+)*)>/
          ids = $1.split(',').map(&:to_i)
          return true if ids.include?(state_id)
        end
      end
    end
    false
  end
  #--------------------------------------------------------------------------
  # ● 状态的自动解除
  #     timing : 时机（1:行动结束 2:回合结束）
  #--------------------------------------------------------------------------
  alias remove_banned_remove_states_auto remove_states_auto
  def remove_states_auto(timing)
    ori_states = states
    remove_banned_remove_states_auto(timing)
    ori_states.each do |state|
      # 只有这个状态受到保护时才进入判定
      next unless remove_banned?(state.id)
      # 满足条件，状态已然自动解除，重新装回
      if state.auto_removal_timing == timing && !states.include?(state)
        add_state(state.id)
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● 受到伤害时解除状态
  #--------------------------------------------------------------------------
  alias remove_banned_remove_states_by_damage remove_states_by_damage
  def remove_states_by_damage
    ori_states = states
    remove_banned_remove_states_by_damage
    ori_states.each do |state|
      # 只有这个状态受到保护时才进入判定
      next unless remove_banned?(state.id)
      # 原始状态会因伤害而解除且现有状态不包含该状态，重新装回
      if state.remove_by_damage && !states.include?(state)
        add_state(state.id)
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● 应用“状态解除”效果
  #--------------------------------------------------------------------------
  alias remove_banned_item_effect_remove_state item_effect_remove_state
  def item_effect_remove_state(user, item, effect)
    # 直接无法解除状态
    return if remove_banned?(effect.data_id)
    remove_banned_item_effect_remove_state(user, item, effect)
  end
end


class Game_Actor < Game_Battler
  #--------------------------------------------------------------------------
  # ● 更新状态的步数计数
  #--------------------------------------------------------------------------
  alias remove_banned_update_state_steps update_state_steps
  def update_state_steps(state)
    # 受保护的状态：不减少步数计数，也不移除
    return if state.remove_by_walking && remove_banned?(state.id)
    
    remove_banned_update_state_steps(state)
  end
end
  