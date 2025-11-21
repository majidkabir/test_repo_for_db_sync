CREATE TABLE [dbo].[externorders]
(
    [ExternOrdersKey] bigint IDENTITY(1,1) NOT NULL,
    [ExternOrderKey] nvarchar(50) NOT NULL,
    [OrderKey] nvarchar(10) NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL,
    [Source] nvarchar(10) NOT NULL DEFAULT (''),
    [BindingDate] datetime NULL DEFAULT (getdate()),
    [ShippedDate] datetime NULL DEFAULT (getdate()),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [PlatformName] nvarchar(100) NOT NULL DEFAULT (''),
    [PlatformOrderNo] nvarchar(50) NOT NULL DEFAULT (''),
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
    CONSTRAINT [PKExternOrders] PRIMARY KEY ([ExternOrdersKey])
);
GO

CREATE INDEX [IX_ExternOrders_PlatformOrderNo] ON [dbo].[externorders] ([PlatformOrderNo], [Storerkey]);
GO
CREATE INDEX [IXExternOrders_ExternOrderKey] ON [dbo].[externorders] ([ExternOrderKey]);
GO
CREATE INDEX [IXExternOrders_OrderKey] ON [dbo].[externorders] ([OrderKey]);
GO
CREATE INDEX [IXExternOrders_Storerkey] ON [dbo].[externorders] ([Storerkey]);
GO