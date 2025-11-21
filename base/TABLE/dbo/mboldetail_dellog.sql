CREATE TABLE [dbo].[mboldetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [MbolKey] nvarchar(10) NOT NULL,
    [MbolLineNumber] nvarchar(5) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [Orderkey] nvarchar(10) NULL,
    CONSTRAINT [PK_mboldetail_dellog] PRIMARY KEY ([Rowref])
);
GO
