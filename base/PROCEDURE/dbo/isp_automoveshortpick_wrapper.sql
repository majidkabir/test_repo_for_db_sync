SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_AutoMoveShortPick_Wrapper                      */  
/* Creation Date: 26-Jan-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 331723-Auto-Move Short Pick                                 */  
/*                                                                      */  
/* Called By: Pickdetail update trigger                                 */    
/*            Stored proc naming: ispAMSPxx                             */
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

CREATE PROCEDURE [dbo].[isp_AutoMoveShortPick_Wrapper]  
      @c_PickDetailKey  NVARCHAR(10)   
   ,  @n_ShortQty       INT
   ,  @b_Success        INT          OUTPUT 
   ,  @n_Err            INT          OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue      INT
         , @n_StartTCnt     INT
         , @c_SPCode        NVARCHAR(10)
         , @c_Storerkey     NVARCHAR(15)
         , @c_SQL           NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT
   SET @c_SPCode     = ''
   SET @c_SQL        = ''
   SET @c_Storerkey  = ''
   
   SELECT @c_Storerkey = Storerkey
   FROM PICKDETAIL WITH (NOLOCK)
   WHERE Pickdetailkey = @c_PickDetailKey

   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'AutoMoveShortPick_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       SET @n_Continue = 3  
       SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Please Setup Stored Procedure Name into Storer Configuration(AutoMoveShortPick_SP) for '
                     + RTRIM(@c_StorerKey)+ '. (isp_AutoMoveShortPick_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 31212
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig UnpickpackORD_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_AutoMoveShortPick_Wrapper)'  
       GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Pickdetailkey, @n_ShortQty'  
              + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

   EXEC sp_executesql @c_SQL 
      , N'@c_Pickdetailkey NVARCHAR(10), @n_ShortQty INT
      , @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
      , @c_PickdetailKey
      , @n_ShortQty
      , @b_Success         OUTPUT                       
      , @n_Err             OUTPUT  
      , @c_ErrMsg          OUTPUT
        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_Continue = 3  
       GOTO QUIT_SP
   END

   QUIT_SP:
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_AutoMoveShortPick_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
END  

GO