SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPRREC02                                                  */
/* Creation Date: 19-OCT-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:SOS#354468 - FrieslandHK- FC System Batch number (lottable02)*/      
/*        : builder                                                     */
/* Called By: ispPreFinalizeReceiptWrapper                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 29-Feb-2016  CSCHONG   1.0 SOS#363444 (CS01)                         */
/************************************************************************/
CREATE PROC [dbo].[ispPRREC02] 
            @c_ReceiptKey        NVARCHAR(10)
         ,  @c_ReceiptLineNumber NVARCHAR(10)  = ''
         ,  @b_Success           INT = 1  OUTPUT 
         ,  @n_err               INT = 0  OUTPUT 
         ,  @c_errmsg            NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_ReceiptLineNo   NVARCHAR(5)    
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)

         , @c_prefix          NVARCHAR(2)
         , @c_FCBatchNo       NVARCHAR(5)
         , @c_Lot             NVARCHAR(10)
         , @c_Lottable02      NVARCHAR(18)  
         , @c_Lottable06      NVARCHAR(30)           
    
         , @c_Recipients      NVARCHAR(1000)
         , @c_Subject         NVARCHAR(250)
         , @c_Body            NVARCHAR(1000)

         , @c_busr4           NVARCHAR(18)           --(CS01)
         , @c_susr2           NVARCHAR(18)           --(CS01)
         , @dt_Lottable05      DATETIME              --(CS01)
         , @dt_Lottable13      DATETIME              --(CS01)
         , @dt_GetLottable13   DATETIME              --(CS01)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_FCBatchNo= ''
   
   BEGIN TRAN 

   SET @c_prefix    = ''
   SET @c_Recipients= ''
   SELECT @c_prefix = Code
         ,@c_Recipients = CASE WHEN Udf01 <> '' THEN Udf01 + ';' ELSE '' END
                        + CASE WHEN Udf02 <> '' THEN Udf02 + ';' ELSE '' END
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = 'FCBATCHNO'

   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT
          Storerkey
         ,Sku
         ,ISNULL(RTRIM(Lottable06),'')
   FROM RECEIPTDETAIL WITH (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey
   AND   ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber),'') = '' THEN ReceiptLineNumber ELSE @c_ReceiptLineNumber END
   AND   (Lottable02 = '' OR Lottable02 IS NULL)
   AND   BeforeReceivedQty > QtyReceived

   OPEN CUR_RD

   FETCH NEXT FROM CUR_RD INTO @c_Storerkey
                              ,@c_Sku
                              ,@c_Lottable06
                         
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      IF NOT EXISTS( SELECT 1 
                     FROM SKU WITH (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                     AND   Sku = @c_Sku
                     AND   Busr4 = 'BM'
                   )
      BEGIN
         GOTO NEXT_REC
      END

      SET @c_FCBatchNo = ''

      DECLARE CUR_RDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ReceiptLineNumber
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE Receiptkey = @c_Receiptkey
      AND   ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber),'') = '' THEN ReceiptLineNumber ELSE @c_ReceiptLineNumber END
      AND   Storerkey = @c_Storerkey
      AND   Sku = @c_Sku
      AND   Lottable06 = @c_Lottable06
      AND   (Lottable02 = '' OR Lottable02 IS NULL)
      AND   BeforeReceivedQty > QtyReceived

      OPEN CUR_RDLINE

      FETCH NEXT FROM CUR_RDLINE INTO @c_ReceiptLineNo

      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         IF @c_FCBatchNo = ''
         BEGIN
            SET @b_Success = 0
            EXECUTE nspg_GetKey     
                     @KeyName       = 'FCBatchNo'        
                  ,  @fieldlength   = 5    
                  ,  @keystring     = @c_FCBatchNo     OUTPUT    
                  ,  @b_Success     = @b_Success   OUTPUT    
                  ,  @n_err         = @n_Err       OUTPUT    
                  ,  @c_errmsg      = @c_Errmsg    OUTPUT    
                  ,  @b_resultset   = 0    
                  ,  @n_batch       = 1

            IF @b_Success <> 1 
            BEGIN 
               SET @n_continue= 3 
               SET @n_err  = 72810
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Execute nspg_GetKey Failed. (ispPRREC02)'
                             + '( ' + RTRIM(@c_errmsg) + ' )'
            END 
         END


       
         SET @c_Lottable02 =  RTRIM(@c_prefix) + RTRIM(@c_FCBatchNo)

         /*CS01 Start*/

        SELECT @dt_lottable05 = RECDET.Lottable05
                ,@c_susr2     = S.sUSR2
                ,@c_busr4     = S.BUSR4
                ,@dt_lottable13 = RECDET.Lottable13
        FROM RECEIPTDETAIL RECDET WITH (NOLOCK)
        JOIN SKU S WITH (NOLOCK) ON S.Sku = RECDET.SKU AND S.storerkey=RECDET.Storerkey
         WHERE Receiptkey = @c_Receiptkey  
         AND   ReceiptLineNumber = @c_ReceiptLineNo  
         AND   RECDET.Storerkey = @c_Storerkey  
         AND   RECDET.Sku = @c_Sku   

         IF @c_busr4 = 'BM' AND ISNULL(CONVERT(DATETIME, @dt_Lottable13, 112), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'  --ISNULL(@dt_Lottable13,'') = '' 
         BEGIN

            IF ISNULL(@c_susr2,'') <> '' 
            BEGIN
              SET @dt_GetLottable13 =  @dt_lottable05 + CONVERT(INT,@c_susr2)
            END
            ELSE
            BEGIN
              SET @dt_GetLottable13 =  @dt_lottable05
            END 
       END
       /*CS01 END*/
             
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
         SET Lottable02 = @c_Lottable02
            ,Lottable13 = @dt_GetLottable13                    --(CS01)
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
            ,Trafficcop = NULL
         WHERE ReceiptKey = @c_Receiptkey
         AND   ReceiptLineNumber = @c_ReceiptLineNo

         SET @n_err = @@ERROR

         IF @n_Err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_Err   = 72815
            SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE RECEIPTDETAIL Fail. (ispPRREC02)'

            GOTO QUIT_SP
         END

         NEXT_LINE:
         FETCH NEXT FROM CUR_RDLINE INTO @c_ReceiptLineNo
      END
      CLOSE CUR_RDLINE
      DEALLOCATE CUR_RDLINE

      NEXT_REC:
      FETCH NEXT FROM CUR_RD INTO @c_Storerkey
                                 ,@c_Sku
                                 ,@c_Lottable06
   END
   CLOSE CUR_RD
   DEALLOCATE CUR_RD

   IF @c_FCBatchNo >= '99990' AND @c_Recipients <> ''
   BEGIN
      DECLARE @tAlert TABLE(
         Msg  NVARCHAR(255)
      )

      INSERT INTO @tAlert VALUES ('FCBatchNo NCounter keycount reaches ''99990''')

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue=3
         SET @n_err = 72820
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'INSERT INTO @tAlert Fail. (ispPRREC02)'
         GOTO QUIT_SP
      END

      SET @c_Subject = 'FC Batch # NCounter KeyCount Alert'  
      SET @c_Body = '<table border="1" cellspacing="0" cellpadding="5">' +
          '<tr bgcolor=silver><th>Error</th></tr>' + CHAR(13) +
          CAST ( ( SELECT td = ISNULL(Msg,'')
                   FROM @tAlert 
              FOR XML PATH('tr'), TYPE
          ) AS NVARCHAR(MAX) ) + '</table>' ;

      EXEC msdb.dbo.sp_send_dbmail
            @recipients      = @c_Recipients,
            @copy_recipients = NULL,
            @subject         = @c_Subject,
            @body            = @c_Body,
            @body_format     = 'HTML' ;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue=3
         SET @n_err = 62030
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Error executing sp_send_dbmail. (ispPRREC02)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP
      END
   END  
            
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_RD') in (0 , 1)  
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
   END


   IF CURSOR_STATUS( 'LOCAL', 'CUR_RDLINE') in (0 , 1)  
   BEGIN
      CLOSE CUR_RDLINE
      DEALLOCATE CUR_RDLINE
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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