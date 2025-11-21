SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_VASJobReleaseTasks_Wrapper                      */  
/* Creation Date: 10-AUG-2015                                            */  
/* Copyright: LFL                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#315701 - Project Merlion - VAP Release Task generates    */
/*          WCS Message                                                  */  
/*                                                                       */  
/* Called By: n_cst_workorderjobdetail.Event ue_releasetasks             */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_VASJobReleaseTasks_Wrapper]  
      @c_JobKey      NVARCHAR(10) 
   ,  @b_Success     INT OUTPUT    
   ,  @n_Err         INT OUTPUT
   ,  @c_Errmsg      NVARCHAR(255) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue     INT
         , @c_SPCode       NVARCHAR(50)
         , @c_StorerKey    NVARCHAR(15)
         , @c_SQL          NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''
   
   SELECT @c_StorerKey = Storerkey
   FROM WORKORDERJOBDETAIL WITH (NOLOCK)
   WHERE JobKey = @c_JobKey  

   SELECT @c_SPCode = ISNULL(RTRIM(sValue),'')
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'VASJobReleaseTasks_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN  
      SET @c_SPCode = 'isp_WOJobReleaseTasks'
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err = 31211
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)  
                  + ': Storerconfig VASJobReleaseTasks_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                  + '). (isp_VASJobReleaseTasks_Wrapper)'  
      GOTO QUIT_SP
   END

   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_JobKey = @c_JobKey, @b_Success = @b_Success OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT'

   EXEC sp_executesql @c_SQL 
      ,  N'@c_JobKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
      ,  @c_JobKey
      ,  @b_Success  OUTPUT   
      ,  @n_Err      OUTPUT
      ,  @c_ErrMsg   OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3  
      GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_VASJobReleaseTasks_Wrapper'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO