/*
 Copyright 2017 Vector Creations Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "PeopleViewController.h"

#import "UIViewController+RiotSearch.h"

#import "RageShakeManager.h"

#import "AppDelegate.h"

#import "RecentsDataSource.h"
#import "RecentTableViewCell.h"
#import "InviteRecentTableViewCell.h"

#import "ContactTableViewCell.h"

@interface PeopleViewController ()
{
    ContactsDataSource *contactsDataSource;
    
    RecentsDataSource *recentsDataSource;
}

@end

@implementation PeopleViewController

- (void)finalizeInit
{
    [super finalizeInit];
    
    self.screenName = @"People";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.view.accessibilityIdentifier = @"PeopleVCView";
    self.recentsTableView.accessibilityIdentifier = @"PeopleVCTableView";
    
    // Tag the recents table with the its recents data source mode.
    // This will be used by the shared RecentsDataSource instance for sanity checks (see UITableViewDataSource methods).
    self.recentsTableView.tag = RecentsDataSourceModePeople;
    
    __weak typeof(self) weakSelf = self;
    // Configure new chat button
    [self setNewChatBlock:^{
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            [self performSegueWithIdentifier:@"presentStartChat" sender:self];
        }
    }];
    
    // Register table view cell for contacts.
    [self.recentsTableView registerClass:ContactTableViewCell.class forCellReuseIdentifier:ContactTableViewCell.defaultReuseIdentifier];
    
    // Change the table data source. It must be the people view controller itself.
    self.recentsTableView.dataSource = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)destroy
{
    contactsDataSource.delegate = nil;
    [contactsDataSource destroy];
    contactsDataSource = nil;
    
    [super destroy];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [AppDelegate theDelegate].masterTabBarController.navigationItem.title = NSLocalizedStringFromTable(@"title_people", @"Vector", nil);
    [[AppDelegate theDelegate].masterTabBarController userInterfaceThemeDidChange];
    
    if (recentsDataSource)
    {
        // Take the lead on the shared data source.
        [recentsDataSource setDelegate:self andRecentsDataSourceMode:RecentsDataSourceModePeople];
    }
    
    // Add new chat icon to navigation bar
    [AppDelegate theDelegate].masterTabBarController.navigationItem.rightBarButtonItem = newChatButton;
    [newChatButton setEnabled:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

#pragma mark - 

- (void)displayList:(MXKRecentsDataSource *)listDataSource
{
    [super displayList:listDataSource];
    
    // Change the table data source. It must be the people view controller itself.
    self.recentsTableView.dataSource = self;
    
    // Keep a ref on the recents data source
    if ([listDataSource isKindOfClass:RecentsDataSource.class])
    {
        recentsDataSource = (RecentsDataSource*)listDataSource;
    }
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    if ([cellData isKindOfClass:MXKContact.class])
    {
        return ContactTableViewCell.class;
    }
    
    return [super cellViewClassForCellData:cellData];
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.dataSource numberOfSectionsInTableView:self.recentsTableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.dataSource tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.dataSource tableView:tableView canEditRowAtIndexPath:indexPath];
}

#pragma mark - UITableView delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

#pragma mark - Override RecentsViewController
    
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0;
}

- (void)refreshCurrentSelectedCell:(BOOL)forceVisible
{
    // Check whether the recents data source is correctly configured.
    if (recentsDataSource.recentsDataSourceMode != RecentsDataSourceModePeople)
    {
        return;
    }
    
    // Update here the index of the current selected cell (if any) - Useful in landscape mode with split view controller.
    [super refreshCurrentSelectedCell:forceVisible];
}

#pragma mark -

- (void)scrollToNextRoomWithMissedNotifications
{
    // Check whether the recents data source is correctly configured.
    if (recentsDataSource.recentsDataSourceMode == RecentsDataSourceModePeople)
    {
        [self scrollToTheTopTheNextRoomWithMissedNotificationsInSection:recentsDataSource.conversationSection];
    }
}

@end
