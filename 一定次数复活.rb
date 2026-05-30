#==============================================================================
# ■ RGSS3 一定次数复活 Ver1.05 (多特征叠加) by conapro
#==============================================================================
# 基于星潟「自动苏生」特征，实现限定复活次数的自动复活。
# 格式：<一定次数复活:回复量,动画ID,次数>
# 例：   <一定次数复活:self.mhp,42,3>
# 多个特征同时存在时，按特征列表顺序依次消耗（一个耗尽才用下一个）。
# 所有次数耗尽后特征失效；若来源为状态则同时移除该状态。
#==============================================================================

module A_Resurrection_Count
  WORD = "一定次数复活"
end

#==============================================================================
# ■ BattleManager
#==============================================================================
class << BattleManager
  def resurrection_count_data
    @resurrection_count_data ||= []
  end

  alias init_members_resurrection_count init_members
  def init_members
    init_members_resurrection_count
    @resurrection_count_data = []
  end

  # 查找指定特征对应的记录
  def resurrection_count_find(user, f_obj)
    resurrection_count_data.find { |d| d[:user] == user && d[:f_obj] == f_obj }
  end

  # 更新特征次数并返回是否仍可用（true 表示本次复活成功）
  def resurrection_count_consume(user, total_count, f_obj)
    data = resurrection_count_find(user, f_obj)
    unless data
      # 首次使用：创建记录，总次数 = total_count
      data = { user: user, f_obj: f_obj, count: total_count.to_i }
      resurrection_count_data.push(data)
    end

    if data[:count] > 0
      data[:count] -= 1
      return true
    else
      return false
    end
  end

  # 删除指定特征的所有记录
  def resurrection_count_delete(user, f_obj)
    resurrection_count_data.reject! { |d| d[:user] == user && d[:f_obj] == f_obj }
  end
end

#==============================================================================
# ■ RPG::BaseItem
#==============================================================================
class RPG::BaseItem
  # 返回所有一定次数复活数据的数组（缓存）
  def a_resurrection_count
    return @a_resurrection_count_cache if @a_resurrection_count_cache
    @a_resurrection_count_cache = []

    @note.each_line do |line|
      memo = line.scan(/<#{A_Resurrection_Count::WORD}[：:](\S+)>/).flatten
      next if memo.empty?

      data = memo[0].split(/\s*,\s*/)
      next if data.size < 2
      data.push("0") if data.size < 3
      data[1] = data[1].to_i
      # 格式: [回复量算式, 动画ID, 总次数字符串]
      @a_resurrection_count_cache.push(data)
    end
    @a_resurrection_count_cache
  end
end

#==============================================================================
# ■ Game_Battler
#==============================================================================
class Game_Battler < Game_BattlerBase
  alias add_state_a_resurrection_count add_state
  def add_state(state_id)
    if state_id == death_state_id && BattleManager.resurrection && !state?(death_state_id)
      # 防重入锁
      return add_state_a_resurrection_count(state_id) if @a_resurrection_processing
      @a_resurrection_processing = true

      original_data = a_resurrection_check(state_id)

      # 收集所有有效的一定次数复活特征（回复量 > 0）
      count_features = a_resurrection_count_features
      chosen = nil

      # 按特征顺序尝试消耗
      count_features.each do |(hp_val, anim_id, f_obj, total_count_str)|
        # 检查该特征是否还有剩余次数
        if BattleManager.resurrection_count_consume(self, total_count_str, f_obj)
          chosen = [hp_val, anim_id, f_obj]
          break
        end
      end

      # 处理选择结果
      if chosen
        # 选中的特征有效，设置复活数据
        @result.a_resurrection = chosen
        # 若特征为状态且次数耗尽（本次消耗后 count 变为 0）则移除状态
        data = BattleManager.resurrection_count_find(self, chosen[2])
        if data && data[:count] == 0 && chosen[2].is_a?(RPG::State)
          remove_state(chosen[2].id)
          BattleManager.resurrection_count_delete(self, chosen[2])
        end
      else
        # 所有次数特征均耗尽，回退到原始自动苏生
        if original_data[0] > 0
          @result.a_resurrection = original_data
        else
          @result.a_resurrection = [0, 0, nil]
        end
      end

      add_state_a_resurrection_count(state_id)
      @a_resurrection_processing = false
    else
      add_state_a_resurrection_count(state_id)
    end
  end

  # 返回所有可用的次数复活特征（已解析回复量、动画、特征对象、总次数）
  def a_resurrection_count_features
    features = []
    feature_objects.each do |f|
      f.a_resurrection_count.each do |data|
        hp_recover = eval(data[0]).to_i
        next unless hp_recover > 0
        features.push([hp_recover, data[1], f, data[2]])
      end
    end
    features
  end
end