#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN
@interface ArucoBridge : NSObject
+ (NSArray<NSNumber *> *)markerIDsInPixelBuffer:(CVPixelBufferRef)pixelBuffer;
+ (NSArray<NSDictionary<NSString *, NSNumber *> *> *)markerObservationsInPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end
NS_ASSUME_NONNULL_END
