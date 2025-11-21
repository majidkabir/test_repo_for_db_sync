SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_RPT_ASN_POSTRECV_001                              */    
/* Creation Date: 28-JUL-2022                                              */    
/* Copyright: LFL                                                          */    
/* Written by: Harshitha                                                   */    
/*                                                                         */    
/* Purpose: WMS-20146                                                      */    
/*                                                                         */    
/* Called By: RPT_ASN_POSTRECV_001                                         */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date        Author    Ver Purposes                                      */
/* 29-Jul-2022 WLChooi   1.0 DevOps Combine Script                         */
/***************************************************************************/ 

CREATE   PROC [dbo].[isp_RPT_ASN_POSTRECV_001]
       @c_Receiptkey         NVARCHAR(10)
      ,@c_ReceiptLineStart   NVARCHAR(5)
      ,@c_ReceiptLineEnd     NVARCHAR(5)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @c_RecLineNo    NVARCHAR(5),
           @c_QRCode       NVARCHAR(250),
           @c_Storerkey    NVARCHAR(15),                 
           @c_Type         NVARCHAR(1) = '1',                      
           @c_DataWindow   NVARCHAR(60) = 'RPT_ASN_POSTRECV_001',  
           @c_RetVal       NVARCHAR(255)  
   
   SET @c_ReceiptLineStart = IIF(ISNULL(@c_ReceiptLineStart,'') = '', '00001', @c_ReceiptLineStart)
   SET @c_ReceiptLineEnd   = IIF(ISNULL(@c_ReceiptLineEnd,'')   = '', '99999', @c_ReceiptLineEnd)

   SELECT @c_Storerkey = Storerkey
   FROM RECEIPT (NOLOCK)
   WHERE ReceiptKey = @c_Receiptkey

   EXEC [dbo].[isp_GetCompanyInfo]  
       @c_Storerkey  = @c_Storerkey  
    ,  @c_Type       = @c_Type  
    ,  @c_DataWindow = @c_DataWindow  
    ,  @c_RetVal     = @c_RetVal           OUTPUT

   SELECT DISTINCT Receiptkey = RECEIPTDETAIL.ReceiptKey,
                   ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber,
                   Storerkey = RECEIPTDETAIL.StorerKey,
                   Sku = RECEIPTDETAIL.Sku,
                   ToLoc = RECEIPTDETAIL.ToLoc,
                   RecPutawayLoc = RECEIPTDETAIL.PutawayLoc,   
                   Lottable01 = RECEIPTDETAIL.Lottable01,
                   Lottable02 = RECEIPTDETAIL.Lottable02,
                   Lottable03 = RECEIPTDETAIL.Lottable03,
                   Lottable04 = RECEIPTDETAIL.Lottable04,
                   Lottable05 = RECEIPTDETAIL.Lottable05,
                   RecQtyExpected = RECEIPTDETAIL.QtyExpected,
                   RecQtyRec = RECEIPTDETAIL.QtyReceived,
                   RecBeforeQty = RECEIPTDETAIL.BeforeReceivedQty,
                   ToID = RECEIPTDETAIL.TOID,
                   POKey = RECEIPTDETAIL.POKey,
                   SKU_DESCR = SKU.DESCR,
                   Lottable01Label = SKU.Lottable01Label,
                   Lottable02Label = SKU.Lottable02Label,
                   Lottable03Label = SKU.Lottable03Label,
                   Lottable04Label = SKU.Lottable04Label,
                   Lottable05Label = SKU.Lottable05Label,
                   CaseCnt = PACK.CaseCnt,
                   PQty = PACK.Qty,
                   P_Ti = PACK.PalletTI,
                   P_Hi = PACK.PalletHI,
                   PackDescr = PACK.PackDescr,
                   Loc_PutawayZone = Loc.Putawayzone,
                   Sku_Putawayzone = Sku.Putawayzone,
                   Loc_Facility = LOC.Facility,
                   Locb_PutawayZone = Loc_b.Putawayzone,
                   Sku_group = SKU.Skugroup,
                   RecUom = RECEIPTDETAIL.UOM,
                   RecExternReceiptKey = RECEIPTDETAIL.ExternReceiptKey,
                   Case_Qty = CASE WHEN PACK.Casecnt <> 0 THEN  CONVERT(INT,(receiptdetail.qtyreceived/pack.casecnt)) ELSE 0 END ,
                   Each_Qty = CASE WHEN pack.casecnt > 1 AND (receiptdetail.qtyreceived/pack.casecnt)-(CONVERT(INT,(receiptdetail.qtyreceived/pack.casecnt))) > 0
                              THEN CONVERT(INT,(receiptdetail.qtyreceived)) - (CASE WHEN PACK.Casecnt <> 0
                              THEN convert(int,(receiptdetail.qtyreceived/pack.casecnt)) ELSE 0 END * pack.casecnt) 
                              ELSE receiptdetail.qtyreceived END ,
                   QRCode = @c_QRCode
   INTO #RESULT
   FROM RECEIPTDETAIL (NOLOCK)
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
   LEFT JOIN LOC LOC_b (NOLOCK) ON  RECEIPTDETAIL.PutawayLoc = LOC_b.Loc
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_Receiptkey ) and
           ( RECEIPTDETAIL.ReceiptlineNumber >= @c_ReceiptLineStart ) AND
           ( RECEIPTDETAIL.ReceiptLineNumber <= @c_ReceiptLineEnd ) ) AND
         (RECEIPTDETAIL.TOID <> '' )


   DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT receiptkey,receiptlinenumber
   FROM #RESULT
   ORDER BY Receiptkey,Receiptlinenumber

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_Receiptkey,@c_RecLineNo
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SELECT @c_QRCode = CAST(RecDet.Sku AS NCHAR(25)) + CAST(RecDet.Lottable02 AS NCHAR(30)) + CAST(RecDet.UOM AS NCHAR(2))
                    + CAST(CONVERT(NVARCHAR(10),R.Case_Qty) AS NCHAR(10)) + CAST(RIGHT(RecDet.Toid,8) AS NCHAR(8))
                    + REPLACE(CONVERT(NCHAR(10), RecDet.Lottable05, 103), '/', '')
                    + CAST(CASE WHEN YEAR(RecDet.Lottable04) <= 1999 THEN 0 ELSE 1 END AS VARCHAR)
                    + SUBSTRING(CAST(YEAR(RecDet.Lottable04) AS VARCHAR),3,2)
                    + REPLACE(STR(CAST(RecDet.Lottable04-DATEADD(yyyy,DATEDIFF(yyyy,0,RecDet.Lottable04),0) AS INT)+1,3), ' ','0')
                     FROM ReceiptDetail RecDet WITH (NOLOCK)
                     JOIN SKU S WITH (NOLOCK) ON S.Sku = RecDet.Sku AND S.StorerKey = RecDet.StorerKey
                     JOIN #Result R WITH (NOLOCK) ON R.receiptkey = RecDet.Receiptkey
                                                 AND R.Receiptlinenumber = RecDet.Receiptlinenumber
                     AND RecDet.Receiptkey = @c_Receiptkey
                     AND RecDet.Receiptlinenumber= @c_RecLineNo

      UPDATE #RESULT
      SET QRCode = @c_QRCode
      WHERE Receiptkey = @c_Receiptkey
      AND Receiptlinenumber = @c_RecLineNo

      FETCH NEXT FROM cur_1 INTO @c_Receiptkey,@c_RecLineNo
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT *, ISNULL(@c_RetVal,'') AS Logo
   FROM #RESULT
   ORDER BY Receiptkey,Receiptlinenumber

   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
      DROP TABLE #RESULT

END      

GO