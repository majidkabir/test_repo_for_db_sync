CREATE TABLE [dbo].[tpb_data_batch]
(
    [Batch_Key] int IDENTITY(1,1) NOT NULL,
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Status] nchar(1) NOT NULL DEFAULT ('W'),
    [Batch_RecRow] bigint NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_tpb_data_batch] PRIMARY KEY ([Batch_Key])
);
GO

CREATE INDEX [IDX_TPB_Data_Batch_01] ON [dbo].[tpb_data_batch] ([Batch_Key], [Status]);
GO