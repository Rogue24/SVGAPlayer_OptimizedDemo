#
# Be sure to run `pod lib lint SVGAPlayer_Optimized.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name         = 'SVGAPlayer_Optimized'
  s.version      = '0.1.1'
  s.summary      = 'An optimized SVGA player with Swift and Objective-C extensions.'
  s.description  = 'SVGARePlayer is a refactored version based on SVGAPlayer, and SVGAExPlayer is an enhanced version of SVGARePlayer. Besides retaining the original functionality, I mainly optimized "loading prevention" and "API simplification".'
  s.homepage     = 'https://github.com/Rogue24/SVGAPlayer_Optimized'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Rogue24' => 'zhoujianping24@hotmail.com' }
  s.source       = { :git => 'https://github.com/Rogue24/SVGAPlayer_Optimized.git', :tag => s.version.to_s }

  s.platform     = :ios, '12.0'
  s.requires_arc = true
  s.swift_version = '5.0'
  
  s.source_files = 'SVGAPlayer_Optimized/*.{h,m,swift}'
  s.public_header_files = 'SVGAPlayer_Optimized/*.h'

  # 依赖声明
  s.dependency 'SVGAPlayer', '2.5.7'
  s.dependency 'Protobuf', '3.22.1'
end
