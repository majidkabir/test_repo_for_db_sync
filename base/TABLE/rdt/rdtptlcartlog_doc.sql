CREATE TABLE [rdt].[rdtptlcartlog_doc]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [CartID] nvarchar(10) NOT NULL,
    [DocKey] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtPTLCartLog_Doc] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtPTLCartLog_Doc_CartID_DocKey] ON [rdt].[rdtptlcartlog_doc] ([CartID], [DocKey]);
GO