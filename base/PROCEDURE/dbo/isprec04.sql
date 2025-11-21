SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispREC04                                           */
/* Creation Date: 03-JUL-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: WMS-13928 SG - RCS û ASN Validation                         */   
/*                                                                      */
/* Called By: isp_ReceiptTrigger_Wrapper from Receipt Trigger           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 16-AUG-2021  CSCHONG  1.1  WMS-17671 revised logic (CS01)            */
/************************************************************************/

CREATE PROC [dbo].[ispREC04]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_TableName       NVARCHAR(30),
           @c_Option1         NVARCHAR(50),
           @c_receiptkey      NVARCHAR(20)
          ,@c_SKU             NVARCHAR(20)
          ,@c_lottable02      NVARCHAR(18)
          ,@n_RecQty          INT
          ,@n_trackqty         INT      
                                                       
    SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
       

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
   SELECT @c_Option1 = ISNULL(Option1,'')
   FROM STORERCONFIG (NOLOCK)
   WHERE Configkey = 'ReceiptTrigger_SP'
   AND Storerkey = @c_Storerkey
   AND Svalue = 'ispREC04'
   
   IF ISNULL(@c_Option1,'') NOT IN('1','2')
     SET @c_Option1 = '1'
   
    IF @c_Action IN('UPDATE')  
    BEGIN
      
      --Capture received status when finalize
     -- IF EXISTS (SELECT 1 FROM #DELETED D 
       --   WHERE D.ASNStatus = '9' AND D.Storerkey = @c_Storerkey)
       --BEGIN    
       IF EXISTS (SELECT 1 FROM #INSERTED I   
                  JOIN #DELETED D ON I.Receiptkey = D.Receiptkey   
                  WHERE I.ASNStatus <> D.ASNStatus AND I.ASNStatus = '9' AND I.Storerkey = @c_Storerkey)      
       BEGIN   
        DECLARE Cur_Receipt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT I.Receiptkey, RD.SKU,RD.lottable02,SUM(RD.Qtyreceived)
         FROM #INSERTED I   
         JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 
         JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.Receiptkey = I.Receiptkey
         JOIN SKU S WITH (NOLOCK) ON S.sku = RD.sku and S.storerkey = RD.storerkey
         WHERE I.Storerkey = @c_Storerkey     
         AND I.ASNStatus = '9' 
         AND S.SUSR4 = 'SSCC'
         --CS01 START
         AND (S.LOTTABLE10LABEL = '' OR S.LOTTABLE10LABEL IS NULL)
         AND CASE WHEN ISNUMERIC(s.busr7) = 1 THEN CAST(S.busr7 AS NUMERIC(10,2)) ELSE 0.00 END >= 0.7
         --CS01 END 
         GROUP BY   I.Receiptkey, RD.SKU,RD.lottable02 
         ORDER BY I.Receiptkey, RD.SKU,RD.lottable02

      OPEN Cur_Receipt
     
       FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_sku,@c_lottable02,@n_recqty

       WHILE @@FETCH_STATUS <> -1 --AND @n_continue IN(1,2)
       BEGIN               
       
       SET @n_trackqty = 0

        SELECT @n_trackqty = SUM(ISNULL(TCKID.qty,0))
        FROM trackingID TCKID WITH (NOLOCK)
        WHERE TCKID.userdefine01 = @c_receiptkey
        AND TCKID.sku = @c_sku 
        AND TCKID.Userdefine03 = @c_lottable02

        IF ISNULL(@n_trackqty,0) <> @n_recqty
          BEGIN
              SELECT @n_continue = 3, @n_err = 61940, @c_errmsg = 'All serial numbers for ASN# ' + RTRIM(@c_Receiptkey) + ' not yet fully scanned. (ispREC04)' 
              GOTO QUIT_SP
          END


       FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_sku,@c_lottable02,@n_recqty
       END
      CLOSE Cur_Receipt
      DEALLOCATE Cur_Receipt
      END        
   END        
      
   QUIT_SP:
   
    IF @n_Continue=3  -- Error Occured - Process AND Return
    BEGIN
       SELECT @b_Success = 0
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
       BEGIN
         ROLLBACK TRAN
       END
       ELSE
       BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
       END
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispREC04'     
       --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_Success = 1
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
         COMMIT TRAN
       END
       RETURN
    END  
END  

GO