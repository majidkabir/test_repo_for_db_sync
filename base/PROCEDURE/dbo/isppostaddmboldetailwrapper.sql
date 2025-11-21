SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOSTAddMBOLDETAILWrapper                        */ 
/* Creation Date: 10-AUG-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:SOS#373477 - TH-Bypass Orders to Mbol autoUpdate TotalCarton */ 
/*                                                                      */ 
/*                                                                      */  
/* Called By: isp_InsertMBOLDetail]                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[ispPOSTAddMBOLDETAILWrapper]    
     @c_mbolKey              NVARCHAR(10)
   , @c_orderkey             NVARCHAR(10)
   , @c_Loadkey              NVARCHAR(10)  
   , @c_POSTAddMBOLDETAILSP  NVARCHAR(10)  
   , @c_MbolDetailLineNumber NVARCHAR(5) = '' 
   , @b_Success              INT           OUTPUT    
   , @n_Err                  INT           OUTPUT    
   , @c_ErrMsg               NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue                INT     
         ,  @n_StartTCnt               INT  -- Holds the current transaction count     
  
   DECLARE  @c_SQL                     NVARCHAR(MAX)      
         ,  @c_SQLParm                 NVARCHAR(MAX)  
   
   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  

   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_POSTAddMBOLDETAILSP),'') = ''  
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63500    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (ispPOSTAddMBOLDETAILWrapper)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_POSTAddMBOLDETAILSP AND TYPE = 'P')
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 63505    
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_POSTAddMBOLDETAILSP + ' Not Found (ispPOSTAddMBOLDETAILWrapper)'
      GOTO EXIT_SP          
   END

   SET @c_SQL = N'  
      EXECUTE ' + @c_POSTAddMBOLDETAILSP           + CHAR(13) +  
      '  @c_mbolKey  =  @c_mbolKey '        + CHAR(13) +  
      ', @c_orderKey =  @c_OrderKey '       + CHAR(13) +  
      ', @c_loadkey =   @c_loadKey '        + CHAR(13) +  
      ', @b_Success  =  @b_Success     OUTPUT '  + CHAR(13) + 
      ', @n_Err      =  @n_Err         OUTPUT '  + CHAR(13) +  
      ', @c_ErrMsg   =  @c_ErrMsg      OUTPUT '  

   SET @c_SQLParm =  N'@c_mbolKey     NVARCHAR(10)'  
                  +   ', @c_orderKey  NVARCHAR(10)'
                  +   ', @c_loadkey   NVARCHAR(10)'
                  +   ', @b_Success   INT OUTPUT'
                  +   ', @n_Err       INT OUTPUT'
                  +   ', @c_ErrMsg    NVARCHAR(250) OUTPUT ' 
        
   EXEC sp_ExecuteSQL @c_SQL
                     ,@c_SQLParm
                     ,@c_mbolKey
                     ,@c_orderKey
                     ,@c_loadkey
                     ,@b_Success OUTPUT
                     ,@n_Err     OUTPUT
                     ,@c_ErrMsg  OUTPUT 
  
   IF @@ERROR <> 0 OR @b_Success <> 1  
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 63510    
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_POSTAddMBOLDETAILSP +   
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPOSTAddMBOLDETAILWrapper)'
      GOTO EXIT_SP                          
   END 
EXIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOSTAddMBOLDETAILWrapper'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012   
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_Success = 1    
      RETURN    
   END    
    
END -- Procedure  

GO