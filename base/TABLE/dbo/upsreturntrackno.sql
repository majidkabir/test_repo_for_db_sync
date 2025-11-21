CREATE TABLE [dbo].[upsreturntrackno]
(
    [Rowid] bigint IDENTITY(1,1) NOT NULL,
    [Pickslipno] nvarchar(10) NULL,
    [Labelno] nvarchar(20) NULL,
    [Orderkey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [Sku] nvarchar(20) NULL,
    [Qty] int NULL DEFAULT ((0)),
    [RefNo01] nvarchar(30) NULL,
    [RefNo02] nvarchar(30) NULL,
    [RefNo03] nvarchar(30) NULL,
    [RefNo04] nvarchar(30) NULL,
    [RefNo05] nvarchar(30) NULL,
    [RefNo06] nvarchar(30) NULL,
    [RefNo07] nvarchar(30) NULL,
    [RefNo08] nvarchar(30) NULL,
    [RefNo09] nvarchar(30) NULL,
    [RefNo10] nvarchar(30) NULL,
    [RePrint] nvarchar(1) NULL DEFAULT ('N'),
    [ADDDate] datetime NULL DEFAULT (getdate()),
    [ADDWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_UPSReturnTrackNo] PRIMARY KEY ([Rowid])
);
GO

CREATE INDEX [IDX_UPSReturnTrackNo_Orderkey] ON [dbo].[upsreturntrackno] ([Orderkey], [OrderLineNumber]);
GO
CREATE INDEX [IDX_UPSReturnTrackNo_Pickslipno] ON [dbo].[upsreturntrackno] ([Pickslipno], [Labelno], [Sku]);
GO
CREATE INDEX [IDX_UPSReturnTrackNo_RefNo01] ON [dbo].[upsreturntrackno] ([RefNo01]);
GO