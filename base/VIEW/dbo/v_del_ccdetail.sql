SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
  CREATE VIEW [dbo].[V_DEL_CCDETAIL]  
AS Select  CCKey  
,CCDetailKey  
,CCSheetNo  
,TagNo  
,Storerkey  
,Sku  
,Lot  
,Loc  
,Id  
,SystemQty  
,Qty  
,Lottable01  
,Lottable02  
,Lottable03  
,Lottable04  
,Lottable05  
,Lottable06
,Lottable07
,Lottable08
,Lottable09
,Lottable10
,Lottable11
,Lottable12
,Lottable13
,Lottable14
,Lottable15
,FinalizeFlag  
,Qty_Cnt2  
,Lottable01_Cnt2  
,Lottable02_Cnt2  
,Lottable03_Cnt2  
,Lottable04_Cnt2  
,Lottable05_Cnt2  
,Lottable06_Cnt2
,Lottable07_Cnt2
,Lottable08_Cnt2
,Lottable09_Cnt2
,Lottable10_Cnt2
,Lottable11_Cnt2
,Lottable12_Cnt2
,Lottable13_Cnt2
,Lottable14_Cnt2
,Lottable15_Cnt2
,FinalizeFlag_Cnt2  
,Qty_Cnt3  
,Lottable01_Cnt3  
,Lottable02_Cnt3  
,Lottable03_Cnt3  
,Lottable04_Cnt3  
,Lottable05_Cnt3  
,Lottable06_Cnt3
,Lottable07_Cnt3
,Lottable08_Cnt3
,Lottable09_Cnt3
,Lottable10_Cnt3
,Lottable11_Cnt3
,Lottable12_Cnt3
,Lottable13_Cnt3
,Lottable14_Cnt3
,Lottable15_Cnt3
,FinalizeFlag_Cnt3  
,Status  
,StatusMsg  
,AddDate  
,AddWho  
,EditDate  
,EditWho  
,TrafficCop  
,ArchiveCop  
,RefNo  
,EditDate_Cnt1  
,EditWho_Cnt1  
,EditDate_Cnt2  
,EditWho_Cnt2  
,EditDate_Cnt3  
,EditWho_Cnt3  
,Counted_Cnt1  
,Counted_Cnt2  
,Counted_Cnt3  
FROM DEL_CCDETAIL WITH (NOLOCK)     
  

GO