//
//  MainViewController.m
//  ZYQAssetPickerControllerDemo
//
//  Created by Zhao Yiqi on 13-12-26.
//  Copyright (c) 2013年 heroims. All rights reserved.
//

#import "MainViewController.h"
#import "ZYQAssetPickerController.h"

@interface MainViewController ()<ZYQAssetPickerControllerDelegate,UINavigationControllerDelegate,UIScrollViewDelegate>{
    UIButton *btn;
    
    UIScrollView *src;
    
    UIPageControl *pageControl;
}

@end

@implementation MainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];


    btn=[[UIButton alloc] init];
    btn.frame=CGRectMake(60., self.view.frame.size.height-80, self.view.frame.size.width-120, 60);
    [btn setTitle:@"Open" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    
    src=[[UIScrollView alloc] initWithFrame:CGRectMake(20, 20, self.view.frame.size.width-40, self.view.frame.size.height-120)];
    src.pagingEnabled=YES;
    src.backgroundColor=[UIColor lightGrayColor];
    src.delegate=self;
    [self.view addSubview:src];
    
    pageControl=[[UIPageControl alloc] initWithFrame:CGRectMake(src.frame.origin.x, src.frame.origin.y+src.frame.size.height-20, src.frame.size.width, 20)];
    [self.view addSubview:pageControl];
	// Do any additional setup after loading the view.
}

-(void)btnClick:(id)sender{

    ZYQAssetPickerController *picker = [[ZYQAssetPickerController alloc] init];    
    picker.maximumNumberOfSelection = 5;
    picker.assetsFilter = ZYQAssetsFilterAllAssets;
    picker.showEmptyGroups=NO;
    picker.delegate=self;
    picker.selectionFilter = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        
        if ([(ZYQAsset*)evaluatedObject mediaType]==ZYQAssetMediaTypeVideo) {
            NSTimeInterval duration = [(ZYQAsset*)evaluatedObject duration];
            return duration >= 5;
        } else {
            return YES;
        }

        
    }];
    picker.modalPresentationStyle=UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:NULL];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ZYQAssetPickerController Delegate
-(void)assetPickerController:(ZYQAssetPickerController *)picker didFinishPickingAssets:(NSArray *)assets{
    [src.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    src.contentSize=CGSizeMake(assets.count*src.frame.size.width, src.frame.size.height);
    pageControl.numberOfPages=assets.count;
    for (int i=0; i<assets.count; i++) {
        ZYQAsset *asset=assets[i];
        UIImageView *imgview=[[UIImageView alloc] initWithFrame:CGRectMake(i*src.frame.size.width, 0, src.frame.size.width, src.frame.size.height)];
        imgview.contentMode=UIViewContentModeScaleAspectFill;
        imgview.clipsToBounds=YES;
        
        [asset setGetThumbnail:^(UIImage *result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [imgview setImage:result];
                [src addSubview:imgview];
            });
            
        } fromNetwokProgressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            NSLog(@"下载中%f",progress);
        }];
    }
}


-(void)assetPickerControllerDidMaximum:(ZYQAssetPickerController *)picker{
    NSLog(@"到达上限");
}

#pragma mark - UIScrollView Delegate

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    pageControl.currentPage=floor(scrollView.contentOffset.x/scrollView.frame.size.width);;
}

@end
