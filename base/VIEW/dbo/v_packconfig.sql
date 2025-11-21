SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_PackConfig]
AS
SELECT [SeqNo]
      ,[Storerkey]
      ,[ExternPOKey]
      ,[SKU]
      ,[PackKey]
      ,[UOM1Barcode]
      ,[UOM2Barcode]
      ,[UOM3Barcode]
      ,[UOM4Barcode]
      ,[BatchNo]
      ,[Status]
      ,[AddDate]
      ,[AddWho]
      ,[EditDate]
      ,[EditWho]
      ,[ArchiveCop]
  FROM [PackConfig] WITH (NOLOCK)

GO