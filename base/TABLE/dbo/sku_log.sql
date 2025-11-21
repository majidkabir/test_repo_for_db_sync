CREATE TABLE [dbo].[sku_log]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [FieldName] nvarchar(25) NOT NULL,
    [OldValue] nvarchar(60) NULL DEFAULT (''),
    [NewValue] nvarchar(60) NULL DEFAULT (''),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [ProgramName] nvarchar(100) NULL,
    CONSTRAINT [PKSKU_Log] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDXSku_log] ON [dbo].[sku_log] ([StorerKey], [SKU], [FieldName]);
GO