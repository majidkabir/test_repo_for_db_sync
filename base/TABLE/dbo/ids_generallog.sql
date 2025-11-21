CREATE TABLE [dbo].[ids_generallog]
(
    [LogKey] int IDENTITY(1,1) NOT NULL,
    [UDF01] nvarchar(100) NULL,
    [UDF02] nvarchar(100) NULL,
    [UDF03] nvarchar(100) NULL,
    [UDF04] nvarchar(100) NULL,
    [UDF05] nvarchar(100) NULL,
    [UDF06] nvarchar(100) NULL,
    [UDF07] nvarchar(100) NULL,
    [UDF08] nvarchar(400) NULL,
    [UDF09] nvarchar(400) NULL,
    [UDF10] datetime NULL,
    [LogDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_IDS_GeneralLog] PRIMARY KEY ([LogKey])
);
GO

CREATE INDEX [IDX_IDS_GeneralLog_LogDate] ON [dbo].[ids_generallog] ([LogDate]);
GO
CREATE INDEX [IX_IDS_GeneralLog] ON [dbo].[ids_generallog] ([UDF01], [UDF02], [UDF03], [UDF04]);
GO