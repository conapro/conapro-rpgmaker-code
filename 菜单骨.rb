#==============================================================================
# ■ 菜单骨（双模式独立功能） ver 1.0         conapro整合
#------------------------------------------------------------------------------
#   两种状态，分别对应不同窗口激活期间的持续扣血，类似 Undertale Sans 战。
#
# 【使用方法】
#   1. 在数据库中的角色/职业/武器/护甲/敌人/状态栏中写入<菜单攻击>或<技能选择攻击>
#   2. 只要有单位拥有该特征，那么就会角色在选择阶段就会持续扣血
#   3. 伤害表达式可用 actor 的相关属性（如 mhp, hp, mmp, level 等）。
#   4. 本脚本完全独立，无需任何其他插件，直接插入即可。
#==============================================================================

module MenuBone
  # ● 菜单攻击（主指令窗口或目标选择窗口激活时生效）
  MENU_ATTACK_WORD = "菜单攻击"               # 状态ID
  MENU_DAMAGE   = "actor.mhp * 0.01"  # 伤害表达式（至少 1 点）
  MENU_INTERVAL = 6                # 伤害间隔（帧）

  # ● 技能选择攻击（技能或物品选择窗口激活时生效）
  SKILL_ATTACK_WORD = "技能选择攻击"             # 状态ID
  SKILL_DAMAGE   = "actor.mhp * 0.02" # 伤害表达式
  SKILL_INTERVAL = 10              # 伤害间隔（帧）
end

class Game_Battler 
  #--------------------------------------------------------------------------
  # ● 检查是否能菜单攻击
  #--------------------------------------------------------------------------
  def menu_attck?
    feature_objects.any?{|obj| obj.note.include?("<#{MenuBone::MENU_ATTACK_WORD}>")}
  end
  #--------------------------------------------------------------------------
  # ● 检查是否能技能选择攻击
  #--------------------------------------------------------------------------
  def skill_attck?
    feature_objects.any?{|obj| obj.note.include?("<#{MenuBone::SKILL_ATTACK_WORD}>")}
  end
end

class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 开始处理（初始化两种计数器）
  #--------------------------------------------------------------------------
  alias menu_bone_start start
  def start
    menu_bone_start
    @menu_counter   = 0
    @skill_counter  = 0
  end

  #--------------------------------------------------------------------------
  # ● 更新画面
  #--------------------------------------------------------------------------
  alias menu_bone_update update
  def update
    update_menu_bone
    menu_bone_update
  end

  #--------------------------------------------------------------------------
  # ● 统一调度两种伤害
  #--------------------------------------------------------------------------
  def update_menu_bone
    update_menu_attack
    update_skill_attack
  end

  #--------------------------------------------------------------------------
  # ● 菜单攻击伤害处理
  #--------------------------------------------------------------------------
  def update_menu_attack
    return unless menu_attack_active? && in_menu_phase?
    @menu_counter += 1
    if @menu_counter >= MenuBone::MENU_INTERVAL
      @menu_counter = 0
      apply_damage_to_party(MenuBone::MENU_DAMAGE)
    end
  end

  #--------------------------------------------------------------------------
  # ● 技能选择攻击伤害处理
  #--------------------------------------------------------------------------
  def update_skill_attack
    return unless skill_attack_active? && in_skill_choose_phase?
    @skill_counter += 1
    if @skill_counter >= MenuBone::SKILL_INTERVAL
      @skill_counter = 0
      apply_damage_to_party(MenuBone::SKILL_DAMAGE)
    end
  end

  #--------------------------------------------------------------------------
  # ● 对全体队员造成伤害
  #--------------------------------------------------------------------------
  def apply_damage_to_party(expression)
    $game_party.battle_members.each do |actor|
      next if actor.dead?
      damage = eval(expression).to_i
      actor.hp -= [damage, 1].max   # 保证最少 1 点伤害
    end
    @status_window.refresh if @status_window   # 刷新状态窗口
  end

  #--------------------------------------------------------------------------
  # ● 菜单攻击状态是否激活？
  #--------------------------------------------------------------------------
  def menu_attack_active?
    $game_party.members.any? { |m| m.menu_attck? } ||
    $game_troop.members.any?  { |m| m.menu_attck? }
  end

  #--------------------------------------------------------------------------
  # ● 技能选择攻击状态是否激活？
  #--------------------------------------------------------------------------
  def skill_attack_active?
    $game_party.members.any? { |m| m.skill_attck? } ||
    $game_troop.members.any?  { |m| m.skill_attck? }
  end

  #--------------------------------------------------------------------------
  # ● 是否处于主指令/目标选择阶段？
  #--------------------------------------------------------------------------
  def in_menu_phase?
    return false unless @actor_command_window
    @actor_command_window.active ||
      (@enemy_window && @enemy_window.active) ||
      (@actor_window && @actor_window.active)
  end

  #--------------------------------------------------------------------------
  # ● 是否处于技能/物品选择阶段？
  #--------------------------------------------------------------------------
  def in_skill_choose_phase?
    (@item_window   && @item_window.active) ||
    (@skill_window  && @skill_window.active)
  end
end