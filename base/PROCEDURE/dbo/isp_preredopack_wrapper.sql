SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PreRedoPack_Wrapper                            */  
/* Creation Date: 2020-10-09                                            */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: WMS-14948 - PH_Benby_Ecom_Packing_Filter.                   */
/*                                                                      */  
/*                                                                      */  
/* Called By: isp_Ecom_RedoPack                                         */  
/*          : Custom SP - ispRedoPAKXX                                  */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Rev   Purposes                                  */  
/* 09-OCT-2020 Wan      1.0   Created                                   */
/************************************************************************/  
CREATE PROC [dbo].[isp_PreRedoPack_Wrapper]    
     @c_PickSlipNo  NVARCHAR(10)  
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(255) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue          INT   = 1  
         ,  @n_StartTCnt         INT   =  @@TRANCOUNT-- Holds the current transaction count     
  
   DECLARE  @c_SQL               NVARCHAR(MAX)  = ''      
         ,  @c_SQLParm           NVARCHAR(MAX)  = '' 
    
         ,  @c_Storerkey         NVARCHAR(15)   = ''   
         ,  @c_Loadkey           NVARCHAR(10)   = ''
         ,  @c_Orderkey          NVARCHAR(10)   = ''
         ,  @c_Facility          NVARCHAR(5)    = ''

         ,  @c_PreRedoPackSP     NVARCHAR(30)   = '' 
    
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  

   SELECT @c_StorerKey = Storerkey
         ,@c_Orderkey = Orderkey  
         ,@c_Loadkey  = Loadkey     
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = Orderkey
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END
   
   SELECT @c_Facility = Facility
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   
   SET @c_PreRedoPackSP = ''
                               
   EXEC nspGetRight  
        @c_Facility  = @c_Facility   
      , @c_StorerKey = @c_StorerKey  
      , @c_sku       = NULL 
      , @c_ConfigKey = 'PreRedoPackSP' 
      , @b_Success   = @b_Success         OUTPUT  
      , @c_authority = @c_PreRedoPackSP  OUTPUT    
      , @n_err       = @n_err             OUTPUT    
      , @c_errmsg    = @c_errmsg          OUTPUT  


   IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreRedoPackSP AND TYPE = 'P')
   BEGIN
      SET @c_SQL = N' 
         EXECUTE ' + @c_PreRedoPackSP + CHAR(13) +  
         '  @c_PickSlipNo= @c_PickSlipNo ' + CHAR(13) +  
         ', @c_Storerkey = @c_StorerKey '  + CHAR(13) + 
         ', @b_Success   = @b_Success     OUTPUT ' + CHAR(13) + 
         ', @n_Err       = @n_Err         OUTPUT ' + CHAR(13) +  
         ', @c_ErrMsg    = @c_ErrMsg      OUTPUT '  


      SET @c_SQLParm =  N'@c_PickSlipNo   NVARCHAR(10)' 
                     +  ', @c_StorerKey   NVARCHAR(15)'   
                     +  ', @b_Success     INT OUTPUT'
                     +  ', @n_Err         INT OUTPUT'
                     +  ', @c_ErrMsg      NVARCHAR(255) OUTPUT '         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_PickSlipNo, @c_StorerKey,
                         @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
     
      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 63510    
         SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PreRedoPackSP +   
                           CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_PreRedoPack_Wrapper)'
         GOTO EXIT_SP                          
      END 
   END
EXIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PreRedoPack_Wrapper'    
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