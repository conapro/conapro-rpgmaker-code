##==============================================================================
# ■ RGSS3 战场扩容系统 Ver1.01 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
#   本插件可以让你突破 RMVA 原版 4 人战斗的硬性限制，
#   通过全局常量和角色/职业/装备/状态/敌人的备注标签，
#   动态计算当前队伍的最大参战人数。
#   同时为战斗状态窗口增加翻页功能，保证 UI 不挤不乱。
#
#------------------------------------------------------------------------------
# 【使用说明】
#
# 【全局固定加成】
#   打开脚本最上方的 MaxBattleMembers 模块，修改 ADD 常量：
#
#   ADD = 2   → 不管队伍里有什么人，基础上限固定 +2
#   ADD = 0   → 不额外加人，全靠角色自身特性撑场面
#   ADD = -1  → 甚至可以减人（如果你他妈想玩极限挑战）
#
# 【角色特性加成 —— 这才是灵魂】
#   在角色、职业、武器、防具、敌人、状态的“备注”栏里写入：
#
#   <增加参战人数:X>
#
#   - X 可以是整数，也可以是一个 Ruby 表达式
#   - 该单位存活时，X 就会加到队伍最大出战人数上
#   - 该单位死亡时，加成自动消失，槽位缩回
#
# 【标签示例】
#   <增加参战人数:1>             → 该单位存活时，队伍上限 +1
#   <增加参战人数:2>             → 队伍上限 +2，将军级人物
#   <减少参战人数:1>             → boss战状态效果，让队伍人数减少
#   <增加参战人数:$game_variables[10]>  → 用变量控制加成量，想加多少你说了算
#
# 【实际用例】
#   （假设全局 ADD = 0，原版上限 4 人）
#
#   战士备注：<增加参战人数:1>
#   法师备注：<增加参战人数:1>
#   → 两人同时存活时，队伍上限 = 4 + 1 + 1 = 6 人
#   → 战士倒下，上限立刻变回 5 人
#   → 第六个人不会被踢出，但无法继续召唤新单位
#
# 【翻页功能】
#   战斗状态窗口固定显示 4 人，超出自动分页。
#   PAGE_SIZE = 4  → 每页显示 4 人（可改）
#   TURN_KEY = :X  → 按 A 键翻页（在 RGSS3 中 :X 映射键盘 A 键）
#   PAGE_POS = :right_up → 页码数字将在右上角绘制
#
#   翻页时光标自动追踪当前行动者，不用手动找人。
#   轮到不在当前页的角色时，窗口自动跳转到他所在的那一页。
#
#------------------------------------------------------------------------------
# 【注意事项】
#   - 战斗中通过事件召唤新单位入队后，窗口会自动刷新。
#   - <增加参战人数> 的 eval 是在顶层上下文执行的，可以引用 $game_variables 等
#     全局变量，但为了你的血压着想，别写太复杂的表达式。
#   - 战斗成员缓存会自动刷新，不用手动管。
#   - 如果战斗中动态修改变量导致加成变化，窗口会在下次 refresh 时自动更新。
#   - 不要在备注里写 <增加参战人数:$game_party.max_battle_members>，
#
#------------------------------------------------------------------------------
# 【可玩出的花活（给设计者的灵感）】
#   - 领导力系统：将军职业自带 +3，亲卫兵 +1，组满一队十人出征
#   - 士气溃败：队长死亡 → 槽位缩水 → 队伍崩盘，压迫感拉满
#   - 临时增援：给角色附加状态（备注 +2），三回合内多两个打手
#
#==============================================================================
# ■ 更新日志
#------------------------------------------------------------------------------
# ver 1.00
#   实现动态队伍容量上限 + 特性加成 + 翻页功能
#------------------------------------------------------------------------------
# ver 1.01
#   实现绘制页码来辅助玩家定位此时的所选页数在队伍何处
#==============================================================================
module MaxBattleMembers
  # 相比原来四个上限的队伍增加的人数
  ADD = 6
  
  # 翻页的符号（在RPSS3中，:X映射A建）
  TURN_KEY = :X
  
  # 页数绘制位置(:right_up符号是右上角，:right_down符号是右下角)
  PAGE_POS = :right_up
end

class Game_Party
  alias ori_max_battle_members max_battle_members
  def max_battle_members
    ori = ori_max_battle_members
    all_members.each { |actor| ori += actor.battle_member_slot_bonus }
    $game_troop.alive_members.each { |enemy| ori -= enemy.battle_member_slot_penalty }
    return (ori + MaxBattleMembers::ADD)
  end
  # 强制刷新战斗成员缓存（让新入队的人立刻出现在战场上）
  def refresh_battle_members_cache
    @battle_members = nil if defined?(@battle_members)
  end
end

class Game_Battler
  #--------------------------------------------------------------------------
  # ● 增加参战人数统计
  #--------------------------------------------------------------------------
  def battle_member_slot_bonus
    sum = 0
    feature_objects.each{|obj|
    if obj.note =~ /<增加参战人数:(.*?)>/
      sum += eval($1)
    end
    }
    sum
  end
  #--------------------------------------------------------------------------
  # ● 减少参战人数统计
  #--------------------------------------------------------------------------
  def battle_member_slot_penalty
    sum = 0
    feature_objects.each do |obj|
      if obj.note =~ /<减少参战人数:(.*?)>/
        sum += eval($1)
      end
    end
    sum
  end
end

#==============================================================================
# 为突破人数上限的战斗状态窗口增加 A 翻页功能
#==============================================================================
class Window_BattleStatus
  PAGE_SIZE = 4

  alias tab_page_initialize initialize
  def initialize
    tab_page_initialize
    @page = 0
    @last_auto_actor = nil
    @last_item_max = item_max  # ★ 记录当前人数
  end

  def page_row_max
    PAGE_SIZE
  end

  def top_row
    @page * PAGE_SIZE
  end

  def top_row=(row)
    self.oy = @page * PAGE_SIZE * line_height
  end

  # ★ 核心：人数变化时重建 contents
  alias tab_page_refresh refresh
  def refresh
    $game_party.refresh_battle_members_cache if $game_party.respond_to?(:refresh_battle_members_cache)
    
    # ★ 重建 contents，保持窗口高度不变
    contents.dispose
    self.contents = Bitmap.new(contents_width, contents_height)
    
    tab_page_refresh  # 现在画，item_max 是最新的
    
    @page ||= 0
    total_pages = (item_max + PAGE_SIZE - 1) / PAGE_SIZE
    @page = total_pages - 1 if @page >= total_pages && total_pages > 0
    @page = 0 if @page < 0

    if index < @page * PAGE_SIZE || index >= (@page + 1) * PAGE_SIZE
      actor = BattleManager.actor
      if actor
        idx = $game_party.battle_members.index(actor)
        if idx && idx.between?(@page * PAGE_SIZE, (@page + 1) * PAGE_SIZE - 1)
          select(idx)
        else
          select(-1)
        end
      else
        select(@page * PAGE_SIZE)
      end
    end
    
    self.top_row = 0
    
    # 绘制页数信息
    draw_page_info
  end

  # 翻页更新
  alias tab_page_update update
  def update
    tab_page_update

    if Input.trigger?(MaxBattleMembers::TURN_KEY )
      Sound.play_cursor
      total_pages = (item_max + PAGE_SIZE - 1) / PAGE_SIZE
      @page = (@page + 1) % total_pages
      refresh
      actor = BattleManager.actor
      if actor
        idx = $game_party.battle_members.index(actor)
        if idx && idx.between?(@page * PAGE_SIZE, (@page + 1) * PAGE_SIZE - 1)
          select(idx)
        else
          select(-1)
        end
      end
    end

    auto_show_current_actor
  end

  def auto_show_current_actor
    actor = BattleManager.actor
    return unless actor
    idx = $game_party.battle_members.index(actor)
    return unless idx
    if @last_auto_actor != actor
      @last_auto_actor = actor
      unless idx.between?(@page * PAGE_SIZE, (@page + 1) * PAGE_SIZE - 1)
        @page = idx / PAGE_SIZE
        refresh
        select(idx)
      end
    end
  end

  # 光标移动
  alias tab_page_cursor_down cursor_down
  def cursor_down(wrap = false)
    return if index < 0
    if index < item_max - 1 && index < (@page + 1) * PAGE_SIZE - 1
      tab_page_cursor_down(wrap)
    end
  end

  alias tab_page_cursor_up cursor_up
  def cursor_up(wrap = false)
    return if index < 0
    if index > @page * PAGE_SIZE && index > 0
      tab_page_cursor_up(wrap)
    end
  end
  #--------------------------------------------------------------------------
  # ● 绘画页数信息
  #--------------------------------------------------------------------------  
  def draw_page_info
    total_pages = (item_max + PAGE_SIZE - 1) / PAGE_SIZE
    return if total_pages <= 1

    change_color(text_color(18))
    contents.font.size = 16
    text = sprintf("%d/%d", @page + 1, total_pages)
    tw = contents.text_size(text).width

    x = contents.width - tw - 4
    case MaxBattleMembers::PAGE_POS 
    when :right_up
      y = @page * item_height * PAGE_SIZE - 4
    when :right_down
      # 每页右下角：当前页底部往上16像素
      page_bottom = [(@page + 1) * PAGE_SIZE, item_max].min * line_height
      y = page_bottom - 16
    end
    rect = Rect.new(x, y, tw + 4, 20)
    contents.draw_text(rect, text, 2)
  end
end