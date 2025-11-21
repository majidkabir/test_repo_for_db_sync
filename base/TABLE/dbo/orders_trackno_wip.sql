CREATE TABLE [dbo].[orders_trackno_wip]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [TrackBatchNo] int NOT NULL,
    [KeyName] nvarchar(50) NOT NULL DEFAULT (''),
    [CarrierName] nvarchar(10) NOT NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Order_TrackNo_WIP] PRIMARY KEY ([RowID])
);
GO

CREATE INDEX [IX_Order_TrackNo_WIP] ON [dbo].[orders_trackno_wip] ([TrackBatchNo], [RowID]);
GO
CREATE INDEX [IX_Orders_TrackNo_WIP_02] ON [dbo].[orders_trackno_wip] ([OrderKey]);
GO