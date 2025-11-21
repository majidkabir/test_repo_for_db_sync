SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_UnpickpackUCC_Wrapper                          */  
/* Creation Date: 05-Oct-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#249056:Unpickpack Orders                                */  
/*          Storerconfig UnpickpackORD_SP={SPName} to enable UNpickpack */
/*          Process                                                     */
/*                                                                      */  
/* Called By: RCM Unpickpack Orders At Unpickpack Orders screen         */  
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
CREATE PROCEDURE [dbo].[isp_UnpickpackUCC_Wrapper]  
      @c_PickslipNo     NVARCHAR(10)   
   ,  @c_LabelNo        NVARCHAR(20)  
   ,  @c_DropID         NVARCHAR(20) 
   ,  @c_UPPLoc         NVARCHAR(10)
   ,  @c_UnpickMoveKey  NVARCHAR(10)  OUTPUT 
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
         , @c_StorerKey     NVARCHAR(15)
         , @c_Loadkey       NVARCHAR(10)
         , @c_SQL           NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_Loadkey    = ''
   SET @c_SQL        = ''
   
   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   SELECT @c_Storerkey = ISNULL(RTRIM(PACKHEADER.Storerkey),'')
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PACKHEADER.PickSlipNo = @c_PickslipNo

   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'UnpickpackUCC_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
      SET @n_Continue = 3  
      SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                  + ': Please Setup Stored Procedure Name into Storer Configuration(UnpickpackUCC_SP) for '
                  + RTRIM(@c_StorerKey)+ '. (isp_UnpickpackUCC_Wrapper)'  
      GOTO QUIT_SP
   END

   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err = 31212
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Storerconfig UnpickpackUCC_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                  + '). (isp_UnpickpackUCC_Wrapper)'  
      GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickSlipNo, @c_LabelNo, @c_DropID, @c_UPPLoc, @c_UnpickMoveKey OUTPUT' 
              + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

   EXEC sp_executesql @c_SQL 
      , N'@c_PickSlipNo NVARCHAR(10), @c_LabelNo NVARCHAR(20), @c_DropID NVARCHAR(20) 
         ,@c_UPPLoc NVARCHAR(10), @c_UnpickMoveKey NVARCHAR(10) OUTPUT
         ,@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
      , @c_PickSlipNo
      , @c_LabelNo
      , @c_DropID
      , @c_UPPLoc
      , @c_UnpickMoveKey   OUTPUT
      , @b_Success         OUTPUT                       
      , @n_Err             OUTPUT  
      , @c_ErrMsg          OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
      SELECT @n_Continue = 3  
      GOTO QUIT_SP
   END
                    
   QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_UnpickpackORD_Wrapper'
      --RAISERROR @n_err @c_errmsg
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