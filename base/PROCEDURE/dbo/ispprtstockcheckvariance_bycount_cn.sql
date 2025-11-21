SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPrtStockCheckVariance_byCount_CN                         */
/* Creation Date: 03-Jan-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: June		                                                */
/*                                                                      */
/* Purpose: IDSCN Swire	(SOS95027)   												*/
/*          Notes : Duplicate from ispPrtStockCheckVariance_byCount_MY  */
/*          Used for report dw :                                        */
/*          1) r_dw_stocktake_variance_cnt1_CN                          */
/*			   2) r_dw_stocktake_variance_cnt2_CN 									*/
/*			   3) r_dw_stocktake_variance_cnt3_CN									*/
/*                                                                      */
/* Called By: 		                                                      */
/*                                                                      */
/* PVCS Version: 1.4		                                                */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2020-Apr-27  WLChooi   1.1   WMS-13148 - LEFT JOIN Storer (WL01)     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_byCount_CN] (
			@c_StockTakeKey NVARCHAR(10),
			@c_StorerKeyStart NVARCHAR(15),
			@c_StorerKeyEnd NVARCHAR(15),
			@c_SkuStart NVARCHAR(20),
			@c_SkuEnd NVARCHAR(20),
			@c_CountNo  NVARCHAR(2)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL 
      DROP TABLE #TempStkVar

	CREATE TABLE [#TempStkVar] (
			[StorerKey] [char] (10),  
			[CCKey] [char] (10),  
			[Sku] [char] (20),		
			[Descr] [char] (60) NULL,  
			[CCSheetNo] [char] (10) NULL, 
			[SUSR3] [char] (18) NULL,  
			[Cost] [money] NULL,  
			[Facility] [char] (5) NULL,	
			[Lot] [char] (10) NULL,	
			[Id] [char] (18) NULL,  
			[Loc] [char] (10) NULL,	
			[Lottable02] [char] (18) NULL,		
			[Lottable02_Cnt2] [char] (18) NULL,  
			[Lottable02_Cnt3] [char] (18) NULL,	
			[Lottable04] [datetime] NULL,		
			[Lottable04_Cnt2] [datetime] NULL,	
			[Lottable04_Cnt3] [datetime] NULL,		
			[Qty] [int],   
			[Qty_Cnt2] [int],	
			[Qty_Cnt3] [int],	
			[PackUOM3] [char] (10) NULL,   
			[PackQty] [float],  
			[LotxLocxId_Qty] [int],	
			[VarQty_cal] [int],		
			[VarHKD_cal] [float] NULL,
	      [SkuGroup] [char] (10) NULL,
	      [ItemClass] [char] (10) NULL, 
			[CompanyName] [char] (45) NULL,
			[Currency] [char] (45) NULL,
			[Lottable05] [datetime] NULL,		   
			[Lottable05_Cnt2] [datetime] NULL,	
			[Lottable05_Cnt3] [datetime] NULL,	
			[UserID] [char] (18) NULL,
			[Size] [char] (5) NULL           
		)


   INSERT INTO #TempStkVar 
	 (	STORERKEY,			CCKey,				Sku,					Descr,					CCSheetNo,			SUSR3,
		Cost,					Facility,			Lot,					Id,                  Loc,					Lottable02,
		Lottable02_Cnt2,	Lottable02_Cnt3,	Lottable04,			Lottable04_Cnt2,		Lottable04_Cnt3,	Qty,
		Qty_Cnt2,			Qty_Cnt3,			PackUOM3,			PackQty,					LotxLocxId_Qty,	VarQty_cal,
		VarHKD_cal, 		SkuGroup,			ItemClass,        CompanyName, 		   Currency,
		Lottable05,			Lottable05_Cnt2,	Lottable05_Cnt3,  
		UserID, 				Size
	)
   SELECT CCDetail.StorerKey,  
         CCDetail.CCKey,  
         CCDetail.Sku,   
			SKU.Descr,  
			CCDetail.CCSheetNo,	
			SKU.SUSR3,  
			SKU.Cost,  
			LOC.Facility,
         CCDetail.Lot,   
         CCDetail.Id,			
         CCDetail.Loc,
			CCDetail.Lottable02,   
			CCDetail.Lottable02_Cnt2,  
			CCDetail.Lottable02_Cnt3,  
         CCDetail.Lottable04,  
			CCDetail.Lottable04_Cnt2,  
			CCDetail.Lottable04_Cnt3,
         CCDetail.Qty AS Qty,   
         CCDetail.Qty_Cnt2 AS Qty_Cnt2,   
         CCDetail.Qty_Cnt3 AS Qty_Cnt3,   
			PACK.PackUOM3,   
			PACK.Qty AS PackQty,  
			CCDetail.SystemQty AS LotxLocxId_qty, 
			VarQty_cal = CASE @c_countno
								WHEN '1' THEN CCDetail.Qty - CCDetail.SystemQty
								WHEN '2' THEN CCDetail.Qty_Cnt2 - CCDetail.SystemQty
								WHEN '3' THEN CCDetail.Qty_Cnt3 - CCDetail.SystemQty
								ELSE 0
							 END, 
			VarHKD_cal = CASE WHEN ((CONVERT(decimal(15,3), SKU.Cost) = null) OR (CONVERT(decimal(15,3), SKU.Cost) = 0) 
											OR (CONVERT(NVARchar(15), SKU.Cost) = '')) THEN 0.0	
						    ELSE CASE @c_countno
                              WHEN '1' THEN CONVERT(decimal(20,2), SKU.Cost * (CCDetail.Qty - CCDetail.SystemQty))
      								WHEN '2' THEN CONVERT(decimal(20,2), SKU.Cost * (CCDetail.Qty_Cnt2 - CCDetail.SystemQty))
      								WHEN '3' THEN CONVERT(decimal(20,2), SKU.Cost * (CCDetail.Qty_Cnt3 - CCDetail.SystemQty))
      							   ELSE 0.0
							      END
						    END,
         SKU.SkuGroup,
         SKU.ItemClass,
			COMPANY.Company,
			CURRENCY.Company,
         CCDetail.Lottable05,       
			CCDetail.Lottable05_Cnt2,  
			CCDetail.Lottable05_Cnt3,  
			UserID = CASE @c_countno
								WHEN '1' THEN ISNULL(EditWho_Cnt1, '')
								WHEN '2' THEN ISNULL(EditWho_Cnt2, '')
								WHEN '3' THEN ISNULL(EditWho_Cnt3, '')
								ELSE ''
                  END,
			SKU.Size 
   FROM  CCDetail CCDetail (NOLOCK)  
   JOIN  SKU SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDetail.StorerKey) 
   JOIN  PACK PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
   JOIN  LOC LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
   LEFT JOIN STORER COMPANY (NOLOCK) ON (COMPANY.Storerkey = 'JDHR')			-- (YokeBeen01) SOS25214   --WL01
   LEFT JOIN STORER CURRENCY (NOLOCK) ON (CURRENCY.Storerkey = 'CURRENCY')	-- (YokeBeen01)            --WL01
	WHERE ( CCDetail.CCKey = @c_StockTakeKey )  
   AND   ( CCDetail.StorerKey >= @c_StorerKeyStart )  
   AND   ( CCDetail.StorerKey <= @c_StorerKeyEnd )  
   AND   ( CCDetail.Sku >= @c_SkuStart )  
   AND   ( CCDetail.Sku <= @c_SkuEnd )
   ORDER BY CCDetail.StorerKey,  
			CCDetail.CCKey,  
         CCDetail.Sku,  
			SKU.SUSR3,  
			LOC.Facility,   
         CCDetail.Loc,   
			CCDetail.Lottable02,   
			CCDetail.Lottable02_Cnt2,  
			CCDetail.Lottable02_Cnt3,  
         CCDetail.Lottable04,  
			CCDetail.Lottable04_Cnt2,  
			CCDetail.Lottable04_Cnt3,  
         CCDetail.Lot,
         CCDetail.Lottable05,       
			CCDetail.Lottable05_Cnt2, 
			CCDetail.Lottable05_Cnt3   

   -- Remove all the records with no variance
   -- DELETE #TempStkVar FROM #TempStkVar WHERE #TempStkVar.VarQty_cal = 0

   SELECT * FROM #TempStkVar  

END

GO