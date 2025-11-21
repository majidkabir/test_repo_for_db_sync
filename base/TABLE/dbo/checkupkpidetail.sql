CREATE TABLE [dbo].[checkupkpidetail]
(
    [KPIDet] int IDENTITY(1,1) NOT NULL,
    [KPI] int NOT NULL,
    [Type] nvarchar(10) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL,
    [Facility] nvarchar(5) NULL,
    [Field] nvarchar(50) NOT NULL,
    [Value] numeric(25, 3) NULL,
    [RunDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_CheckUpKPIDetail] PRIMARY KEY ([KPIDet]),
    CONSTRAINT [FK_CheckUpKPIDetail_CheckUpKPI] FOREIGN KEY ([KPI]) REFERENCES [dbo].[CheckUpKPI] ([KPI])
);
GO

CREATE INDEX [IDX_CheckUpKPIDetail_01] ON [dbo].[checkupkpidetail] ([KPI], [StorerKey], [Facility]);
GO
CREATE INDEX [IDX_CheckUpKPIDetail_RunDate] ON [dbo].[checkupkpidetail] ([RunDate], [KPI]);
GO