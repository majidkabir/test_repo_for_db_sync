SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPRADJ01                                                  */
/* Creation Date: 19-OCT-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:SOS#354468 - FrieslandHK- FC System Batch number (lottable02)*/      
/*        : builder                                                     */
/* Called By: ispPreFinalizeADJWrapper                                  */
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
CREATE PROC [dbo].[ispPRADJ01] 
            @c_AdjustmentKey  NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_AdjLineNumber   NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)

         , @c_prefix          NVARCHAR(2)
         , @c_FCBatchNo       NVARCHAR(5)
         , @c_Lot02           NVARCHAR(18)
         , @c_Lot             NVARCHAR(10)
         , @c_Lottable01      NVARCHAR(18)    
         , @c_Lottable02      NVARCHAR(18)   
         , @c_Lottable03      NVARCHAR(18)    
         , @dt_Lottable04     DATETIME       
         , @dt_Lottable05     DATETIME       
         , @c_Lottable06      NVARCHAR(30)   
         , @c_Lottable07      NVARCHAR(30)    
         , @c_Lottable08      NVARCHAR(30)    
         , @c_Lottable09      NVARCHAR(30)   
         , @c_Lottable10      NVARCHAR(30)   
         , @c_Lottable11      NVARCHAR(30)   
         , @c_Lottable12      NVARCHAR(30)    
         , @dt_Lottable13     DATETIME       
         , @dt_Lottable14     DATETIME       
         , @dt_Lottable15     DATETIME  

         , @c_Recipients      NVARCHAR(1000)
         , @c_Subject         NVARCHAR(250)
         , @c_Body            NVARCHAR(1000)

         , @c_busr4           NVARCHAR(18)         --(CS01)
         , @c_susr2           NVARCHAR(18)         --(CS01)
         , @dt_GetLottable13  DATETIME             --(CS01)
   

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_FCBatchNo= ''

 
   IF EXISTS( SELECT 1
              FROM ADJUSTMENT WITH (NOLOCK)
              WHERE Adjustmentkey = @c_Adjustmentkey
              AND AdjustmentType = 'NIF'
            )
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN 

   SET @c_prefix    = ''
   SET @c_Recipients= ''
   SELECT @c_prefix = Code
         ,@c_Recipients = CASE WHEN Udf01 <> '' THEN Udf01 + ';' ELSE '' END
                        + CASE WHEN Udf02 <> '' THEN Udf02 + ';' ELSE '' END
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = 'FCBATCHNO'

   DECLARE CUR_AD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT
          Storerkey
         ,Sku
         ,ISNULL(RTRIM(Lottable06),'')
   FROM ADJUSTMENTDETAIL WITH (NOLOCK)
   WHERE Adjustmentkey = @c_AdjustmentKey
   AND   (Lot = '' OR Lot IS NULL)
   AND   Qty > 0 

   OPEN CUR_AD

   FETCH NEXT FROM CUR_AD INTO @c_Storerkey
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

      DECLARE CUR_ADLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT AdjustmentLineNumber
            ,Lot
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
      FROM ADJUSTMENTDETAIL WITH (NOLOCK)
      WHERE Adjustmentkey = @c_AdjustmentKey
      AND   Storerkey = @c_Storerkey
      AND   Sku = @c_Sku
      AND   Lottable06 = @c_Lottable06
      AND   (Lot = '' OR Lot IS NULL)
      AND   Qty > 0

      OPEN CUR_ADLINE

      FETCH NEXT FROM CUR_ADLINE INTO @c_AdjLineNumber
                                    , @c_Lot
                                    , @c_Lottable01 
                                    , @c_Lottable02 
                                    , @c_Lottable03 
                                    , @dt_Lottable04
                                    , @dt_Lottable05
                                    , @c_Lottable06 
                                    , @c_Lottable07 
                                    , @c_Lottable08 
                                    , @c_Lottable09 
                                    , @c_Lottable10 
                                    , @c_Lottable11 
                                    , @c_Lottable12 
                                    , @dt_Lottable13
                                    , @dt_Lottable14
                                    , @dt_Lottable15

      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         IF ISNULL(RTRIM(@c_Lottable02),'') <> '' 
         BEGIN
            EXECUTE nsp_lotlookup
                     @c_Storerkey   = @c_Storerkey  
                  ,  @c_Sku         = @c_Sku        
                  ,  @c_Lottable01  = @c_Lottable01 
                  ,  @c_Lottable02  = @c_Lottable02 
                  ,  @c_Lottable03  = @c_Lottable03 
                  ,  @c_Lottable04  = @dt_Lottable04
                  ,  @c_Lottable05  = @dt_Lottable05
                  ,  @c_Lottable06  = @c_Lottable06 
                  ,  @c_Lottable07  = @c_Lottable07 
                  ,  @c_Lottable08  = @c_Lottable08 
                  ,  @c_Lottable09  = @c_Lottable09 
                  ,  @c_Lottable10  = @c_Lottable10 
                  ,  @c_Lottable11  = @c_Lottable11 
                  ,  @c_Lottable12  = @c_Lottable12 
                  ,  @c_Lottable13  = @dt_Lottable13
                  ,  @c_Lottable14  = @dt_Lottable14
                  ,  @c_Lottable15  = @dt_Lottable15
                  ,  @c_lot         = @c_lot      OUTPUT
                  ,  @b_Success     = @b_Success  OUTPUT
                  ,  @n_err         = @n_err      OUTPUT
                  ,  @c_errmsg      = @c_errmsg   OUTPUT

            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_err  = 72805
               SET @c_errmsg = 'NSQL'+ +CONVERT(CHAR(5),@n_err)+': Execute nsp_lotlookup Failed.(isp_FinalizeADJ)'
                             + '( ' + RTRIM(@c_errmsg) + ' )'
               GOTO QUIT_SP
            END
         END

         IF ISNULL(RTRIM(@c_lot),'') <> '' 
         BEGIN
            GOTO NEXT_LINE
         END

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
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Execute nspg_GetKey Failed. (ispPRADJ01)'
                             + '( ' + RTRIM(@c_errmsg) + ' )'
            END 

            SET @c_Lot02 =  RTRIM(@c_Prefix) + RTRIM(@c_FCBatchNo)
         END
       /*CS01 Start*/
         SELECT    @c_susr2     = S.sUSR2
                  ,@c_busr4     = S.BUSR4             
        FROM ADJUSTMENTDETAIL ADJDET WITH (NOLOCK)
        JOIN SKU S WITH (NOLOCK) ON S.Sku = ADJDET.SKU
        WHERE AdjustmentKey = @c_Adjustmentkey  
         AND   AdjustmentLineNumber = @c_AdjLineNumber  
         AND   ADJDET.Storerkey = @c_Storerkey  
         AND   ADJDET.Sku = @c_Sku   


         IF @c_busr4 = 'BM' AND ISNULL(@dt_Lottable13,'') = '' 
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
   /*CS01 End*/

         UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
         SET Lottable02 = @c_Lot02
            ,Lottable13 = @dt_GetLottable13                     --(CS01)
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
            ,Trafficcop = NULL
         WHERE AdjustmentKey = @c_Adjustmentkey
         AND   AdjustmentLineNumber = @c_AdjLineNumber

         SET @n_err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_Err   = 72815
            SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE Adjustmentdetail Fail. (ispPRADJ01)'
            GOTO QUIT_SP
         END

         NEXT_LINE:
         FETCH NEXT FROM CUR_ADLINE INTO @c_AdjLineNumber
                                       , @c_Lot
                                       , @c_Lottable01 
                                       , @c_Lottable02 
                                       , @c_Lottable03 
                                       , @dt_Lottable04
                                       , @dt_Lottable05
                                       , @c_Lottable06 
                                       , @c_Lottable07 
                                       , @c_Lottable08 
                                       , @c_Lottable09 
                                       , @c_Lottable10 
                                       , @c_Lottable11 
                                       , @c_Lottable12 
                                       , @dt_Lottable13
                                       , @dt_Lottable14
                                       , @dt_Lottable15
      END
      CLOSE CUR_ADLINE
      DEALLOCATE CUR_ADLINE

      NEXT_REC:
      FETCH NEXT FROM CUR_AD INTO @c_Storerkey
                                 ,@c_Sku
                                 ,@c_Lottable06
   END
   CLOSE CUR_AD
   DEALLOCATE CUR_AD

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
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'INSERT INTO @tAlert Fail. (ispPRADJ01)'
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
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Error executing sp_send_dbmail. (ispPRADJ01)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP
      END
   END   
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_AD') in (0 , 1)  
   BEGIN
      CLOSE CUR_AD
      DEALLOCATE CUR_AD
   END


   IF CURSOR_STATUS( 'LOCAL', 'CUR_ADLINE') in (0 , 1)  
   BEGIN
      CLOSE CUR_ADLINE
      DEALLOCATE CUR_ADLINE
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRADJ01'
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