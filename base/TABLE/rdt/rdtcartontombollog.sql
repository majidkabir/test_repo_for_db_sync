CREATE TABLE [rdt].[rdtcartontombollog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [MBOLKey] nvarchar(15) NOT NULL,
    [CartonID] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtCartonToMBOLLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtCartonToMBOLLog01] ON [rdt].[rdtcartontombollog] ([MBOLKey], [CartonID], [StorerKey]);
GO