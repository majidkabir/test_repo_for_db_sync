SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: ispWVRLE01                                               */
/* Creation Date: 08-Aug-2012                                                 */
/* Copyright: IDS                                                             */
/* Written by: YTWan                                                          */
/*                                                                            */
/* Purpose:  SOS#251460-Release WAVE Error Log (Additional Validation).       */
/*                                                                            */
/* Called By: Wave Print WaveRelErrRpt                                        */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */  
/******************************************************************************/

CREATE PROC [dbo].[ispWVRLE01] (
             @c_WaveKey    NVARCHAR(10)
            ,@b_Success    INT            OUTPUT
            ,@n_Err        INT            OUTPUT
            ,@c_ErrMsg     NVARCHAR(255)  OUTPUT)
AS
BEGIN
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @c_SQL          NVARCHAR(MAX)

   DECLARE @b_ValidateOnly INT
         , @c_Storerkey    NVARCHAR(15)
         , @c_SPCode       NVARCHAR(10)
         
   SET @b_Success       = 1
   SET @n_Err           = 0
   SET @c_ErrMsg        = ''

   SET @c_SQL           = ''

   SET @b_ValidateOnly  = 1   
   SET @c_Storerkey     = ''
   SET @c_SPCode        = ''

--   DELETE [WaveRelErrorReport] WHERE WaveKey = @c_WaveKey 
--  
--   EXEC [dbo].[ispReddWerkWaveValidation] 
--         @c_WaveKey 
--      ,  @b_Success  OUTPUT 
--      ,  @n_Err      OUTPUT 
--      ,  @c_ErrMsg   OUTPUT


   SELECT @c_Storerkey = MAX(ORDERS.Storerkey)
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE WAVEDETAIL.Wavekey = @c_WaveKey    
   
   SELECT @c_SPCode = sVALUE
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'WaveReleaseToWCS_SP' 

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       GOTO QUIT_SP
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       GOTO QUIT_SP
   END

   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_WaveKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @b_ValidateOnly'
   
   EXEC sp_executesql 
            @c_SQL 
        ,   N'@c_WaveKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @b_ValidateOnly INT'  
        ,   @c_WaveKey 
        ,   @b_Success  OUTPUT                     
        ,   @n_Err      OUTPUT  
        ,   @c_ErrMsg   OUTPUT
        ,   @b_ValidateOnly

   QUIT_SP:
END


GO