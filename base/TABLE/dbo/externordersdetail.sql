CREATE TABLE [dbo].[externordersdetail]
(
    [ExternOrderDetailKey] bigint IDENTITY(1,1) NOT NULL,
    [ExternOrderKey] nvarchar(50) NOT NULL,
    [ExternLineNo] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NULL DEFAULT (''),
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QRCode] nvarchar(100) NOT NULL,
    [RFIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [TIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [Userdefine01] nvarchar(20) NULL,
    [Userdefine02] nvarchar(20) NULL,
    [Userdefine03] nvarchar(20) NULL,
    [Userdefine04] nvarchar(20) NULL,
    [Userdefine05] nvarchar(20) NULL,
    [Userdefine06] nvarchar(20) NULL,
    [Userdefine07] nvarchar(20) NULL,
    [Userdefine08] nvarchar(20) NULL,
    [Userdefine09] nvarchar(20) NULL,
    [Userdefine10] nvarchar(20) NULL,
    [Notes] nvarchar(4000) NULL,
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Adddate] datetime NOT NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Editdate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKExternOrdersDetail] PRIMARY KEY ([ExternOrderDetailKey])
);
GO

CREATE INDEX [IX_ExternOrdersDetail_ExternOrderKey] ON [dbo].[externordersdetail] ([ExternOrderKey], [ExternLineNo]);
GO
CREATE INDEX [IX_ExternOrdersDetail_OrderKey] ON [dbo].[externordersdetail] ([OrderKey], [OrderLineNumber]);
GO
CREATE INDEX [IX_ExternOrdersDetail_QRCode] ON [dbo].[externordersdetail] ([QRCode]);
GO
CREATE INDEX [IX_ExternOrdersDetail_RFIDNo] ON [dbo].[externordersdetail] ([RFIDNo], [Storerkey]);
GO
CREATE INDEX [IX_ExternOrdersDetail_SKU] ON [dbo].[externordersdetail] ([Storerkey], [SKU]);
GO