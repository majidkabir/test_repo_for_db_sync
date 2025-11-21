SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPRALC05                                         */  
/* Creation Date: 22-Jun-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  WMS-17326 - CN Nike Preallocation update lottable01 as     */
/*                       hostwhcode.                                    */
/*           Set the sp to storerconfig PreAllocationSP                 */
/*                                                                      */  
/* Called By: ispPreAllocationWrapper                                   */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispPRALC05] (
     @c_OrderKey        NVARCHAR(10)  
   , @c_LoadKey         NVARCHAR(10)    
   , @c_WaveKey         NVARCHAR(10)  
   , @b_Success         INT           OUTPUT    
   , @n_Err             INT           OUTPUT    
   , @c_ErrMsg          NVARCHAR(250) OUTPUT    
   , @b_debug           INT = 0 )
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue    INT,  
           @n_StartTCnt   INT,
           @B_Company     NVARCHAR(30),
           @c_Lottable01  NVARCHAR(18)

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   DECLARE @c_OrderLineNumber        NVARCHAR(5)

   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
   	  IF NOT EXISTS(SELECT 1 
   	                FROM ORDERS O (NOLOCK)
   	                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   	                WHERE O.Orderkey = @c_Orderkey
   	                AND ((O.b_company = '3940' AND OD.Lottable01 = '')
   	                      OR
   	                     (O.b_company <> '3940' AND OD.Lottable01 = '001')
   	                     )  
   	               )    
   	  BEGIN
   	  	 RETURN  --auto allocation
   	  END                         
   	     	  
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey, O.b_company
         FROM ORDERS O (NOLOCK)
         WHERE O.OrderKey = @c_OrderKey 
         --AND O.b_company = '3940'        
   END
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey, O.b_company 
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         WHERE LPD.LoadKey = @c_LoadKey     
         --AND O.b_company = '3940'
   END
   ELSE
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey, O.b_company 
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         WHERE WD.WaveKey = @c_WaveKey
         --AND O.b_company = '3940'            
   END          
          
   OPEN CUR_ORDERKEY    

   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @b_company
     
   WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2) --loop order
   BEGIN          	
   	  DECLARE CUR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT OD.OrderLineNumber, OD.Lottable01
   	     FROM ORDERDETAIL OD (NOLOCK)
   	     WHERE OD.Orderkey = @c_Orderkey
   	     AND (OD.Lottable01 = '' OR OD.Lottable01 = '001')
   	     ORDER BY OD.OrderLineNumber

      OPEN CUR_ORDERDET    
      
      FETCH NEXT FROM CUR_ORDERDET INTO @c_OrderLinenumber, @c_Lottable01
        
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) --loop order detail
      BEGIN       
      	 IF ISNULL(@b_company,'') = '3940' 
      	 BEGIN
      	 	  IF ISNULL(@c_Lottable01,'') = ''
      	 	  BEGIN
      	       UPDATE ORDERDETAIL WITH (ROWLOCK)
      	       SET Lottable01 = '001',
      	           TrafficCop = NULL
      	       WHERE Orderkey = @c_Orderkey
      	       AND OrderLineNumber = @c_OrderLineNumber
      	    END
      	 END
      	 ELSE IF ISNULL(@c_Lottable01,'') = '001'
      	 BEGIN
      	    UPDATE ORDERDETAIL WITH (ROWLOCK)
      	    SET Lottable01 = '',
      	        TrafficCop = NULL
      	    WHERE Orderkey = @c_Orderkey
      	    AND OrderLineNumber = @c_OrderLineNumber
      	 END
      	      	
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63500    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error update ORDERDETAIL table. (ispPRALC05)'
         END

         FETCH NEXT FROM CUR_ORDERDET INTO @c_OrderLinenumber, @c_Lottable01
   	  END   
   	  CLOSE CUR_ORDERDET
   	  DEALLOCATE CUR_ORDERDET
   	        
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @b_company       
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRALC05'  
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
END    

GO