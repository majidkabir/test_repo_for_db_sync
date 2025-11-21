CREATE TABLE [dbo].[fedextracking]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [Status] nvarchar(10) NOT NULL,
    [TrackingNumber] nvarchar(30) NOT NULL,
    [UpdateSource] nvarchar(50) NULL,
    [SendFlag] nvarchar(1) NULL,
    [ServiceType] nvarchar(30) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_FedexTracking] PRIMARY KEY ([RowID])
);
GO

CREATE INDEX [IX_FedexTracking] ON [dbo].[fedextracking] ([OrderKey]);
GO
CREATE INDEX [IX_FedexTracking1] ON [dbo].[fedextracking] ([PickSlipNo], [CartonNo]);
GO