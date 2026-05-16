#==============================================================================
# ■ RGSS3 战斗bgm Ver1.00 by conapro
#==============================================================================
# 本代码可自由用于非商业用途，商业用途请联系作者（B站 conapro）
#------------------------------------------------------------------------------
# 【功能概述】
# 让敌人战斗时可以播放它专属的bgm，省去事件页的编写来改敌群的bgm
#------------------------------------------------------------------------------
# 实现：
# 在战斗开始时，会自动阅览敌群里的单位，找到顺序下第一个有专属bgm的敌人的bgm播放
# 有bgm的敌人受伤时，会自动切换战斗bgm至该敌人(踹到音响了)
# 某敌人变身为拥有专属bgm的敌人时，也会切换bgm
#==============================================================================
module EnemyBGM
  DEFAULT = {
    # 302是该敌人的脚本库绝对编号
    302 => {  
      name: "",
      volume: 80,
      pitch: 100,
    }
  }
  
  # 一般战斗的BGM
  CommonBGM = ["戦闘２",80,100]
end

class << BattleManager
  #--------------------------------------------------------------------------
  # ● 设置
  #--------------------------------------------------------------------------
  alias bgm_setup setup
  def setup(troop_id, can_escape = true, can_lose = true)
    bgm_setup(troop_id, can_escape, can_lose)
    $game_troop.members.each do |enemy|
     break if enemy.set_battle_bgm
    end
  end
  #--------------------------------------------------------------------------
  # ● 战斗结束
  #     result : 结果（0:胜利 1:撤退 2:全灭）
  #--------------------------------------------------------------------------
  alias bgm_battle_end battle_end
  def battle_end(result)
    bgm_battle_end(result)
    # 重置bgm为正常战斗bgm
    array = EnemyBGM::CommonBGM 
    $game_system.battle_bgm = RPG::BGM.new(array[0],array[1],array[2])
  end
end

class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 应用战斗背景音乐
  #--------------------------------------------------------------------------
  def set_battle_bgm
    bgm = EnemyBGM::DEFAULT[self.enemy_id]
    if bgm
      $game_system.battle_bgm = RPG::BGM.new(bgm[:name],bgm[:volume],bgm[:pitch])
      RPG::BGM.new(bgm[:name],bgm[:volume],bgm[:pitch]).play
      return true
    end
    return false
  end
  #--------------------------------------------------------------------------
  # ● 变身
  #--------------------------------------------------------------------------
  alias bgm_transform transform
  def transform(enemy_id)
    bgm_transform(enemy_id)
    set_battle_bgm
  end
end

class Game_Battler < Game_BattlerBase
  #--------------------------------------------------------------------------
  # ● 处理伤害
  #    调用前需要设置好
  #    @result.hp_damage   @result.mp_damage 
  #    @result.hp_drain    @result.mp_drain
  #--------------------------------------------------------------------------
  alias bgm_execute_damage execute_damage
  def execute_damage(user)
    bgm_execute_damage(user)
    self.set_battle_bgm if self.enemy?
  end
end