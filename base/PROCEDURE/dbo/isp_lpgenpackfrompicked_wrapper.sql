SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_LPGenPackFromPicked_Wrapper                    */  
/* Creation Date: 10-Nov-2010                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: SOS#195377 - Load Plan Generate Pack From Pick              */  
/*                                                                      */  
/* Called By: Load Plan (Call ispLPPK01)                                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2018-11-14  Wan01    1.1   WMS-6788 - [CN] NIKECN PreCartonization   */
/*                            Logic                                     */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_LPGenPackFromPicked_Wrapper]  
   @c_LoadKey    NVARCHAR(10),    
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

         , @n_CallWaveSP   BIT   = 0         --(Wan01)
         , @n_SourceExist  BIT   = 0         --(Wan01)
         , @c_Source       NVARCHAR(10)= ''  --(Wan01)
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
   
   SELECT @c_Storerkey = MAX(ORDERS.Storerkey)
   FROM LOADPLANDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE LOADPLANDETAIL.Loadkey = @c_LoadKey    
   
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'LPGENPACKFROMPICKED'  

   IF ISNULL(RTRIM(@c_SPCode),'') =''
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Please Setup Stored Procedure Name into Storer Configuration for '+RTRIM(@c_StorerKey)+' (isp_LPGenPackFromPicked_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig LPGENPACKFROMPICKED - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_LPGenPackFromPicked_Wrapper)'  
       GOTO QUIT_SP
   END
   --(Wan01) - START
   SELECT @n_CallWaveSP = ISNULL(MAX(CASE WHEN PARAMETER_NAME = '@c_Wavekey' THEN 1 ELSE 0 END),0)
         ,@n_SourceExist= ISNULL(MAX(CASE WHEN PARAMETER_NAME = '@c_Source' THEN 1 ELSE 0 END),0)
   FROM [INFORMATION_SCHEMA].[PARAMETERS] 
   WHERE SPECIFIC_NAME= @c_SPCode

   IF @n_CallWaveSP  = 1
   BEGIN
      IF @n_SourceExist = 0
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 31013-- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Call Wave Share SP but SP has no @c_Source parameter. Action Abort!'
                       + ' (isp_LPGenPackFromPicked_Wrapper)'  
         GOTO QUIT_SP
      END

      SET @c_Source = 'LP'
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Wavekey = @c_LoadKey, @b_Success = @b_Success OUTPUT, @n_Err = @n_Err OUTPUT,' +
                   '@c_ErrMsg = @c_ErrMsg OUTPUT, @c_Source = @c_Source'

      EXEC sp_executesql @c_SQL 
          , N'@c_LoadKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @c_Source  NVARCHAR(10) ' 
          , @c_LoadKey
          , @b_Success  OUTPUT                      
          , @n_Err      OUTPUT 
          , @c_ErrMsg   OUTPUT
          , @c_Source
   END
   ELSE
   BEGIN
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_LoadKey, @b_Success OUTPUT, @n_Err OUTPUT,' +
                   ' @c_ErrMsg OUTPUT '

      EXEC sp_executesql @c_SQL, 
           N'@c_LoadKey NVARCHAR(10), @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
           @c_LoadKey,
           @b_Success OUTPUT,                      
           @n_Err OUTPUT, 
           @c_ErrMsg OUTPUT
   END
   --(Wan01) - END 
                          
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_LPGenPackFromPicked_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO