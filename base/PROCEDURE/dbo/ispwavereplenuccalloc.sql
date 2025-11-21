SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/********************************************************************************/  
/* Stored Procedure: ispWaveReplenUCCAlloc                                      */  
/* Creation Date: 05-May-2015                                                   */  
/* Copyright: IDS                                                               */  
/* Written by: Shong                                                            */  
/*                                                                              */  
/* Purpose: UCC Allocation Special Design Genaric SP base on StorerConfig       */  
/*                                                                              */  
/*                                                                              */  
/* Called By: From Wave Maintenance Screen                                      */  
/*                                                                              */  
/* PVCS Version: 1.1                                                            */  
/*                                                                              */  
/* Version: 5.4                                                                 */  
/*                                                                              */  
/* Data Modifications:                                                          */  
/*                                                                              */  
/* Updates:                                                                     */  
/* Date         Author     Ver     Purposes                                     */  
/* 06-May-2022  NJOW01     1.0     Add @c_code parameter to support calling by  */
/*                                 RCMConfig                                    */
/********************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispWaveReplenUCCAlloc]  
   @c_WaveKey NVARCHAR(10),  
   @b_Success int OUTPUT,  
   @n_err     int OUTPUT,  
   @c_errmsg  NVARCHAR(250) OUTPUT,  
   @c_code     NVARCHAR(30)=''        
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
   --SET @b_Success    = 1  
   SET @c_errmsg     = ''  
  
   SET @n_Continue   = 1  
   SET @c_SPCode     = ''  
   SET @c_StorerKey  = ''  
   SET @c_SQL        = ''  
     
   SELECT TOP 1 @c_StorerKey = O.Storerkey  
   FROM WAVEDETAIL WD (NOLOCK)  
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)  
   WHERE WD.Wavekey = @c_Wavekey    
  
   -- Set default Stored Procedure as ispWRUCC01 (Original from ispWaveReplenUCCAllocation_SP)  
   SET @c_SPCode = 'ispWRUCC01'  
     
   SELECT @c_SPCode = ISNULL(sVALUE, 'ispWRUCC01')   
   FROM   StorerConfig WITH (NOLOCK)   
   WHERE  StorerKey = @c_StorerKey  
   AND    ConfigKey = 'WaveReplenUCCAllocation_SP'    
  
   IF ISNULL(RTRIM(@c_SPCode),'') = ''  
   BEGIN    
       SET @n_Continue = 3    
       SET @n_Err = 31210  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)    
                        + ': Storerconfig WaveReplenUCCAllocation_SP Not Yet Setup'  
                        + '). (ispWaveReplenUCCAlloc)'    
       GOTO QUIT_SP  
   END  
     
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
   BEGIN  
       SET @n_Continue = 3    
       SET @n_Err = 31211  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)    
                        + ': Storerconfig WaveReplenUCCAllocation_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))  
                        + '). (ispWaveReplenUCCAlloc)'    
       GOTO QUIT_SP  
   END  
  
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_WaveKey=@c_Wavekey, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT'  
     
   EXEC sp_executesql @c_SQL   
      ,  N'@c_WaveKey NVARCHAR(10), @b_Success int OUTPUT,  @n_Err INT OUTPUT, @c_ErrMsg  NVARCHAR(250) OUTPUT'   
      ,  @c_Wavekey                                    
      ,  @b_Success OUTPUT   
      ,  @n_Err     OUTPUT  
      , @c_ErrMsg  OUTPUT  
                
   IF @b_Success <> 1  
   BEGIN  
       SELECT @n_Continue = 3    
       GOTO QUIT_SP  
   END  
                      
   QUIT_SP:  
   IF @n_Continue = 3  
   BEGIN  
       SELECT @b_Success = 0  
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveReplenUCCAlloc'    
   END     
END    

GO