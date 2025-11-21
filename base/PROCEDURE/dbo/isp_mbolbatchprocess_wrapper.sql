SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_MBOLBatchProcess_Wrapper                        */  
/* Creation Date: 19-02-2019                                             */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-7891 Mbol batch process                                  */  
/*          Storerconfig MBOLBatchProcess_SP={ispMBPROxx} to call        */
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
CREATE PROCEDURE [dbo].[isp_MBOLBatchProcess_Wrapper]  
      @c_Mbollist   NVARCHAR(MAX) 
   ,  @b_Success    INT OUTPUT    
   ,  @n_Err        INT OUTPUT
   ,	@c_Errmsg     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue     INT
         , @c_SPCode       NVARCHAR(50)
         , @c_StorerKey    NVARCHAR(15)
         , @c_facility     NVARCHAR(5)
         , @c_SQL          NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''
   
   IF EXISTS(SELECT 1 
             FROM MBOLDETAIL MD (NOLOCK) 
             JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
             WHERE MD.Mbolkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_Mbollist))
             HAVING COUNT(DISTINCT O.Storerkey) > 1)             
   BEGIN
   	  SET @n_continue = 3
      SET @n_Err = 31210
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                       + ': Found selected MBOL have more than one storer. Only allow one storer pre process. (isp_MBOLBatchProcess_Wrapper)'  
      
      GOTO QUIT_SP
   END             
   
   SELECT TOP 1 @c_StorerKey = O.Storerkey,
                @c_Facility = O.Facility
   FROM MBOL M (NOLOCK)  
   JOIN MBOLDETAIL MD (NOLOCK) ON M.Mbolkey = MD.Mbolkey
   JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
   WHERE M.MbolKey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_Mbollist))
   
   SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MBOLBatchProcess_SP') 
         
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 31220
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Storerconfig MBOLBatchProcess_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                        + '). (isp_MBOLBatchProcess_Wrapper)'  
       GOTO QUIT_SP
   END

   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Mbollist, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT'
   
   EXEC sp_executesql @c_SQL 
      ,  N'@c_Mbollist NVARCHAR(MAX), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
      ,  @c_Mbollist
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
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_MBOLBatchProcess_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO