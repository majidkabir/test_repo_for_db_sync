CREATE TABLE [dbo].[strategy]
(
    [StrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [PreAllocateStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [AllocateStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ReplenishmentStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [PutawayStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [PickStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [TTMStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [VASStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ABCPAStrategyKey] nvarchar(10) NULL,
    [TransferStrategyKey] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PKStrategy] PRIMARY KEY ([StrategyKey])
);
GO
