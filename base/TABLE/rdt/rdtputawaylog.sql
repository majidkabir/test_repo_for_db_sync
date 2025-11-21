CREATE TABLE [rdt].[rdtputawaylog]
(
    [PutawayKey] int IDENTITY(1,1) NOT NULL,
    [mobile] int NOT NULL,
    [status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Storerkey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [UOM] nvarchar(5) NOT NULL,
    [Packkey] nvarchar(10) NOT NULL,
    [Sourcekey] nvarchar(30) NOT NULL,
    [caseID] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [ID] nvarchar(18) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKrdtPutaway] PRIMARY KEY ([PutawayKey])
);
GO

CREATE INDEX [IDX_RDTPUTAWAYLOG_01] ON [rdt].[rdtputawaylog] ([SKU], [AddWho], [status]);
GO
CREATE INDEX [IX_rdtPutaway_Mobile] ON [rdt].[rdtputawaylog] ([mobile]);
GO