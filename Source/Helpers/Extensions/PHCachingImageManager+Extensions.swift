//
//  PHCachingImageManager+Helpers.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 26/01/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Photos

extension PHCachingImageManager {
    
    private func photoImageRequestOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        options.isSynchronous = true // Ok since we're already in a background thread
        return options
    }
    
    func fetchImage(for asset: PHAsset, cropRect: CGRect?, targetSize: CGSize?, callback: @escaping (UIImage, [String: Any]) -> Void) {
        let options = photoImageRequestOptions()
        
        // Fetch Highiest quality image possible.
        requestImageData(for: asset, options: options) { data, dataUTI, CTFontOrientation, info in
            
            if let data = data, let image = UIImage(data: data)?.resetOrientation() {
            
                if let cropRect = cropRect, let targetSize = targetSize {
                    
                    // if we have a cropRect and a targetSize, proceed with crop
                    
                    // Crop the high quality image manually.
                    let xCrop: CGFloat = cropRect.origin.x * CGFloat(asset.pixelWidth)
                    let yCrop: CGFloat = cropRect.origin.y * CGFloat(asset.pixelHeight)
                    let scaledCropRect = CGRect(x: xCrop,
                                                y: yCrop,
                                                width: targetSize.width,
                                                height: targetSize.height)
                    if let imageRef = image.cgImage?.cropping(to: scaledCropRect) {
                        let croppedImage = UIImage(cgImage: imageRef)
                        let exifs = self.metadataForImageData(data: data)
                        callback(croppedImage, exifs)
                    }
                    
                } else {
                    
                    // if we don't have a crop rect and target size, send back the original image
                    
                    let exifs = self.metadataForImageData(data: data)
                    callback(image, exifs)
                }
            }
        }
    }
    
    private func metadataForImageData(data: Data) -> [String: Any] {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil),
        let metaData = imageProperties as? [String : Any] {
            return metaData
        }
        return [:]
    }
    
    func fetchPreviewFor(video asset: PHAsset, callback: @escaping (UIImage) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        let screenWidth = UIScreen.main.bounds.width
        let ts = CGSize(width: screenWidth, height: screenWidth)
        requestImage(for: asset, targetSize: ts, contentMode: .aspectFill, options: options) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    callback(image)
                }
            }
        }
    }
    
    func fetchPlayerItem(for video: PHAsset, callback: @escaping (AVPlayerItem) -> Void) {
        let videosOptions = PHVideoRequestOptions()
        videosOptions.deliveryMode = PHVideoRequestOptionsDeliveryMode.automatic
        videosOptions.isNetworkAccessAllowed = true
        requestPlayerItem(forVideo: video, options: videosOptions, resultHandler: { playerItem, _ in
            DispatchQueue.main.async {
                if let playerItem = playerItem {
                    callback(playerItem)
                }
            }
        })
    }
    
    /// This method return two images in the callback. First is with low resolution, second with high.
    /// So the callback fires twice. But with isSynchronous = true there is only one high resolution image.
    /// Bool = isFromCloud
    func fetch(photo asset: PHAsset, callback: @escaping (UIImage, Bool) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        requestImage(for: asset,
                     targetSize: PHImageManagerMaximumSize,
                     contentMode: .aspectFill,
                     options: options) { result, info in
                        guard let image = result else {
                            return
                        }
                        DispatchQueue.main.async {
                            var isFromCloud = false
                            if let fromCloud = info?[PHImageResultIsDegradedKey] as? Bool {
                                isFromCloud = fromCloud
                            }
                            callback(image, isFromCloud)
                        }
        }
    }
}
