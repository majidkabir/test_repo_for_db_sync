SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_03_rpt                             */
/* Creation Date: 17-OCT-2014                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#323254 - [TW] CR Create Pallet Label in the report module  */
/*        : Reprint r_dw_receivinglabel03 (PALLET Label) FROM LotxLocxid   */
/* Called By: PB: r_dw_receivinglabel03_rpt                                */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_Receiving_Label_03_rpt]
         @c_Sku         NVARCHAR(20)
        ,@c_Loc         NVARCHAR(10)
        ,@c_Id          NVARCHAR(18)

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   CREATE TABLE #TMP_CL 
      (  Storerkey                   NVARCHAR(15)
      ,  CarrierNameOnReprn          NVARCHAR(30)
      ,  CustLot2LabelOnReprn        NVARCHAR(60)
      ,  CustLot3LabelOnReprn        NVARCHAR(60) 
      ,  ShowCarrierNameOnReprn      INT  
      ,  ShowLot4BlankIfNullOnReprn  INT
      )

   INSERT INTO #TMP_CL
      (  Storerkey
      ,  CarrierNameOnReprn
      ,  CustLot2LabelOnReprn
      ,  CustLot3LabelOnReprn
      ,  ShowCarrierNameOnReprn
      ,  ShowLot4BlankIfNullOnReprn
      )
   SELECT Storerkey   = CL.Storerkey
         ,CarrierName = MAX(CASE WHEN CL.Code = 'ShowCarrierNameOnReprn' THEN N'寄倉' ELSE '' END)
         ,CustLot2Label = MAX(CASE WHEN CL.Code = 'ShowCustLot2LabelOnReprn' THEN 'Batch Number (L2):' ELSE '' END)
         ,CustLot3Label = MAX(CASE WHEN CL.Code = 'ShowCustLot3LabelOnReprn' THEN 'Customer Order Number (L3):' ELSE '' END)
         ,ShowCarrierName = MAX(CASE WHEN CL.Code = 'ShowCarrierNameOnReprn' THEN 1 ELSE 0 END)
         ,ShowLot4BlankIfNULL = MAX(CASE WHEN CL.Code = 'ShowLot4BlankIfNULLOnReprn' THEN 1 ELSE 0 END)
   FROM CODELKUP CL WITH (NOLOCK) 
   WHERE CL.ListName = 'REPORTCFG' 
     AND CL.Long = 'r_dw_receivinglabel03_rpt' 
     AND CL.Short IS NULL OR CL.Short <> 'N' 
   GROUP BY CL.Storerkey
 
   SELECT DISTINCT 
         ''  
	   ,  ''  
      ,  LOTxLOCxID.StorerKey   
      ,  LOTxLOCxID.Sku   
      ,  LOTxLOCxID.Loc
      ,  LOTxLOCxID.Loc
      ,  LOTATTRIBUTE.Lottable01   
      ,  LOTATTRIBUTE.Lottable02   
      ,  LOTATTRIBUTE.Lottable03   
      ,  Lottable04 = CASE WHEN CL.ShowLot4BlankIfNULLOnReprn = 1 AND LOTATTRIBUTE.Lottable04 = '1900-01-01'  
                           THEN NULL
                           ELSE LOTATTRIBUTE.Lottable04
                           END
      ,  LOTATTRIBUTE.Lottable05   
      ,  LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked  
      ,  LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked 
	   ,  LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked
	   ,  LOTxLOCxID.ID
	   ,  ''  
      ,  SKU.DESCR   
	   ,  SKU.Lottable01Label
	   ,  SKU.Lottable02Label
	   ,  SKU.Lottable03Label
	   ,  SKU.Lottable04Label
	   ,  SKU.Lottable05Label
      ,  PACK.CaseCnt   
      ,  PACK.Qty   
      ,  PACK.PalletTI   
      ,  PACK.PalletHI 
	   ,  PACK.PackDescr
	   ,  LOC.Putawayzone 
	   ,  SKU.Putawayzone
	   ,  LOC.Facility
	   ,  LOC.Putawayzone 
      ,  CL.ShowCarrierNameOnReprn
      ,  CL.CarrierNameOnReprn
      ,  CL.CustLot2LabelOnReprn  
      ,  CL.CustLot3LabelOnReprn
   FROM LOTxLOCxID WITH (NOLOCK)   
   JOIN LOTATTRIBUTE WITH (NOLOCK)     ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU  WITH (NOLOCK) 				ON (LOTxLOCxID.StorerKey = SKU.StorerKey)  
							 				      AND(LOTxLOCxID.Sku = SKU.Sku)
   JOIN PACK WITH (NOLOCK) 				ON (PACK.PackKey = SKU.PACKKey) 
   JOIN LOC  WITH (NOLOCK) 				ON (LOC.Loc = LOTxLOCxID.Loc)   
   LEFT JOIN #TMP_CL CL                ON (LOTxLOCxID.Storerkey = CL.Storerkey)
   WHERE ( ( LOTxLOCxID.Sku = CASE WHEN ISNULL(RTRIM(@c_Sku),'') = '' THEN LOTxLOCxID.Sku ELSE @c_Sku END )  
   AND     ( LOTxLOCxID.Loc = CASE WHEN ISNULL(RTRIM(@c_Loc),'') = '' THEN LOTxLOCxID.Loc ELSE @c_Loc END )
   AND     ( LOTxLOCxID.ID = CASE WHEN ISNULL(RTRIM(@c_ID),'') = '' THEN LOTxLOCxID.ID ELSE @c_ID END ) ) 
   AND	( LOTxLOCxID.ID <> '' )
   AND   ( LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked > 0 )

END

SET QUOTED_IDENTIFIER OFF 

GO