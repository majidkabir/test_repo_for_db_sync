SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA20                                           */    
/* Creation Date: 01-JUL-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-17393 - CN GBMAX generate get trackingno interface      */  
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
/* 30-Jul-2021  NJOW01  1.0   Fix key to auto running number            */
/************************************************************************/    
CREATE PROC [dbo].[ispPOA20]      
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
      
   DECLARE  @n_Continue      INT,      
            @n_StartTCnt     INT, -- Holds the current transaction count  
            @c_Storerkey     NVARCHAR(15),
            @c_Facility      NVARCHAR(5),
            @c_option1       NVARCHAR(50),
            @c_option2       NVARCHAR(50),
            @c_option3       NVARCHAR(50),
            @c_option4       NVARCHAR(50),
            @c_option5       NVARCHAR(4000),
            @c_authority     NVARCHAR(30),
            @c_Key2          NVARCHAR(10)            
                                                                                        
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
   
   IF @n_Continue IN (1,2)
   BEGIN
   	  IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN   
         SELECT @c_Storerkey = O.StorerKey,
                @c_Facility  = O.Facility
         FROM ORDERS O (NOLOCK)  
         WHERE O.Orderkey = @c_Orderkey
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         SELECT TOP 1 @c_Storerkey = O.StorerKey,
                @c_Facility  = O.Facility
         FROM LoadPlanDetail LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey  
         WHERE LPD.Loadkey = @c_Loadkey  
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         SELECT TOP 1 @c_Storerkey = O.StorerKey,
                @c_Facility  = O.Facility
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.Wavekey = @c_Wavekey  
      END 
      
      SELECT @b_success = 0

      Execute nspGetRight                                
       @c_Facility  = @c_facility,                     
       @c_StorerKey = @c_StorerKey,                    
       @c_sku       = '',                          
       @c_ConfigKey = 'PostAllocationSP',     
       @b_Success   = @b_success   OUTPUT,             
       @c_authority = @c_authority OUTPUT,             
       @n_err       = @n_err       OUTPUT,             
       @c_errmsg    = @c_errmsg    OUTPUT,             
       @c_Option1   = @c_option1   OUTPUT,  --table name        
       @c_Option2   = @c_option2   OUTPUT,             
       @c_Option3   = @c_option3   OUTPUT,               
       @c_Option4   = @c_option4   OUTPUT,               
       @c_Option5   = @c_option5   OUTPUT   
       
       IF ISNULL(@c_Option1,'') = ''
       BEGIN
          SELECT @n_Continue = 3                                                                                                                                                              
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Tablename not Setup at storerconfig.option1 of PostAllocationSP. (ispPOA20)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                    	
       END             
   END                                        
      
   IF @n_continue IN(1,2)   
   BEGIN   
   	BEGIN TRAN
   
      IF ISNULL(@c_OrderKey,'') <> ''
      BEGIN
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey 
         FROM ORDERS O (NOLOCK)
         WHERE O.OrderKey = @c_OrderKey 
         AND O.Status = '2'
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''       
      BEGIN
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey 
         FROM LoadPlanDetail LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey  
         WHERE LPD.Loadkey = @c_Loadkey  
         AND O.Status = '2'         
      END	
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''                
      BEGIN
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.Wavekey = @c_Wavekey        	
         AND O.Status = '2'         
      END       
           
      OPEN CUR_ORDERKEY    
            
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_Orderkey  
            
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN       
      	SET @c_Key2 = ''
      	
      	EXEC dbo.nspg_GetKey                
        @KeyName = 'ispPOA20'    
       ,@fieldlength = 10    
       ,@keystring = @c_Key2 OUTPUT    
       ,@b_Success = @b_success OUTPUT    
       ,@n_err = @n_err OUTPUT    
       ,@c_errmsg = @c_errmsg OUTPUT
       ,@b_resultset = 0    
       ,@n_batch     = 1                  

        EXEC ispGenTransmitLog2                                             
         @c_TableName     = @c_Option1,                                        
         @c_Key1          = @c_Orderkey,                                        
         @c_Key2          = @c_Key2,               
         @c_Key3          = @c_Storerkey,                                        
         @c_TransmitBatch = 'N',                                        
         @b_Success       = @b_Success OUTPUT,                                   
         @n_err           = @n_err     OUTPUT,                                   
         @c_errmsg        = @c_errmsg  OUTPUT  
           
         IF @b_Success <> 1                                                                                                                                                               
         BEGIN                                                                                                                                                                                  
            SELECT @n_Continue = 3                                                                                                                                                              
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Transmitlog2 Failed. (ispPOA20)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
         END  
  
         FETCH NEXT FROM CUR_ORDERKEY INTO @c_Orderkey  
      END
      CLOSE CUR_ORDERKEY
      DEALLOCATE CUR_ORDERKEY    
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA20'      
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