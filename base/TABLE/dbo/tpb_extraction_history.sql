CREATE TABLE [dbo].[tpb_extraction_history]
(
    [TEH_Key] bigint IDENTITY(1,1) NOT NULL,
    [TEH_Batch_Key] int NOT NULL,
    [TEH_TPB_Key] int NOT NULL,
    [TEH_Datatime] datetime NULL DEFAULT (getdate()),
    [TEH_Row_Count] bigint NULL,
    [TEH_SQLMsg] nvarchar(250) NULL,
    [BillDate] date NULL,
    CONSTRAINT [PK_tpb_extraction_history] PRIMARY KEY ([TEH_Key])
);
GO
