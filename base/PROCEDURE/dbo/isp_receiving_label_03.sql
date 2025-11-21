SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_03                                 */
/* Creation Date: 01-JUL-2014                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Move Select statement to SP                                   */
/* Called By: PB: r_dw_receivinglabel03                                    */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 08-JUL-2014  YTWan     1.1   SOS#314644 - [TW] 20784 - Receiving Label  */
/*                              for CJF                                    */
/* 29-Jan-2016  CSCHONG   1.2   SOS#360316 (CS01)                          */
/***************************************************************************/
CREATE PROC [dbo].[isp_Receiving_Label_03]
         @c_ReceiptKey         NVARCHAR(10) 
        ,@c_Receiptline_Start  NVARCHAR(5)
        ,@c_Receiptline_End    NVARCHAR(5)

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_Storerkey       NVARCHAR(15)
         , @c_CarrierName     NVARCHAR(30)
         , @c_CustLot2Label   NVARCHAR(60)
         , @c_CustLot3Label   NVARCHAR(60)


   SET @c_Storerkey = ''
   SET @c_CarrierName = ''
   SET @c_CustLot2Label = ''
   SET @c_CustLot3Label = ''

   CREATE TABLE #TMP_CL 
      (  Storerkey            NVARCHAR(15)
      ,  CarrierName          NVARCHAR(30)
      ,  CustLot2Label        NVARCHAR(60)
      ,  CustLot3Label        NVARCHAR(60) 
      ,  ShowCarrierName      INT  
      ,  ShowLot4BlankIfNull  INT
      ,  PrintPreRecv         INT
      ,  showLot06            INT                   --CS01  
      )

   INSERT INTO #TMP_CL
      (  Storerkey
      ,  CarrierName
      ,  CustLot2Label
      ,  CustLot3Label
      ,  ShowCarrierName
      ,  ShowLot4BlankIfNull
      ,  PrintPreRecv
      ,  showLot06
      )
   SELECT Storerkey   = RH.Storerkey
         ,CarrierName = MAX(CASE WHEN CL.Code = 'ShowCarrierName' THEN ISNULL(RTRIM(RH.CarrierName),'') ELSE '' END)
         ,CustLot2Label = MAX(CASE WHEN CL.Code = 'ShowCustLot2Label' THEN 'Batch Number (L2):' ELSE '' END)
         ,CustLot3Label = MAX(CASE WHEN CL.Code = 'ShowCustLot3Label' THEN 'Customer Order Number (L3):' ELSE '' END)
         ,ShowCarrierName = MAX(CASE WHEN CL.Code = 'ShowCarrierName' THEN 1 ELSE 0 END)
         ,ShowLot4BlankIfNULL = MAX(CASE WHEN CL.Code = 'ShowLot4BlankIfNULL' THEN 1 ELSE 0 END)
         ,PrintPreRecv    = MAX(CASE WHEN CL.Code = 'PrintPreRecv' THEN 1 ELSE 0 END)
         ,showlot06       = MAX(CASE WHEN CL.Code = 'showLot06' THEN 1 ELSE 0 END)                          --CS01
   FROM RECEIPT  RH WITH (NOLOCK)
   JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'REPORTCFG')
                                  AND(CL.Storerkey= RH.Storerkey)
                                  AND(CL.Long = 'r_dw_receivinglabel03')
                                  AND(CL.Short IS NULL OR CL.Short <> 'N')
   WHERE ReceiptKey = @c_ReceiptKey 
   GROUP BY RH.Storerkey
 
   SELECT RECEIPTDETAIL.ReceiptKey  
	   ,  RECEIPTDETAIL.ReceiptLineNumber  
      ,  RECEIPTDETAIL.StorerKey   
      ,  RECEIPTDETAIL.Sku   
      ,  RECEIPTDETAIL.ToLoc   
      ,  RECEIPTDETAIL.PutawayLoc   
      ,  RECEIPTDETAIL.Lottable01   
      ,  RECEIPTDETAIL.Lottable02   
      ,  RECEIPTDETAIL.Lottable03   
      ,  Lottable04 = CASE WHEN CL.ShowLot4BlankIfNULL = 1 AND RECEIPTDETAIL.Lottable04 = '1900-01-01'  
                           THEN NULL
                           ELSE convert(nvarchar(10),RECEIPTDETAIL.lottable04,103) --RECEIPTDETAIL.Lottable04
                           END
      ,  RECEIPTDETAIL.Lottable05   
      ,  RECEIPTDETAIL.QtyExpected   
      ,  RECEIPTDETAIL.QtyReceived 
	   ,  RECEIPTDETAIL.BeforeReceivedQty 
	   ,  RECEIPTDETAIL.TOID
	   ,  RECEIPTDETAIL.POKey  
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
	   ,  Loc.Putawayzone 
	   ,  Sku.Putawayzone
	   ,  LOC.Facility
	   ,  Loc_b.Putawayzone 
      ,  CL.ShowCarrierName
      ,  CL.CarrierName
      ,  CL.CustLot2Label  
      ,  CL.CustLot3Label
      ,  ISNULL(CL.showLot06,0) as   showLot06               --CS01
      ,  SKU.Lottable06Label                                 --CS01
      ,  RECEIPTDETAIL.Lottable06                            --CS01
   FROM RECEIPTDETAIL WITH (NOLOCK)   
   JOIN SKU  WITH (NOLOCK) 				ON (RECEIPTDETAIL.StorerKey = SKU.StorerKey)  
							 				      AND(RECEIPTDETAIL.Sku = SKU.Sku)
   JOIN PACK WITH (NOLOCK) 				ON (PACK.PackKey = SKU.PACKKey) 
   JOIN LOC  WITH (NOLOCK) 				ON (LOC.Loc = RECEIPTDETAIL.ToLoc)   
   LEFT JOIN LOC LOC_b WITH (NOLOCK) 	ON (LOC_b.Loc = RECEIPTDETAIL.PutawayLoc)  
   LEFT JOIN #TMP_CL CL ON (RECEIPTDETAIL.Storerkey = CL.Storerkey)
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) 
   AND     ( RECEIPTDETAIL.ReceiptlineNumber >= @c_receiptline_start )  
   AND     ( RECEIPTDETAIL.ReceiptLineNumber <= @c_receiptline_end ) ) 
   AND	( RECEIPTDETAIL.TOID <> '' )
   AND   ( RECEIPTDETAIL.QtyReceived >= CASE WHEN PrintPreRecv = 1 THEN 0 ELSE 1 END)

END

SET QUOTED_IDENTIFIER OFF 

GO