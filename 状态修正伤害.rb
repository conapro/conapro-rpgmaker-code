class RPG::BaseItem
  # 根据正则模式提取备注里的数据，返回形如 [["10","2.0","50"], ...] 的数组
  def get_state_damage_data(pattern)
    self.note.scan(pattern).map { |m| m[0].split(/\s*,\s*/).map(&:strip) }
  end
end

class Game_Battler
  alias state_damage_execute_damage execute_damage

  def execute_damage(user)
    # 1. 使用者状态修正（标签：<状态伤害修正自:状态ID,公式,概率>）
    user_mods = user.feature_objects.flat_map { |obj|
      obj.get_state_damage_data(/<状态伤害修正自[：:]\s*(.+?)>/i)
    }
    apply_state_mod(user_mods) { |d| user.state?(d[0].to_i) }

    # 2. 目标状态修正（标签：<状态伤害修正敌:状态ID,公式,概率>）
    target_mods = feature_objects.flat_map { |obj|
      obj.get_state_damage_data(/<状态伤害修正敌[：:]\s*(?!(?:自))(.+?)>/i)
    }
    apply_state_mod(target_mods) { |d| state?(d[0].to_i) }

    # 3. 双方状态修正（标签：<状态伤害修正敌自:目标状态ID,使用者状态ID,公式,概率>）
    combo_mods = feature_objects.flat_map { |obj|
      obj.get_state_damage_data(/<状态伤害修正敌自[：:]\s*(.+?)>/i)
    }
    apply_state_mod(combo_mods) { |d| state?(d[0].to_i) && user.state?(d[1].to_i) }

    state_damage_execute_damage(user)
  end


  def apply_state_mod(data)
    data.each do |d|
      next unless yield(d)                         # 检查状态条件
      next unless d[-1].to_i > rand(100)           # 概率判定（d[-1]是概率）
      @result.hp_damage = (@result.hp_damage * eval(d[-2])).to_i  # 应用公式（d[-2]是公式）
    end
  end
end