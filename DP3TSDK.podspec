
Pod::Spec.new do |spec|

  spec.name         = "DP3TSDK"
  spec.version      = ENV['LIB_VERSION'] || '1.1.1'
  spec.summary      = "Open protocol for COVID-19 proximity tracing using Bluetooth Low Energy on mobile devices"

  spec.description  = <<-DESC
  The Decentralised Privacy-Preserving Proximity Tracing (DP-3T) project is an open protocol for COVID-19 proximity tracing using Bluetooth Low Energy functionality on mobile devices that ensures personal data and computation stays entirely on an individual's phone. It was produced by a core team of over 25 scientists and academic researchers from across Europe. It has also been scrutinized and improved by the wider community.

DP-3T is a free-standing effort started at EPFL and ETHZ that produced this protocol and that is implementing it in an open-sourced app and server.
                   DESC

  spec.homepage     = "https://github.com/DP-3T/documents"

  spec.license      = { :type => "MPL", :file => "LICENSE" }

  spec.author             = { "DP^3T" => "dp3t@ubique.ch" }

  spec.platform     = :ios, "13.5"

  spec.swift_versions = "5.2"

  spec.source       = { :git => "https://github.com/DP-3T/dp3t-sdk-ios.git", :branch => "develop" }

  spec.source_files  = "Sources/DP3TSDK", "Sources/DP3TSDK/**/*.{h,m,swift}"
  spec.exclude_files = "Sources/DP3TSDK/Exclude"

  spec.dependency "ZIPFoundation", "~>0.9"
  spec.dependency 'SwiftProtobuf', '~> 1.6'
  spec.dependency 'SwiftJWT', '~> 3.5'
end
