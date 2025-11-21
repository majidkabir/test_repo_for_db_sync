CREATE TABLE [dbo].[batchpick]
(
    [Loadkey] nvarchar(10) NOT NULL,
    [QTYAllocated] int NULL DEFAULT ((0)),
    [QtyScanned] int NULL DEFAULT ((0))
);
GO

CREATE INDEX [IX_BATCHPICK_Loadkey] ON [dbo].[batchpick] ([Loadkey]);
GO