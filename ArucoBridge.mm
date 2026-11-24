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
@end
