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

TT::Lib.compatible?('2.6.0', 'V-Ray Tools²')

#-----------------------------------------------------------------------------

module TT::Plugins::VRayTools
  
  ### CONSTANTS ### --------------------------------------------------------
  
  PLUGIN_NAME = 'V-Ray Tools²'.freeze
  PLUGIN_VERSION = '2.0.0'.freeze
  
  PREF_KEY = 'TT_VRayTools'.freeze
  
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH_PLUGIN = File.join( PATH_ROOT, 'V-Ray Tools 2' ).freeze
  PATH_ICONS  = File.join( PATH_PLUGIN, 'Icons' ).freeze
  
  VRAY_ATTRIBUTES = {
    '1.05' => '{DD17A615-9867-4806-8F46-B37031D7F153}'.freeze,
    '1.48' => 'Something...Check the previous project to see the value we used'.freeze
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
  rescue LoadError
    @vray_loader = nil
  end
  
  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    # Commands
    cmd = UI::Command.new( 'Load V-Ray' ) { 
      self.load_vray
    }
    cmd.small_icon = File.join( PATH_ICONS, 'vfsu_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'vfsu_24.png' )
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
      self.open_camera_window
    }
    cmd.small_icon = File.join( PATH_ICONS, 'camera_aspect_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'camera_aspect_24.png' )
    cmd_set_camera_aspect_ratio = cmd
    
    cmd = UI::Command.new( 'Reset Camera Aspect Ratio' ) { 
      self.reset_camera_aspect_ratio
    }
    cmd.small_icon = File.join( PATH_ICONS, 'camera_reset_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'camera_reset_24.png' )
    cmd.tooltip = 'Resets the camera aspect ratio'
    cmd.status_bar_text = 'Resets the camera aspect ratio'
    cmd_reset_camera_aspect_ratio = cmd
    
    cmd = UI::Command.new( 'Export CameraView' ) { 
      self.open_camera_window
    }
    cmd.small_icon = File.join( PATH_ICONS, 'camera_export_viewport_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'camera_export_viewport_24.png' )
    cmd_export_camera_view = cmd
    
    
    # Menus
    m = TT.menu('Plugins').add_submenu( PLUGIN_NAME )
    
    menu = m.add_item( cmd_load_vfsu )
    m.set_validation_proc( menu ) { menu_validate_vfsu_load }
    
    m.add_separator
    
    m.add_item( 'Distance Probe' ) {
      Sketchup.active_model.select_tool( DistanceProbe.new )
    }
    
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
    #toolbar.add_item( cmd_export_camera_view )
    
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
  end
  
  
  # @since 2.0.0
  def self.menu_validate_vfsu_load
    if file_loaded?('R2P.rb')
      MF_DISABLED | MF_GRAYED
    else
      MF_ENABLED
    end
  end
  
  
  # @since 2.0.0
  def self.menu_validate_selected_face_material
    if self.selection_is_face_with_material?
      MF_ENABLED
    else
      MF_DISABLED | MF_GRAYED
    end
  end
  
  
  # @since 2.0.0
  def self.selection_is_face_with_material?
    model = Sketchup.active_model
    sel = model.selection
    sel.length == 1 && sel[0].is_a?( Sketchup::Face ) && sel[0].material
  end
  
  
  ### MAIN SCRIPT ### ------------------------------------------------------
  
  # @since 2.0.0
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
  
  
  # @since 2.0.0
  def self.each_vray_dictionary( entity )
    VRAY_ATTRIBUTES.each { |version, vr_attribute|
      dictionary = entity.attribute_dictionary( vr_attribute )
      yield dictionary if dictionary
    }
  end
  
  
  # @since 2.0.0
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
  #
  # @since 2.0.0
  def self.todo
    UI.messagebox('Not implemented yet!')
  end
  
  
  # Reset Camera aspect ratio
  #
  # @since 2.0.0
  def self.reset_camera_aspect_ratio
    Sketchup.active_model.active_view.camera.aspect_ratio = 0
  end
  
  
  # @since 2.0.0
  def self.open_camera_window
    
    view = Sketchup.active_model.active_view
    camera = view.camera
    
    #unless @window
      props = {
        :dialog_title => 'Camera Tools',
        :width => 200,
        :height => 250,
        :resizable => false
      }
      @window = TT::GUI::ToolWindow.new( props )
      @window.theme = TT::GUI::Window::THEME_GRAPHITE
      
      change_event = proc { |control|
        #self.filter_changed( control.value )
        puts control.value
      }
      
      # Aspect Ratio
      eAspectChange = DeferredEvent.new { |value| self.aspect_changed( value ) }
      aspect_ratio = TT::Locale.float_to_string( camera.aspect_ratio )
      txtAspectRatio = TT::GUI::Textbox.new( aspect_ratio )
      txtAspectRatio.top = 10
      txtAspectRatio.left = 80
      txtAspectRatio.width = 30
      txtAspectRatio.add_event_handler( :textchange ) { |control|
        eAspectChange.call( control.value )
      }
      @window.add_control( txtAspectRatio )
      
      lblWidth = TT::GUI::Label.new( 'Aspect Ratio:', txtAspectRatio )
      lblWidth.top = 10
      lblWidth.left = 10
      @window.add_control( lblWidth )
      
      btnResetAspect = TT::GUI::Button.new( 'Reset' ) { |control|
        self.reset_camera_aspect_ratio
        textbox = @window.get_control_by_ui_id( txtAspectRatio.ui_id )
        textbox.value = TT::Locale.float_to_string( 0.0 )
      }
      btnResetAspect.size( 75, 23 )
      btnResetAspect.right = 5
      btnResetAspect.top = 7
      @window.add_control( btnResetAspect )
      
      # Width
      eWidthChange = DeferredEvent.new { |value| self.width_changed( value ) }
      txtWidth = TT::GUI::Textbox.new( view.vpwidth )
      txtWidth.top = 100
      txtWidth.left = 50
      txtWidth.width = 40
      txtWidth.add_event_handler( :textchange ) { |control|
        eWidthChange.call( control.value )
      }
      @window.add_control( txtWidth )
      
      lblWidth = TT::GUI::Label.new( 'Width:', txtWidth )
      lblWidth.top = 100
      lblWidth.left = 10
      @window.add_control( lblWidth )
      
      # Height
      txtHeight = TT::GUI::Textbox.new( view.vpheight )
      txtHeight.top = 100
      txtHeight.left = 140
      txtHeight.width = 40
      txtHeight.add_event_handler( :textchange, &change_event )
      @window.add_control( txtHeight )
      
      lblHeight = TT::GUI::Label.new( 'Height:', txtHeight )
      lblHeight.top = 100
      lblHeight.left = 100
      @window.add_control( lblHeight )
      
      # Export
      btnExport = TT::GUI::Button.new( 'Export' ) { |control|
        self.todo
      }
      btnExport.size( 75, 23 )
      btnExport.right = 5
      btnExport.top = 130
      @window.add_control( btnExport )
      
      # Close
      btnClose = TT::GUI::Button.new( 'Close' ) { |control|
        control.window.close
      }
      btnClose.size( 75, 23 )
      btnClose.right = 5
      btnClose.bottom = 5
      @window.add_control( btnClose )
    #end
    
    @window.show_window
    @window
  end
  
  
  # Class that defer a procs execution by a given delay. If a value is given
  # it will only trigger if the value has changed.
  #
  # @since 2.0.0
  class DeferredEvent
    
    # @since 2.0.0
    def initialize( delay = 0.2, &block )
      @proc = block
      @delay = delay
      @last_value = nil
      @timer = nil
    end
    
    # @since 2.0.0
    def call( value )
      return false if value == @last_value
      UI.stop_timer( @timer ) if @timer
      @timer = UI.start_timer( @delay, false ) {
        UI.stop_timer( @timer ) # Ensure it only runs once.
        @proc.call( value )
      }
      true
    end
    
  end # class DeferredEvent
  
  
  # @since 2.0.0
  def self.width_changed( value )
    puts value
  end
  
  
  # @since 2.0.0
  def self.aspect_changed( value )
    aspect_ratio = TT::Locale.string_to_float( value )
    Sketchup.active_model.active_view.camera.aspect_ratio = aspect_ratio
  end
  
  
  # @since 2.0.0
  def self.export_safeframe
    # (!)
    self.export_viewport( width, height )
  end
  
  
  # @since 2.0.0
  class DistanceProbe
    
    # @since 2.0.0
    def initialize
      @distance = nil
      @ip_mouse = Sketchup::InputPoint.new
    end
    
    # @since 2.0.0
    def resume( view )
      view.invalidate
    end
    
    # @since 2.0.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 2.0.0
    def onMouseMove( flags, x, y, view )
      @ip_mouse.pick( view, x, y )
      @distance = view.camera.eye.distance( @ip_mouse.position )
      inches = sprintf( '%.2f', @distance.to_f )
      view.tooltip = "Distance in model units: #{@distance}\nDistance in inches: #{inches}"
      view.invalidate
    end
    
    # @since 2.0.0
    def draw( view )
      if @ip_mouse.display?
        view.drawing_color = [0,0,0]
        view.line_stipple = ''
        view.line_width = 1
        view.draw( GL_LINES, view.camera.eye, @ip_mouse.position )
        
        @ip_mouse.draw( view )
      end
    end
    
  end
  
  
  # @since 2.0.0
  def self.export_viewport( width, height, antialias = false, transparent = false )
      filename = UI.savepanel('Export Camera Safeframe')
      return if filename == nil
      
      view = Sketchup.active_model.active_view
      result = view.write_image( filename, width, height, antialias )
      
      if result
        UI.messagebox 'Image saved to: ' + filename
      else
        UI.messagebox 'Failed to save image.'
      end
    end
  
  
  # Clone Material
  #
  # @since 2.0.0
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
  #
  # @since 2.0.0
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
  #
  # @since 2.0.0
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
  #
  # @since 2.0.0
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
  #
  # @since 2.0.0
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
  
  
  # @since 2.0.0
  def self.load_vray
    if @vray_loader
      require @vray_loader
    else
      UI.messagebox( 'Could not load V-Ray for SketchUp. Is it installed correctly?' )
    end
  end
  
  
  ### DEBUG ### ------------------------------------------------------------
  
  # TT::Plugins::VRayTools.reload
  #
  # @since 2.0.0
  def self.reload
    original_verbose = $VERBOSE
    $VERBOSE = nil
    load __FILE__
  ensure
    $VERBOSE = original_verbose
  end
  
end # module

#-----------------------------------------------------------------------------
file_loaded( __FILE__ )
#-----------------------------------------------------------------------------