#==============================================================================
# ■ RGSS3 战斗召唤 Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
#   实现战斗中的召唤流程，战斗时召唤，战斗后离队的效果
#   战斗中召唤了该角色后全体队友都会遗忘该召唤技能，但记录谁会有召唤技能
#   战斗结束后会召唤技能的角色将重新记起召唤技能
#
# 【使用方法】
#   1. 在技能里添加备注<战斗召唤:x>即可让id为x的角色在战斗时入队
#==============================================================================

module AutoSummon
  
  # 记录召唤了多少单位的变量的id
  # 这只是为了适配某些纯事件实现召唤功能的工程而设立
  VARIABLE_ID = 35
  
end

#==============================================================================
# ■ RPG::Skill
#==============================================================================
class RPG::Skill < RPG::UsableItem
  # 正则表达式：匹配 <战斗召唤:数字>
  SUMMON_ACTOR = /<战斗召唤\s*:\s*(\d+)>/i

  # 返回该技能召唤的角色ID，如果没有则返回 nil
  def summon_actor_id
    return @summon_actor_id if instance_variable_defined?(:@summon_actor_id)
    @summon_actor_id = note =~ SUMMON_ACTOR ? $1.to_i : nil
  end
end

#==============================================================================
# ■ BattleManager
#==============================================================================
class << BattleManager
  # 战斗结束时清理召唤数据
  alias summon_battle_end battle_end
  def battle_end(result)
    $game_temp.clear_summon_data   # 先执行清理（含离队、恢复技能）
    summon_battle_end(result)
  end
end

#==============================================================================
# ■ Game_Temp
#==============================================================================
class Game_Temp
  # 公开实例变量（如果需要外部访问，可用）
  attr_accessor :summoned_actors     # 已被召唤出来的角色ID集合（Hash: id => true）
  attr_accessor :summon_skill_owners # 拥有召唤技能的角色记忆（Hash: actor => [skill_ids]）

  # 初始化追加
  alias summon_initialize initialize
  def initialize
    summon_initialize
    init_summon_data
  end

  # 初始化召唤相关哈希
  def init_summon_data
    @summoned_actors = {}
    @summon_skill_owners = {}
  end

  # 战斗结束时统一清理：召唤角色离队 + 恢复技能
  def clear_summon_data
    dismiss_summoned_actors
    restore_summon_skills
    $game_variables[AutoSummon::VARIABLE_ID] = 0
    init_summon_data
  end

  # 让所有被召唤的角色离队，并且完全恢复状态
  def dismiss_summoned_actors
    @summoned_actors.keys.each do |actor_id|
      actor = $game_actors[actor_id]
      actor.recover_all
      $game_party.remove_actor(actor_id) if $game_party.members.include?(actor)
    end
  end

  # 恢复所有召唤者的召唤技能
  def restore_summon_skills
    @summon_skill_owners.each do |actor, skill_ids|
      skill_ids.each do |skill_id|
        actor.learn_skill(skill_id) unless actor.skill_learn?($data_skills[skill_id])
      end
    end
  end

  # 记录一个召唤事件：被召唤角色ID 和 使用该技能的召唤者
  def register_summon(actor_id, summoner, skill_id)
    @summoned_actors[actor_id] = true
    @summon_skill_owners[summoner] ||= []
    @summon_skill_owners[summoner] << skill_id
    @summon_skill_owners[summoner].uniq!
  end
end

#==============================================================================
# ■ Game_Battler
#==============================================================================
class Game_Battler < Game_BattlerBase
  # 使用技能/物品时检测召唤效果
  alias summon_use_item use_item
  def use_item(item)
    summon_actor_if_possible(item) if item.is_a?(RPG::Skill)
    summon_use_item(item)
  end

  # 如果技能含召唤效果，则执行召唤并记录
  def summon_actor_if_possible(skill)
    return unless $game_party.in_battle          # 仅在战斗中生效
     return unless self.actor?                # 只有我方角色才能召唤
    actor_id = skill.summon_actor_id
    return unless actor_id                       # 没有召唤备注则跳过
    return if $game_party.members.include?($game_actors[actor_id]) # 已在队中则不再重复召唤

    # 将被召唤角色加入队伍
    $game_party.add_actor(actor_id)

    # 全体队友遗忘此召唤技能
    $game_party.members.each do |member|
      next unless member.skill_learn?(skill)
      member.forget_skill(skill.id)
    end

    # 记录召唤信息（关键：召唤者是谁，召唤了谁）
    $game_temp.register_summon(actor_id, self, skill.id)
    
    # 召唤数的变量增加
    $game_variables[AutoSummon::VARIABLE_ID] += 1
  end
end

