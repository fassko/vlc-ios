/*****************************************************************************
 * VLCNetworkLoginViewController.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Pierre SAGASPE <pierre.sagaspe # me.com>
 *          Vincent L. Cone <vincent.l.cone # tuta.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCNetworkLoginViewController.h"
#import "VLCPlexWebAPI.h"

#import "VLCNetworkLoginDataSource.h"
#import "VLCNetworkLoginDataSourceProtocol.h"
#import "VLCNetworkLoginDataSourceLogin.h"
#import "VLCNetworkLoginDataSourceSavedLogins.h"
#import "VLCNetworkServerLoginInformation.h"
#import "VLC-Swift.h"


// for protocol identifier
#import "VLCLocalNetworkServiceBrowserPlex.h"
#import "VLCLocalNetworkServiceBrowserFTP.h"
#import "VLCLocalNetworkServiceBrowserDSM.h"


@interface VLCNetworkLoginViewController () <UITextFieldDelegate, VLCNetworkLoginDataSourceProtocolDelegate, VLCNetworkLoginDataSourceLoginDelegate, VLCNetworkLoginDataSourceSavedLoginsDelegate>

@property (nonatomic) VLCNetworkLoginDataSource *dataSource;
@property (nonatomic) VLCNetworkLoginDataSourceProtocol *protocolDataSource;
@property (nonatomic) VLCNetworkLoginDataSourceLogin *loginDataSource;
@property (nonatomic) VLCNetworkLoginDataSourceSavedLogins *savedLoginsDataSource;

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end

@implementation VLCNetworkLoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.modalPresentationStyle = UIModalPresentationFormSheet;

    self.title = NSLocalizedString(@"CONNECT_TO_SERVER", nil);

    self.tableView.backgroundColor = PresentationTheme.current.colors.background;
    self.tableView.separatorColor = PresentationTheme.current.colors.separatorColor;

    self.protocolDataSource = [[VLCNetworkLoginDataSourceProtocol alloc] init];
    self.protocolDataSource.delegate = self;
    self.protocolDataSource.protocol = [self protocolForProtocolIdentifier:self.loginInformation.protocolIdentifier];
    self.loginDataSource = [[VLCNetworkLoginDataSourceLogin alloc] init];
    self.loginDataSource.loginInformation = self.loginInformation;
    self.loginDataSource.delegate = self;
    self.savedLoginsDataSource = [[VLCNetworkLoginDataSourceSavedLogins alloc] init];
    self.savedLoginsDataSource.delegate = self;

    VLCNetworkLoginDataSource *dataSource = [[VLCNetworkLoginDataSource alloc] init];
    dataSource.dataSources = @[self.protocolDataSource, self.loginDataSource, self.savedLoginsDataSource];
    [dataSource configureWithTableView:self.tableView];
    self.dataSource = dataSource;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithTitle:NSLocalizedString(@"BUTTON_CONNECT", nil)
                                              style:UIBarButtonItemStyleDone target:self
                                              action:@selector(connectLoginDataSource)];
    if (@available(iOS 13.0, *)) {
        self.navigationController.navigationBar.standardAppearance = [VLCApperanceManager navigationbarAppearance];
        self.navigationController.navigationBar.scrollEdgeAppearance = [VLCApperanceManager navigationbarAppearance];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return PresentationTheme.current.colors.statusBarStyle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark -

- (VLCServerProtocol)protocolForProtocolIdentifier:(NSString *)protocolIdentifier
{
    VLCServerProtocol protocol = VLCServerProtocolUndefined;
    if ([protocolIdentifier isEqualToString:VLCNetworkServerProtocolIdentifierFTP]) {
        protocol = VLCServerProtocolFTP;
    } else if ([protocolIdentifier isEqualToString:VLCNetworkServerProtocolIdentifierSMB]) {
        protocol = VLCServerProtocolSMB;
    } else if ([protocolIdentifier isEqualToString:VLCNetworkServerProtocolIdentifierPlex]) {
        protocol = VLCServerProtocolPLEX;
    }
    return protocol;
}

- (nullable NSString *)protocolIdentifierForProtocol:(VLCServerProtocol)protocol
{
    NSString *protocolIdentifier = nil;
    switch (protocol) {
        case VLCServerProtocolFTP:
        {
            protocolIdentifier = VLCNetworkServerProtocolIdentifierFTP;
            break;
        }
        case VLCServerProtocolPLEX:
        {
            protocolIdentifier = VLCNetworkServerProtocolIdentifierPlex;
            break;
        }
        case VLCServerProtocolSMB:
        {
            protocolIdentifier = VLCNetworkServerProtocolIdentifierSMB;
        }
        default:
            break;
    }
    return protocolIdentifier;
}

- (void)setLoginInformation:(VLCNetworkServerLoginInformation *)loginInformation
{
    _loginInformation = loginInformation;
    self.protocolDataSource.protocol = [self protocolForProtocolIdentifier:loginInformation.protocolIdentifier];
    self.loginDataSource.loginInformation = loginInformation;
}

#pragma mark - VLCNetworkLoginDataSourceProtocolDelegate
- (void)protocolDidChange:(VLCNetworkLoginDataSourceProtocol *)protocolSection
{
    NSString *protocolIdentifier = [self protocolIdentifierForProtocol:protocolSection.protocol];
    VLCNetworkServerLoginInformation *login = [VLCNetworkServerLoginInformation newLoginInformationForProtocol:protocolIdentifier];
    login.address = self.loginInformation.address;
    login.username = self.loginInformation.username;
    login.password = self.loginInformation.password;
    self.loginDataSource.loginInformation = login;
}

#pragma mark - VLCNetworkLoginDataSourceLoginDelegate

- (void)saveLoginDataSource:(VLCNetworkLoginDataSourceLogin *)dataSource
{
    if (!self.protocolSelected)
        return;

    VLCNetworkServerLoginInformation *login = dataSource.loginInformation;
    // TODO: move somewere else?
    // Normalize Plex login
    if ([login.protocolIdentifier isEqualToString:@"plex"]) {
        if (!login.address.length) {
            login.address = @"Account";
        }
        if (!login.port) {
            login.port = @32400;
        }
    }

    self.loginInformation = login;
    NSError *error = nil;
    if (![self.savedLoginsDataSource saveLogin:login error:&error]) {
        [VLCAlertViewController alertViewManagerWithTitle:error.localizedDescription
                                             errorMessage:error.localizedFailureReason
                                           viewController:self];
    }

    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

- (void)connectLoginDataSource:(VLCNetworkLoginDataSourceLogin *)dataSource
{
    if (!self.protocolSelected)
        return;

    VLCNetworkServerLoginInformation *loginInformation = dataSource.loginInformation;
    self.loginInformation = loginInformation;

    [self.delegate loginWithLoginViewController:self loginInfo:dataSource.loginInformation];

    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];

    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)connectLoginDataSource
{
    [self connectLoginDataSource:self.loginDataSource];
}

- (BOOL)protocolSelected
{
    if (self.protocolDataSource.protocol == VLCServerProtocolUndefined) {
        [VLCAlertViewController alertViewManagerWithTitle:NSLocalizedString(@"PROTOCOL_NOT_SELECTED", nil)
                                             errorMessage:NSLocalizedString(@"PROTOCOL_NOT_SELECTED", nil)
                                           viewController:self];
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
        return NO;
    }
    return YES;
}

#pragma mark - VLCNetworkLoginDataSourceSavedLoginsDelegate
- (void)loginsDataSource:(VLCNetworkLoginDataSourceSavedLogins *)dataSource selectedLogin:(VLCNetworkServerLoginInformation *)login
{
    self.loginInformation = login;
}

@end
