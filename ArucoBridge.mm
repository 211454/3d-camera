#import "ArucoBridge.h"
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/calib3d.hpp>
#include <cmath>
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
                                @"edgePixels": @(length), @"angleDegrees": @(angle)}];
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return result;
}

+ (NSArray<NSDictionary<NSString *, NSNumber *> *> *)markerPosesInPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                                              fx:(double)fx fy:(double)fy cx:(double)cx cy:(double)cy {
    if (!pixelBuffer || fx <= 0 || fy <= 0) return @[];
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
        cv::Matx33d K(fx, 0, cx, 0, fy, cy, 0, 0, 1);
        // 26 mm ArUco square; all four corners, not the projected image edge angle.
        const float half = 0.013f;
        std::vector<cv::Point3f> objectPoints = {
            {-half, half, 0}, {half, half, 0}, {half, -half, 0}, {-half, -half, 0}
        };
        for (size_t i = 0; i < ids.size(); ++i) {
            if (corners[i].size() != 4) continue;
            cv::Vec3d rvec, tvec;
            if (!cv::solvePnP(objectPoints, corners[i], K, cv::noArray(), rvec, tvec, false, cv::SOLVEPNP_IPPE_SQUARE)) continue;
            cv::Matx33d R;
            cv::Rodrigues(rvec, R);
            std::vector<cv::Point2f> projected;
            cv::projectPoints(objectPoints, rvec, tvec, K, cv::noArray(), projected);
            double error = 0;
            for (size_t j = 0; j < 4; ++j) error += cv::norm(projected[j] - corners[i][j]);
            error /= 4.0;
            if (!std::isfinite(error) || error > 3.0 || tvec[2] <= 0) continue;
            [result addObject:@{@"id": @(ids[i]), @"r00": @(R(0,0)), @"r01": @(R(0,1)), @"r02": @(R(0,2)),
                                @"r10": @(R(1,0)), @"r11": @(R(1,1)), @"r12": @(R(1,2)),
                                @"r20": @(R(2,0)), @"r21": @(R(2,1)), @"r22": @(R(2,2)),
                                @"errorPx": @(error)}];
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return result;
}
@end
