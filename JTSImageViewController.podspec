Pod::Spec.new do |s|
  s.name         = "JTSImageViewController"
  s.version      = "1.5"
  s.summary      = "An interactive iOS image viewer that does it all: double tap to zoom, flick to dismiss, et cetera."
  s.homepage     = "https://github.com/jaredsinclair/JTSImageViewController"
  s.license      = { :type => 'MIT', :file => 'LICENSE'  }
  s.author       = { "Jared Sinclair" => "desk@jaredsinclair.com" }
  s.source       = { :git => "http://github.com/mafmoff/JTSImageViewController.git", :tag => "#{s.version}" }  
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.frameworks   = 'UIKit', 'ImageIO', 'Accelerate'
  
  s.compiler_flags = "-fmodules"
  
  s.ios.deployment_target = '7.0'
  
  s.source_files = ['Source/*.{h,m}']

end
