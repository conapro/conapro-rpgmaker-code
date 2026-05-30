
#==============================================================================
# ■ RGSS3 棍母      Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
#   让单位变成棍母，无法锁定，无法受到伤害，只能通过反击和魔法反射才能对其造成伤害
#------------------------------------------------------------------------------

class RPG::BaseItem
  #--------------------------------------------------------------------------
  # ● 获取棍母真身战斗图名（不再是布尔值）
  #    备注中写入 <棍母真身:战斗图名> 或 <棍母真身：战斗图名>
  #    返回战斗图文件名字符串，未设置则返回 nil
  #--------------------------------------------------------------------------
  def true_form_name
    self.note =~ /<棍母真身[：:]\s*(\S+)>/ ? $1 : nil
  end
end

class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 是否为不可选中的棍母（布尔判断，内部使用）
  #--------------------------------------------------------------------------
  def unselectable?
    !true_form_name.nil?
  end

  #--------------------------------------------------------------------------
  # ● 获取真身战斗图名（综合所有特性）
  #--------------------------------------------------------------------------
  def true_form_name
    # 遍历所有特性对象（职业、装备、状态、敌人数据库等），返回第一个有效名字
    feature_objects.each do |obj|
      name = obj.true_form_name
      return name if name
    end
    nil
  end
end

class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 初始化对象（棍母初始时隐藏战斗图）
  #--------------------------------------------------------------------------
  alias true_form_initialize initialize
  def initialize(index, enemy_id)
    true_form_initialize(index, enemy_id)
    @battler_name = "" if unselectable?   # 平时战斗图设为空，即不显示
  end
end

class Scene_Battle < Scene_Base

  #--------------------------------------------------------------------------
  # ● 开始选择敌人（无目标时自动取消）
  #--------------------------------------------------------------------------
  alias true_form_select_enemy_selection select_enemy_selection
  def select_enemy_selection
    @enemy_window.refresh
    if @enemy_window.item_max == 0
      on_enemy_cancel
    else
      true_form_select_enemy_selection
    end
  end

  #--------------------------------------------------------------------------
  # ● 显示动画（去除我方主动攻击时的棍母动画）
  #--------------------------------------------------------------------------
  alias true_form_show_animation show_animation
  def show_animation(targets, animation_id)
    visible_targets = targets.reject { |target|
      target.unselectable? && @subject.opposite?(target)
    }
    if @subject.enemy? && @subject.unselectable?
      # 攻击瞬间设置真身战斗图
      @subject.instance_variable_set(:@battler_name, @subject.true_form_name)
    end
    true_form_show_animation(visible_targets, animation_id)
  end

  #--------------------------------------------------------------------------
  # ● 发动技能／物品（我方直接攻击棍母无效）
  #--------------------------------------------------------------------------
  alias true_form_invoke_item invoke_item
  def invoke_item(target, item)
    return if target.unselectable? && @subject.opposite?(target)
    if @subject.enemy? && @subject.unselectable?
      # 攻击瞬间设置真身战斗图
      @subject.instance_variable_set(:@battler_name, @subject.true_form_name)
    end
    true_form_invoke_item(target, item)
    if @subject.enemy? && @subject.unselectable?
      # 攻击结束后重新隐藏
      @subject.instance_variable_set(:@battler_name, "")
    end
  end
end

class Window_BattleEnemy < Window_Selectable
  #--------------------------------------------------------------------------
  # ● 获取当前可显示的敌人列表（过滤掉棍母）
  #--------------------------------------------------------------------------
  def visible_enemies
    $game_troop.alive_members.select { |enemy| !enemy.unselectable? }
  end

  #--------------------------------------------------------------------------
  # ● 获取项目数
  #--------------------------------------------------------------------------
  def item_max
    visible_enemies.size
  end

  #--------------------------------------------------------------------------
  # ● 获取敌人实例
  #--------------------------------------------------------------------------
  def enemy
    visible_enemies[@index]
  end

  #--------------------------------------------------------------------------
  # ● 绘制项目
  #--------------------------------------------------------------------------
  def draw_item(index)
    change_color(normal_color)
    name = visible_enemies[index].name
    draw_text(item_rect_for_text(index), name)
  end

  #--------------------------------------------------------------------------
  # ● 刷新窗口
  #--------------------------------------------------------------------------
  def refresh
    self.contents.clear if self.contents
    super if defined?(super)
    self.index = [@index, item_max - 1].min if item_max > 0
  end
end
