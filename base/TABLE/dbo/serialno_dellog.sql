CREATE TABLE [dbo].[serialno_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [SerialNoKey] nvarchar(10) NOT NULL,
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] char(1) NULL,
    CONSTRAINT [PK_serialno_dellog] PRIMARY KEY ([Rowref])
);
GO
