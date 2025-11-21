CREATE TABLE [rdt].[rdtflowthrusortdistr]
(
    [BatchNo] nvarchar(10) NOT NULL,
    [UserName] nvarchar(128) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [PickSlipNo] nvarchar(10) NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [ConsigneeKey] nvarchar(15) NULL,
    [C_Company] nvarchar(45) NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT ('')
);
GO

CREATE UNIQUE INDEX [PK_rdtFlowThruSort] ON [rdt].[rdtflowthrusortdistr] ([BatchNo], [UserName], [WaveKey], [OrderKey], [SKU]);
GO