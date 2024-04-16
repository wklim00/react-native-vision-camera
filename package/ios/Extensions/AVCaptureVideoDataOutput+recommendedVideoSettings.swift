//
//  AVCaptureVideoDataOutput+recommendedVideoSettings.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 22.11.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVCaptureVideoDataOutput {
  private func supportsCodec(_ videoCodec: AVVideoCodecType, writingTo fileType: AVFileType) -> Bool {
    let availableCodecs = availableVideoCodecTypesForAssetWriter(writingTo: fileType)
    return availableCodecs.contains(videoCodec)
  }

  /**
   Get the recommended options for an [AVAssetWriter] with the desired [RecordVideoOptions].
   */
  func recommendedVideoSettings(forOptions options: RecordVideoOptions) throws -> [String: Any] {
    let settings: [String: Any]?
    if let videoCodec = options.codec {
      // User passed a custom codec
      if supportsCodec(videoCodec, writingTo: options.fileType) {
        // The codec is supported, use it
        settings = recommendedVideoSettings(forVideoCodecType: videoCodec, assetWriterOutputFileType: options.fileType)
        ReactLogger.log(level: .info, message: "Using codec \(videoCodec)...")
      } else {
        // The codec is not supported, fall-back to default
        settings = recommendedVideoSettingsForAssetWriter(writingTo: options.fileType)
        ReactLogger.log(level: .info, message: "Codec \(videoCodec) is not supported, falling back to default...")
      }
    } else {
      // User didn't pass a custom codec, just use default
      settings = recommendedVideoSettingsForAssetWriter(writingTo: options.fileType)
    }
    guard var settings else {
      throw CameraError.capture(.createRecorderError(message: "Failed to get video settings!"))
    }

    if let bitRateOverride = options.bitRateOverride {
      // Convert from Mbps -> bps
      let bitsPerSecond = bitRateOverride * 1_000_000
      if settings[AVVideoCompressionPropertiesKey] == nil {
        settings[AVVideoCompressionPropertiesKey] = [:]
      }
      var compressionSettings = settings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
      let currentBitRate = compressionSettings[AVVideoAverageBitRateKey] as? NSNumber
      ReactLogger.log(level: .info, message: "Setting Video Bit-Rate from \(currentBitRate?.doubleValue.description ?? "nil") bps to \(bitsPerSecond) bps...")

      compressionSettings[AVVideoAverageBitRateKey] = NSNumber(value: bitsPerSecond)
      settings[AVVideoCompressionPropertiesKey] = compressionSettings
    }

    if let bitRateMultiplier = options.bitRateMultiplier {
      // Check if the bit-rate even exists in the settings
      if var compressionSettings = settings[AVVideoCompressionPropertiesKey] as? [String: Any],
         let currentBitRate = compressionSettings[AVVideoAverageBitRateKey] as? NSNumber {
        // Multiply the current value by the given multiplier
        let newBitRate = Int(currentBitRate.doubleValue * bitRateMultiplier)
        ReactLogger.log(level: .info, message: "Setting Video Bit-Rate from \(currentBitRate) bps to \(newBitRate) bps...")

        compressionSettings[AVVideoAverageBitRateKey] = NSNumber(value: newBitRate)
        settings[AVVideoCompressionPropertiesKey] = compressionSettings
      }
    }

    return settings
  }
}
