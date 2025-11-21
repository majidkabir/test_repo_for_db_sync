SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
  
 CREATE VIEW [dbo].[V_WithdrawStock]   
AS   
SELECT [StorerKey]  
, [SKU]  
, [LOT]  
, [ID]  
, [Loc]  
, [Qty]  
, [Lottable01]  
, [Lottable02]  
, [Lottable03]  
, [Lottable04]  
, [Lottable05]  
, [Lottable06]
, [Lottable07]
, [Lottable08]
, [Lottable09]
, [Lottable10]
, [Lottable11]
, [Lottable12]
, [Lottable13]
, [Lottable14]
, [Lottable15]
, [RowId]  
, [Sourcekey]  
, [Sourcetype]  
FROM [WithdrawStock] (NOLOCK)   
  

GO