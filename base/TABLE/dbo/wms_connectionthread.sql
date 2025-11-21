CREATE TABLE [dbo].[wms_connectionthread]
(
    [SEQ] int IDENTITY(1,1) NOT NULL,
    [datetime] datetime NOT NULL DEFAULT (getdate()),
    [instance_name] nvarchar(50) NOT NULL,
    [machine_name] nvarchar(50) NOT NULL,
    [Workerthread] int NOT NULL DEFAULT ((0)),
    [Workerthread_Max] int NOT NULL DEFAULT ((0)),
    [Threshold_Value] int NOT NULL DEFAULT ((0)),
    [Current_Workerthread] int NOT NULL DEFAULT ((0)),
    [Work_Queue] int NOT NULL DEFAULT ((0)),
    [SP_Connection_Count] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_wms_connectionthread] PRIMARY KEY ([SEQ])
);
GO
