SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA10                                           */  
/* Creation Date: 22-FEB-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-9194 TH YVES post allocation update set sku allocted qty*/
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
CREATE PROC [dbo].[ispPOA10]    
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
    
   DECLARE  @n_Continue              INT,    
            @n_StartTCnt             INT, -- Holds the current transaction count
            @c_Pickdetailkey         NVARCHAR(10),
            @c_Sku                   NVARCHAR(20),
            @c_Userdefine02          NVARCHAR(20), 
            @n_MinQtyAllocated       INT,
            @n_skuQtyAllocated       INT,
            @n_QtyToReduce           INT,
            @n_PickQty               INT            
                                                                           
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
    
   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = '' AND ISNULL(RTRIM(@c_WaveKey),'') = ''
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey & Orderkey & Wavekey are Blank (ispPOA10)'
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
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM LoadplanDetail (NOLOCK)
      WHERE LoadKey = @c_LoadKey      
   END
   ELSE
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM WaveDetail (NOLOCK)
      WHERE WaveKey = @c_WaveKey      
   END
 
   OPEN CUR_ORDERKEY    

   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey
     
   WHILE @@FETCH_STATUS <> -1  --loop order
   BEGIN          	
   	  --Get the min qty of the sku set
      DECLARE cur_ORDERSET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT SKUSET.Userdefine02, MIN(SKUSET.QtyAllocated)    	  
   	     FROM (
   	        SELECT Sku, Userdefine02, SUM(QtyAllocated + QtyPicked) AS QtyAllocated
   	        FROM ORDERDETAIL (NOLOCK)
   	        WHERE Orderkey = @c_Orderkey
   	        AND Userdefine02 <> '' 
   	        AND userdefine02 IS NOT NULL
   	        GROUP BY Sku, Userdefine02) AS SKUSET
   	     GROUP BY SKUSET.Userdefine02   
   	     
      OPEN cur_ORDERSET  
         
      FETCH NEXT FROM cur_ORDERSET INTO @c_Userdefine02, @n_MinQtyAllocated     
         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 --Get the sku allocated qty which is more than min qty of the sku set
         DECLARE cur_SKUSET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Sku, SUM(QtyAllocated + QtyPicked) AS SkuQtyAllocated 
            FROM ORDERDETAIL (NOLOCK)
            WHERE Orderkey = @c_Orderkey
            AND Userdefine02 = @c_Userdefine02
            GROUP BY Sku
            HAVING SUM(QtyAllocated + QtyPicked) > @n_MinQtyallocated OR SUM(QtyAllocated + QtyPicked) < 5 

         OPEN cur_SKUSET  
         
         FETCH NEXT FROM cur_SKUSET INTO @c_Sku, @n_skuQtyAllocated              
          
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN            
         	  IF @n_MinQtyAllocated < 5  --if less than 5 qty unallocate the sku set
         	    SET @n_QtyToReduce = @n_skuQtyAllocated
         	  ELSE
              SET @n_QtyToReduce = @n_skuQtyAllocated - @n_MinQtyAllocated
            
            --Get the pick detail of the sku with qtyallocated more than min qty of the sku set
            DECLARE cur_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.Pickdetailkey, PD.Qty
               FROM ORDERDETAIL OD (NOLOCK)
               JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber               
               WHERE OD.Orderkey = @c_Orderkey
               AND OD.Sku = @c_Sku
               AND OD.Userdefine02 = @c_Userdefine02
               ORDER BY OD.OrderLineNumber
            
            OPEN cur_PICKDET  
            
            FETCH NEXT FROM cur_PICKDET INTO @c_Pickdetailkey, @n_PickQty              
             
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyToReduce > 0
            BEGIN
            	 --reduce the qty of the sku to be same as min qty of the sku set
            	 
            	 IF @n_PickQty <= @n_QtyToReduce
            	 BEGIN
            	    DELETE FROM PICKDETAIL WHERE Pickdetailkey = @c_Pickdetailkey

                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3    
                     SELECT @n_Err = 63500    
                     SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA10)'
                  END            	    
            	    
            	    SET @n_QtyToReduce = @n_QtyToReduce - @n_PickQty
            	 END 
            	 ELSE
            	 BEGIN
            	 	  UPDATE PICKDETAIL
            	 	  SET Qty = Qty - @n_QtyToReduce
            	 	  WHERE Pickdetailkey = @c_PIckdetailkey      
            	 	  
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3    
                     SELECT @n_Err = 63510    
                     SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while updating pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA10)'
                  END
            	 	  
            	    SET @n_QtyToReduce = 0
            	 END
            	             	             
               FETCH NEXT FROM cur_PICKDET INTO @c_Pickdetailkey, @n_PickQty              
            END
            CLOSE cur_PICKDET
            DEALLOCATE cur_PICKDET            
            
            FETCH NEXT FROM cur_SKUSET INTO @c_Sku, @n_skuQtyAllocated                       	
         END         
         CLOSE cur_SKUSET
         DEALLOCATE cur_SKUSET            
      	 
         FETCH NEXT FROM cur_ORDERSET INTO @c_Userdefine02, @n_MinQtyAllocated     
      END 
      CLOSE cur_ORDERSET
      DEALLOCATE cur_ORDERSET   	        	     
   	     	      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA10'    
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