
Pod::Spec.new do |s|
  s.name             = 'CrystDB'
  s.version          = '0.0.1'
  s.summary          = 'CrystDB is a thread-safe Object Relational Mapping database that stores object based on SQLite.'
  s.description      = <<-DESC
  CrystDB has these features:
    * It can automatically transform the property type of an object to storage sqlite type  for each object 
   to get better performance.
    * Uses the class to sort object and is not affected by modifying the class structure.
    * Supports filtering by conditions.
                       DESC
  s.homepage         = 'https://github.com/Chasel-Shao/CrystDB.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chasel-Shao' => '753080265@qq.com' }
  s.source           = { :git => 'https://github.com/Chasel-Shao/CrystDB.git', :tag => s.version.to_s }
  s.requires_arc = true 
  s.ios.deployment_target = '8.0'

  s.source_files = 'CrystDB/*.{h,m}'
  s.public_header_files = 'CrystDB/*.{h}'
  s.libraries = 'sqlite3'
  s.frameworks = 'UIKit', 'CoreFoundation'

end
