CREATE TABLE [dbo].[exceptionhandling]
(
    [RowRef] bigint NOT NULL DEFAULT ((0)),
    [Sourcekey] nvarchar(20) NOT NULL DEFAULT (''),
    [SourceType] nvarchar(30) NOT NULL DEFAULT (''),
    [ModuleType] nvarchar(30) NOT NULL DEFAULT ('PACK'),
    [Facility] nvarchar(5) NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [ExceptionCode] nvarchar(10) NULL DEFAULT (''),
    [ExceptionMsg] nvarchar(255) NULL DEFAULT (''),
    [ProcessMsg] nvarchar(255) NULL DEFAULT (''),
    [ProcessWho] nvarchar(18) NULL DEFAULT (''),
    [ProcessDate] datetime NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [UDF01] nvarchar(18) NULL DEFAULT (''),
    [UDF02] nvarchar(18) NULL DEFAULT (''),
    [UDF03] nvarchar(18) NULL DEFAULT (''),
    [UDF04] nvarchar(18) NULL DEFAULT (''),
    [UDF05] nvarchar(18) NULL DEFAULT (''),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Trafficcop] nvarchar(1) NULL,
    [Archivecop] nvarchar(1) NULL,
    CONSTRAINT [PK_EXCEPTIONHANDLING] PRIMARY KEY ([RowRef])
);
GO
