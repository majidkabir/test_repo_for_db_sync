SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPRPPLPO01                                            */
/* Creation Date: 07-DEC-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-585 - [TW] ASN RCM  Populate From PO Logic              */
/*        :                                                             */
/* Called By:  isp_PrePopulatePO_Wrapper                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPRPPLPO01]
           @c_Receiptkey      NVARCHAR(10)
         , @c_POKeys          NVARCHAR(MAX)
         , @c_POLineNumbers   NVARCHAR(MAX) = ''
         , @b_Success         INT OUTPUT    
         , @n_Err             INT OUTPUT
         , @c_Errmsg          NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT
         , @n_RecCnt             INT
          
         , @c_POKey              NVARCHAR(10)
         , @c_POLineNumber       NVARCHAR(5)
         , @c_ReceiptLineNumber  NVARCHAR(5)         
         , @c_ExternReceiptKey   NVARCHAR(20)
         , @c_ExternLineNo       NVARCHAR(20)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   CREATE TABLE #PREPPL_PO
      (  SeqNo          INT
      ,  POKey          NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  POLineNumber   NVARCHAR(5)    NOT NULL DEFAULT ('')
      )

   INSERT INTO #PREPPL_PO
      (  SeqNo
      ,  POKey
      )     
   SELECT SeqNo
      ,   ColValue
   FROM dbo.fnc_DelimSplit (',', @c_POKeys)
   
   IF @c_POLineNumbers <> ''
   BEGIN
      UPDATE #PREPPL_PO
      SET POLineNumber = ColValue
      FROM dbo.fnc_DelimSplit (',', @c_POLineNumbers) T
      WHERE #PREPPL_PO.SeqNo = T.SeqNo
   END

   SET @n_RecCnt = 0
   SELECT @n_RecCnt = 1
   FROM RECEIPT (NOLOCK)
   WHERE ReceiptKey = @c_Receiptkey
   AND DocType = 'R'
   
   IF @n_RecCnt = 0
   BEGIN
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM #PREPPL_PO
               JOIN PO WITH (NOLOCK) ON (#PREPPL_PO.POKey = PO.POKey)
               WHERE PO.POType <> 'P' 
               )
   BEGIN
      SET @n_RecCnt = 0
      SELECT @n_RecCnt = 1
      FROM #PREPPL_PO
      WHERE EXISTS (SELECT 1
                    FROM PO WITH (NOLOCK) 
                    WHERE PO.POKey = #PREPPL_PO.POKey
                    AND POType = 'P')

      IF @n_RecCnt = 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 50010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Not Allow to Populate PO Type ''P'' with Other PO Type. (ispPRPPLPO01)'          
      END 

      GOTO QUIT_SP
   END

   SET @n_RecCnt = 0
   SET @c_POKey  = ''
   SELECT @n_RecCnt = COUNT (DISTINCT POKey)
         ,@c_POKey  = MIN(POKey)
   FROM #PREPPL_PO

   IF @n_RecCnt > 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50020
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Not Allow to Populate Multiple PO. (ispPRPPLPO01)'  
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM RECEIPTDETAIL
               WHERE RECEIPTDETAIL.ReceiptKey = @c_Receiptkey
               AND ISNULL(RECEIPTDETAIL.POKey,'') <> ''
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50030
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': PO Detail had already populated to ASN. (ispPRPPLPO01)'  
      GOTO QUIT_SP
   END

   IF EXISTS (
               SELECT 1
               FROM PODETAIL WITH (NOLOCK)
               WHERE POKey = @c_POKey
               AND NOT EXISTS (  SELECT 1
                                 FROM #PREPPL_PO
                                 WHERE #PREPPL_PO.POKey = PODETAIL.POKey
                                 AND #PREPPL_PO.POLineNumber = PODETAIL.POLineNumber
                                 AND #PREPPL_PO.POLineNumber <> ''
                              )
            )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50040
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Not Allow to Populate Partial PO Detail. (ispPRPPLPO01)'  
      GOTO QUIT_SP
   END
   
   BEGIN TRAN

   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RECEIPTDETAIL.ExternReceiptKey
         ,RECEIPTDETAIL.ExternLineNo
         ,RECEIPTDETAIL.Storerkey
         ,RECEIPTDETAIL.Sku
         ,RECEIPTDETAIL.ReceiptLineNumber
   FROM  RECEIPTDETAIL WITH (NOLOCK)
   WHERE RECEIPTDETAIL.Receiptkey = @c_Receiptkey
   AND   RECEIPTDETAIL.BeforeReceivedQty = 0
   AND   RECEIPTDETAIL.QtyReceived = 0
   AND   RECEIPTDETAIL.POKey = ''
   ORDER BY RECEIPTDETAIL.Storerkey
         ,  RECEIPTDETAIL.Sku
   
   OPEN CUR_RD
   
   FETCH NEXT FROM CUR_RD INTO @c_ExternReceiptKey, @c_ExternLineNo
                              , @c_Storerkey       , @c_Sku
                              , @c_ReceiptLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PODETAIL.POLineNumber  
      FROM PODETAIL WITH (NOLOCK) 
      WHERE PODETAIL.POKey   = @c_POKey
      AND PODETAIL.Storerkey = @c_Storerkey
      AND PODETAIL.Sku = @c_Sku

      OPEN CUR_PD 

      FETCH NEXT FROM CUR_PD INTO @c_POLineNumber

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PODETAIL WITH (ROWLOCK)
         SET UserDefine02 = @c_ExternReceiptKey
            ,UserDefine03 = @c_ExternLineNo
            ,Trafficcop   = NULL
            ,EditWho      = SUSER_NAME()
            ,EditDate     = GETDATE()
         WHERE POKey = @c_POKey
         AND   POLineNumber = @c_POLineNumber

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err=50050
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err)
                          + ': Update Failed On Table PODETAIL. (ispPRPPLPO01)'
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_PD INTO @c_POLineNumber
      END
      CLOSE CUR_PD
      DEALLOCATE CUR_PD

      DELETE RECEIPTDETAIL WITH (ROWLOCK)
      WHERE ReceiptKey = @c_ReceiptKey
      AND   ReceiptLineNumber = @c_ReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err=50060
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err)
                        + ': Delete Failed From Table RECEIPTDETAIL. (ispPRPPLPO01)'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM CUR_RD INTO @c_ExternReceiptKey, @c_ExternLineNo
                                , @c_Storerkey       , @c_Sku
                                , @c_ReceiptLineNumber
   END
   CLOSE CUR_RD
   DEALLOCATE CUR_RD 

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_RD') in (0 , 1)  
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PD') in (0 , 1)  
   BEGIN
      CLOSE CUR_PD
      DEALLOCATE CUR_PD
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRPPLPO01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO