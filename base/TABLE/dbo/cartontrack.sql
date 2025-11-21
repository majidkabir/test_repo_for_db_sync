CREATE TABLE [dbo].[cartontrack]
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
    [InvDespatchDate] datetime NULL,
    [ActualDeliveryDate] datetime NULL,
    [UDF01] nvarchar(30) NULL DEFAULT (''),
    [UDF02] nvarchar(30) NULL DEFAULT (''),
    [UDF03] nvarchar(30) NULL DEFAULT (''),
    [PrintData] nvarchar(MAX) NULL DEFAULT (''),
    [TrackingURL] nvarchar(200) NULL,
    [VendorTrackingURL] nvarchar(200) NULL,
    [Cost] float NULL DEFAULT ((0)),
    CONSTRAINT [PK_CartonTrack] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_CartonTrack_CarrierRef1] ON [dbo].[cartontrack] ([CarrierRef1]);
GO
CREATE INDEX [idx_cartontrack_LabelNo] ON [dbo].[cartontrack] ([LabelNo]);
GO
CREATE INDEX [IX_CARTONTRACK_03] ON [dbo].[cartontrack] ([CarrierName], [KeyName], [CarrierRef2], [LabelNo]);
GO
CREATE UNIQUE INDEX [idx_cartontrack_TrackingNo] ON [dbo].[cartontrack] ([TrackingNo], [CarrierName]);
GO