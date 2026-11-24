#import "ArucoBridge.h"
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/objdetect/aruco_detector.hpp>
#import <opencv2/objdetect/aruco_dictionary.hpp>

@implementation ArucoBridge
+ (NSArray<NSNumber *> *)markerIDsInPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) return @[];
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    @try {
        const size_t width = CVPixelBufferGetWidth(pixelBuffer);
        const size_t height = CVPixelBufferGetHeight(pixelBuffer);
        const size_t stride = CVPixelBufferGetBytesPerRow(pixelBuffer);
        void *bytes = CVPixelBufferGetBaseAddress(pixelBuffer);
        if (bytes && CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA) {
            cv::Mat bgra((int)height, (int)width, CV_8UC4, bytes, stride);
            cv::Mat gray;
            cv::cvtColor(bgra, gray, cv::COLOR_BGRA2GRAY);
            cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_250);
            cv::aruco::ArucoDetector detector(dictionary);
            std::vector<int> ids;
            std::vector<std::vector<cv::Point2f>> corners;
            detector.detectMarkers(gray, corners, ids);
            for (int markerID : ids) [result addObject:@(markerID)];
        }
    } @catch (NSException *exception) {
        NSLog(@"ArucoBridge error: %@", exception);
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return result;
}

+ (NSArray<NSDictionary<NSString *, NSNumber *> *> *)markerObservationsInPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) return @[];
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *result = [NSMutableArray array];
    const size_t width = CVPixelBufferGetWidth(pixelBuffer);
    const size_t height = CVPixelBufferGetHeight(pixelBuffer);
    void *bytes = CVPixelBufferGetBaseAddress(pixelBuffer);
    if (bytes && width > 0 && height > 0 && CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA) {
        cv::Mat bgra((int)height, (int)width, CV_8UC4, bytes, CVPixelBufferGetBytesPerRow(pixelBuffer));
        cv::Mat gray;
        cv::cvtColor(bgra, gray, cv::COLOR_BGRA2GRAY);
        cv::aruco::ArucoDetector detector(cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_250));
        std::vector<int> ids;
        std::vector<std::vector<cv::Point2f>> corners;
        detector.detectMarkers(gray, corners, ids);
        for (size_t i = 0; i < ids.size(); ++i) {
            if (corners[i].size() != 4) continue;
            cv::Point2f center(0, 0);
            for (const auto &point : corners[i]) center += point;
            center *= 0.25f;
            cv::Point2f edge = corners[i][1] - corners[i][0];
            float length = cv::norm(edge);
            float angle = std::atan2(edge.y, edge.x) * 180.0f / (float)CV_PI;
            [result addObject:@{@"id": @(ids[i]), @"x": @(center.x), @"y": @(center.y),
                                @"edgePixels": @(length), @"angleDegrees": @(angle),
                                @"u0": @(corners[i][0].x), @"v0": @(corners[i][0].y),
                                @"u1": @(corners[i][1].x), @"v1": @(corners[i][1].y),
                                @"u2": @(corners[i][2].x), @"v2": @(corners[i][2].y),
                                @"u3": @(corners[i][3].x), @"v3": @(corners[i][3].y)}];
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return result;
}
@end
