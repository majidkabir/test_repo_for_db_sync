SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_HoldStatusChangeValidation_Wrapper              */  
/* Creation Date: 06-03-2019                                             */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8016 CN Fabory hold status change validation             */  
/*          Storerconfig HoldStatusChangeValidation_SP={ispHoldxx} to call*/
/*          customize SP                                                 */                     
/*                                                                       */  
/* Called By: MBOL RCM Batch process                                     */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_HoldStatusChangeValidation_Wrapper]  
      @c_InventoryHoldkey   NVARCHAR(10) 
   ,  @c_NewHoldStatus NVARCHAR(1)
   ,  @c_prompttosave  NVARCHAR(10) = 'N' OUTPUT
   ,  @b_Success    INT OUTPUT    
   ,  @n_Err        INT OUTPUT
   ,	@c_Errmsg     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue       INT
         , @c_SPCode         NVARCHAR(50)
         , @c_StorerKey      NVARCHAR(15)
         , @c_SQL            NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''
      
   SELECT @c_StorerKey = Storerkey
   FROM INVENTORYHOLD (NOLOCK)
   WHERE InventoryHoldKey = @c_InventoryHoldKey
   
   SELECT @c_SPCode = dbo.fnc_GetRight('', @c_Storerkey, '', 'HoldStatusChangeValidation_SP') 
         
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 31220
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Storerconfig HoldStatusChangeValidation_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                        + '). (isp_HoldStatusChangeValidation_Wrapper)'  
       GOTO QUIT_SP
   END

   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_InventoryHoldkey, @c_NewHoldStatus, @c_Prompttosave OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT'
   
   EXEC sp_executesql @c_SQL 
      ,  N'@c_InventoryHoldKey NVARCHAR(10), @c_NewHoldStatus NVARCHAR(1), @c_Prompttosave NVARCHAR(10) OUTPUT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
      ,  @c_InventoryHoldkey
      ,  @c_NewHoldStatus 
      ,  @c_Prompttosave OUTPUT
      ,  @b_Success OUTPUT   
      ,  @n_Err OUTPUT
      ,	 @c_ErrMsg OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_Continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_Continue = 3
   BEGIN
       SELECT @b_Success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_HoldStatusChangeValidation_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO