CREATE TABLE [rdt].[rdtuccprercvauditlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [NewUCCNo] nvarchar(20) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [QTY] int NOT NULL DEFAULT ((0)),
    [OrgUCCNo] nvarchar(20) NOT NULL DEFAULT (''),
    [ExternKey] nvarchar(20) NOT NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtUCCPreRCVAuditLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtUCCPreRCVAuditLog_RefNo1_StorerKey] ON [rdt].[rdtuccprercvauditlog] ([OrgUCCNo], [StorerKey]);
GO
CREATE INDEX [IX_rdtUCCPreRCVAuditLog_TrolleyNo_UCCNo] ON [rdt].[rdtuccprercvauditlog] ([NewUCCNo], [StorerKey], [SKU]);
GO