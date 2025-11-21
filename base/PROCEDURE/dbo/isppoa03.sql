SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA03                                           */  
/* Creation Date: 17-Apr-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-4345 CN UA Post allocation find and update multi orders */  
/*          conso carton from bulk                                      */
/*                                                                      */  
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispPOA03]    
     @c_OrderKey    NVARCHAR(10) = '' 
   , @c_LoadKey     NVARCHAR(10) = ''
   , @c_Wavekey     NVARCHAR(10) = ''
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF         
    
   DECLARE  @n_Continue              INT,    
            @n_StartTCnt             INT, -- Holds the current transaction count
            @c_OrderLineNumber       NVARCHAR(5),
            @c_Pickdetailkey         NVARCHAR(10)
                                                              
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''  
    
   IF @n_continue IN(1,2)  
   BEGIN    
   	  IF ISNULL(@c_OrderKey,'') <> ''
   	     GOTO EXIT_SP
   	        	  
      IF ISNULL(@c_WaveKey,'') = '' AND ISNULL(@c_LoadKey,'') = '' 
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey & Wavekey are Blank (ispPOA03)'
         GOTO EXIT_SP    
      END
      
      IF EXISTS(SELECT 1 
                FROM ORDERS (NOLOCK)
                WHERE (Loadkey = @c_Loadkey OR ISNULL(@c_Loadkey,'') = '')
                AND (Userdefine09 = @c_Wavekey OR ISNULL(@c_Wavekey,'') = '')
                AND Doctype = 'E'
                )
      BEGIN
         GOTO EXIT_SP
      END                                          
   END 
   
   IF @n_continue IN(1,2)
   BEGIN   	
      EXEC isp_ConsolidatePickdetail        
          @c_Loadkey = @c_Loadkey
         ,@c_Wavekey = @c_Wavekey
         ,@c_UOM = '2'
         ,@c_GroupFieldList = 'ORDERS.Orderkey'
         ,@c_SQLCondition  = 'SKUXLOC.LocationType NOT IN (''CASE'',''PICK'')' 
         ,@c_CaseCntByUCC = 'N'
         ,@c_PickMethodOfConso = 'C' 
         ,@c_UOMOfConso = '6'
         ,@b_Success = @b_success OUTPUT  
         ,@n_Err = @n_Err OUTPUT  
         ,@c_ErrMsg = @c_ErrMsg OUTPUT
      
      IF @b_success <> 1
         SELECT @n_continue = 3     
   END
         
EXIT_SP:
    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA03'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
    
END -- Procedure  

GO