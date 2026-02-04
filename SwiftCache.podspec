Pod::Spec.new do |s|
  s.name             = 'SwiftCache'
  s.version          = '1.0.0'
  s.summary          = 'High-performance caching framework with disk and memory support'
  s.description      = 'High-performance caching framework with disk and memory support. Built with modern Swift.'
  s.homepage         = 'https://github.com/muhittincamdali/SwiftCache'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Muhittin Camdali' => 'contact@muhittincamdali.com' }
  s.source           = { :git => 'https://github.com/muhittincamdali/SwiftCache.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_versions = ['5.9', '5.10', '6.0']
  s.source_files = 'Sources/**/*.swift'
end
