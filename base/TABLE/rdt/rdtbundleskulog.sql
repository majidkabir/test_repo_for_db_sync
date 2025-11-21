CREATE TABLE [rdt].[rdtbundleskulog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [GroupKey] int NOT NULL DEFAULT ((0)),
    [Mobile] int NOT NULL,
    [WorkOrderKey] nvarchar(10) NOT NULL,
    [Type] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [SerialNo] nvarchar(50) NOT NULL,
    [UserDefine01] nvarchar(18) NOT NULL DEFAULT (''),
    [UserDefine02] nvarchar(18) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtBundleSKULog] PRIMARY KEY ([RowRef])
);
GO
