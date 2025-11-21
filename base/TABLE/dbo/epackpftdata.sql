CREATE TABLE [dbo].[epackpftdata]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [TaskBatchNo] nvarchar(10) NULL,
    [Orderkey] nvarchar(10) NULL,
    [OrderMode] nvarchar(10) NULL,
    [Cartonno] int NULL,
    [Sku] nvarchar(20) NULL,
    [RefNo] nvarchar(40) NULL,
    [CartonType] nvarchar(20) NULL,
    [Weight] float NULL,
    [PackConfirm] nvarchar(10) NULL DEFAULT ('N'),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [LoginID] nvarchar(30) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [SerialNo] nvarchar(30) NULL DEFAULT (''),
    [QRCode] nvarchar(100) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_EPACKPFTDATA] PRIMARY KEY ([RowRef])
);
GO
