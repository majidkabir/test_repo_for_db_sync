SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_FxRATE] 
AS 
SELECT [CurrencyKey]
, [Descrip]
, [BaseCurrency]
, [TargetCurrency]
, [ConversionRate]
, [FxDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [FxRATE] (NOLOCK) 

GO