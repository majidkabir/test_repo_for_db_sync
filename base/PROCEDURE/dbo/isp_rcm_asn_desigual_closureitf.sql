SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_RCM_ASN_Desigual_ClosureITF                         */  
/* Creation Date: 2023-05-23                                            */  
/* Copyright: Maersk                                                    */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-22531-[CN] Desigual Receipt Clourse trigger point       */  
/*        :                                                             */  
/* Called By: Custom RCM Menu                                           */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2023-05-23  WAN      1.0   Created & DEVOPS combine script           */
/************************************************************************/  
CREATE   PROC [dbo].[isp_RCM_ASN_Desigual_ClosureITF]  
   @c_Receiptkey  NVARCHAR(MAX)   = ''  
,  @b_Success     INT            = 1  OUTPUT
,  @n_Err         INT            = 0  OUTPUT
,  @c_Errmsg      NVARCHAR(225)  = '' OUTPUT  
,  @c_Code        NVARCHAR(30)   = ''  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1 
         
         , @n_Cnt_Str            INT   = 0
         , @n_Cnt_Fac            INT   = 0
  
         , @c_ReceiptKeys        NVARCHAR(MAX) = ''
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_DocType            NVARCHAR(10) = '' 
         , @c_Status             NVARCHAR(10) = ''
         , @c_ASNStatus          NVARCHAR(10) = ''
         
         , @c_TableName          NVARCHAR(30) = 'RCCLORCMLG'
         , @c_RCCLORCMLG         NVARCHAR(10) = ''
         
         , @CUR_ASN              CURSOR
         
   SET @n_Err      = 0  
   SET @c_Errmsg   = ''  
   SET @c_ReceiptKeys = @c_Receiptkey
  
   BEGIN TRAN
   
   IF OBJECT_ID('tempdb..#TMPASN','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMPASN;
   END
   
   CREATE TABLE #TMPASN (Receiptkey NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
                        ,Storerkey  NVARCHAR(15)   NOT NULL DEFAULT('') 
                        ,Facility   NVARCHAR(5)    NOT NULL DEFAULT('') 
                        ,[Status]   NVARCHAR(10)   NOT NULL DEFAULT('')
                        ,ASNStatus  NVARCHAR(10)   NOT NULL DEFAULT('')
                        )
   
   INSERT INTO #TMPASN ( Receiptkey,Storerkey,Facility,[Status],ASNStatus )
   SELECT r.Receiptkey,r.Storerkey,r.Facility,r.[Status],r.ASNStatus 
   FROM STRING_SPLIT(@c_ReceiptKeys, ',') AS ss
   JOIN dbo.RECEIPT AS r WITH (NOLOCK) ON r.ReceiptKey = ss.[value]
   GROUP BY r.Receiptkey,r.Storerkey,r.Facility,r.[Status],r.ASNStatus 
   ORDER BY r.Receiptkey 
   
   SELECT @n_Cnt_Str = COUNT(DISTINCT t.Storerkey)
         ,@n_Cnt_Fac = COUNT(DISTINCT t.Facility)
   FROM #TMPASN AS t WITH (NOLOCK)
    
   IF @n_Cnt_Str > 1 OR @n_Cnt_Fac > 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69010 
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Multiple Storerkey / Facility Found. '   
                    + '(isp_RCM_ASN_Desigual_ClosureITF)'
      GOTO QUIT_SP              
   END
               
   IF EXISTS (SELECT 1 FROM #TMPASN AS t WHERE t.[Status] <> '9' AND t.ASNStatus <> '9')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69020 
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ASN has not received and closed yet. '   
                    + '(isp_RCM_ASN_Desigual_ClosureITF)'
      GOTO QUIT_SP              
   END

   SELECT TOP 1 
         @c_Storerkey= t.Storerkey
      ,  @c_Facility = t.Facility
   FROM #TMPASN AS t WITH (NOLOCK)
   
   SELECT @c_RCCLORCMLG = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', @c_TableName)
   
   IF @c_RCCLORCMLG = '1'
   BEGIN
      SET @CUR_ASN = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT t.Storerkey
           , t.Receiptkey
      FROM #TMPASN AS t WITH (NOLOCK)
      ORDER BY t.ReceiptKey 
      
      OPEN @CUR_ASN
      
      FETCH NEXT FROM @CUR_ASN INTO @c_Storerkey, @c_Receiptkey
       
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ('1','2')
      BEGIN   
         EXEC ispGenTransmitLog3 
              @c_Tablename     = @c_Tablename
            , @c_Key1          = @c_Receiptkey
            , @c_Key2          = ''
            , @c_Key3          = @c_Storerkey
            , @c_TransmitBatch = ''  
            , @b_Success       = @b_Success      OUTPUT   
            , @n_Err           = @n_Err          OUTPUT  
            , @c_Errmsg        = @c_Errmsg       OUTPUT  
       
         IF @b_Success <> 1  
         BEGIN
            SET @n_Continue = 3  
         END
         
         FETCH NEXT FROM @CUR_ASN INTO @c_Storerkey, @c_Receiptkey
      END
      CLOSE @CUR_ASN
      DEALLOCATE @CUR_ASN
   END
QUIT_SP:  
   IF OBJECT_ID('tempdb..#TMPASN','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMPASN;
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ASN_Desigual_ClosureITF'  
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