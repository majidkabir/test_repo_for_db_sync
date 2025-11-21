CREATE TABLE [dbo].[cc]
(
    [CCKey] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT (' '),
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [Facility] nvarchar(5) NULL,
    CONSTRAINT [PKCC] PRIMARY KEY ([CCKey])
);
GO

CREATE INDEX [IDX_CC_STATUS] ON [dbo].[cc] ([Status]);
GO
CREATE INDEX [IDX_CC_TASKDETAILKEY] ON [dbo].[cc] ([TaskDetailKey]);
GO