SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Print_Putaway15                                */
/* Creation Date: 22/05/2020                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: WMS-13406 CN INDITEX PutawayList                            */
/*                                                                      */
/* Called By: d_dw_print_putaway15                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_Putaway15] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_userid NVARCHAR(18)
   )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @c_storerkey NVARCHAR(15),
            @c_udf01 NVARCHAR(60),
            @c_udf02 NVARCHAR(60),
            @c_udf03 NVARCHAR(60),
            @c_TableName NVARCHAR(100),
            @c_ColName NVARCHAR(100),
            @c_ColType NVARCHAR(100),
            @c_ISCombineSKU NCHAR(1),
            @cSQL NVARCHAR(Max),
            @c_FromWhere NVARCHAR(2000),              
            @c_InsertSelect NVARCHAR(2000),
            @n_NoOfLine     INT,
            @n_MaxRecCnt    INT


    SET @n_NoOfLine  = 5       
    SET @n_MaxRecCnt = 1                  
    

   SELECT DISTINCT  RD.ReceiptKey as Receiptkey,   
                     RD.userdefine05 as RDUDF05,
                     (Row_Number() OVER (PARTITION BY RD.ReceiptKey ORDER BY RD.userdefine05 Asc)-1)+ 1 as cnt
                     --COUNT(1) AS RecCnt,
                     --1 as pageno
   INTO #TEMPRECCNT 
   FROM RECEIPT R WITH (NOLOCK) 
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON ( R.ReceiptKey = RD.ReceiptKey )
   WHERE ( R.ReceiptKey >= @c_receiptkeystart ) AND  
         ( R.ReceiptKey <= @c_receiptkeyend)
   GROUP BY RD.ReceiptKey ,   
            RD.userdefine05
   ORDER BY RD.ReceiptKey ,   
            RD.userdefine05

  SELECT @n_MaxRecCnt = MAX(cnt) 
  FROM #TEMPRECCNT
   WHERE ( ReceiptKey >= @c_receiptkeystart ) AND  
               ( ReceiptKey <= @c_receiptkeyend) 
                
    SELECT   R.ReceiptKey as Receiptkey,   
             RD.ExternReceiptKey as ExternReceiptKey, 
             RD.userdefine05 as RDUDF05,   
             RD.Sku as SKU, 
             R.Storerkey, 
             R.userdefine02 as RHUDF02,   
             RD.ToId as ToID,   
             RD.ToLoc as ToLoC,   
             RD.Qtyexpected as QtyExp,          
             ceiling(RD.Qtyexpected/CAST(ISNULL(S.BUSR5,'1') as FLOAT)) as cnt,
             S.BUSR4 as BUSR4,
             S.SUSR2 as BUSR2,
             CONVERT(NVARCHAR(10),P.podate,111) as RAddate,
             S.SUSR5 as SUSR5,
             TRC.cnt as Cntrec,
             @n_MaxRecCnt as TTLCNT, 
             ((Row_Number() OVER (PARTITION BY R.ReceiptKey,RD.userdefine05 ORDER BY R.ReceiptKey,RD.userdefine05,RD.sku Asc)-1)/5)+1 as recgrp, 
             (Row_Number() OVER (PARTITION BY R.ReceiptKey,RD.userdefine05 ORDER BY R.ReceiptKey,RD.userdefine05,RD.sku Asc)-1)+1 as seqno 
    INTO #TEMPRECCNTRESULT
    FROM RECEIPT R WITH (NOLOCK) 
    JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON ( R.ReceiptKey = RD.ReceiptKey )
    JOIN SKU S WITH (NOLOCK) ON S.SKU = RD.SKU AND S.Storerkey = RD.Storerkey
    JOIN PO P WITH (NOLOCK) ON P.pokey = rd.pokey
    JOIN #TEMPRECCNT TRC ON TRC.Receiptkey = RD.Receiptkey AND TRC.RDUDF05=RD.userdefine05
    WHERE ( R.ReceiptKey >= @c_receiptkeystart ) AND  
          ( R.ReceiptKey <= @c_receiptkeyend )
   ORDER BY R.Receiptkey,RD.userdefine05,RD.SKU

   SELECT *
   FROM #TEMPRECCNTRESULT
   ORDER BY Receiptkey,RDUDF05,sku

 END     

DROP TABLE #TEMPRECCNT   


GO