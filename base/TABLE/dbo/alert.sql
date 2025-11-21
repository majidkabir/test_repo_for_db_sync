CREATE TABLE [dbo].[alert]
(
    [AlertKey] nvarchar(18) NOT NULL,
    [ModuleName] nvarchar(30) NOT NULL,
    [AlertMessage] nvarchar(255) NOT NULL,
    [Severity] int NOT NULL DEFAULT ((5)),
    [LogDate] datetime NOT NULL DEFAULT (getdate()),
    [UserId] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [NotifyId] nvarchar(128) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Resolution] nvarchar(4000) NOT NULL DEFAULT (' '),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [Activity] nvarchar(20) NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [SKU] nvarchar(20) NULL DEFAULT (''),
    [UOM] nvarchar(10) NULL DEFAULT (''),
    [UOMQty] int NULL DEFAULT ((0)),
    [Qty] int NULL DEFAULT ((0)),
    [Lot] nvarchar(10) NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL DEFAULT (''),
    [ID] nvarchar(20) NULL DEFAULT (''),
    [TaskDetailKey] nvarchar(20) NULL DEFAULT (''),
    [UCCNo] nvarchar(20) NULL DEFAULT (''),
    [ResolveDate] datetime NULL,
    [TaskDetailKey2] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PKALert] PRIMARY KEY ([AlertKey])
);
GO
