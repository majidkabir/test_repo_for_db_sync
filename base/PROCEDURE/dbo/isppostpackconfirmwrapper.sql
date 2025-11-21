SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPostPackConfirmWrapper                          */  
/* Creation Date: 06-FEB-2014                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#301554: VFCDC - Update UCC when Pack confirm in Exceed. */
/*                                                                      */  
/*                                                                      */  
/* Called By: ntrPackHeaderUpdate                                       */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 29-SEP-2020  NJOW01  1.0   WMS-15309 add config to update TTLCNTS    */
/************************************************************************/  
CREATE PROC [dbo].[ispPostPackConfirmWrapper]    
     @c_PickSlipNo  NVARCHAR(10)  
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue    INT     
         ,  @n_StartTCnt   INT  -- Holds the current transaction count     
  
   DECLARE  @c_SQL               NVARCHAR(MAX)      
         ,  @c_SQLParm           NVARCHAR(MAX)  
         ,  @c_PostPackConfirmSP NVARCHAR(10)
         ,  @c_Storerkey         NVARCHAR(15)    
         ,  @c_Loadkey           NVARCHAR(10)  
         ,  @c_Orderkey          NVARCHAR(10)
         ,  @c_Facility          NVARCHAR(5)
         ,  @c_PackCfmUpdTTLCNTS NVARCHAR(30)
         ,  @n_TTLCNTS           INT
    
   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  

   SELECT @c_StorerKey = Storerkey
         ,@c_Orderkey = Orderkey  
         ,@c_Loadkey  = Loadkey     
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   --NJOW01 S
   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = Orderkey
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END
   
   SELECT @c_Facility = Facility
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   
   SET @c_PackCfmUpdTTLCNTS = ''
   
   EXEC nspGetRight  
        @c_Facility  = @c_Facility     
      , @c_StorerKey = @c_StorerKey  
      , @c_sku       = NULL 
      , @c_ConfigKey = 'PackCfmUpdTTLCNTS' 
      , @b_Success   = @b_Success                  OUTPUT  
      , @c_authority = @c_PackCfmUpdTTLCNTS        OUTPUT    
      , @n_err       = @n_err                      OUTPUT    
      , @c_errmsg    = @c_errmsg                   OUTPUT  
      
   IF @c_PackCfmUpdTTLCNTS = '1'
   BEGIN
   	  SET @n_TTLCNTS = 0
   	  SELECT @n_TTLCNTS = COUNT(DISTINCT Labelno)
   	  FROM PACKDETAIL (NOLOCK)
   	  WHERE Pickslipno = @c_PickSlipNo
   	  
   	  IF @n_TTLCNTS > 0 
   	  BEGIN
   	  	 UPDATE PACKHEADER WITH (ROWLOCK)
   	  	 SET TTLCNTS = @n_TTLCNTS,
       	  	 ArchiveCop = NULL
   	  	 WHERE Pickslipno = @c_Pickslipno
      
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 63501    
            SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update PACKHEDER table Failed (ispPostPackConfirmWrapper)' 
            GOTO EXIT_SP 
         END    	  	 
   	  END
   END
   --NJOW01 E
  
   SET @c_PostPackConfirmSP = ''
                               
   EXEC nspGetRight  
        @c_Facility  = @c_Facility  --NJOW01   
      , @c_StorerKey = @c_StorerKey  
      , @c_sku       = NULL 
      , @c_ConfigKey = 'PostPackConfirmSP' 
      , @b_Success   = @b_Success                  OUTPUT  
      , @c_authority = @c_PostPackConfirmSP        OUTPUT    
      , @n_err       = @n_err                      OUTPUT    
      , @c_errmsg    = @c_errmsg                   OUTPUT  


   IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostPackConfirmSP AND TYPE = 'P')
   BEGIN
      SET @c_SQL = N' 
         EXECUTE ' + @c_PostPackConfirmSP + CHAR(13) +  
         '  @c_PickSlipNo= @c_PickSlipNo ' + CHAR(13) +  
         ', @c_Storerkey = @c_StorerKey '  + CHAR(13) + 
         ', @b_Success   = @b_Success     OUTPUT ' + CHAR(13) + 
         ', @n_Err       = @n_Err         OUTPUT ' + CHAR(13) +  
         ', @c_ErrMsg    = @c_ErrMsg      OUTPUT '  


      SET @c_SQLParm =  N'@c_PickSlipNo   NVARCHAR(10), ' + 
                         '@c_StorerKey NVARCHAR(15), ' +   
                         '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT '         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_PickSlipNo, @c_StorerKey,
                         @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
     
      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 63502    
         SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostPackConfirmSP +   
                           CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostPackConfirmWrapper)'
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPostPackConfirmWrapper'    
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