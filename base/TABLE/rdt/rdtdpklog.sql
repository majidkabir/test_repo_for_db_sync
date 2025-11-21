CREATE TABLE [rdt].[rdtdpklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [DropID] nvarchar(18) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [FromLot] nvarchar(10) NOT NULL,
    [FromID] nvarchar(18) NULL,
    [QtyMove] int NOT NULL,
    [PAQty] int NOT NULL,
    [CaseID] nvarchar(20) NULL,
    [BOMSKU] nvarchar(20) NULL,
    [Taskdetailkey] nvarchar(10) NOT NULL,
    [UserKey] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_rdtDPKLog] PRIMARY KEY ([RowRef])
);
GO
