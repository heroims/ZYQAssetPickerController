//
//  ZYQAssetPickerController.h
//  ZYQAssetPickerControllerDemo
//
//  Created by Zhao Yiqi on 13-12-25.
//  Copyright (c) 2013年 heroims. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

typedef enum ZYQAssetsFilter:NSInteger{
    ZYQAssetsFilterAllPhotos=0,
    ZYQAssetsFilterAllVideos,
    ZYQAssetsFilterAllAssets
}ZYQAssetsFilter;

#pragma mark - ZYQAssetsGroup
typedef void (^ZYQAssetsGroupEnumerationResultsBlock)(id obj, NSUInteger index, BOOL *stop);

@interface ZYQAssetsGroup : NSObject

@property(nonatomic,strong)id originAssetGroup;
@property(nonatomic,strong)id originFetchResult;

@property(nonatomic,strong)NSString *groupName;
@property(nonatomic,assign,readonly)NSInteger count;
@property(nonatomic,copy)void(^getThumbnail)(UIImage *result);

- (void)enumerateObjectsUsingBlock:(ZYQAssetsGroupEnumerationResultsBlock)enumerationBlock;

@end

#pragma mark - ZYQAsset

typedef NS_ENUM(NSInteger, ZYQAssetMediaType) {
    ZYQAssetMediaTypeUnknown = 0,
    ZYQAssetMediaTypeImage   = 1,
    ZYQAssetMediaTypeVideo   = 2,
    ZYQAssetMediaTypeAudio   = 3,
};

@interface ZYQAsset : NSObject

@property(nonatomic,strong)id originAsset;
@property(nonatomic,copy)void(^getThumbnail)(UIImage *result);
@property(nonatomic,copy)void(^getFullScreenImage)(UIImage *result);
@property(nonatomic,copy)void(^getOriginImage)(UIImage *result);
@property(nonatomic,copy)void(^getExportSession)(AVAssetExportSession *result);
@property(nonatomic,assign,readonly)NSTimeInterval duration;
@property(nonatomic,assign,readonly)ZYQAssetMediaType mediaType;
@property(nonatomic,retain,readonly)NSDate *modificationDate;
@property(nonatomic,assign,readonly)CGSize size;

-(void)setGetThumbnail:(void (^)(UIImage *))getThumbnail fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler;

-(void)setGetFullScreenImage:(void (^)(UIImage *))getFullScreenImage fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler;

-(void)setGetOriginImage:(void (^)(UIImage *))getOriginImage fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler;

-(void)setGetExportSession:(void (^)(AVAssetExportSession *))getExportSession exportPreset:(NSString *)exportPreset fromNetwokProgressHandler:(void (^)(double ,NSError * , BOOL *, NSDictionary *))progressHandler;

@end

#pragma mark - ZYQAssetPickerController

@protocol ZYQAssetPickerControllerDelegate;

@interface ZYQAssetPickerController : UINavigationController

@property (nonatomic, weak) id <UINavigationControllerDelegate, ZYQAssetPickerControllerDelegate> delegate;

@property (nonatomic, assign) ZYQAssetsFilter assetsFilter;

@property (nonatomic, copy, readonly) NSArray *indexPathsForSelectedItems;

@property (nonatomic, assign) NSInteger maximumNumberOfSelection;
@property (nonatomic, assign) NSInteger minimumNumberOfSelection;

@property (nonatomic, strong) NSPredicate *selectionFilter;
/**
 是否根据时间降序排列,
默认：NO
 NO：时间较早拍摄的的照片，展示时排列在上面
YES：时间较早拍摄的的照片，展示时排列在最下面，（用户进入相册可以看到最新照片）
 */
@property (nonatomic, assign) BOOL timeDescSort;

@property (nonatomic, assign) BOOL scrollBottom;

@property (nonatomic, assign) BOOL showCancelButton;

@property (nonatomic, assign) BOOL showEmptyGroups;

@property (nonatomic, assign) BOOL isFinishDismissViewController;

@end

@protocol ZYQAssetPickerControllerDelegate <NSObject>

-(void)assetPickerController:(ZYQAssetPickerController *)picker didFinishPickingAssets:(NSArray *)assets;

@optional

-(void)assetPickerControllerDidCancel:(ZYQAssetPickerController *)picker;

-(void)assetPickerController:(ZYQAssetPickerController *)picker didSelectAsset:(ZYQAsset*)asset;

-(void)assetPickerController:(ZYQAssetPickerController *)picker didDeselectAsset:(ZYQAsset*)asset;

-(void)assetPickerControllerDidMaximum:(ZYQAssetPickerController *)picker;

-(void)assetPickerControllerDidMinimum:(ZYQAssetPickerController *)picker;

@end

#pragma mark - ZYQAssetViewController

@interface ZYQAssetViewController : UITableViewController

@property (nonatomic, strong) ZYQAssetsGroup *assetsGroup;
@property (nonatomic, strong) NSMutableArray *indexPathsForSelectedItems;

@end

#pragma mark - ZYQVideoTitleView

@interface ZYQVideoTitleView : UILabel

@end

#pragma mark - ZYQTapAssetView

@protocol ZYQTapAssetViewDelegate <NSObject>

-(void)touchSelect:(BOOL)select;
-(BOOL)shouldTap:(BOOL)select;

@end

@interface ZYQTapAssetView : UIView

@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) BOOL disabled;
@property (nonatomic, weak) id<ZYQTapAssetViewDelegate> delegate;

@end

#pragma mark - ZYQAssetView

@protocol ZYQAssetViewDelegate <NSObject>

-(BOOL)shouldSelectAsset:(ZYQAsset*)asset select:(BOOL)select;
-(void)tapSelectHandle:(BOOL)select asset:(ZYQAsset*)asset;

@end

@interface ZYQAssetView : UIView

- (void)bind:(ZYQAsset*)asset selectionFilter:(NSPredicate*)selectionFilter isSeleced:(BOOL)isSeleced;

@end

#pragma mark - ZYQAssetViewCell

@protocol ZYQAssetViewCellDelegate;

@interface ZYQAssetViewCell : UITableViewCell

@property(nonatomic,weak)id<ZYQAssetViewCellDelegate> delegate;

- (void)bind:(NSArray *)assets selectionFilter:(NSPredicate*)selectionFilter minimumInteritemSpacing:(float)minimumInteritemSpacing minimumLineSpacing:(float)minimumLineSpacing columns:(int)columns assetViewX:(float)assetViewX;

@end

@protocol ZYQAssetViewCellDelegate <NSObject>

- (BOOL)shouldSelectAsset:(ZYQAsset*)asset select:(BOOL)select;
- (void)didSelectAsset:(ZYQAsset*)asset;
- (void)didDeselectAsset:(ZYQAsset*)asset;

@end

#pragma mark - ZYQAssetGroupViewCell

@interface ZYQAssetGroupViewCell : UITableViewCell

- (void)bind:(ZYQAssetsGroup*)assetsGroup;

@end

#pragma mark - ZYQAssetGroupViewController

@interface ZYQAssetGroupViewController : UITableViewController

@end

