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

TT::Lib.compatible?('2.5.0', 'V-Ray Tools²')

#-----------------------------------------------------------------------------

module TT::Plugins::VRayTools
  
  ### CONSTANTS ### --------------------------------------------------------
  
  VERSION = '2.0.0'.freeze
  PREF_KEY = 'TT_VRayTools'.freeze
  PLUGIN_NAME = 'V-Ray Tools²'.freeze
  
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
    m = TT.menu('Plugins').add_submenu( PLUGIN_NAME )
    
    m_loader = m.add_item('Load V-Ray') { self.load_vray }
    m.set_validation_proc( m_loader ) { menu_validate_vfsu_load }
    
    m.add_separator
    
    m.add_item('Purge All V-Ray Data') { self.purge_all }
  end
  
  
  def self.menu_validate_vfsu_load
    if file_loaded?('R2P.rb')
      MF_DISABLED | MF_GRAYED
    else
      MF_ENABLED
    end
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
  
  
  # ...
  def self.purge_all
    model = Sketchup.active_model
    materials = model.materials
    
    # Count data size
    size = 0
    
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
    
    message = "Purged model for #{size} bytes of V-Ray data"
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