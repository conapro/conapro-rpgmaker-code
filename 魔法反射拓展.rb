#==============================================================================
# ■ RGSS3 魔法反射拓展 Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
# 让魔法反射可以不再局限于反射魔法攻击，而是可以什么都反射，和让魔法攻击完全无法反射
# 说人话就是我把我的反击拓展的关于<特殊反击可能>和<特殊反击不可>词条实现的功能移植到
# 了魔法反射系统上面…………
#------------------------------------------------------------------------------

module SPECIAL_REFLECTION
  
  # 优先判断“魔法反射可能”还是优先判断“魔法反射不可”
  # true为优先“魔法反射可能”
  REFLECTION_FIRST = true
  
  # 攻击时，敌人无法触发反射 (技能，物品，角色，职业，武器，护甲，敌人，状态都可以写)
  WORD1 = "魔法反射不可"
  
  # 被攻击时，可以触发魔法反射（无视原版命中类型限制）
  WORD2 = "魔法反射可能"
  
end

class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 计算技能／物品的反射几率
  #--------------------------------------------------------------------------
  alias special_reflection_item_mrf item_mrf
  def item_mrf(user, item)
    
    if SPECIAL_REFLECTION::REFLECTION_FIRST
      # 先检查是否可以反击
      return mrf if check_reflection_possible(user, item)
      # 再检查是否不能反击
      return 0 if check_reflection_impossible(user, item)
    else
      # 不是反击先判断的,反面处理
      return 0 if check_reflection_impossible(user, item)
      return mrf if check_reflection_possible(user, item)
    end
    # 没有特殊备注，则调用原版逻辑（或后续其他插件的逻辑）
    return special_reflection_item_mrf(user, item)
  end
  #--------------------------------------------------------------------------
  # ● 检查反射可能
  #--------------------------------------------------------------------------
  def check_reflection_possible(user, item)
    feature_objects.each{|obj| 
    return true if obj.note.include?("<#{SPECIAL_REFLECTION::WORD2}>")
    }
    if item.note.include?("<#{SPECIAL_REFLECTION::WORD2}>")
      return true  # 写了 <魔法反射可能>，无条件按自身反射率触发
    end
    return nil
  end
  #--------------------------------------------------------------------------
  # ● 检查反射不可
  #--------------------------------------------------------------------------
  def check_reflection_impossible(user, item)
    user.feature_objects.each{|obj| 
    return true if obj.note.include?("<#{SPECIAL_REFLECTION::WORD1}>")
    }
    if item.note.include?("<#{SPECIAL_REFLECTION::WORD1}>")
      return true # 写了 <魔法反射不可>，绝对不反射
    end
    return nil
  end
end