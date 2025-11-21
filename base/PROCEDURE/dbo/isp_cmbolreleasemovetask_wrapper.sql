SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_CMBOLReleaseMoveTask_Wrapper                    */  
/* Creation Date: 24-Oct-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: 257389-FNPC Release move tasks                               */  
/*          Storerconfig ReleaseCMBOL_MV_SP={ispMBRTKxx} to call         */
/*          customize SP                                                 */                     
/*                                                                       */  
/* Called By: MBOL/CBOL RCM Release Move Task                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 15-Mar-2016  NJOW01   1.0  360341-If MBOL without order, try get     */
/*                            storerkey from container/pallet manifest  */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_CMBOLReleaseMoveTask_Wrapper]  
      @c_MbolKey    NVARCHAR(10) 
   ,  @b_Success    INT OUTPUT    
   ,  @n_Err        INT OUTPUT
   ,	@c_Errmsg     NVARCHAR(250) OUTPUT
   ,  @n_Cbolkey    BIGINT = 0
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
   
   SELECT TOP 1 @c_StorerKey = O.Storerkey
   FROM MBOL M (NOLOCK) 
   JOIN MBOLDETAIL MD (NOLOCK) ON M.Mbolkey = MD.Mbolkey
   JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
   WHERE M.MbolKey = @c_MbolKey 
        OR (@n_Cbolkey > 0 AND M.Cbolkey = @n_Cbolkey)  

   --NJOW01
   IF ISNULL(@c_Storerkey,'') = '' AND ISNULL(@c_MbolKey,'') <> ''
   BEGIN
   	  SELECT TOP 1 @c_Storerkey = P.Storerkey
 	    FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      WHERE C.Mbolkey = @c_Mbolkey 
   END

   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'ReleaseCMBOL_MV_SP'  

   /*IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN  
   	  GOTO QUIT_SP
   END*/
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 31211
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Storerconfig ReleaseCMBOL_MV_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                        + '). (isp_CMBOLReleaseMoveTask_Wrapper)'  
       GOTO QUIT_SP
   END

   
   IF ISNULL(@c_Mbolkey,'') = '' AND @n_Cbolkey > 0 
   BEGIN    
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Mbolkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @n_Cbolkey'
      
      EXEC sp_executesql @c_SQL 
         ,  N'@c_Mbolkey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT, @n_Cbolkey Bigint' 
         ,  @c_Mbolkey
         ,  @b_Success OUTPUT   
         ,  @n_Err OUTPUT
         ,	@c_ErrMsg OUTPUT
         ,  @n_Cbolkey
                           
      IF @b_Success <> 1
      BEGIN
          SELECT @n_Continue = 3  
          GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Mbolkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT'
      
      EXEC sp_executesql @c_SQL 
         ,  N'@c_Mbolkey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
         ,  @c_Mbolkey
         ,  @b_Success OUTPUT   
         ,  @n_Err OUTPUT
         ,	@c_ErrMsg OUTPUT
                           
      IF @b_Success <> 1
      BEGIN
          SELECT @n_Continue = 3  
          GOTO QUIT_SP
      END
   END      
                    
   QUIT_SP:
   IF @n_Continue = 3
   BEGIN
       SELECT @b_Success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_CMBOLReleaseMoveTask_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO