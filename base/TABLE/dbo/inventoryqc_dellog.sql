CREATE TABLE [dbo].[inventoryqc_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [QC_Key] nvarchar(10) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_inventoryqc_dellog] PRIMARY KEY ([Rowref])
);
GO
