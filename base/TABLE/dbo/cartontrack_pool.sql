CREATE TABLE [dbo].[cartontrack_pool]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TrackingNo] nvarchar(40) NULL,
    [CarrierName] nvarchar(30) NULL DEFAULT (' '),
    [KeyName] nvarchar(30) NULL DEFAULT (' '),
    [LabelNo] nvarchar(20) NULL DEFAULT (' '),
    [CarrierRef1] nvarchar(40) NULL DEFAULT (' '),
    [CarrierRef2] nvarchar(40) NULL DEFAULT (' '),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_CartonTrack_Pool] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_CartonTrack_pool_KeyName] ON [dbo].[cartontrack_pool] ([KeyName], [CarrierName]);
GO
CREATE INDEX [IX_cartontrack_pool_03] ON [dbo].[cartontrack_pool] ([CarrierName], [KeyName], [CarrierRef2], [LabelNo]);
GO
CREATE UNIQUE INDEX [IDX_Cartontrack_pool_TrackingNo] ON [dbo].[cartontrack_pool] ([TrackingNo], [CarrierName]);
GO