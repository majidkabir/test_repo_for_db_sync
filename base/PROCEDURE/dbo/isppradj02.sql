SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: ispPRADJ02                                                  */  
/* Creation Date: 18-FEB-20156                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:SOS#363444-FrieslandHK-FC Availability Date                  */
/*                               (lottable13) builder                   */  
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
/* 28-09-21		GHUI	  1.0 Fixed Bug (JSM-21666)                     */
/*                                                                      */
/************************************************************************/  
CREATE PROC [dbo].[ispPRADJ02]   
            @c_AdjustmentKey  NVARCHAR(10)  
         ,  @b_Success        INT = 1  OUTPUT   
         ,  @n_err            INT = 0  OUTPUT   
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT  
AS  
BEGIN  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
         , @c_AdjLineNumber   NVARCHAR(5)  
         , @c_Storerkey       NVARCHAR(15)  
         , @c_Sku             NVARCHAR(20)  
         , @c_UserDefine02    NVARCHAR(20)  
  
         , @c_prefix          NVARCHAR(2)  
         , @c_FCBatchNo       NVARCHAR(5)  
         , @c_Lot02           NVARCHAR(18)  
         , @c_Lot             NVARCHAR(10)  
         , @c_Lottable01   NVARCHAR(18)      
         , @c_Lottable02   NVARCHAR(18)     
         , @c_Lottable03   NVARCHAR(18)      
         , @dt_Lottable04  DATETIME         
         , @dt_Lottable05  DATETIME         
         , @c_Lottable06   NVARCHAR(30)     
         , @c_Lottable07   NVARCHAR(30)      
         , @c_Lottable08   NVARCHAR(30)      
         , @c_Lottable09   NVARCHAR(30)     
         , @c_Lottable10   NVARCHAR(30)     
         , @c_Lottable11   NVARCHAR(30)     
         , @c_Lottable12   NVARCHAR(30)      
         , @dt_Lottable13  DATETIME         
         , @dt_Lottable14  DATETIME         
         , @dt_Lottable15  DATETIME    
  
         , @c_Recipients      NVARCHAR(1000)  
         , @c_Subject         NVARCHAR(250)  
         , @c_Body            NVARCHAR(1000) 

         , @c_busr4           NVARCHAR(18)  
         , @c_susr2           NVARCHAR(18)  
         , @dt_GetLottable13  DATETIME 
     
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   BEGIN TRAN   
  
    
   DECLARE CUR_AD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT  
          Storerkey  
         ,Sku  
        -- ,ISNULL(RTRIM(UserDefine02),'')  
   FROM ADJUSTMENTDETAIL WITH (NOLOCK)  
   WHERE Adjustmentkey = @c_AdjustmentKey  
     
   OPEN CUR_AD  
  
   FETCH NEXT FROM CUR_AD INTO @c_Storerkey  
                              ,@c_Sku  
                               
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
      
  
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
         
       SELECT    @c_susr2     = S.sUSR2
                ,@c_busr4     = S.BUSR4             
        FROM ADJUSTMENTDETAIL ADJDET WITH (NOLOCK)
        JOIN SKU S WITH (NOLOCK) ON S.Sku = ADJDET.SKU
        WHERE AdjustmentKey = @c_Adjustmentkey  
         AND   AdjustmentLineNumber = @c_AdjLineNumber  
         AND   ADJDET.Storerkey = @c_Storerkey  
         AND   ADJDET.Sku = @c_Sku   

       
  
       IF @c_busr4 = 'BM' AND (@dt_Lottable13 = '' OR @dt_Lottable13 IS NULL)
         BEGIN

            IF ISNULL(@c_susr2,'') <> '' 
            BEGIN
              SET @dt_GetLottable13 =  @dt_lottable05 + CONVERT(INT,@c_susr2)
            END
            ELSE
            BEGIN
              SET @dt_GetLottable13 =  @dt_lottable05
            END  
          
  
         UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)  
         SET Lottable13 = @dt_GetLottable13  
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
            SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE Adjustmentdetail Fail. (ispPRADJ02)'  
            GOTO QUIT_SP  
         END  
    END  --(JSM-21666)
  
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
                                 
   END  
   CLOSE CUR_AD  
   DEALLOCATE CUR_AD  
  
      
QUIT_SP:  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_AD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_AD  
      DEALLOCATE CUR_AD  
   END  
  
   PRINT CURSOR_STATUS( 'LOCAL', 'CUR_ADLINE')  --(JSM-21666)
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRADJ02'  
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