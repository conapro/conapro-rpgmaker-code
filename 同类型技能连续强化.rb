#==============================================================================
# ■ RGSS3 同类型技能连续强化 Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
#   连续使用有交集的技能时，相同类别的技能会逐渐获得额外伤害和倍率加成。
#   四个判定维度中只要有一个匹配，增益就会保留并累积；
#   只有在所有维度都不匹配时，之前的加成才会完全归零。
#
#   四个判定维度：
#     - 技能类型（特技、魔法等）
#     - 效果范围（敌单体、敌全体等）
#     - 命中类型（物理攻击、魔法攻击等）
#     - 伤害属性（火、冰、雷等）
#
#------------------------------------------------------------------------------
# 【核心机制：部分匹配即可保留增益】
#
#   增伤不是绑定在单个技能上，而是基于四个维度的“或”逻辑：
#   只要当前使用的技能与之前积累增益的技能在任意一个维度上相同，
#   该技能就仍有资格继续累积增益。
#   只有当某个技能在所有四个维度上都不匹配时，它的增益才会被清零。
#
#   例：单位拥有 <技能类型增伤:50,1.2,80> 和 <效果范围增伤:30,1.1,90>
#       第1回合：使用“火球术”（特技、敌单体、魔法攻击、火）
#          → 技能类型匹配 → 火球术获得技能类型增伤
#          → 效果范围匹配 → 火球术获得效果范围增伤
#       第2回合：使用“冰锥术”（特技、敌全体、魔法攻击、冰）
#          → 技能类型仍为特技，匹配 → 保留并继续累积
#          → 效果范围变为敌全体，与上次不同，但效果范围增伤标签
#            依然会匹配当前技能的“敌全体”，因此效果范围增益
#            被重新判定（概率通过则从零开始累积）
#          → 伤害属性变为冰，属性增伤标签若存在也会匹配
#       第3回合：使用“治疗术”（魔法、己方单体、必定命中、无属性）
#          → 技能类型变为魔法，与之前特技不匹配
#          → 效果范围变为己方单体，不匹配
#          → 命中类型变为必定命中，不匹配
#          → 属性无，不匹配
#          → 所有维度都不匹配 → 之前积累的所有增益完全清零
#
#   简单说：技能之间只要还有“共同点”，增伤就能延续；
#           一旦新技能与之前积累的技能毫无共同点，全部归零。
#
#------------------------------------------------------------------------------
# 【四种判定标签】
#   在角色、职业、武器、防具、状态的备注栏中添加以下标签：
#
#   <技能类型增伤:额外伤害,倍率,成功率>
#      → 按技能类型（stype_id）判定。例如“特技”“魔法”。
#      → 每次使用相同技能类型的技能时，有概率叠加一层增伤。
#
#   <效果范围增伤:额外伤害,倍率,成功率>
#      → 按效果范围（scope）判定。例如“敌单体”“敌全体”“己方单体”。
#
#   <命中类型增伤:额外伤害,倍率,成功率>
#      → 按命中类型（hit_type）判定。例如“物理攻击”“魔法攻击”“必定命中”。
#
#   <属性增伤:额外伤害,倍率,成功率>
#      → 按伤害属性（damage.element_id）判定。例如“火”“冰”“雷”。
#
#   参数说明：
#     额外伤害 : 每次成功判定后追加的固定伤害（整数）
#     倍率     : 每次成功判定后伤害乘以的倍数（小数，1.0=不变）
#     成功率   : 每次判定成功的概率（1~100，100=必定成功）
#
#   例：<技能类型增伤:100,1.2,80>
#       → 连续使用同一技能类型的技能时，每次有80%概率成功
#       → 成功后追加100伤害，倍率额外×1.2
#
#------------------------------------------------------------------------------
# 【多个同类型标签的处理】
#   如果同一标签存在多个（例如武器和防具都写了 <技能类型增伤>），
#   它们合并为一条，额外伤害叠加、倍率叠加、成功率取平均值。
#
#     例：武器 <技能类型增伤:100,1.2,80>
#         防具 <技能类型增伤:50,1.1,90>
#         → 合并为：额外伤害=150，倍率=1.3，成功率=85%
#
#------------------------------------------------------------------------------
# 【标签失效处理】
#   如果单位失去了某个标签（例如装备被卸下、状态到期），
#   该标签对应的维度不再参与判定。
#   当四个维度的标签全部消失时，所有技能的增益立即归零。
#
#------------------------------------------------------------------------------
# 【伤害计算公式】
#   每次使用技能后，所有存在的维度分别对匹配的技能进行概率判定。
#   判定通过则对应技能的增益叠加，判定失败则对应技能的增益清零。
#   所有维度都不匹配的技能，增益直接归零。
#
#   最终伤害 = 原伤害 + 所有生效维度的增益合计
#
#     单个维度的增益 = (原伤害 × 该维度的倍率累积)
#                     + (该维度的额外伤害累加)
#
#
#------------------------------------------------------------------------------
# 【注意事项】
#   - 四个维度是“或”的关系，只要有一个维度匹配，增益就有机会保留。
#   - 所有维度都不匹配时，累积的增益才会完全清零。
#   - 标签来源可以是角色、职业、武器、防具、状态任意组合。
#   - 同一标签多个来源会自动合并（额外伤害叠加、倍率叠加、成功率取均值）。
#   - 该效果仅在战斗场景中生效，战斗结束自动清零。
#   - 技能必须造成非零伤害（HP或MP）才会触发增益更新。
#==============================================================================
module SkillUseBonus
  
  WORDS = {
    stype:"技能类型增伤",
    scope:"效果范围增伤",
    hit_type:"命中类型增伤",
    element:"属性增伤",
  }
  
  ADD_WORD = "加成"
  
  MULTIPLE_WORD = "倍率" 
  
  
end

class RPG::BaseItem
  #--------------------------------------------------------------------------
  # ● 获取技能类型增伤的特征
  # 从当前物品（角色、职业、武器、防具、状态等）的备注栏中解析 
  #--------------------------------------------------------------------------
  def check_skill_continous_bonus(type)
    
    data_list = []
    
    self.note.each_line{|l|
    # 从备注中匹配模式（支持中英文冒号）
    memo = l.scan(/<#{SkillUseBonus::WORDS[type]}[：:](\S+)>/).flatten
    next unless (memo != nil && !memo.empty?) 
    data = memo[0].split(',').map { |s| s.strip.to_f }
    data_list.push(data) 
    }
    
    return [0, 1.0, 100] if data_list.empty?

    [
      data_list.inject(0) { |s, d| s + d[0].to_i },
      1.0 + data_list.inject(0.0) { |s, d| s + d[1] - 1.0 },
      (data_list.inject(0.0) { |s, d| s + d[2] } / data_list.size).round
    ]
    
  end
end



class Game_Temp
  # 访问器（如果你想在外部直接读取整个哈希）
  attr_accessor :skill_continous_bonus_data

  # 初始化时清空
  alias skill_continous_bonus_initialize initialize
  def initialize
    skill_continous_bonus_initialize
    clear_skill_continous_bonus_data
  end

  # 清空/初始化数据
  def clear_skill_continous_bonus_data
    @skill_continous_bonus_data = Hash.new do |battler_hash, battler|
      # 每个战斗者一个内层哈希，技能ID → [伤害修正, 倍率修正]
      battler_hash[battler] = Hash.new do |skill_hash, skill_id|
        skill_hash[skill_id] = [0, 1.0]   # 0位：额外伤害，1位：倍率
      end
    end
  end
end

class << BattleManager
  # 战斗结束加成清零
  alias skill_continous_bonus_battle_end battle_end
  def battle_end(result)
    $game_temp.clear_skill_continous_bonus_data
    skill_continous_bonus_battle_end(result)
  end
end

class Game_Battler
  # 获取自己所有的技能
  def bonus_skills
    $game_temp.skill_continous_bonus_data[self]
  end
  # 获取自己技能对应的修正数组
  def skill_bonus(skill_id)
    $game_temp.skill_continous_bonus_data[self][skill_id]
  end
  #--------------------------------------------------------------------------
  # ● 技能／使用物品
  #    对使用目标使用完毕后，应用对于使用目标以外的效果。
  #--------------------------------------------------------------------------
  alias skill_continous_bonus_use_item use_item
  def use_item(item)
    skill_continous_bonus_use_item(item)
    if item.is_a?(RPG::Skill)
      bonused_skills = []
      SkillUseBonus::WORDS.keys.each do |type|
        feature_objects.each{|obj|
         data = obj.check_skill_continous_bonus(type)
         next if data == [0, 1.0, 100]
         case type
         when :stype
           bonus_skills.each_key{|skill_id|
           next unless $data_skills[skill_id].stype_id == item.stype_id
           next unless data[2] > rand(100)
           skill_bonus(skill_id)[0] += data[0]
           skill_bonus(skill_id)[1] *= data[1] 
           bonused_skills.push(skill_id) unless bonused_skills.include?(skill_id)
           }
         when :scope
           bonus_skills.each_key{|skill_id|
           next unless $data_skills[skill_id].scope == item.scope
           next unless data[2] > rand(100)
           skill_bonus(skill_id)[0] += data[0]
           skill_bonus(skill_id)[1] *= data[1] 
           bonused_skills.push(skill_id) unless bonused_skills.include?(skill_id)
           }
         when :hit_type
           bonus_skills.each_key{|skill_id|
           next unless $data_skills[skill_id].hit_type == item.hit_type
           next unless data[2] > rand(100)
           skill_bonus(skill_id)[0] += data[0]
           skill_bonus(skill_id)[1] *= data[1] 
           bonused_skills.push(skill_id) unless bonused_skills.include?(skill_id)
           }
          when :element
           bonus_skills.each_key{|skill_id|
           next unless $data_skills[skill_id].damage.element_id == item.damage.element_id
           next unless data[2] > rand(100)
           skill_bonus(skill_id)[0] += data[0]
           skill_bonus(skill_id)[1] *= data[1]
           bonused_skills.push(skill_id) unless bonused_skills.include?(skill_id)
           }
         end
         
        }
      end
      bonus_skills.each_key{|skill_id|
      bonus_skills[skill_id] = [0, 1.0] unless bonused_skills.include?(skill_id)
      }
    end
  end
  #--------------------------------------------------------------------------
  # ● 计算伤害
  #--------------------------------------------------------------------------
  alias skill_continous_bonus_make_damage_value make_damage_value
  def make_damage_value(user, item)
    skill_continous_bonus_make_damage_value(user, item)
    return unless $game_party.in_battle && item.is_a?(RPG::Skill)
    bonus = user.skill_bonus(item.id)   # 获取 [额外伤害, 倍率]
    return if bonus[0] == 0 && bonus[1] == 1.0
    abs_value = [@result.hp_damage.abs,@result.mp_damage.abs].max
    value = abs_value == @result.hp_damage.abs ? @result.hp_damage : @result.mp_damage
    return if value == 0 # 之前没有造成效果，现在也不能有效果
    value = value * bonus[1] + bonus[0] * value / value.abs  
    @result.make_damage(value.to_i, item)
  end
end


class Window_BattleSkill < Window_SkillList
  #--------------------------------------------------------------------------
  # ● 绘制项目（添加增益显示在技能名字上方）
  #--------------------------------------------------------------------------
  def draw_item(index)
    skill = @data[index]
    return unless skill

    rect = item_rect(index)
    rect.width -= 4

    if $game_party.in_battle
      bonus = @actor.skill_bonus(skill.id)
      if bonus && (bonus[0] != 0 || bonus[1] != 1.0)
        # 小字体绘制增益信息
        contents.font.size = 15
        change_color(text_color(24))  # 橙色
        text1 = bonus[0] != 0 ? "#{SkillUseBonus::ADD_WORD}#{bonus[0]} " : ""
        text2 = bonus[1] != 1.0 ? "#{SkillUseBonus::MULTIPLE_WORD}#{bonus[1]}" : ""
        text = text1 + text2
        draw_text(rect.x, rect.y - 4, rect.width, 16, text, 1)
      end
    end

    # 恢复默认字体（draw_item_name 内部会重新设置字体大小）
    contents.font.size = Font.default_size
    draw_item_name(skill, rect.x, rect.y, enable?(skill))
    draw_skill_cost(rect, skill)
  end
end