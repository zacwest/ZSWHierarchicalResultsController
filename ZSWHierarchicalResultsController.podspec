Pod::Spec.new do |s|
  s.name             = "ZSWHierarchicalResultsController"
  s.version          = "1.0"
  s.summary          = "An NSFetchedResultsController replacement for a hierarchical object relationship"
  s.description      = <<-DESC
                       ZSWHierarchicalResultsController creates one section per object of its
                       NSFetchRequest and creates items inside that section for all objects in a designated
                       relationship.
                       DESC
  s.homepage         = "https://github.com/zacwest/ZSWHierarchicalResultsController"
  s.license          = 'MIT'
  s.author           = { "Zachary West" => "zacwest@gmail.com" }
  s.source           = { :git => "https://github.com/zacwest/ZSWHierarchicalResultsController.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/zacwest'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'ZSWHierarchicalResultsController/Classes/**/*', 'ZSWHierarchicalResultsController/Private/**/*'
  s.public_header_files = 'ZSWHierarchicalResultsController/Classes/**/*.h'
  s.private_header_files = 'ZSWHierarchicalResultsController/Private/**/*.h'
end
