SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_HMIND_AutoCreateAsnByPO                        */
/* Creation Date: 19-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20778 - HMIND - Schedule ASN creation Job               */
/*                                                                      */
/* Called By: SQL Job                                                   */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_HMIND_AutoCreateAsnByPO] 
      @c_Storerkey NVARCHAR(15) = 'HMIND'
    , @b_success   INT = 1 OUTPUT
    , @n_err       INT = 0 OUTPUT
    , @c_errmsg    NVARCHAR(225) = '' OUTPUT
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue         INT
           , @n_cnt              INT
           , @n_starttcnt        INT
           , @c_POKey            NVARCHAR(10)
           , @n_WarningNo        INT
           , @c_UserName         NVARCHAR(128) = SUSER_SNAME()
           , @n_ErrGroupKey      INT
           , @c_Receiptkey       NVARCHAR(10)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   DECLARE CUR_PO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TRIM(POD.POKey)
   FROM PODETAIL POD (NOLOCK)
   JOIN PO (NOLOCK) ON PO.POKey = POD.POKey
   LEFT JOIN RECEIPTDETAIL RD (NOLOCK) ON RD.POKey = POD.POKey 
                                      AND RD.StorerKey = POD.StorerKey
   WHERE POD.StorerKey = @c_Storerkey
   AND POD.UserDefine05 <> ''
   AND POD.UserDefine09 <> ''
   AND PO.[Status] = '0'
   AND PO.ExternStatus = '0'
   AND DATEDIFF(Minute, PO.Adddate, GETDATE()) >= 3   --To ensure the PO is completely created
   AND RD.POKey IS NULL

   OPEN CUR_PO

   FETCH NEXT FROM CUR_PO INTO @c_POKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --Create Receipt Header
      SET @c_Receiptkey = ''

      EXEC dbo.nspg_GetKey @KeyName = N'RECEIPT'                
                         , @fieldlength = 10              
                         , @keystring = @c_Receiptkey OUTPUT
                         , @b_Success = @b_Success    OUTPUT
                         , @n_err = @n_err            OUTPUT        
                         , @c_errmsg = @c_errmsg      OUTPUT  
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 62010     
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': EXEC nspg_GetKey Failed. (isp_HMIND_AutoCreateAsnByPO)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP 
      END

      IF @c_Receiptkey <> ''
      BEGIN
         INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, ReceiptDate, Facility, DOCTYPE, RECType) 
         SELECT TOP 1 @c_Receiptkey, PO.ExternPOKey, PO.StorerKey, GETDATE(), POD.Facility, 'A', 'NORMAL'
         FROM PODETAIL POD (NOLOCK)
         JOIN PO (NOLOCK) ON PO.POKey = POD.POKey
         WHERE PO.POKey = @c_POKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 62015    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RECEIPT Failed. (isp_HMIND_AutoCreateAsnByPO)'   
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            GOTO QUIT_SP 
         END
      END

      EXEC WM.lsp_ASN_PopulatePOs_Wrapper
            @c_ReceiptKey           = @c_Receiptkey 
         ,  @c_POKeyList            = @c_POKey  -- PO Keys seperated by '|'  
         ,  @c_PopulateType         = '1PO1ASN'  -- Populate type, '1PO1ASN' if 1 PO to 1 ASN. 'MPO1ASN' if Many PO to 1 ASN  
         ,  @b_PopulateFromArchive  = 0  -- Pass in 1 if Populate PO from Archive DB  
         ,  @b_Success              = @b_Success      OUTPUT  
         ,  @n_err                  = @n_err          OUTPUT  
         ,  @c_ErrMsg               = @c_ErrMsg       OUTPUT  
         ,  @n_WarningNo            = @n_WarningNo    OUTPUT  
         ,  @c_ProceedWithWarning   = 'Y'  
         ,  @c_UserName             = @c_UserName
         ,  @n_ErrGroupKey          = @n_ErrGroupKey  OUTPUT  

      IF @n_err <> 0
      BEGIN   
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 62020      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': EXEC WM.lsp_ASN_PopulatePOs_Wrapper Failed. (isp_HMIND_AutoCreateAsnByPO)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP  
      END

      EXEC dbo.isp_RCM_ASN_HM_SplitToSMCtn 
            @c_Receiptkey = @c_Receiptkey    
          , @b_success    = @b_success   OUTPUT
          , @n_err        = @n_err       OUTPUT    
          , @c_errmsg     = @c_errmsg    OUTPUT 
          , @c_code       = N''              
      
      IF @n_err <> 0
      BEGIN   
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 62025      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': EXEC isp_RCM_ASN_HM_SplitToSMCtn Failed. (isp_HMIND_AutoCreateAsnByPO)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP  
      END

      UPDATE dbo.PO
      SET ExternStatus = '5'
      WHERE POKey = @c_POKey

      IF @@ERROR <> 0
      BEGIN   
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 62030      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PO Failed. (isp_HMIND_AutoCreateAsnByPO)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP  
      END

      FETCH NEXT FROM CUR_PO INTO @c_POKey
   END
   CLOSE CUR_PO
   DEALLOCATE CUR_PO
      
QUIT_SP: 
   IF CURSOR_STATUS('LOCAL', 'CUR_PO') IN (0 , 1)
   BEGIN
      CLOSE CUR_PO
      DEALLOCATE CUR_PO   
   END
      
   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
       BEGIN
          ROLLBACK TRAN
       END
    ELSE
       BEGIN
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
       END
       execute nsp_logerror @n_err, @c_errmsg, 'isp_HMIND_AutoCreateAsnByPO'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
       BEGIN
          SELECT @b_success = 1
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
          RETURN
       END      
END -- End PROC

GO