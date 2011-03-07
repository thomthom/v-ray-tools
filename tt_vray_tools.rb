#-----------------------------------------------------------------------------
# Compatible: SketchUp 7 (PC)
#             (other versions untested)
#-----------------------------------------------------------------------------
#
# CHANGELOG
# 2.0.0 - 01.03.2011
#		 * Initial release.
#
#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.4', 'V-Ray Tools²')

#-----------------------------------------------------------------------------

module TT::Plugins::VRayTools
  
  ### CONSTANTS ### --------------------------------------------------------
  
  VERSION = '2.0.0'.freeze
  PREF_KEY = 'TT_VRayTools'.freeze
  PLUGIN_NAME = 'V-Ray Tools²'.freeze
  
  PLUGIN_PATH = File.dirname( __FILE__ )
  PLUGIN_RESOURCE_PATH = File.join( PLUGIN_PATH, 'V-Ray Tools 2' )
  ICONS_PATH = File.join( PLUGIN_RESOURCE_PATH, 'Icons' )
  
  VRAY_ATTRIBUTES = {
    '1.05' => '{DD17A615-9867-4806-8F46-B37031D7F153}',
    '1.48' => 'Something...Check the previous project to see the value we used'
  }.freeze
  
  
  ### MODULE VARIABLES ### -------------------------------------------------
  
  # Preference
  #@settings = TT::Settings.new(PREF_KEY)
  #@settings[:ray_stop_at_ground, false]
  #@settings[:rayspray_number, 32]
  
  # Ensure the VfSU 1.48+ core is loaded.
  begin
    require 'vfs.rb'
    @vray_loader = File.join( ASGVISRubyFolder, 'R2P.rb' )
  rescue
    @vray_loader = nil
  end
  
  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( File.basename(__FILE__) )
    # Commands
    cmd = UI::Command.new( 'Load V-Ray' ) { 
      self.load_vray
    }
    cmd.small_icon = File.join( ICONS_PATH, 'vfsu_16.png' )
    cmd.large_icon = File.join( ICONS_PATH, 'vfsu_24.png' )
    cmd.tooltip = 'Loads V-Ray for SketchUp'
    cmd.status_bar_text = 'Loads V-Ray for SketchUp'
    cmd_load_vfsu = cmd
    
    cmd = UI::Command.new( 'Use Selected as Material Override' ) { 
      self.load_vray
    }
    cmd.tooltip = "Use selected face's material as Material Override"
    cmd.status_bar_text = "Use selected face's material as Material Override"
    cmd_override_material = cmd
    
    cmd = UI::Command.new( 'Set Camera Aspect Ratio' ) { 
      self.todo
    }
    cmd.small_icon = File.join( ICONS_PATH, 'camera_aspect_16.png' )
    cmd.large_icon = File.join( ICONS_PATH, 'camera_aspect_24.png' )
    cmd_set_camera_aspect_ratio = cmd
    
    cmd = UI::Command.new( 'Reset Camera Aspect Ratio' ) { 
      self.reset_camera_aspect_ratio
    }
    cmd.small_icon = File.join( ICONS_PATH, 'camera_reset_16.png' )
    cmd.large_icon = File.join( ICONS_PATH, 'camera_reset_24.png' )
    cmd.tooltip = 'Resets the camera aspect ratio'
    cmd.status_bar_text = 'Resets the camera aspect ratio'
    cmd_reset_camera_aspect_ratio = cmd
    
    cmd = UI::Command.new( 'Export CameraView' ) { 
      self.todo
    }
    cmd.small_icon = File.join( ICONS_PATH, 'camera_export_viewport_16.png' )
    cmd.large_icon = File.join( ICONS_PATH, 'camera_export_viewport_24.png' )
    cmd_export_camera_view = cmd
    
    
    # Menus
    m = TT.menu('Plugins').add_submenu( PLUGIN_NAME )
    
    m_loader = m.add_item( cmd_load_vfsu )
    m.set_validation_proc( m_loader ) { menu_validate_vfsu_load }
    
    m.add_separator
    
    m.add_item( cmd_override_material )
    
    m.add_separator
    
    m.add_item('Purge V-Ray Materials') {
      self.purge_materials
    }
    m.add_item('Purge V-Ray Settings and Materials') {
      self.purge_settings_and_materialsh
    }
    m.add_item('Purge All V-Ray Data') {
      self.purge_all
    }
    
    # Context Menu
    UI.add_context_menu_handler { |context_menu|
      if self.selection_is_face_with_material?
        m = context_menu.add_submenu( PLUGIN_NAME )
        item = m.add_item( cmd_override_material )
      end
    }
    
    # Toolbar
    toolbar = UI::Toolbar.new( PLUGIN_NAME )
    
    toolbar.add_item( cmd_load_vfsu )
    toolbar.add_separator
    toolbar.add_item( cmd_set_camera_aspect_ratio )
    toolbar.add_item( cmd_reset_camera_aspect_ratio )
    toolbar.add_item( cmd_export_camera_view )
    
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
  end
  
  
  def self.menu_validate_vfsu_load
    if file_loaded?('R2P.rb')
      MF_DISABLED | MF_GRAYED
    else
      MF_ENABLED
    end
  end
  
  
  def self.menu_validate_selected_face_material
    if self.selection_is_face_with_material?
      MF_ENABLED
    else
      MF_DISABLED | MF_GRAYED
    end
  end
  
  
  def self.selection_is_face_with_material?
    model = Sketchup.active_model
    sel = model.selection
    sel.length == 1 && sel[0].is_a?( Sketchup::Face ) && sel[0].material
  end
  
  
  ### MAIN SCRIPT ### ------------------------------------------------------
  
  def self.is_vray_object?( entity )
    return false unless TT::Instance.is?( entity )
    return false if entity.attribute_dictionaries.nil?
    #VRAY_ATTRIBUTES.each { |version, vr_attribute|
    #  return true unless entity.attribute_dictionary( vr_attribute )
    #}
    self.each_vray_dictionary( entity ) { |dictionary|
      return true
    }
    return false
  end
  
  
  def self.each_vray_dictionary( entity )
    VRAY_ATTRIBUTES.each { |version, vr_attribute|
      dictionary = entity.attribute_dictionary( vr_attribute )
      yield dictionary if dictionary
    }
  end
  
  
  def self.vray_data_size( entity )
    size = 0
    self.each_vray_dictionary( entity ) { |dictionary|
      dictionary.each_pair { |k,v|
        size += v.length if v.respond_to?( :length )
      }
    }
    size
  end
  
  
  # Dummy message
  def self.todo
    UI.messagebox('Not implemented yet!')
  end
  
  
  # Reset Camera aspect ratio
  def self.reset_camera_aspect_ratio
    Sketchup.active_model.active_view.camera.aspect_ratio = 0
  end
  
  
  # Clone Material
  def self.clone_material( material, model, force_name = nil )
    if force_name
      new_material = model.materials[ force_name ] || model.materials.add( force_name )
    else
      new_material = model.materials.add( material.name )
    end
    new_material.color = material.color
    new_material.alpha = material.alpha
    if material.texture
      if File.exist?( material.texture.filename )
        new_material.texture = material.texture.filename
      else
        filename = File.basename( material.texture.filename )
        temp_file = File.join( TT::System.temp_path, 'VRayTools', filename )
        temp_group = model.entities.add_group
        temp_group.material = material
        tw = Sketchup.create_texture_writer
        tw.load( temp_group )
        tw.write( temp_group, temp_file )
        new_material.texture = temp_file
        File.delete( temp_file )
        temp_group.erase!
      end
      new_material.texture.size = [ material.texture.width, material.texture.height ]
    end
    new_material
  end
  
  
  # Use the front-side material of the selected face as material override.
  def self.use_selected_materials_as_override
    model = Sketchup.active_model
    materials = model.materials
    sel = model.selection
    
    #unless materials.respond_to?( :rename )
    #  msg = 'This function is only availible to SketchUp 8 Service Release 1 or newer.'
    #  UI.messagebox( msg )
    #  return
    #end
    
    unless self.selection_is_face_with_material?
      msg = 'Invalid selection. Select a single face with a material applied to the front.'
      UI.messagebox( msg )
      return
    end
    
    face = sel[0]
    self.clone_material( face.material, model, 'VRayOverrideMaterial' )
  end
  
  
  # Purges ALL the V-Ray attributes in the model. This includes attributes that
  # define lights, infinite planes, etc...
  def self.purge_all
    message = 'This will remove ALL V-Ray data in the model. Lights and infinite planes will no longer have V-Ray properties. Continue?'
    result = UI.messagebox( message, MB_YESNO )
    return if result == 7
    
    model = Sketchup.active_model
    materials = model.materials
    
    # Count data size
    size = 0
    
    TT::Model.start_operation('Purge All V-Ray Data')
    
    # Model
    size += self.vray_data_size( model )
    self.each_vray_dictionary( model ) { |dictionary|
      model.attribute_dictionaries.delete( dictionary )
    }
    
    # Definitions
    model.definitions.each { |d|
      next if d.image?
      size += self.vray_data_size( d )
      self.each_vray_dictionary( d ) { |dictionary|
        d.attribute_dictionaries.delete( dictionary )
      }
      # Instances
      d.instances.each { |i|
        size += self.vray_data_size( i )
        self.each_vray_dictionary( i ) { |dictionary|
          i.attribute_dictionaries.delete( dictionary )
        }
      }
    }
    
    # Materials
    (0...materials.count).each { |i|
      material = materials[i]
      size += self.vray_data_size( material )
      self.each_vray_dictionary( material ) { |dictionary|
        material.attribute_dictionaries.delete( dictionary )
      }
    }
    
    model.commit_operation
    
    message = "Purged model for #{size} bytes of V-Ray data"
    puts message
    UI.messagebox( message )
    
    size
  end
  
  
  # Purge settings and materials.
  def self.purge_settings_and_materials
    message = 'This will remove the V-Ray render settings and material data. Continue?'
    result = UI.messagebox( message, MB_YESNO )
    return if result == 7
    
    model = Sketchup.active_model
    materials = model.materials
    
    # Count data size
    size = 0
    
    TT::Model.start_operation('Purge V-Ray Settings and Materials')
    
    # Model
    size += self.vray_data_size( model )
    self.each_vray_dictionary( model ) { |dictionary|
      model.attribute_dictionaries.delete( dictionary )
    }
    
    # Materials
    (0...materials.count).each { |i|
      material = materials[i]
      size += self.vray_data_size( material )
      self.each_vray_dictionary( material ) { |dictionary|
        material.attribute_dictionaries.delete( dictionary )
      }
    }
    
    model.commit_operation
    
    message = "Purged model for #{size} bytes of V-Ray data"
    puts message
    UI.messagebox( message )
    
    size
  end
  
  
  # Purge materials.
  def self.purge_materials
    message = 'This will remove the V-Ray render material data. Continue?'
    result = UI.messagebox( message, MB_YESNO )
    return if result == 7
    
    model = Sketchup.active_model
    materials = model.materials
    
    # Count data size
    size = 0
    
    TT::Model.start_operation('Purge V-Ray Materials')
    
    # Materials
    (0...materials.count).each { |i|
      material = materials[i]
      size += self.vray_data_size( material )
      self.each_vray_dictionary( material ) { |dictionary|
        material.attribute_dictionaries.delete( dictionary )
      }
    }
    
    model.commit_operation
    
    message = "Purged materials for #{size} bytes of V-Ray data"
    puts message
    UI.messagebox( message )
    
    size
  end
  
  
  def self.load_vray
    if @vray_loader
      require @vray_loader
    else
      UI.messagebox( 'Could not load V-Ray for SketchUp. Is it installed correctly?' )
    end
  end
  
  
  ### DEBUG ### ------------------------------------------------------------
  
  def self.reload
    load __FILE__
  end
  
end # module

#-----------------------------------------------------------------------------
file_loaded( File.basename(__FILE__) )
#-----------------------------------------------------------------------------