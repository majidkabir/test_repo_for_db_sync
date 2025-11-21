SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PrePopulatePO_Wrapper                          */  
/* Creation Date:                                                       */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-585 - [TW] ASN RCM  Populate From PO Logic              */ 
/*          (ispPRPPLPO??)                                              */ 
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 01/10/2018   NJOW01   1.0  WMS-6038 get storerkey po if ASN not found*/
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_PrePopulatePO_Wrapper]  
      @c_Receiptkey     NVARCHAR(10)
   ,  @c_POKeys         NVARCHAR(MAX)
   ,  @c_POLineNumbers  NVARCHAR(MAX)
   ,  @b_Success        INT OUTPUT    
   ,  @n_Err            INT OUTPUT
   ,  @c_Errmsg         NVARCHAR(255) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_PrePopulatePOSP NVARCHAR(30)
         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_SQL             NVARCHAR(MAX)
           

   SET @n_StartTCnt       = @@TRANCOUNT
   SET @n_Continue        = 1
   SET @b_Success         = 1
   SET @n_err             = 0
   SET @c_errmsg          = ''
   SET @c_PrePopulatePOSP = ''
   SET @c_SQL             = ''
   SET @c_Facility        = ''
   SET @c_Storerkey       = ''

   SELECT @c_Facility  = Facility
         ,@c_Storerkey = Storerkey
   FROM RECEIPT WITH (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey
   
   --NJOW01
   IF ISNULL(@c_Storerkey, '') = '' AND ISNULL(@c_POKeys, '') <> ''
   BEGIN
   	  SELECT TOP 1 @c_Storerkey = Storerkey
   	  FROM PO (NOLOCK)
   	  WHERE Pokey IN (SELECT ColValue FROM dbo.fnc_DelimSplit (',', @c_POKeys))
   END

   SET @c_PrePopulatePOSP = ''
                                     
   EXEC nspGetRight  
          @c_Facility  = @c_Facility   
       ,  @c_StorerKey = @c_StorerKey  
       ,  @c_sku       = NULL  
       ,  @c_ConfigKey = 'PrePopulatePOSP'   
       ,  @b_Success   = @b_Success                 OUTPUT  
       ,  @c_authority = @c_PrePopulatePOSP         OUTPUT   
       ,  @n_err       = @n_err                     OUTPUT   
       ,  @c_errmsg    = @c_errmsg                  OUTPUT  

   IF EXISTS (SELECT 1 FROM sys.Objects WHERE NAME = @c_PrePopulatePOSP AND TYPE = 'P')
   BEGIN
      BEGIN TRAN
      SET @c_SQL = 'EXEC ' + @c_PrePopulatePOSP + ' @c_ReceiptKey, @c_POKeys, @c_POLineNumbers'  
                 + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

      EXEC sp_executesql @c_SQL 
         , N'@c_ReceiptKey NVARCHAR(10), @c_POKeys NVARCHAR(MAX), @c_POLineNumbers NVARCHAR(MAX)
         , @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
         , @c_ReceiptKey
         , @c_POKeys 
         , @c_POLineNumbers 
         , @b_Success         OUTPUT                       
         , @n_Err             OUTPUT  
         , @c_ErrMsg          OUTPUT
       
      IF @b_Success <> 1
      BEGIN
          SET @n_Continue = 3  
          GOTO QUIT_SP
      END
   END
              
   QUIT_SP:
   
   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
   	SET @b_Success = 0
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_PrePopulatePO_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO