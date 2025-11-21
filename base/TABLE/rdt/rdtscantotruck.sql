CREATE TABLE [rdt].[rdtscantotruck]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [MBOLKey] nvarchar(10) NOT NULL,
    [LoadKey] nvarchar(10) NOT NULL,
    [CartonType] nvarchar(10) NOT NULL DEFAULT (''),
    [RefNo] nvarchar(40) NOT NULL DEFAULT (''),
    [URNNo] nvarchar(40) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Door] nvarchar(10) NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PKrdtScanToTruck] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_RDTScanToTruck_Mbol_Load_URNNo] ON [rdt].[rdtscantotruck] ([MBOLKey], [LoadKey], [URNNo]);
GO
CREATE INDEX [IX_rdtScanToTruck_URNNo] ON [rdt].[rdtscantotruck] ([URNNo]);
GO