SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA24                                           */    
/* Creation Date: 04-APR-2023                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-22213 - KR HM - Wave Generate Load by Putawayzone.      */  
/*                                                                      */
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */ 
/* 04-APR-2023  NJOW    1.0   Devops Combine Script                     */
/************************************************************************/    
CREATE   PROC [dbo].[ispPOA24]      
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
            @c_PutawayZone           NVARCHAR(10),
            @c_GetOrderkey           NVARCHAR(10)
                                  
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
      
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue IN(1,2)   
   BEGIN      	
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Orderkey
            FROM ORDERS O (NOLOCK)
            WHERE O.Orderkey = @c_OrderKey
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Orderkey
            FROM LoadPlanDetail LPD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey 
            WHERE LPD.LoadKey = @c_Loadkey
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Orderkey
            FROM WaveDetail WD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
            WHERE WD.Wavekey = @c_Wavekey
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 67060      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA24)'  
         GOTO EXIT_SP      
      END    
   	        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN
         SET @c_PutawayZone = ''
                   
         SELECT @c_PutawayZone = CASE WHEN COUNT(DISTINCT LOC.Putawayzone) > 1 THEN 'MULTIZONE' ELSE MAX(LOC.Putawayzone) END
         FROM ORDERS O (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         WHERE O.Orderkey = @c_Orderkey
         GROUP BY O.Orderkey
                                  
         UPDATE ORDERS WITH (ROWLOCK)
         SET M_vat = @c_Putawayzone
           , TrafficCop   = NULL
           , EditDate     = GETDATE()
           , EditWho      = SUSER_SNAME()
         WHERE OrderKey   = @c_GetOrderkey
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0                                                                                                                                                               
         BEGIN                                                                                                                                                                                  
            SELECT @n_Continue = 3                                                                                                                                                              
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS Failed. (ispPOA24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
         END
                        
         FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
      END  
      CLOSE cur_ORD
      DEALLOCATE cur_ORD    
   END  

EXIT_SP:        

   IF CURSOR_STATUS('LOCAL', 'cur_ORD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORD
      DEALLOCATE cur_ORD   
   END 
   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA24'      
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