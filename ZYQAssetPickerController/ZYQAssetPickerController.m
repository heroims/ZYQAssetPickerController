//
//  ZYQAssetPickerController.m
//  ZYQAssetPickerControllerDemo
//
//  Created by Zhao Yiqi on 13-12-25.
//  Copyright (c) 2013年 heroims. All rights reserved.
//

#import "ZYQAssetPickerController.h"

#define IS_IOS7             ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending)
#define IS_IOS8             ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)

#define kThumbnailLength    78.0f
#define kThumbnailSize      CGSizeMake(kThumbnailLength, kThumbnailLength)
#define kPopoverContentSize CGSizeMake(320, 480)

#pragma mark -

@interface NSDate (TimeInterval)

+ (NSDateComponents *)componetsWithTimeInterval:(NSTimeInterval)timeInterval;
+ (NSString *)timeDescriptionOfTimeInterval:(NSTimeInterval)timeInterval;

@end

@implementation NSDate (TimeInterval)

+ (NSDateComponents *)componetsWithTimeInterval:(NSTimeInterval)timeInterval
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:timeInterval sinceDate:date1];
    
    unsigned int unitFlags =
    NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour |
    NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear;
    
    return [calendar components:unitFlags
                       fromDate:date1
                         toDate:date2
                        options:0];
}

+ (NSString *)timeDescriptionOfTimeInterval:(NSTimeInterval)timeInterval
{
    NSString *newTime;
    if (timeInterval < 10) {
        newTime = [NSString stringWithFormat:@"0:0%zd",(NSInteger)timeInterval];
    } else if (timeInterval < 60) {
        newTime = [NSString stringWithFormat:@"0:%zd",(NSInteger)timeInterval];
    } else {
        NSInteger min = timeInterval / 60;
        NSInteger sec = timeInterval - (min * 60);
        if (sec < 10) {
            newTime = [NSString stringWithFormat:@"%zd:0%zd",min,sec];
        } else {
            newTime = [NSString stringWithFormat:@"%zd:%zd",min,sec];
        }
    }
    return newTime;
}

@end

#pragma mark - ZYQAssetsGroup

@interface ZYQAssetsGroup(){
    UIImage *_cacheThumbnail;
}

@end

@implementation ZYQAssetsGroup : NSObject

-(NSString*)groupName{
    if (_originAssetGroup) {
        if ([_originAssetGroup isKindOfClass:[PHCollection class]]) {
            return [(PHCollection*)_originAssetGroup localizedTitle];
        }
        else if([_originAssetGroup isKindOfClass:[ALAssetsGroup class]]){
            return [(ALAssetsGroup*)_originAssetGroup valueForProperty:ALAssetsGroupPropertyName];
        }
    }
    return nil;
}

-(NSInteger)count{
    if (_originAssetGroup) {
        if ([_originAssetGroup isKindOfClass:[PHCollection class]]) {
            if (!_originFetchResult) {
                PHFetchOptions *fetchOptionsAlbums=[[PHFetchOptions alloc] init];
                
                _originFetchResult=[PHCollection fetchCollectionsInCollectionList:_originAssetGroup options:fetchOptionsAlbums];
            }
            return [(PHFetchResult*)_originFetchResult count];
        }
        else if([_originAssetGroup isKindOfClass:[ALAssetsGroup class]]){
            return [(ALAssetsGroup*)_originAssetGroup numberOfAssets];
        }
    }
    return 0;
}

-(void)setGetThumbnail:(void (^)(UIImage *))getThumbnail{
    _getThumbnail=getThumbnail;
    
    if (_originAssetGroup) {
        if (_cacheThumbnail) {
            _getThumbnail(_cacheThumbnail);
            return;
        }
        
        if ([_originAssetGroup isKindOfClass:[ALAssetsGroup class]]) {
            
            CGImageRef posterImage      = [(ALAssetsGroup*)_originAssetGroup posterImage];
            size_t height               = CGImageGetHeight(posterImage);
            float scale                 = height / kThumbnailLength;
            
            _cacheThumbnail             = [UIImage imageWithCGImage:posterImage scale:scale orientation:UIImageOrientationUp];

            _getThumbnail(_cacheThumbnail);
        }
        else if ([_originAssetGroup isKindOfClass:[PHCollection class]]){
            if (!_originFetchResult) {
                PHFetchOptions *fetchOptionsAlbums=[[PHFetchOptions alloc] init];
                
                _originFetchResult=[PHCollection fetchCollectionsInCollectionList:_originAssetGroup options:fetchOptionsAlbums];
            }
            PHFetchResult *tmpFetchResult=_originFetchResult;
            PHAsset *tmpAsset=[tmpFetchResult objectAtIndex:tmpFetchResult.count-1];
            
            PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            [[PHImageManager defaultManager] requestImageForAsset:tmpAsset targetSize:CGSizeMake(200, 200) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage *result, NSDictionary *info){
                BOOL downloadFinined = ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];
                
                //设置BOOL判断，确定返回高清照片
                if (downloadFinined) {
                    float scale                 = result.size.height / kThumbnailLength;
                    
                    _cacheThumbnail=[UIImage imageWithCGImage:result.CGImage scale:scale orientation:UIImageOrientationUp];
                    
                    _getThumbnail(_cacheThumbnail);
                    
                }
            }];
        }
    }
}

-(void)enumerateObjectsUsingBlock:(ZYQAssetsGroupEnumerationResultsBlock)enumerationBlock{
    if (_originAssetGroup) {
        if ([_originAssetGroup isKindOfClass:[PHCollection class]]) {
            if (!_originFetchResult) {
                PHFetchOptions *fetchOptionsAlbums=[[PHFetchOptions alloc] init];
                
                _originFetchResult=[PHCollection fetchCollectionsInCollectionList:_originAssetGroup options:fetchOptionsAlbums];
            }
            return [(PHFetchResult*)_originFetchResult enumerateObjectsUsingBlock:enumerationBlock];
        }
        else if([_originAssetGroup isKindOfClass:[ALAssetsGroup class]]){
            return [(ALAssetsGroup*)_originAssetGroup enumerateAssetsUsingBlock:enumerationBlock];
        }
    }
}

@end
#pragma mark - ZYQAsset
@interface ZYQAsset(){
    UIImage *_cacheThumbnail;
    UIImage *_cacheFullScreenImage;
    UIImage *_cacheOriginImage;

    AVAssetExportSession *_cacheExportSession;
}

@end

@implementation ZYQAsset : NSObject

-(void)setGetThumbnail:(void (^)(UIImage *))getThumbnail fromNetwokProgressHandler:(void (^)(double, NSError *, BOOL *, NSDictionary *))progressHandler{
    _getThumbnail=getThumbnail;
    
    if (_originAsset) {
        if (_cacheThumbnail) {
            _getThumbnail(_cacheThumbnail);
            return;
        }
        
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            _cacheThumbnail=[UIImage imageWithCGImage:[(ALAsset*)_originAsset thumbnail]];
            _getThumbnail(_cacheThumbnail);
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                if (progressHandler) {
                    progressHandler(progress,error,stop,info);
                }
            };
            [[PHImageManager defaultManager] requestImageForAsset:_originAsset targetSize:CGSizeMake(200, 200) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage *result, NSDictionary *info){
                BOOL downloadFinined = NO;
                
                downloadFinined = ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];//设置BOOL判断，确定返回高清照片

                if (downloadFinined) {
                    _cacheThumbnail=result;
                    _getThumbnail(_cacheThumbnail);
                }
            }];
        }
    }
}

-(void)setGetExportSession:(void (^)(AVAssetExportSession *))getExportSession exportPreset:(NSString *)exportPreset fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler{
    
    _getExportSession=getExportSession;
    
    if (_originAsset) {
        if (_cacheExportSession) {
            _getExportSession(_cacheExportSession);
            return;
        }
        
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            
            AVURLAsset *avasset=[AVURLAsset URLAssetWithURL:[(ALAsset*)_originAsset defaultRepresentation].url options:nil];
            _cacheExportSession = [[AVAssetExportSession alloc] initWithAsset:avasset presetName:exportPreset];
            _getExportSession(_cacheExportSession);
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            PHVideoRequestOptions *requestOptions = [[PHVideoRequestOptions alloc] init];
            requestOptions.deliveryMode = PHVideoRequestOptionsDeliveryModeMediumQualityFormat;
            requestOptions.networkAccessAllowed=YES;
            
            requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                if (progressHandler) {
                    progressHandler(progress,error,stop,info);
                }
            };
            
            [[PHImageManager defaultManager]  requestExportSessionForVideo:_originAsset options:requestOptions exportPreset:exportPreset resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
                
                _cacheExportSession=exportSession;
                _getExportSession(_cacheExportSession);
            }];
        }
    }

}

-(void)setGetFullScreenImage:(void (^)(UIImage *))getFullScreenImage fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler{
    _getFullScreenImage=getFullScreenImage;
    
    if (_originAsset) {
        if (_cacheFullScreenImage) {
            _getFullScreenImage(_cacheFullScreenImage);
            return;
        }
        
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            _cacheFullScreenImage=[UIImage imageWithCGImage:[(ALAsset*)_originAsset defaultRepresentation].fullScreenImage];
            _getFullScreenImage(_cacheFullScreenImage);
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            
            CGFloat photoWidth = [UIScreen mainScreen].bounds.size.width;
            
            CGFloat aspectRatio = ((PHAsset*)_originAsset).pixelWidth / (CGFloat)((PHAsset*)_originAsset).pixelHeight;
            CGFloat multiple = [UIScreen mainScreen].scale;
            CGFloat pixelWidth = photoWidth * multiple;
            CGFloat pixelHeight = pixelWidth / aspectRatio;
            
            requestOptions.networkAccessAllowed=YES;
            
            
            requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                if (progressHandler) {
                    progressHandler(progress,error,stop,info);
                }
            };
            
            [[PHImageManager defaultManager] requestImageForAsset:_originAsset targetSize:CGSizeMake(pixelWidth, pixelHeight) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage *result, NSDictionary *info){
                BOOL downloadFinined = NO;
                
                downloadFinined = ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];//设置BOOL判断，确定返回高清照片
                
                if (downloadFinined) {
                    _cacheFullScreenImage=result;
                    _getFullScreenImage(_cacheFullScreenImage);
                }
            }];
        }
    }

}

-(void)setGetOriginImage:(void (^)(UIImage *))getOriginImage fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler{
    _getOriginImage=getOriginImage;
    
    if (_originAsset) {
        if (_cacheOriginImage) {
            _getOriginImage(_cacheOriginImage);
            return;
        }
        
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            ALAssetRepresentation *image_representation=[(ALAsset*)_originAsset defaultRepresentation];
            Byte * buffer = (Byte*)malloc(image_representation.size);
            NSUInteger length = [image_representation getBytes:buffer fromOffset: 0.0 length:image_representation.size error:nil];

            if (length != 0)  {
                NSData *adata = [[NSData alloc] initWithBytesNoCopy:buffer length:image_representation.size freeWhenDone:YES];
                _cacheOriginImage = [UIImage imageWithData:adata];
            }

            _getOriginImage(_cacheOriginImage);
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
                                    
            requestOptions.networkAccessAllowed=YES;
            
            requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                if (progressHandler) {
                    progressHandler(progress,error,stop,info);
                }
            };
            
            [[PHImageManager defaultManager] requestImageForAsset:_originAsset targetSize:CGSizeMake(((PHAsset*)_originAsset).pixelWidth, ((PHAsset*)_originAsset).pixelHeight) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage *result, NSDictionary *info){
                BOOL downloadFinined = NO;
                
                downloadFinined = ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];//设置BOOL判断，确定返回高清照片

                if (downloadFinined) {
                    _cacheFullScreenImage=result;
                    _getFullScreenImage(_cacheFullScreenImage);
                }
            }];
        }
    }
}

-(void)setGetExportSession:(void (^)(AVAssetExportSession *))getExportSession{
    [self setGetExportSession:getExportSession exportPreset:AVAssetExportPresetMediumQuality fromNetwokProgressHandler:nil];
}

-(void)setGetThumbnail:(void (^)(UIImage *))getThumbnail{
    [self setGetThumbnail:getThumbnail fromNetwokProgressHandler:nil];
}

-(void)setGetFullScreenImage:(void (^)(UIImage *))getFullScreenImage{
    [self setGetFullScreenImage:getFullScreenImage fromNetwokProgressHandler:nil];
}

-(void)setGetOriginImage:(void (^)(UIImage *))getOriginImage{
    [self setGetOriginImage:getOriginImage fromNetwokProgressHandler:nil];
}


-(NSTimeInterval)duration{
    if (_originAsset) {
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            return [[(ALAsset*)_originAsset valueForProperty:ALAssetPropertyDuration] doubleValue];
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            return [(PHAsset*)_originAsset duration];
        }
    }
    return 0;
}

-(CGSize)size{
    if (_originAsset) {
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            return [(ALAsset*)_originAsset defaultRepresentation].dimensions;
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            return CGSizeMake(((PHAsset*)_originAsset).pixelWidth, ((PHAsset*)_originAsset).pixelHeight);
        }
    }
    return CGSizeMake(0, 0);

}
-(NSDate*)modificationDate{
    if (_originAsset) {
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            return [(ALAsset*)_originAsset valueForProperty:ALAssetPropertyDate];
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            return [(PHAsset*)_originAsset modificationDate];
        }
    }
    return nil;

}

-(ZYQAssetMediaType)mediaType{
    if (_originAsset) {
        if ([_originAsset isKindOfClass:[ALAsset class]]) {
            if ([[(ALAsset*)_originAsset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypePhoto]) {
                return ZYQAssetMediaTypeImage;
            }
            if ([[(ALAsset*)_originAsset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]) {
                return ZYQAssetMediaTypeVideo;
            }
        }
        else if ([_originAsset isKindOfClass:[PHAsset class]]){
            switch ([(PHAsset*)_originAsset mediaType]) {
                case PHAssetMediaTypeImage:
                    return ZYQAssetMediaTypeImage;
                case PHAssetMediaTypeVideo:
                    return ZYQAssetMediaTypeVideo;
                case PHAssetMediaTypeAudio:
                    return ZYQAssetMediaTypeAudio;
                default:
                    break;
            }
        }
    }
    return ZYQAssetMediaTypeUnknown;
}

@end

#pragma mark - ZYQAssetPickerController

@interface ZYQAssetPickerController ()

@property (nonatomic, copy) NSArray *indexPathsForSelectedItems;

@end

#pragma mark - ZYQVideoTitleView

@implementation ZYQVideoTitleView

-(void)drawRect:(CGRect)rect{
    CGFloat colors [] = {
        0.0, 0.0, 0.0, 0.0,
        0.7, 0.7, 0.7, 0.6,
        1.0, 1.0, 1.0, 1.0
    };

    CGFloat locations [] = {0.0, 0.75, 1.0};

    CGColorSpaceRef baseSpace   = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient      = CGGradientCreateWithColorComponents(baseSpace, colors, locations, 2);
    CGColorSpaceRelease(baseSpace);

    CGContextRef context    = UIGraphicsGetCurrentContext();
    
    CGFloat height          = rect.size.height;
    CGPoint startPoint      = CGPointMake(0, 0);
    CGPoint endPoint        = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);

    CGGradientRelease(gradient);

    CGSize titleSize        = [self.text sizeWithAttributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:self.textColor}];
    [self.text drawAtPoint:CGPointMake(rect.size.width - titleSize.width - 2 , (height - 12) / 2) withAttributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:self.textColor}];

    UIImage *videoIcon=[UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"ZYQAssetPicker.Bundle/Images/AssetsPickerVideo@2x.png"]];
    
    [videoIcon drawAtPoint:CGPointMake(2, (height - videoIcon.size.height) / 2)];
    
}

@end

#pragma mark - ZYQTapAssetView

@interface ZYQTapAssetView ()

@property(nonatomic,retain)UIImageView *selectView;

@end

@implementation ZYQTapAssetView

static UIImage *checkedIcon;
static UIColor *selectedColor;
static UIColor *disabledColor;

+ (void)initialize
{
    checkedIcon     = [UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"ZYQAssetPicker.Bundle/Images/%@@2x.png",(!IS_IOS7) ? @"AssetsPickerChecked~iOS6" : @"AssetsPickerChecked"]]];
    selectedColor   = [UIColor colorWithWhite:1 alpha:0.3];
    disabledColor   = [UIColor colorWithWhite:1 alpha:0.9];
}

-(id)initWithFrame:(CGRect)frame{
    if (self=[super initWithFrame:frame]) {
        _selectView=[[UIImageView alloc] initWithFrame:CGRectMake(frame.size.width-checkedIcon.size.width, frame.size.height-checkedIcon.size.height, checkedIcon.size.width, checkedIcon.size.height)];
        [self addSubview:_selectView];
    }
    return self;
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if (_disabled) {
        return;
    }
    
    if (_delegate!=nil&&[_delegate respondsToSelector:@selector(shouldTap:)]) {
        if (![_delegate shouldTap:_selected]&&!_selected) {
            return;
        }
    }

    if ((_selected=!_selected)) {
        self.backgroundColor=selectedColor;
        [_selectView setImage:checkedIcon];
    }
    else{
        self.backgroundColor=[UIColor clearColor];
        [_selectView setImage:nil];
    }
    if (_delegate!=nil&&[_delegate respondsToSelector:@selector(touchSelect:)]) {
        [_delegate touchSelect:_selected];
    }
}

-(void)setDisabled:(BOOL)disabled{
    _disabled=disabled;
    if (_disabled) {
        self.backgroundColor=disabledColor;
    }
    else{
        self.backgroundColor=[UIColor clearColor];
    }
}

-(void)setSelected:(BOOL)selected{
    if (_disabled) {
        self.backgroundColor=disabledColor;
        [_selectView setImage:nil];
        return;
    }

    _selected=selected;
    if (_selected) {
        self.backgroundColor=selectedColor;
        [_selectView setImage:checkedIcon];
    }
    else{
        self.backgroundColor=[UIColor clearColor];
        [_selectView setImage:nil];
    }
}

@end

#pragma mark - ZYQAssetView

@interface ZYQAssetView ()<ZYQTapAssetViewDelegate>

@property (nonatomic, strong) ZYQAsset *asset;

@property (nonatomic, weak) id<ZYQAssetViewDelegate> delegate;

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) ZYQVideoTitleView *videoTitle;
@property (nonatomic, retain) ZYQTapAssetView *tapAssetView;

@end

@implementation ZYQAssetView

static UIFont *titleFont = nil;

static CGFloat titleHeight;
static UIColor *titleColor;

+ (void)initialize
{
    titleFont       = [UIFont systemFontOfSize:12];
    titleHeight     = 20.0f;
    titleColor      = [UIColor whiteColor];
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.opaque                     = YES;
        self.isAccessibilityElement     = YES;
        self.accessibilityTraits        = UIAccessibilityTraitImage;
        
        _imageView=[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kThumbnailSize.width, kThumbnailSize.height)];
        [self addSubview:_imageView];
        
        _videoTitle=[[ZYQVideoTitleView alloc] initWithFrame:CGRectMake(0, kThumbnailSize.height-20, kThumbnailSize.width, titleHeight)];
        _videoTitle.hidden=YES;
        _videoTitle.font=titleFont;
        _videoTitle.textColor=titleColor;
        _videoTitle.textAlignment=NSTextAlignmentRight;
        _videoTitle.backgroundColor=[UIColor colorWithWhite:0 alpha:0.6];
        [self addSubview:_videoTitle];
        
        _tapAssetView=[[ZYQTapAssetView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _tapAssetView.delegate=self;
        [self addSubview:_tapAssetView];
    }
    
    return self;
}

- (void)bind:(ZYQAsset*)asset selectionFilter:(NSPredicate*)selectionFilter isSeleced:(BOOL)isSeleced
{
    self.asset=asset;

    __weak typeof(self) weakSelf=self;
    [_asset setGetThumbnail:^(UIImage *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.imageView.image=result;
        });
    }];
    
    
    if (_asset.mediaType==ZYQAssetMediaTypeVideo) {
        _videoTitle.hidden=NO;
        _videoTitle.text=[NSDate timeDescriptionOfTimeInterval:_asset.duration];
        NSLog(@"%@",_videoTitle.text);

    }
    else{
        _videoTitle.hidden=YES;
    }
    
    _tapAssetView.disabled=! [selectionFilter evaluateWithObject:_asset];
    
    _tapAssetView.selected=isSeleced;
}

#pragma mark - ZYQTapAssetView Delegate

-(BOOL)shouldTap:(BOOL)select{
    if (_delegate!=nil&&[_delegate respondsToSelector:@selector(shouldSelectAsset:select:)]) {
        return [_delegate shouldSelectAsset:_asset select:select];
    }
    return YES;
}

-(void)touchSelect:(BOOL)select{
    if (_delegate!=nil&&[_delegate respondsToSelector:@selector(tapSelectHandle:asset:)]) {
        [_delegate tapSelectHandle:select asset:_asset];
    }
}

@end

#pragma mark - ZYQAssetViewCell

@interface ZYQAssetViewCell ()<ZYQAssetViewDelegate>

@end

@class ZYQAssetViewController;

@implementation ZYQAssetViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self=[super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    return self;
}

- (void)bind:(NSArray *)assets selectionFilter:(NSPredicate*)selectionFilter minimumInteritemSpacing:(float)minimumInteritemSpacing minimumLineSpacing:(float)minimumLineSpacing columns:(int)columns assetViewX:(float)assetViewX{
    
    if (self.contentView.subviews.count<assets.count) {
        for (int i=0; i<assets.count; i++) {
            if (i>((NSInteger)self.contentView.subviews.count-1)) {
                ZYQAssetView *assetView=[[ZYQAssetView alloc] initWithFrame:CGRectMake(assetViewX+(kThumbnailSize.width+minimumInteritemSpacing)*i, minimumLineSpacing-1, kThumbnailSize.width, kThumbnailSize.height)];
                [assetView bind:assets[i] selectionFilter:selectionFilter isSeleced:[((ZYQAssetViewController*)_delegate).indexPathsForSelectedItems containsObject:assets[i]]];
                assetView.delegate=self;
                [self.contentView addSubview:assetView];
            }
            else{
                ((ZYQAssetView*)self.contentView.subviews[i]).frame=CGRectMake(assetViewX+(kThumbnailSize.width+minimumInteritemSpacing)*(i), minimumLineSpacing-1, kThumbnailSize.width, kThumbnailSize.height);
                [(ZYQAssetView*)self.contentView.subviews[i] bind:assets[i] selectionFilter:selectionFilter isSeleced:[((ZYQAssetViewController*)_delegate).indexPathsForSelectedItems containsObject:assets[i]]];
            }

        }
        
    }
    else{
        for (NSInteger i=self.contentView.subviews.count; i>0; i--) {
            if (i>assets.count) {
                [((ZYQAssetView*)self.contentView.subviews[i-1]) removeFromSuperview];
            }
            else{
                ((ZYQAssetView*)self.contentView.subviews[i-1]).frame=CGRectMake(assetViewX+(kThumbnailSize.width+minimumInteritemSpacing)*(i-1), minimumLineSpacing-1, kThumbnailSize.width, kThumbnailSize.height);
                [(ZYQAssetView*)self.contentView.subviews[i-1] bind:assets[i-1] selectionFilter:selectionFilter isSeleced:[((ZYQAssetViewController*)_delegate).indexPathsForSelectedItems containsObject:assets[i-1]]];
            }
        }
    }
}

#pragma mark - ZYQAssetView Delegate

-(BOOL)shouldSelectAsset:(ZYQAsset*)asset select:(BOOL)select{
    if (_delegate!=nil&&[_delegate respondsToSelector:@selector(shouldSelectAsset:select:)]) {
        return [_delegate shouldSelectAsset:asset select:select];
    }
    return YES;
}

-(void)tapSelectHandle:(BOOL)select asset:(ZYQAsset*)asset{
    if (select) {
        if (_delegate!=nil&&[_delegate respondsToSelector:@selector(didSelectAsset:)]) {
            [_delegate didSelectAsset:asset];
        }
    }
    else{
        if (_delegate!=nil&&[_delegate respondsToSelector:@selector(didDeselectAsset:)]) {
            [_delegate didDeselectAsset:asset];
        }
    }
}

@end

#pragma mark - ZYQAssetViewController

@interface ZYQAssetViewController ()<ZYQAssetViewCellDelegate>{
    int columns;
    
    float minimumInteritemSpacing;
    float minimumLineSpacing;
    
    BOOL unFirst;
}

@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, assign) NSInteger numberOfPhotos;
@property (nonatomic, assign) NSInteger numberOfVideos;

@end

#define kAssetViewCellIdentifier           @"AssetViewCellIdentifier"

@implementation ZYQAssetViewController

- (id)init
{
    if (self = [super init])
    {
        _indexPathsForSelectedItems=[[NSMutableArray alloc] init];
        
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        {
            self.tableView.contentInset=UIEdgeInsetsMake(9.0, 2.0, 0, 2.0);
            
            minimumInteritemSpacing=3;
            minimumLineSpacing=3;
            
        }
        else
        {
            self.tableView.contentInset=UIEdgeInsetsMake(9.0, 0, 0, 0);
            
            minimumInteritemSpacing=2;
            minimumLineSpacing=2;
        }
        
        if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
            [self setEdgesForExtendedLayout:UIRectEdgeNone];
        
        if ([self respondsToSelector:@selector(setContentSizeForViewInPopover:)])
            [self setPreferredContentSize:kPopoverContentSize];
        
    }
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupViews];
    [self setupButtons];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!unFirst) {
        columns=floor(self.view.frame.size.width/(kThumbnailSize.width+minimumInteritemSpacing));
        
        [self setupAssets];
        
        unFirst=YES;
    }
}


#pragma mark - Rotation

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
    {
        self.tableView.contentInset=UIEdgeInsetsMake(9.0, 0, 0, 0);
        
        minimumInteritemSpacing=3;
        minimumLineSpacing=3;
    }
    else
    {
        self.tableView.contentInset=UIEdgeInsetsMake(9.0, 0, 0, 0);
        
        minimumInteritemSpacing=2;
        minimumLineSpacing=2;
    }
    
    columns=floor(self.view.frame.size.width/(kThumbnailSize.width+minimumInteritemSpacing));

    [self.tableView reloadData];
}

#pragma mark - Setup

- (void)setupViews
{
    self.tableView.backgroundColor = [UIColor whiteColor];
}

- (void)setupButtons
{
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"完成", nil)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(finishPickingAssets:)];
}

- (void)setupAssets
{
    self.title = self.assetsGroup.groupName;
    self.numberOfPhotos = 0;
    self.numberOfVideos = 0;
    
    if (!self.assets)
        self.assets = [[NSMutableArray alloc] init];
    else
        [self.assets removeAllObjects];
    
    ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;

    [self.assetsGroup enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj)
        {
            ZYQAsset *asset=[[ZYQAsset alloc] init];
            asset.originAsset=obj;
            
            [self.assets addObject:asset];
            
            switch ([asset mediaType]) {
                case ZYQAssetMediaTypeImage:
                    self.numberOfPhotos ++;
                    break;
                case ZYQAssetMediaTypeVideo:
                    self.numberOfVideos ++;
                    break;
                default:
                    break;
            }
        }
        
        if (self.assetsGroup.count-1 == idx)
        {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];

                if (picker.scrollBottom) {
                    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:ceil(self.assets.count*1.0/columns)  inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
                }
            });
        }
        
    }];
    
    /**
     将数组倒序
     */
    if(picker.timeDescSort){
        NSArray *tempArray =    [[self.assets reverseObjectEnumerator] allObjects];
        [self.assets removeAllObjects];
        [self.assets addObjectsFromArray:tempArray];
    }
    

    
}

#pragma mark - UITableView DataSource
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if (indexPath.row==ceil(self.assets.count*1.0/columns)) {
        UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cellFooter"];
        
        if (cell==nil) {
            cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cellFooter"];
            cell.textLabel.font=[UIFont systemFontOfSize:18];
            cell.textLabel.backgroundColor=[UIColor clearColor];
            cell.textLabel.textAlignment=NSTextAlignmentCenter;
            cell.textLabel.textColor=[UIColor blackColor];
            cell.backgroundColor=[UIColor clearColor];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        }
        
        NSString *title;
        
        if (_numberOfVideos == 0)
            title = [NSString stringWithFormat:NSLocalizedString(@"%ld 张照片", nil), (long)_numberOfPhotos];
        else if (_numberOfPhotos == 0)
            title = [NSString stringWithFormat:NSLocalizedString(@"%ld 部视频", nil), (long)_numberOfVideos];
        else
            title = [NSString stringWithFormat:NSLocalizedString(@"%ld 张照片, %ld 部视频", nil), (long)_numberOfPhotos, (long)_numberOfVideos];
        
        cell.textLabel.text=title;
        return cell;
    }
    
    
    NSMutableArray *tempAssets=[[NSMutableArray alloc] init];
    for (int i=0; i<columns; i++) {
        if ((indexPath.row*columns+i)<self.assets.count) {
            [tempAssets addObject:[self.assets objectAtIndex:indexPath.row*columns+i]];
        }
    }
    
    static NSString *CellIdentifier = kAssetViewCellIdentifier;
    ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;
    
    ZYQAssetViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell==nil) {
        cell=[[ZYQAssetViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.delegate=self;

    [cell bind:tempAssets selectionFilter:picker.selectionFilter minimumInteritemSpacing:minimumInteritemSpacing minimumLineSpacing:minimumLineSpacing columns:columns assetViewX:(self.tableView.frame.size.width-kThumbnailSize.width*tempAssets.count-minimumInteritemSpacing*(tempAssets.count-1))/2];
    return cell;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return ceil(self.assets.count*1.0/columns)+1;
}

#pragma mark - UITableView Delegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row==ceil(self.assets.count*1.0/columns)) {
        return 44;
    }
    return kThumbnailSize.height+minimumLineSpacing;
}


#pragma mark - ZYQAssetViewCell Delegate

- (BOOL)shouldSelectAsset:(id)asset select:(BOOL)select
{
    ZYQAssetPickerController *vc = (ZYQAssetPickerController *)self.navigationController;
    BOOL selectable = [vc.selectionFilter evaluateWithObject:asset];
    if (_indexPathsForSelectedItems.count >= vc.maximumNumberOfSelection&&!select) {
        if (vc.delegate!=nil&&[vc.delegate respondsToSelector:@selector(assetPickerControllerDidMaximum:)]) {
            [vc.delegate assetPickerControllerDidMaximum:vc];
        }
    }

    return (selectable && _indexPathsForSelectedItems.count < vc.maximumNumberOfSelection);
}

- (void)didSelectAsset:(id)asset
{
    [_indexPathsForSelectedItems addObject:asset];
    
    ZYQAssetPickerController *vc = (ZYQAssetPickerController *)self.navigationController;
    vc.indexPathsForSelectedItems = _indexPathsForSelectedItems;
    
    if (vc.delegate!=nil&&[vc.delegate respondsToSelector:@selector(assetPickerController:didSelectAsset:)])
        [vc.delegate assetPickerController:vc didSelectAsset:asset];
    
    [self setTitleWithSelectedIndexPaths:_indexPathsForSelectedItems];
}

- (void)didDeselectAsset:(id)asset
{
    [_indexPathsForSelectedItems removeObject:asset];
    
    ZYQAssetPickerController *vc = (ZYQAssetPickerController *)self.navigationController;
    vc.indexPathsForSelectedItems = _indexPathsForSelectedItems;
    
    if (vc.delegate!=nil&&[vc.delegate respondsToSelector:@selector(assetPickerController:didDeselectAsset:)])
        [vc.delegate assetPickerController:vc didDeselectAsset:asset];
    
    [self setTitleWithSelectedIndexPaths:_indexPathsForSelectedItems];
}


#pragma mark - Title

- (void)setTitleWithSelectedIndexPaths:(NSArray *)indexPaths
{
    if (indexPaths.count == 0)
    {
        self.title = self.assetsGroup.groupName;
        return;
    }
    
    BOOL photosSelected = NO;
    BOOL videoSelected  = NO;
    
    for (int i=0; i<indexPaths.count; i++) {
        ZYQAsset *asset = indexPaths[i];
        
        if (asset.mediaType==ZYQAssetMediaTypeImage)
            photosSelected  = YES;
        
        if (asset.mediaType==ZYQAssetMediaTypeVideo)
            videoSelected   = YES;
        
        if (photosSelected && videoSelected)
            break;
        
    }
    
    NSString *format;
    
    if (photosSelected && videoSelected)
        format = NSLocalizedString(@"已选择 %ld 个项目", nil);
    
    else if (photosSelected)
        format = (indexPaths.count > 1) ? NSLocalizedString(@"已选择 %ld 张照片", nil) : NSLocalizedString(@"已选择 %ld 张照片 ", nil);
    
    else if (videoSelected)
        format = (indexPaths.count > 1) ? NSLocalizedString(@"已选择 %ld 部视频", nil) : NSLocalizedString(@"已选择 %ld 部视频 ", nil);
    
    self.title = [NSString stringWithFormat:format, (long)indexPaths.count];

}


#pragma mark - Actions

- (void)finishPickingAssets:(id)sender
{
    
    ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;
    
    if (_indexPathsForSelectedItems.count < picker.minimumNumberOfSelection) {
        if (picker.delegate!=nil&&[picker.delegate respondsToSelector:@selector(assetPickerControllerDidMaximum:)]) {
            [picker.delegate assetPickerControllerDidMaximum:picker];
        }
    }
    

    if ([picker.delegate respondsToSelector:@selector(assetPickerController:didFinishPickingAssets:)])
        [picker.delegate assetPickerController:picker didFinishPickingAssets:_indexPathsForSelectedItems];
    
    if (picker.isFinishDismissViewController) {
        [picker.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
    }
}

@end

#pragma mark - ZYQAssetGroupViewCell

@interface ZYQAssetGroupViewCell ()

@property (nonatomic, strong) ZYQAssetsGroup *assetsGroup;

@end

@implementation ZYQAssetGroupViewCell


- (void)bind:(ZYQAssetsGroup*)assetsGroup
{
    self.assetsGroup            = assetsGroup;
    
    __weak typeof(self) weakSelf=self;
    
    [_assetsGroup setGetThumbnail:^(UIImage *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.imageView.image=result;
            [weakSelf setNeedsLayout];
        });
    }];
    
    self.textLabel.text=_assetsGroup.groupName;
    self.detailTextLabel.text   = [NSString stringWithFormat:@"%zi", _assetsGroup.count];
    self.accessoryType          = UITableViewCellAccessoryDisclosureIndicator;
}

- (NSString *)accessibilityLabel
{
    return [_assetsGroup.groupName stringByAppendingFormat:NSLocalizedString(@"%ld 张照片", nil), (long)_assetsGroup.count];
}

@end


#pragma mark - ZYQAssetGroupViewController

@interface ZYQAssetGroupViewController()

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) NSMutableArray *groups;

@end

@implementation ZYQAssetGroupViewController

- (id)init
{
    if (self = [super initWithStyle:UITableViewStylePlain])
    {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
        self.preferredContentSize=kPopoverContentSize;
#else
        if ([self respondsToSelector:@selector(setContentSizeForViewInPopover:)])
            [self setContentSizeForViewInPopover:kPopoverContentSize];
#endif
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupViews];
    [self setupButtons];
    [self localize];
    [self setupGroup];
}


#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}


#pragma mark - Setup

- (void)setupViews
{
    self.tableView.rowHeight = kThumbnailLength + 12;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)setupButtons
{
    ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;
    
    if (picker.showCancelButton)
    {
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"取消", nil)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(dismiss:)];
    }
}

- (void)localize
{
    self.title = NSLocalizedString(@"相簿", nil);
}

- (void)setupGroup
{
    if (!self.groups)
        self.groups = [[NSMutableArray alloc] init];
    else
        [self.groups removeAllObjects];
    
    
    if (IS_IOS8) {
        __block BOOL showNotAllowed=YES;
        ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;
        
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc]init];
        
        PHFetchResult *smartAlbumsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:fetchOptions];
        //遍历相机胶卷
        [smartAlbumsFetchResult enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull collection, NSUInteger idx, BOOL *stop) {
            showNotAllowed=NO;
            PHFetchOptions *fetchOptionsAlbums=[[PHFetchOptions alloc] init];
            
            switch (picker.assetsFilter) {
                case ZYQAssetsFilterAllVideos:
                    fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
                    break;
                case ZYQAssetsFilterAllPhotos:
                    fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
                    break;
                default:
                    break;
            }
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptionsAlbums];
            
            
            if (![collection.localizedTitle isEqualToString:@"Videos"]) {
                if (fetchResult.count>0) {
                    ZYQAssetsGroup *tmpGroup=[[ZYQAssetsGroup alloc] init];
                    tmpGroup.originAssetGroup=collection;
                    tmpGroup.originFetchResult=fetchResult;
                    [self.groups addObject:tmpGroup];
                }
            }
        }];
        //遍历自建相册
        PHFetchResult *customAlbumsFetchResult = [PHAssetCollection fetchTopLevelUserCollectionsWithOptions:fetchOptions];
        [customAlbumsFetchResult enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull collection, NSUInteger idx, BOOL *stop) {
            showNotAllowed=NO;

            PHFetchOptions *fetchOptionsAlbums=[[PHFetchOptions alloc] init];
            
            switch (picker.assetsFilter) {
                case ZYQAssetsFilterAllVideos:
                    fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
                    break;
                case ZYQAssetsFilterAllPhotos:
                    fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
                    break;
                default:
                    break;
            }
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptionsAlbums];
            
            if (fetchResult.count>0) {
                ZYQAssetsGroup *tmpGroup=[[ZYQAssetsGroup alloc] init];
                tmpGroup.originAssetGroup=collection;
                tmpGroup.originFetchResult=fetchResult;
                [self.groups addObject:tmpGroup];
            }

        }];
        
        if (showNotAllowed) {
            [self showNotAllowed];
        }
        else
        {
            [self reloadData];
        }
    }
    else{
        if (!self.assetsLibrary)
            self.assetsLibrary = [self.class defaultAssetsLibrary];
        
        ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;
        
        ALAssetsFilter *assetsFilter = [ALAssetsFilter allAssets];
        
        switch (picker.assetsFilter) {
            case ZYQAssetsFilterAllPhotos:
                assetsFilter=[ALAssetsFilter allPhotos];
                break;
            case ZYQAssetsFilterAllVideos:
                assetsFilter=[ALAssetsFilter allVideos];
                break;
            default:
                break;
        }
        
        ALAssetsLibraryGroupsEnumerationResultsBlock resultsBlock = ^(ALAssetsGroup *group, BOOL *stop) {
            
            if (group)
            {
                [group setAssetsFilter:assetsFilter];
                if (group.numberOfAssets > 0 || picker.showEmptyGroups){
                    ZYQAssetsGroup *tmpGroup=[[ZYQAssetsGroup alloc] init];
                    tmpGroup.originAssetGroup=group;
                    [self.groups addObject:tmpGroup];
                }
            }
            else
            {
                [self reloadData];
            }
        };
        
        
        ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
            
            [self showNotAllowed];
            
        };
        
        // Enumerate Camera roll first
        [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                          usingBlock:resultsBlock
                                        failureBlock:failureBlock];
        
        // Then all other groups
        NSUInteger type =
        ALAssetsGroupLibrary | ALAssetsGroupAlbum | ALAssetsGroupEvent |
        ALAssetsGroupFaces | ALAssetsGroupPhotoStream;
        
        [self.assetsLibrary enumerateGroupsWithTypes:type
                                          usingBlock:resultsBlock
                                        failureBlock:failureBlock];
    }
    
}


#pragma mark - Reload Data

- (void)reloadData
{
    if (self.groups.count == 0)
        [self showNoAssets];
    
    [self.tableView reloadData];
}


#pragma mark - ALAssetsLibrary

+ (ALAssetsLibrary *)defaultAssetsLibrary
{
    static dispatch_once_t pred = 0;
    static ALAssetsLibrary *library = nil;
    dispatch_once(&pred, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    return library;
}


#pragma mark - Not allowed / No assets

- (void)showNotAllowed
{
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
        [self setEdgesForExtendedLayout:UIRectEdgeLeft | UIRectEdgeRight | UIRectEdgeBottom];
    
    self.title              = nil;
    
    UIImageView *padlock    = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"ZYQAssetPicker.Bundle/Images/AssetsPickerLocked@2x.png"]]];
    padlock.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *title          = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.preferredMaxLayoutWidth = 304.0f;
    
    UILabel *message        = [UILabel new];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.preferredMaxLayoutWidth = 304.0f;
    
    title.text              = NSLocalizedString(@"此应用无法使用您的照片或视频。", nil);
    title.font              = [UIFont boldSystemFontOfSize:17.0];
    title.textColor         = [UIColor colorWithRed:129.0/255.0 green:136.0/255.0 blue:148.0/255.0 alpha:1];
    title.textAlignment     = NSTextAlignmentCenter;
    title.numberOfLines     = 5;
    
    message.text            = NSLocalizedString(@"你可以在「隐私设置」中启用存取。", nil);
    message.font            = [UIFont systemFontOfSize:14.0];
    message.textColor       = [UIColor colorWithRed:129.0/255.0 green:136.0/255.0 blue:148.0/255.0 alpha:1];
    message.textAlignment   = NSTextAlignmentCenter;
    message.numberOfLines   = 5;
    
    [title sizeToFit];
    [message sizeToFit];
    
    UIView *centerView = [UIView new];
    centerView.translatesAutoresizingMaskIntoConstraints = NO;
    [centerView addSubview:padlock];
    [centerView addSubview:title];
    [centerView addSubview:message];
    
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(padlock, title, message);
    
    [centerView addConstraint:[NSLayoutConstraint constraintWithItem:padlock attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:centerView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [centerView addConstraint:[NSLayoutConstraint constraintWithItem:title attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:padlock attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [centerView addConstraint:[NSLayoutConstraint constraintWithItem:message attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:padlock attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [centerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[padlock]-[title]-[message]|" options:0 metrics:nil views:viewsDictionary]];
    
    UIView *backgroundView = [UIView new];
    [backgroundView addSubview:centerView];
    [backgroundView addConstraint:[NSLayoutConstraint constraintWithItem:centerView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [backgroundView addConstraint:[NSLayoutConstraint constraintWithItem:centerView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0.0f]];
    
    self.tableView.backgroundView = backgroundView;
}

- (void)showNoAssets
{
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
        [self setEdgesForExtendedLayout:UIRectEdgeLeft | UIRectEdgeRight | UIRectEdgeBottom];
    
    UILabel *title          = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.preferredMaxLayoutWidth = 304.0f;
    UILabel *message        = [UILabel new];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.preferredMaxLayoutWidth = 304.0f;
    
    title.text              = NSLocalizedString(@"没有照片或视频。", nil);
    title.font              = [UIFont systemFontOfSize:26.0];
    title.textColor         = [UIColor colorWithRed:153.0/255.0 green:153.0/255.0 blue:153.0/255.0 alpha:1];
    title.textAlignment     = NSTextAlignmentCenter;
    title.numberOfLines     = 5;
    
    message.text            = NSLocalizedString(@"您可以使用 iTunes 将照片和视频\n同步到 iPhone。", nil);
    message.font            = [UIFont systemFontOfSize:18.0];
    message.textColor       = [UIColor colorWithRed:153.0/255.0 green:153.0/255.0 blue:153.0/255.0 alpha:1];
    message.textAlignment   = NSTextAlignmentCenter;
    message.numberOfLines   = 5;
    
    [title sizeToFit];
    [message sizeToFit];
    
    UIView *centerView = [UIView new];
    centerView.translatesAutoresizingMaskIntoConstraints = NO;
    [centerView addSubview:title];
    [centerView addSubview:message];
    
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(title, message);
    
    [centerView addConstraint:[NSLayoutConstraint constraintWithItem:title attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:centerView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [centerView addConstraint:[NSLayoutConstraint constraintWithItem:message attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:title attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [centerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[title]-[message]|" options:0 metrics:nil views:viewsDictionary]];
    
    UIView *backgroundView = [UIView new];
    [backgroundView addSubview:centerView];
    [backgroundView addConstraint:[NSLayoutConstraint constraintWithItem:centerView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [backgroundView addConstraint:[NSLayoutConstraint constraintWithItem:centerView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0.0f]];
    
    self.tableView.backgroundView = backgroundView;
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.groups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    ZYQAssetGroupViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[ZYQAssetGroupViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    [cell bind:[self.groups objectAtIndex:indexPath.row]];
    
    return cell;
}


#pragma mark - UITableView Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kThumbnailLength + 12;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ZYQAssetViewController *vc = [[ZYQAssetViewController alloc] init];
    vc.assetsGroup = [self.groups objectAtIndex:indexPath.row];
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Actions

- (void)dismiss:(id)sender
{
    ZYQAssetPickerController *picker = (ZYQAssetPickerController *)self.navigationController;
    
    if ([picker.delegate respondsToSelector:@selector(assetPickerControllerDidCancel:)])
        [picker.delegate assetPickerControllerDidCancel:picker];
    
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

@end

#pragma mark - ZYQAssetPickerController

@implementation ZYQAssetPickerController

@dynamic delegate;

- (id)init
{
    ZYQAssetGroupViewController *groupViewController = [[ZYQAssetGroupViewController alloc] init];
    
    if (self = [super initWithRootViewController:groupViewController])
    {
        _maximumNumberOfSelection      = 10;
        _minimumNumberOfSelection      = 0;
        _assetsFilter                  = ZYQAssetsFilterAllAssets;
        _showCancelButton              = YES;
        _showEmptyGroups               = NO;
        _selectionFilter               = [NSPredicate predicateWithValue:YES];
        _isFinishDismissViewController = YES;
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
        self.preferredContentSize=kPopoverContentSize;
#else
        if ([self respondsToSelector:@selector(setContentSizeForViewInPopover:)])
            [self setContentSizeForViewInPopover:kPopoverContentSize];
#endif
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
