CREATE TABLE [dbo].[accessorialdetail]
(
    [Accessorialkey] nvarchar(10) NOT NULL,
    [AccessorialDetailkey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [Rate] decimal(22, 6) NOT NULL,
    [Base] nvarchar(1) NOT NULL DEFAULT ('Q'),
    [MasterUnits] decimal(12, 6) NOT NULL DEFAULT ((1.0)),
    [UomShow] nvarchar(10) NULL DEFAULT (' '),
    [TaxGroupKey] nvarchar(10) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [GLDistributionKey] nvarchar(10) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [CostRate] decimal(22, 6) NULL DEFAULT ((0.0)),
    [CostBase] nvarchar(1) NULL DEFAULT ('Q'),
    [CostMasterUnits] decimal(12, 6) NULL DEFAULT ((1.0)),
    [CostUOMShow] nvarchar(10) NULL DEFAULT (' '),
    CONSTRAINT [PKAccessorialDetail] PRIMARY KEY ([AccessorialDetailkey]),
    CONSTRAINT [FK_AccDet_GLDist_01] FOREIGN KEY ([GLDistributionKey]) REFERENCES [dbo].[GLDistribution] ([GLDistributionKey]),
    CONSTRAINT [FKAccessorialDetail] FOREIGN KEY ([Accessorialkey]) REFERENCES [dbo].[Accessorial] ([Accessorialkey]),
    CONSTRAINT [CK_AccDet_Base] CHECK ([Base]='R' OR [Base]='F' OR [Base]='C' OR [Base]='G' OR [Base]='Q'),
    CONSTRAINT [CK_AccDet_CostBase] CHECK ([CostBase]='R' OR [CostBase]='F' OR [CostBase]='C' OR [CostBase]='G' OR [CostBase]='Q'),
    CONSTRAINT [CK_AccDet_MU] CHECK ([MasterUnits]>(0.0))
);
GO
