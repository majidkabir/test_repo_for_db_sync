CREATE TABLE [dbo].[rdspodetailsize_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [rdsPONo] int NOT NULL,
    [rdsPOLineNo] nvarchar(10) NOT NULL,
    [SKU] nvarchar(30) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdspodetailsize_dellog] PRIMARY KEY ([Rowref])
);
GO
