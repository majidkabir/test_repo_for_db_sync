SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PreCombineOrder_Wrapper                        */  
/* Creation Date:                                                       */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 333313 - Pre combine order process (ispPRCBO??)             */  
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
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_PreCombineOrder_Wrapper]  
      @c_ToOrderkey NVARCHAR(10)
   ,  @c_OrderList NVARCHAR(MAX)
   ,  @b_Success    INT OUTPUT    
   ,  @n_Err        INT OUTPUT
   ,	@c_Errmsg     NVARCHAR(255) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_TxtResult     NVARCHAR(MAX),
           @n_continue      INT,
           @c_OrderKey      NVARCHAR(10),
           @n_starttcnt     INT,
           @c_SPCode        NVARCHAR(10),
           @c_Storerkey     NVARCHAR(15),
           @c_SQL           NVARCHAR(MAX)
           
   SELECT @n_continue = 1, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
   SET @n_starttcnt = @@TRANCOUNT  
   SET @c_SPCode     = ''
   SET @c_SQL        = ''
   SET @c_Storerkey  = ''

   SELECT @c_Storerkey = Storerkey
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_ToOrderkey
   
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'PreCombineOrder_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       --SET @n_Continue = 3  
       --SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       --SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
       --              + ': Please Setup Stored Procedure Name into Storer Configuration(PreCombineOrder_SP) for '
       --              + RTRIM(@c_StorerKey)+ '. (isp_PreCombineOrder_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 31212
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig PreCombineOrder_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_PreCombineOrder_Wrapper)'  
       GOTO QUIT_SP
   END
   
   BEGIN TRAN
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_ToOrderkey, @c_OrderList'  
              + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

   EXEC sp_executesql @c_SQL 
      , N'@c_ToOrderkey NVARCHAR(10), @c_OrderList NVARCHAR(MAX)
      , @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
      , @c_ToOrderKey
      , @c_OrderList 
      , @b_Success         OUTPUT                       
      , @n_Err             OUTPUT  
      , @c_ErrMsg          OUTPUT
        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_Continue = 3  
       GOTO QUIT_SP
   END
           
   QUIT_SP:
   
   IF @n_continue = 3  -- Error Occured - Process And Return
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_PreCombineOrder_Wrapper'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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