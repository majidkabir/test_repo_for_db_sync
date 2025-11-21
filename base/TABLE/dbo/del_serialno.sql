CREATE TABLE [dbo].[del_serialno]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [SerialNoKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [SerialNo] nvarchar(30) NOT NULL,
    [Qty] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [LotNo] nvarchar(20) NULL,
    CONSTRAINT [PK_del_serialno] PRIMARY KEY ([Rowref])
);
GO
