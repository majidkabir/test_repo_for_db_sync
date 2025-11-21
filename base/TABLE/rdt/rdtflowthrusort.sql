CREATE TABLE [rdt].[rdtflowthrusort]
(
    [BatchNo] nvarchar(10) NOT NULL,
    [UserName] nvarchar(128) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT ('')
);
GO

CREATE INDEX [idx1_rdtFlowThruSort] ON [rdt].[rdtflowthrusort] ([UserName], [WaveKey], [SKU]);
GO
CREATE INDEX [idx2_rdtFlowThruSort] ON [rdt].[rdtflowthrusort] ([UserName], [WaveKey]);
GO
CREATE UNIQUE INDEX [PK_rdtFlowThruSort] ON [rdt].[rdtflowthrusort] ([BatchNo], [UserName], [WaveKey], [SKU], [Status]);
GO