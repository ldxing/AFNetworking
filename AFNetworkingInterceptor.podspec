Pod::Spec.new do |s|
  s.name         = "AFNetworkingInterceptor"
  s.version      = "1.0.0"
  s.summary      = "A powerful interceptor system for AFNetworking"
  s.description  = <<-DESC
                    A feature-complete interceptor system for AFNetworking that supports request pre-interception and response post-interception.
                    DESC
  s.homepage     = "https://github.com/yourusername/AFNetworkingInterceptor"
  s.license      = "MIT"
  s.author       = { "Your Name" => "your.email@example.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/yourusername/AFNetworkingInterceptor.git", :tag => s.version.to_s }
  s.source_files = "AFNetworkingInterceptor/**/*.{h,m}"
  s.dependency   "AFNetworking", "~> 4.0"
  s.requires_arc = true
end