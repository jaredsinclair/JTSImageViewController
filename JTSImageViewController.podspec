Pod::Spec.new do |s|
  s.name         = "JTSImageViewController"
  s.version      = "0.0.1"
  s.summary      = "An interactive iOS image viewer that does it all: double tap to zoom, flick to dismiss, et cetera."
  s.description  = <<-DESC
                   JTSImageViewController is like a "light box" for iOS. It's similar to image viewers you may have seen in apps like Twitter, Tweetbot, and others. It presents an image in a full-screen interactive view. Users can pan and zoom, and use Tweetbot-style dynamic gestures to dismiss it with a fun flick.
                   DESC
  s.homepage     = "https://github.com/jaredsinclair/JTSImageViewController"
  s.author    = "Jared Sinclair"
  s.social_media_url   = "http://twitter.com/jaredsinclair"

  s.platform     = :ios, "7.0"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.source       = { :git => "https://github.com/jaredsinclair/JTSImageViewController.git", :tag => s.version.to_s }
  s.source_files  = "Source"
  s.compiler_flags = "-fmodules"

  s.requires_arc = true
end
