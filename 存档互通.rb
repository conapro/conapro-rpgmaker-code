#encoding:utf-8
#==============================================================================
# ■ DataManager (公共存档同步扩展 — 修复 nil 帧计数)
#==============================================================================

class << DataManager
  #--------------------------------------------------------------------------
  # ● 共享存档目录
  #--------------------------------------------------------------------------
  def shared_save_dir
    user_home = ENV['USERPROFILE'] || ENV['HOME']
    File.join(user_home, 'AppData', 'LocalLow', 'RMVXsave')
  end

  #--------------------------------------------------------------------------
  # ● 确保共享目录存在
  #--------------------------------------------------------------------------
  def ensure_shared_dir
    dir = shared_save_dir
    Dir.mkdir(dir) unless File.directory?(dir)
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 读取完整存档文件，返回 [header, contents]
  #--------------------------------------------------------------------------
  def load_full_save(filename)
    File.open(filename, "rb") do |f|
      header   = Marshal.load(f)
      contents = Marshal.load(f)
      return header, contents
    end
  rescue
    nil
  end

  #--------------------------------------------------------------------------
  # ● 写入完整存档文件（header + contents）
  #--------------------------------------------------------------------------
  def save_full_save(filename, header, contents)
    File.open(filename, "wb") do |f|
      Marshal.dump(header, f)
      Marshal.dump(contents, f)
    end
  rescue
    false
  end

  #--------------------------------------------------------------------------
  # ● 备份当前所有游戏对象
  #--------------------------------------------------------------------------
  def backup_game_objects
    @saved_objects = {
      temp:          $game_temp,
      system:        $game_system,
      timer:         $game_timer,
      message:       $game_message,
      switches:      $game_switches,
      variables:     $game_variables,
      self_switches: $game_self_switches,
      actors:        $game_actors,
      party:         $game_party,
      troop:         $game_troop,
      map:           $game_map,
      player:        $game_player
    }
  end

  #--------------------------------------------------------------------------
  # ● 恢复备份的游戏对象
  #--------------------------------------------------------------------------
  def restore_game_objects
    return unless @saved_objects
    $game_temp          = @saved_objects[:temp]
    $game_system        = @saved_objects[:system]
    $game_timer         = @saved_objects[:timer]
    $game_message       = @saved_objects[:message]
    $game_switches      = @saved_objects[:switches]
    $game_variables     = @saved_objects[:variables]
    $game_self_switches = @saved_objects[:self_switches]
    $game_actors        = @saved_objects[:actors]
    $game_party         = @saved_objects[:party]
    $game_troop         = @saved_objects[:troop]
    $game_map           = @saved_objects[:map]
    $game_player        = @saved_objects[:player]
    @saved_objects = nil
  end

  #--------------------------------------------------------------------------
  # ● 合并角色和队伍数据
  #--------------------------------------------------------------------------
  def merge_shared_data(src_header, src_contents, dst_header, dst_contents)
    dst_contents[:actors] = src_contents[:actors] if src_contents[:actors]
    dst_contents[:party]  = src_contents[:party]  if src_contents[:party]
    dst_header[:characters] = src_header[:characters] if src_header[:characters]
    return dst_header, dst_contents
  end

  #--------------------------------------------------------------------------
  # ● 文件复制
  #--------------------------------------------------------------------------
  def copy_file(src, dst)
    return unless File.exist?(src)
    File.open(dst, 'wb') {}
    IO.copy_stream(src, dst)
  end

  #--------------------------------------------------------------------------
  # ● 创建基于新游戏默认状态并注入公共角色/队伍数据的存档
  #--------------------------------------------------------------------------
  def create_new_save_with_shared(index, shared_file)
    backup_game_objects
    setup_new_game
    # 必须调用 on_before_save，否则 @frames_on_save 为 nil，读档时崩溃
    $game_system.on_before_save
    default_header   = make_save_header
    default_contents = make_save_contents
    restore_game_objects

    shared_data = load_full_save(shared_file)
    return unless shared_data
    shared_header, shared_contents = shared_data

    new_header, new_contents = merge_shared_data(
      shared_header, shared_contents,
      default_header, default_contents
    )
    save_full_save(make_filename(index), new_header, new_contents)
  end

  #--------------------------------------------------------------------------
  # ● 启动时同步
  #--------------------------------------------------------------------------
  def sync_all_from_shared
    ensure_shared_dir
    (0...savefile_max).each do |i|
      local_file  = make_filename(i)
      shared_file = File.join(shared_save_dir, local_file)
      next unless File.exist?(shared_file)

      if File.exist?(local_file)
        shared_data = load_full_save(shared_file)
        local_data  = load_full_save(local_file)
        next unless shared_data && local_data
        shared_header, shared_contents = shared_data
        local_header,  local_contents  = local_data
        new_header, new_contents = merge_shared_data(
          shared_header, shared_contents,
          local_header, local_contents
        )
        save_full_save(local_file, new_header, new_contents)
      else
        create_new_save_with_shared(i, shared_file)
      end
    end
  end

  #--------------------------------------------------------------------------
  # ● 保存时同步
  #--------------------------------------------------------------------------
  def update_shared_with_local(index)
    ensure_shared_dir
    local_file  = make_filename(index)
    shared_file = File.join(shared_save_dir, local_file)

    local_data = load_full_save(local_file)
    return unless local_data
    local_header, local_contents = local_data

    if File.exist?(shared_file)
      shared_data = load_full_save(shared_file)
      if shared_data
        shared_header, shared_contents = shared_data
        new_header, new_contents = merge_shared_data(
          local_header, local_contents,
          shared_header, shared_contents
        )
        save_full_save(shared_file, new_header, new_contents)
      else
        copy_file(local_file, shared_file)
      end
    else
      copy_file(local_file, shared_file)
    end
  end

  #--------------------------------------------------------------------------
  # ● 别名：初始化
  #--------------------------------------------------------------------------
  alias shared_patch_init init
  def init
    shared_patch_init
    sync_all_from_shared unless $BTEST
  end

  #--------------------------------------------------------------------------
  # ● 别名：存档
  #--------------------------------------------------------------------------
  alias shared_patch_save_without_rescue save_game_without_rescue
  def save_game_without_rescue(index)
    result = shared_patch_save_without_rescue(index)
    update_shared_with_local(index) if result
    result
  end

  #--------------------------------------------------------------------------
  # ● 别名：删除存档
  #--------------------------------------------------------------------------
  alias shared_patch_delete_file delete_save_file
  def delete_save_file(index)
    shared_patch_delete_file(index)
    file = File.join(shared_save_dir, make_filename(index))
    File.delete(file) if File.exist?(file)
  end
end