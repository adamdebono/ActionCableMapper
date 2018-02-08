Pod::Spec.new do |s|
  s.name         = "ActionCableMapper"
  s.version      = "0.1"
  s.summary      = "A framework to map rails ActionCable channels into swift objects"
  s.homepage     = "http://github.com/adamdebono/ActionCableMapper"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Adam Debono" => "me@adamdebono.com" }

  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.12"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "10.0"

  s.source       = { :git => "https://github.com/adamdebono/ActionCableMapper.git", :tag => s.version }
  s.source_files  = "Source/*.swift"

  s.dependency "Starscream", "~> 3.0.4"
end
