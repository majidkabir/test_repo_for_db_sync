CREATE TABLE [dbo].[packtaskdetail]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [TaskBatchNo] nvarchar(10) NOT NULL DEFAULT (''),
    [LogicalName] nvarchar(10) NOT NULL DEFAULT (''),
    [Orderkey] nvarchar(10) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [QtyPacked] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Trafficcop] nvarchar(1) NULL,
    [Archivecop] nvarchar(1) NULL,
    CONSTRAINT [PK_packtaskdetail] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_PACKTASKDETAIL] ON [dbo].[packtaskdetail] ([TaskBatchNo], [Orderkey], [Storerkey], [Sku]);
GO
CREATE INDEX [IDX_PACKTASKDETAIL_Orderkey] ON [dbo].[packtaskdetail] ([Orderkey]);
GO