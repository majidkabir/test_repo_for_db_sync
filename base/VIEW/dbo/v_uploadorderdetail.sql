SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_UPLOADORDERDETAIL]   
AS   
SELECT [Orderkey]  
, [Orderlinenumber]  
, [ExternOrderkey]  
, [OrderGroup]  
, [SKU]  
, [Storerkey]  
, [Openqty]  
, [Packkey]  
, [UOM]  
, [ExternLineno]  
, [ExtendedPrice]  
, [UnitPrice]  
, [Facility]  
, [Mode]  
, [status]  
, [remarks]  
, [adddate]  
, [Lottable01]  
, [Lottable02]  
, [Lottable03]  
, [Lottable04]  
, [Lottable05]  
FROM [UPLOADORDERDETAIL] (NOLOCK)   
GO