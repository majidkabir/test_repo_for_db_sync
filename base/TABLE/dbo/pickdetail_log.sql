CREATE TABLE [dbo].[pickdetail_log]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [OrderKey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [WaveKey] nvarchar(10) NULL,
    [StorerKey] nvarchar(15) NULL,
    [B_SKU] nvarchar(20) NULL,
    [B_Lot] nvarchar(10) NULL,
    [B_Loc] nvarchar(10) NULL,
    [B_ID] nvarchar(18) NULL,
    [B_Qty] int NULL,
    [A_SKU] nvarchar(20) NULL,
    [A_Lot] nvarchar(10) NULL,
    [A_Loc] nvarchar(10) NULL,
    [A_ID] nvarchar(18) NULL,
    [A_Qty] int NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT (''),
    [PickDetailKey] nvarchar(18) NOT NULL DEFAULT (''),
    [TransmitlogKey] nvarchar(10) NOT NULL DEFAULT (''),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(215) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_PickDetail_Log] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IX_PickDetail_Log_WaveKey] ON [dbo].[pickdetail_log] ([WaveKey]);
GO