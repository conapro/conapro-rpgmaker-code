#==============================================================================
# ■ RGSS3 反击拓展 Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
# 反击不再固定为普通攻击，可以通过备注自由指定反击技能、
# 设置反击技能优先级、随机使用技能池中的技能，
# 并可分别控制攻击方与受击方的反击许可。
#------------------------------------------------------------------------------
# 【模块配置说明】
#
# ● COUNTER_DAMAGE = true
#   反击前是否先对反击者造成一次伤害（true=先挨刀再反击，false=原版无敌反击）
#
# ● COUNTER_FIRST = true
#   优先判断“反击可能”还是“反击不可”（true=反击可能优先）
#
#------------------------------------------------------------------------------
# 【备注标签一览】
#
# ● <特殊反击:技能ID>
#   写在角色/职业/武器/防具/状态 的备注栏，指定反击时使用的技能。
#   复数存在时，按“优先度→ID最大”规则选取。
#   例：<特殊反击:15>
#
# ● <特殊反击优先度:数值>
#   写在技能的备注栏，设置该技能被选为反击技能时的优先度（越大越优先）。
#   例：<特殊反击优先度:5>
#
# ● <随机技能反击>
#   写在角色/职业/武器/防具/状态 的备注栏，反击时从自身技能池随机抽取技能。
#   角色技能池=已习得技能，敌人技能池=行动模式中配置的技能。
#   此标签优先度最高，会跳过 <特殊反击:ID> 的指定。
#   例：<随机技能反击>
#
# ● <特殊反击可能>
#   强制允许反击（无视原版命中类型限制）。
#   受击者特性（角色/职业/武器/防具/状态/敌人）：受击者获得“必定能触发反击”的特性。
#   攻击技能自身：此技能打中对方时，对方按自身反击率正常判定反击。
#   例：<特殊反击可能>
#
# ● <特殊反击不可>
#   禁止触发反击。
#   攻击者特性（角色/职业/武器/防具/状态/敌人）：攻击者所有攻击均无法被反击。
#   攻击技能自身：此技能打中对方时，对方绝对无法反击。
#   例：<特殊反击不可>
#
#------------------------------------------------------------------------------
# 【配置范例】
#
# 1.让角色反击固定使用技能ID 20：
#   在角色备注写 <特殊反击:20>
#
# 2.多个反击技能按优先度竞争：
#   技能A备注：<特殊反击优先度:10>
#   技能B备注：<特殊反击优先度:5>
#   角色备注：<特殊反击:技能AID> <特殊反击:技能BID>
#
#
# 3.必中攻击也能触发反击的防具：
#   防具备注写 <特殊反击可能>
#
# 4.混乱状态时反击随机出招：
#   状态备注写 <随机技能反击>
#
# 5.硬核模式+随机反击：
#   将 COUNTER_DAMAGE 设为 true
#   角色备注写 <随机技能反击>
#==============================================================================

module SPECIAL_COUNTER
  
  # 特殊反击的技能
  # 用于在角色、职业、武器、防具、状态等备注中指定特殊反击技能ID
  WORD1 = "特殊反击"
  
  # 特殊反击的技能的优先度
  # 用于在技能备注中设置该技能作为反击技能时的优先级
  WORD2 = "特殊反击优先度"
  
  # 攻击时，敌人无法触发反击 (技能，物品，角色，职业，武器，护甲，敌人，状态都可以写)
  WORD3 = "特殊反击不可"   
  
  # 被攻击时，可以触发反击（无视原版命中类型限制）
  WORD4 = "特殊反击可能" 
  
  # 反击是随机抽取技能组里的一个技能反击
  # 该反击的优先度大于所有特殊反击
  WORD5 = "随机技能反击"
  
  # 反击前是否会先对反击者造成一次伤害，true为会
  COUNTER_DAMAGE = true
  
  # 优先判断“反击可能”还是优先判断“反击不可”
  # true为优先“反击可能”
  COUNTER_FIRST = true
end

class Game_BattlerBase
  # 公开实例变量，用于标记当前是否处于反击状态
  attr_accessor :counter_attack_flag
  # 反击技能释放的缓存
  attr_accessor :counter_skill_cache  
  #--------------------------------------------------------------------------
  # ● 初始化对象
  #--------------------------------------------------------------------------
  alias special_counter_attack_initialize initialize
  def initialize
    # 初始时未处于反击状态
    @counter_attack_flag = false
    # 初始没有任何反击技能
    @counter_skill_cache = nil
    special_counter_attack_initialize
  end
  
  #--------------------------------------------------------------------------
  # ● 获取普通攻击的技能 ID
  # 该方法会在计算普通攻击（包括反击）时被调用，
  # 根据当前是否为反击状态返回不同的技能ID。
  #--------------------------------------------------------------------------
  alias special_counter_attack_skill_id attack_skill_id
  def attack_skill_id
    
    # 除非现在是反击，否则所有一切都按普通攻击算
    return special_counter_attack_skill_id unless @counter_attack_flag
    
    # ---- 以下是反击状态的处理 ----
    
    # ---- 随机技能反击 ----
    feature_objects.each do |obj|
      if obj.note.include?("<#{SPECIAL_COUNTER::WORD5}>")
        # 如果已经缓存过技能，直接返回
        return @counter_skill_cache if @counter_skill_cache

        skill_ids = if self.is_a?(Game_Actor)
                      skills.map(&:id)
                    else
                      enemy.actions.select { |a| a.skill_id > 0 }.map(&:skill_id).uniq
                    end
        skill_ids.select! { |id| usable?($data_skills[id]) }
        skill_ids.select! { |id| $data_skills[id].for_opponent? }
        break if skill_ids.empty?

        # 随机抽取并缓存
        @counter_skill_cache = skill_ids.sample
        return @counter_skill_cache
      end
    end
    
    # 创建数组存数据：存放所有激活的特性对象提供的特殊反击技能ID
    data = []
    
    # 遍历当前战斗者身上所有生效的特性（职业、装备、状态等）
    feature_objects.each do |f|
      data.push(f.special_counter_attack_skill_id) if f.special_counter_attack_skill_id != 0
    end
    
    # 如果没有任何特殊反击技能被设置，则退回使用原始的普通攻击技能ID
    return special_counter_attack_skill_id if data.empty?
    
    # 去除重复的技能ID，并按从小到大排序
    data.uniq!
    data.sort!
    
    
    data.select! { |skill_id| usable?($data_skills[skill_id]) }
    # 如果全部被过滤掉了，也退回普通攻击
    return special_counter_attack_skill_id if data.empty?
    
    # 找出所有候选技能中最高的优先度数值
    number = 0
    data.each do |d|
      if number <= $data_skills[d].counter_attack_skill_priority
        number = $data_skills[d].counter_attack_skill_priority
      end
    end
    
    # 剔除所有优先度不等于最高值的技能，只保留优先级最高的技能
    data.reject! {|d| $data_skills[d].counter_attack_skill_priority != number}
    
    # 返回剩余技能中 ID 最大的那个（因为 data 已经排序，pop 取的是最后一个，即最大ID）
    return data.pop
    
  end
end


class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 【别名】计算技能/物品的反击率
  # 整合了“先挨刀”的逻辑以外，新增了手动控制反击可否的功能。
  #--------------------------------------------------------------------------
  alias special_counter_item_cnt item_cnt
  def item_cnt(user, item)
    return 0 unless opposite?(user)         # 友军还是无法打友军
    
    if SPECIAL_COUNTER::COUNTER_FIRST
      # 先检查是否可以反击
      return cnt if check_counter_possible(user, item)
      # 再检查是否不能反击
      return 0 if check_counter_impossible(user, item)
    else
      # 不是反击先判断的,反面处理
      return 0 if check_counter_impossible(user, item)
      return cnt if check_counter_possible(user, item)
    end
    # 没有特殊备注，则调用原版逻辑（或后续其他插件的逻辑）
    return special_counter_item_cnt(user, item)
  end
  #--------------------------------------------------------------------------
  # ● 检查反击可能
  #--------------------------------------------------------------------------
  def check_counter_possible(user, item)
    feature_objects.each{|obj| 
    return true if obj.note.include?("<#{SPECIAL_COUNTER::WORD4}>")
    }
    if item.note.include?("<#{SPECIAL_COUNTER::WORD4}>")
      return true  # 写了 <特殊反击可能>，无条件按自身反击率触发
    end
    return nil
  end
  #--------------------------------------------------------------------------
  # ● 检查反击不可
  #--------------------------------------------------------------------------
  def check_counter_impossible(user, item)
    user.feature_objects.each{|obj| 
    return true if obj.note.include?("<#{SPECIAL_COUNTER::WORD3}>")
    }
    if item.note.include?("<#{SPECIAL_COUNTER::WORD3}>")
      return true # 写了 <特殊反击不可>，绝对不反击
    end
    return nil
  end
end


class Scene_Battle < Scene_Base
  
  #--------------------------------------------------------------------------
  # ● 发动反击
  #--------------------------------------------------------------------------
  alias special_counter_invoke_counter_attack invoke_counter_attack
  def invoke_counter_attack(target, item)
    
    # 反击开始前，检验
    if SPECIAL_COUNTER::COUNTER_DAMAGE
      apply_item_effects(apply_substitute(target, item), item)
    end
    
    # 死人不能再继续反击了
    return if target.dead?
    
    # 在反击开始时，将目标的 counter_attack_flag 设为 true
    target.counter_attack_flag = true
    @counter_target = target      # 记录反击者，供 refresh_status 使用
    skill = $data_skills[target.attack_skill_id]   # 这里会触发缓存生成
    # 获取特殊反击技能（此时 attack_skill_id 已受标记影响）
    skill = $data_skills[target.attack_skill_id]

    # 判断是否为特殊反击（与原普攻不同）
    target.counter_attack_flag = false
    original_id = target.attack_skill_id
    target.counter_attack_flag = true
    is_special = (skill.id != original_id)
    
    
    # 执行原本的反击逻辑（其中会调用 attack_skill_id，此时会进入特殊分支）
    special_counter_invoke_counter_attack(target, item)
    
    target.counter_attack_flag = false
    # ----- 如果技能重复次数大于 1，追加剩余次数 -----
    if is_special && skill.repeats > 1
      (skill.repeats - 1).times do
        # 再次应用效果（不播放动画）
        @subject.item_apply(target, skill)
        refresh_status
        @log_window.display_action_results(@subject, skill)
        # 被敌人反死了(target是敌人，@subject是此时行动主体)
        break if @subject.dead?
      end
    end
    # 反击结束后立即还原标记，避免影响其他攻击判断
    @counter_target = nil
     # 反击彻底结束，清空缓存
    target.counter_skill_cache = nil
  end
  

  #--------------------------------------------------------------------------
  # ● 刷新状态（插入反击动画）
  #--------------------------------------------------------------------------
  alias special_counter_refresh_status refresh_status
  def refresh_status
    # 如果当前正处于特殊反击，则播放技能动画
    if @counter_target && @counter_target.counter_attack_flag
      # 临时关闭标记，获取原始攻击技能 ID
      @counter_target.counter_attack_flag = false
      original_id = @counter_target.attack_skill_id
      @counter_target.counter_attack_flag = true
      current_id  = @counter_target.attack_skill_id

      # 只有当前技能与原始攻击不同时才播放动画
      if current_id != original_id
        skill = $data_skills[current_id]
        if skill && skill.animation_id > 0
          # 在攻击者（@subject）身上播放反击技能动画
          show_animation([@subject], skill.animation_id)
          @log_window.wait
          wait_for_animation
        end
      end
    end
    # 调用原 refresh_status
    special_counter_refresh_status
  end
end

class Window_BattleLog < Window_Selectable
  #--------------------------------------------------------------------------
  # ● 显示反击
  #--------------------------------------------------------------------------
  alias special_counter_display_counter display_counter
  def display_counter(target, item)
    special_counter_display_counter(target, item)
    # 先把反击主体的反击标志擦去，然后记录下原始的普攻技能id
    # 最后保存并比较，这只是为了防止有插件改了普攻技能id
    target.counter_attack_flag = false
    ori_attack_skill_id = target.attack_skill_id
    target.counter_attack_flag = true
    # 比较是否是普攻技能,不是则额外显示信息
    if target.attack_skill_id != ori_attack_skill_id
      counter_skill = $data_skills[target.attack_skill_id]
      display_use_item(target, counter_skill)
    end
  end
end

class RPG::BaseItem
  #--------------------------------------------------------------------------
  # ● 获取特殊反击技能ID
  # 从当前物品（角色、职业、武器、防具、状态等）的备注栏中解析 <特殊反击:ID>
  #--------------------------------------------------------------------------
  def special_counter_attack_skill_id
    

    # 从备注中匹配模式：<特殊反击:数字> 或 <特殊反击：数字>（支持中英文冒号）
    memo = self.note.scan(/<#{SPECIAL_COUNTER::WORD1}[：:](\S+)>/).flatten
    
    # 匹配到了则转为整数，否则为 0
    special_counter_attack_skill_id = (memo != nil && !memo.empty?) ? memo[0].to_i : 0
    
    return special_counter_attack_skill_id
  end
end

class RPG::Skill < RPG::UsableItem
  #--------------------------------------------------------------------------
  # ● 获取该技能的特殊反击优先度
  # 从技能备注栏中解析 <特殊反击优先度:数字>
  #--------------------------------------------------------------------------
  def counter_attack_skill_priority
    
 
    # 从备注匹配 <特殊反击优先度:数字>
    memo = self.note.scan(/<#{SPECIAL_COUNTER::WORD2}[：:](\S+)>/).flatten
    
    # 匹配成功则取整数，否则为 0
    counter_attack_skill_priority = (memo != nil && !memo.empty?) ? memo[0].to_i : 0
    
    return counter_attack_skill_priority
  end
end