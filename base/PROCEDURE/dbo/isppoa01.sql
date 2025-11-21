SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA01                                           */  
/* Creation Date: 12-Jun-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 342109 - update pickdetail pickmethod                       */  
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
CREATE PROC [dbo].[ispPOA01]    
     @c_OrderKey    NVARCHAR(10)  
   , @c_LoadKey     NVARCHAR(10)
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
    
   DECLARE  @n_Continue    INT,    
            @n_StartTCnt   INT -- Holds the current transaction count
                          
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
    
   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = ''
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey & Orderkey are Blank (ispPOA01)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey 
   END
   ELSE
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM LoadplanDetail WITH (NOLOCK)
      WHERE LoadKey = @c_LoadKey      
   END
   
   OPEN CUR_ORDERKEY    

   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey     
  
   WHILE @@FETCH_STATUS <> -1        
   BEGIN       
      IF @b_debug=1    
      BEGIN    
         PRINT @c_OrderKey       
      END    
      
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET PickMethod = CASE WHEN UOM = '2' THEN 'F' ELSE 'L' END,
          TrafficCop = NULL
      FROM PICKDETAIL
      WHERE Orderkey = @c_Orderkey
     
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey       
   END -- WHILE @@FETCH_STATUS <> -1    
   
   CLOSE CUR_ORDERKEY        
   DEALLOCATE CUR_ORDERKEY  
   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA01'    
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