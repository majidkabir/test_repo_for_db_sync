SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_MBOLReleasePickTask_Wrapper                    */  
/* Creation Date: 01-Nov-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: SOS#229328 - MBOL Release Task                              */  
/*          Storerconfig AllowMBReleasePickTask=1 to enable release     */
/*          pick tasks RCM option                                       */
/*                                                                      */  
/* Called By: MBOL (Call ispMBRTK01)                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 15-Mar-2016  NJOW01   1.0  360341-If MBOL without order, try get     */
/*                            storerkey from container/pallet manifest  */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_MBOLReleasePickTask_Wrapper]  
   @c_MbolKey    NVARCHAR(10),    
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_StorerKey     NVARCHAR(15),
           @c_SPCode        NVARCHAR(10),
           @c_SQL           NVARCHAR(MAX)
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
   
   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
   FROM MBOLDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE MBOLDETAIL.Mbolkey = @c_MbolKey    
   
   --NJOW01
   IF ISNULL(@c_Storerkey,'') = ''
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
   AND    ConfigKey = 'MBOLRELEASETASK_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') =''
   BEGIN       
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Please Setup Stored Procedure Name into Storer Configuration(MBOLRELEASETASK_SP) for '
              +RTRIM(@c_StorerKey)+' (isp_MBOLReleasePickTask_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig MBOLRELEASETASK_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_MBOLReleasePickTask_Wrapper)'  
       GOTO QUIT_SP
   END

   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_MbolKey, @b_Success OUTPUT, @n_Err OUTPUT,' +
                ' @c_ErrMsg OUTPUT '
     
   EXEC sp_executesql @c_SQL, 
        N'@c_MbolKey NVARCHAR(10), @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
        @c_MbolKey,
        @b_Success OUTPUT,                      
        @n_Err OUTPUT, 
        @c_ErrMsg OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_MBOLReleasePickTask_Wrapper'  
       --RAISERROR @n_Err @c_ErrMsg
   END   
END

GO