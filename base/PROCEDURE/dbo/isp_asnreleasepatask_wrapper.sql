SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ASNReleasePATask_Wrapper                       */  
/* Creation Date: 18-Sep-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#255755:Release Putaway Task                             */  
/*          Storerconfig ASNReleasePATask_SP={SPName} to enable release */
/*          PA Task                                                     */
/*                                                                      */  
/* Called By: ASN RCM Release Putaway Tasks                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_ASNReleasePATask_Wrapper]  
   @c_ReceiptKey NVARCHAR(10),    
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT
         , @c_SPCode        NVARCHAR(10)
         , @c_StorerKey     NVARCHAR(15)
         , @c_ASNStatus     NVARCHAR(10)
         , @c_SQL           NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_ASNStatus  = ''
   SET @c_SQL        = ''
   
   SELECT @c_Storerkey = ISNULL(RTRIM(RECEIPT.Storerkey),'') 
         ,@c_ASNStatus = ISNULL(RTRIM(ASNStatus),'0')
   FROM RECEIPT WITH (NOLOCK)
   WHERE RECEIPT.Receiptkey = @c_ReceiptKey

   IF @c_ASNStatus = 'CANC'   
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': ASN#: ' + RTRIM(@c_ReceiptKey) + ' has been cancelled. (isp_ASNReleasePATask_Wrapper)'  
       GOTO QUIT_SP
   END

--   IF @c_ASNStatus = '9'   
--   BEGIN
--       SET @n_continue = 3  
--       SET @n_Err = 31212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
--                     + ': ASN#: ' + RTRIM(@c_ReceiptKey) + ' has been closed. (isp_ASNReleasePATask_Wrapper)'  
--       GOTO QUIT_SP
--   END
   
   IF NOT EXISTS (SELECT 1  
                  FROM RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @c_Receiptkey
                  AND FinalizeFlag = 'Y')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31213 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': ASN#: ' + RTRIM(@c_ReceiptKey) + ' has been not finalized yet. (isp_ASNReleasePATask_Wrapper)'  
       GOTO QUIT_SP
   END

   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'ASNReleasePATask_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31214 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Please Setup Stored Procedure Name into Storer Configuration(ASNReleasePATask_SP) for '
                     + RTRIM(@c_StorerKey)+ '. (isp_ASNReleasePATask_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31215
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig ASNReleasePATask_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_ASNReleasePATask_Wrapper)'  
       GOTO QUIT_SP
   END

   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_ReceiptKey, @b_Success OUTPUT, @n_Err OUTPUT,' +
                ' @c_ErrMsg OUTPUT '

   EXEC sp_executesql @c_SQL 
      , N'@c_ReceiptKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
      , @c_ReceiptKey 
      , @b_Success   OUTPUT                       
      , @n_Err       OUTPUT  
      , @c_ErrMsg    OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_ASNReleasePATask_Wrapper'  
   END   
END  

GO