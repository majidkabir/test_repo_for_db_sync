CREATE TABLE [dbo].[tpprintconfig]
(
    [Storerkey] nvarchar(15) NOT NULL,
    [Shipperkey] nvarchar(15) NOT NULL,
    [Module] nvarchar(20) NOT NULL DEFAULT (''),
    [ReportType] nvarchar(10) NOT NULL DEFAULT (''),
    [PrePrint_StoredProc] nvarchar(30) NOT NULL,
    [TPPrint_StoredProc] nvarchar(30) NOT NULL,
    [Platform] nvarchar(30) NOT NULL DEFAULT (''),
    [Description] nvarchar(250) NULL,
    [ActiveFlag] nvarchar(5) NOT NULL,
    [UDF01] nvarchar(200) NULL DEFAULT (''),
    [UDF02] nvarchar(200) NULL DEFAULT (''),
    [UDF03] nvarchar(4000) NULL DEFAULT (''),
    [UDF04] nvarchar(4000) NULL DEFAULT (''),
    [UDF05] nvarchar(4000) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_TPPRINTCONFIG] PRIMARY KEY ([Storerkey], [Shipperkey], [Module], [ReportType], [Platform])
);
GO
