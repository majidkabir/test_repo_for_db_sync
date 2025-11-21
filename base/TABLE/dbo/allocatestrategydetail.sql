CREATE TABLE [dbo].[allocatestrategydetail]
(
    [AllocateStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [AllocateStrategyLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [DESCR] nvarchar(60) NOT NULL DEFAULT (' '),
    [UOM] nvarchar(10) NOT NULL DEFAULT (' '),
    [PickCode] nvarchar(30) NOT NULL DEFAULT (' '),
    [LocationTypeOverride] nvarchar(10) NOT NULL DEFAULT (' '),
    [LocationTypeOverRideStripe] nvarchar(10) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKAllocateStrategyDetail] PRIMARY KEY ([AllocateStrategyKey], [AllocateStrategyLineNumber])
);
GO
