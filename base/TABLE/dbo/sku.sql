CREATE TABLE [dbo].[sku]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [DESCR] nvarchar(60) NULL,
    [SUSR1] nvarchar(18) NULL,
    [SUSR2] nvarchar(18) NULL,
    [SUSR3] nvarchar(18) NULL DEFAULT (' '),
    [SUSR4] nvarchar(18) NULL,
    [SUSR5] nvarchar(18) NULL,
    [MANUFACTURERSKU] nvarchar(20) NULL DEFAULT (''),
    [RETAILSKU] nvarchar(20) NULL DEFAULT (''),
    [ALTSKU] nvarchar(20) NULL DEFAULT (''),
    [PACKKey] nvarchar(10) NOT NULL DEFAULT ('STD'),
    [STDGROSSWGT] float NOT NULL DEFAULT ((0)),
    [STDNETWGT] float NOT NULL DEFAULT ((0)),
    [STDCUBE] float NOT NULL DEFAULT ((0)),
    [TARE] float NOT NULL DEFAULT ((0)),
    [CLASS] nvarchar(10) NOT NULL DEFAULT ('STD'),
    [ACTIVE] nvarchar(10) NOT NULL DEFAULT ('1'),
    [SKUGROUP] nvarchar(10) NOT NULL DEFAULT ('STD'),
    [Tariffkey] nvarchar(10) NULL DEFAULT ('XXXXXXXXXX'),
    [BUSR1] nvarchar(30) NULL,
    [BUSR2] nvarchar(30) NULL,
    [BUSR3] nvarchar(30) NULL,
    [BUSR4] nvarchar(200) NULL,
    [BUSR5] nvarchar(30) NULL,
    [LOTTABLE01LABEL] nvarchar(20) NOT NULL DEFAULT (' '),
    [LOTTABLE02LABEL] nvarchar(20) NOT NULL DEFAULT (' '),
    [LOTTABLE03LABEL] nvarchar(20) NOT NULL DEFAULT (' '),
    [LOTTABLE04LABEL] nvarchar(20) NOT NULL DEFAULT (' '),
    [LOTTABLE05LABEL] nvarchar(20) NOT NULL DEFAULT (' '),
    [NOTES1] nvarchar(4000) NULL,
    [NOTES2] nvarchar(4000) NULL,
    [PickCode] nvarchar(10) NOT NULL DEFAULT ('NSPRPFIFO'),
    [StrategyKey] nvarchar(10) NOT NULL DEFAULT ('STD'),
    [CartonGroup] nvarchar(10) NOT NULL DEFAULT ('STD'),
    [PutCode] nvarchar(10) NOT NULL DEFAULT ('NSPPASTD'),
    [PutawayLoc] nvarchar(10) NULL DEFAULT ('UNKNOWN'),
    [PutawayZone] nvarchar(10) NULL DEFAULT ('BULK'),
    [InnerPack] int NOT NULL DEFAULT ((0)),
    [Cube] float NOT NULL DEFAULT ((0)),
    [GrossWgt] float NOT NULL DEFAULT ((0)),
    [NetWgt] float NOT NULL DEFAULT ((0)),
    [ABC] nvarchar(5) NULL DEFAULT ('B'),
    [CycleCountFrequency] int NULL,
    [LastCycleCount] datetime NULL,
    [ReorderPoint] int NULL,
    [ReorderQty] int NULL,
    [StdOrderCost] float NULL,
    [CarryCost] float NULL,
    [Price] money NULL,
    [Cost] money NULL,
    [ReceiptHoldCode] nvarchar(10) NOT NULL DEFAULT (' '),
    [ReceiptInspectionLoc] nvarchar(10) NOT NULL DEFAULT ('QC'),
    [OnReceiptCopyPackkey] nvarchar(10) NOT NULL DEFAULT ('0'),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [IOFlag] nvarchar(1) NULL,
    [TareWeight] float NULL DEFAULT ((0)),
    [LotxIdDetailOtherlabel1] nvarchar(30) NULL DEFAULT ('Ser#'),
    [LotxIdDetailOtherlabel2] nvarchar(30) NULL DEFAULT ('CSID'),
    [LotxIdDetailOtherlabel3] nvarchar(30) NULL DEFAULT ('Other'),
    [AvgCaseWeight] float NULL DEFAULT ((0)),
    [TolerancePct] float NULL DEFAULT ((0)),
    [SkuStatus] nvarchar(10) NULL DEFAULT ('ACTIVE'),
    [Length] float NULL DEFAULT ((0.00)),
    [Width] float NULL DEFAULT ((0.00)),
    [Height] float NULL DEFAULT ((0.00)),
    [weight] real NULL,
    [itemclass] nvarchar(10) NULL DEFAULT (' '),
    [ShelfLife] int NULL DEFAULT ((0)),
    [Facility] nvarchar(5) NULL,
    [BUSR6] nvarchar(30) NULL DEFAULT (' '),
    [BUSR7] nvarchar(30) NULL DEFAULT (' '),
    [BUSR8] nvarchar(30) NULL DEFAULT (' '),
    [BUSR9] nvarchar(30) NULL DEFAULT (' '),
    [BUSR10] nvarchar(30) NULL DEFAULT (' '),
    [ReturnLoc] nvarchar(10) NULL,
    [ReceiptLoc] nvarchar(10) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [archiveqty] nvarchar(30) NULL DEFAULT ((0)),
    [XDockReceiptLoc] nvarchar(10) NULL,
    [PrePackIndicator] nvarchar(30) NULL DEFAULT (' '),
    [PackQtyIndicator] int NULL DEFAULT ((0)),
    [StackFactor] int NULL DEFAULT ((0)),
    [IVAS] nvarchar(30) NULL,
    [OVAS] nvarchar(30) NULL,
    [Style] nvarchar(20) NOT NULL DEFAULT (' '),
    [Color] nvarchar(10) NOT NULL DEFAULT (''),
    [Size] nvarchar(10) NULL,
    [Measurement] nvarchar(5) NULL,
    [HazardousFlag] nvarchar(30) NULL DEFAULT (''),
    [TemperatureFlag] nvarchar(30) NULL DEFAULT (''),
    [ProductModel] nvarchar(30) NULL DEFAULT (''),
    [CtnPickQty] int NOT NULL DEFAULT ((0)),
    [CountryOfOrigin] nvarchar(30) NULL DEFAULT (''),
    [IB_UOM] nvarchar(10) NOT NULL DEFAULT (' '),
    [IB_RPT_UOM] nvarchar(10) NOT NULL DEFAULT (' '),
    [OB_UOM] nvarchar(10) NOT NULL DEFAULT (' '),
    [OB_RPT_UOM] nvarchar(10) NOT NULL DEFAULT (' '),
    [ABCPL] nvarchar(5) NULL DEFAULT ('B'),
    [ABCCS] nvarchar(5) NULL DEFAULT ('B'),
    [ABCEA] nvarchar(5) NULL DEFAULT ('B'),
    [DisableABCCalc] nvarchar(1) NOT NULL DEFAULT ('N'),
    [ABCPeriod] int NOT NULL DEFAULT ((0)),
    [ABCStorerkey] nvarchar(15) NULL DEFAULT (' '),
    [ABCSku] nvarchar(20) NULL DEFAULT (' '),
    [OldStorerkey] nvarchar(15) NULL DEFAULT (' '),
    [OldSku] nvarchar(20) NULL DEFAULT (' '),
    [ImageFolder] nvarchar(200) NULL,
    [LOTTABLE06LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE07LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE08LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE09LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE10LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE11LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE12LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE13LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE14LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LOTTABLE15LABEL] nvarchar(20) NOT NULL DEFAULT (''),
    [LottableCode] nvarchar(30) NULL DEFAULT ('STD'),
    [OTM_SKUGroup] nvarchar(50) NULL DEFAULT (''),
    [Pressure] nvarchar(10) NULL DEFAULT ('0'),
    [SerialNoCapture] nvarchar(1) NOT NULL DEFAULT (''),
    [DataCapture] nvarchar(1) NOT NULL DEFAULT (''),
    [EcomCartonType] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PKSKU] PRIMARY KEY ([StorerKey], [Sku]),
    CONSTRAINT [FK_SKU_STORER_01] FOREIGN KEY ([StorerKey]) REFERENCES [dbo].[STORER] ([StorerKey])
);
GO

CREATE INDEX [IDX_SKU_CIdx] ON [dbo].[sku] ([StorerKey], [BUSR5], [itemclass], [SKUGROUP], [Style], [Color], [Size], [Measurement]);
GO
CREATE INDEX [IDX_SKU_SKU] ON [dbo].[sku] ([Sku]);
GO
CREATE INDEX [IX_SKU_AltSku] ON [dbo].[sku] ([ALTSKU]);
GO
CREATE INDEX [IX_SKU_BUSR5] ON [dbo].[sku] ([BUSR5], [StorerKey]);
GO
CREATE INDEX [IX_SKU_BUSR6] ON [dbo].[sku] ([BUSR6], [StorerKey]);
GO
CREATE INDEX [IX_SKU_BUSR7] ON [dbo].[sku] ([BUSR7], [StorerKey]);
GO
CREATE INDEX [IX_SKU_editdate] ON [dbo].[sku] ([EditDate]);
GO
CREATE INDEX [IX_SKU_ManufacturerSku] ON [dbo].[sku] ([MANUFACTURERSKU], [StorerKey]);
GO
CREATE INDEX [IX_SKU_OTM_SKUGroup] ON [dbo].[sku] ([OTM_SKUGroup], [StorerKey]);
GO
CREATE INDEX [IX_SKU_PackKey] ON [dbo].[sku] ([PACKKey]);
GO
CREATE INDEX [IX_SKU_PutawayZone] ON [dbo].[sku] ([PutawayZone]);
GO
CREATE INDEX [IX_SKU_RetailSKU] ON [dbo].[sku] ([RETAILSKU]);
GO
CREATE INDEX [IX_SKU_StyleColorSizeM] ON [dbo].[sku] ([Style], [Color], [Size], [Measurement]);
GO