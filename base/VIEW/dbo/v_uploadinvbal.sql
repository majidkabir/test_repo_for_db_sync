SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



 CREATE VIEW [dbo].[V_UploadINVBAL]   
AS   
SELECT [STORERKEY]  
, [SKU]  
, [LOCATION]  
, [lottable01]  
, [lottable02]  
, [lottable03]  
, [lottable04]  
, [lottable05] 
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
, [QTY]  
, [STATUS]  
, [RUNNING]  
, [UploadStatus]  
, [Reason]  
, [OldLocation]  
FROM [UploadINVBAL] (NOLOCK)   
  

GO