SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA11                                           */  
/* Creation Date: 22-FEB-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-12445 CN Porsche post allocation check safety stock     */
/*          and max sku order qty for offline order                     */ 
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
CREATE PROC [dbo].[ispPOA11]    
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
            @c_Busr5                 NVARCHAR(30),
            @c_Busr9                 NVARCHAR(30),
            @n_Safetystock           INT,
            @n_MaxOrderQty           INT,
            @c_Facility              NVARCHAR(5),
            @n_QtyAvailable          INT,
            @n_OpenQty               INT,
            @n_QtyAllocated          INT,
            @n_Casecnt               INT,
            @n_Pallet                INT,            
            @c_Pickdetailkey         NVARCHAR(10),
            @C_Storerkey             NVARCHAR(15),
            @c_Sku                   NVARCHAR(20),
            @n_QtyToReduce           INT,
            @c_UOM                   NVARCHAR(10),
            @n_PickQty               INT,
            @n_UpdateQty             INT,
            @n_UpdateUOMQty          INT,
            @n_QtyCanAllocate        INT           
                                                                           
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
    
   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = '' AND ISNULL(RTRIM(@c_WaveKey),'') = ''
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey & Orderkey & Wavekey are Blank (ispPOA11)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, Storerkey, Facility 
      FROM ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey 
      AND Type <> 'OFFLINE'
   END
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.OrderKey, O.Storerkey, O.Facility 
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
      WHERE LPD.LoadKey = @c_LoadKey      
      AND O.Type <> 'OFFLINE'
      ORDER BY O.Userdefine10, O.Orderkey
   END
   ELSE
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.OrderKey, O.Storerkey, O.Facility  
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      WHERE WD.WaveKey = @c_WaveKey      
      AND O.Type <> 'OFFLINE'
      ORDER BY O.Userdefine10, O.Orderkey
   END
 
   OPEN CUR_ORDERKEY    

   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @c_Storerkey, @c_Facility
     
   WHILE @@FETCH_STATUS <> -1  --loop order
   BEGIN          	
      DECLARE cur_ORDERSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OD.Sku, SKU.Busr5, SKU.Busr9, SUM(OD.OpenQty), SUM(OD.QtyAllocated + OD.QtyPicked),
                PACK.CaseCnt, PACK.Pallet
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE OD.QtyAllocated + OD.QtyPicked > 0
         AND OD.Orderkey = @c_Orderkey
         GROUP BY OD.Sku, SKU.Busr5, SKU.Busr9, PACK.CaseCnt, PACK.Pallet
         
      OPEN cur_ORDERSKU  
         
      FETCH NEXT FROM cur_ORDERSKU INTO @c_Sku, @c_Busr5, @c_Busr9, @n_OpenQty, @n_QtyAllocated, @n_CaseCnt, @n_Pallet
         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 IF ISNUMERIC(@c_Busr5) = 1 
      	    SET @n_SafetyStock = CAST(@c_Busr5 AS INT)
      	 ELSE
      	    SET @n_SafetyStock = 0
      	    
      	 IF ISNUMERIC(@c_Busr9) = 1 
      	    SET @n_MaxOrderQty = CAST(@c_Busr9 AS INT)
      	 ELSE
      	    SET @n_MaxOrderQty = 99999
      	 
      	 --skip if not setup safety stock and max order qty   
      	 IF @n_SafetyStock = 0 AND (@n_MaxOrderQty = 99999 OR @n_MaxOrderQty = 0) 
      	    GOTO NEXT_SKU
      	 
      	 SET @n_QtyAvailable = 0
      	 
      	 SELECT @n_QtyAvailable = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
      	 FROM LOTXLOCXID LLI (NOLOCK)
      	 JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      	 JOIN ID (NOLOCK) ON LLI.ID = ID.Id
      	 JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
      	 WHERE LLI.Storerkey = @c_Storerkey
      	 AND LLI.Sku = @c_Sku
      	 AND LOC.Facility = @c_Facility
      	 AND ID.Status = 'OK'
      	 AND LOT.Status = 'OK'      	
      	 AND LOC.LocationFlag = 'NONE'
      	 AND LOC.Status = 'OK'      	         	          	    
      	 
      	 IF @n_SafetyStock >= (@n_QtyAvailable + @n_QtyAllocated) AND @n_SafetyStock > 0  --Below safety stock
      	    SET @n_QtyCanAllocate = 0
      	 ELSE
      	    SET @n_QtyCanAllocate = (@n_QtyAvailable + @n_QtyAllocated) - @n_SafetyStock 
      	 
      	 IF @n_QtyCanAllocate > 0 AND @n_MaxOrderQty <> 99999 AND @n_MaxOrderQty <> 0
      	 BEGIN
      	    IF @n_QtyCanAllocate >= @n_MaxOrderQty  --more than max order qty
      	       SET @n_QtyCanAllocate = @n_MaxOrderQty
      	    ELSE IF @n_QtyCanAllocate < @n_MaxOrderQty AND @n_QtyCanAllocate < @n_OpenQty  --below max order qty and not sufficient for order qty
      	       SET @n_QtyCanAllocate = 0      	       
      	 END
      	 
      	 --Remove pickdetail for the sku if not allow allocate
      	 IF @n_QtyCanAllocate = 0 AND @n_QtyAllocated > 0
      	 BEGIN
      	    DECLARE cur_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      	       SELECT Pickdetailkey
      	       FROM PICKDETAIL (NOLOCK)
      	       WHERE Orderkey = @c_Orderkey
      	       AND Sku = @c_Sku    
      	       
            OPEN cur_PICK  
               
            FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey
               
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
            BEGIN
            	 DELETE FROM PICKDETAIL 
            	 WHERE Pickdetailkey = @c_Pickdetailkey            

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3    
                  SELECT @n_Err = 63510    
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA11)'
               END            	    
            	
               FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey            	
            END
            CLOSE cur_PICK
            DEALLOCATE cur_PICK      	 	
      	 END
      	 
      	 --Reduce qty allocted from pick if allocated over the qty allowed.
      	 IF @n_QtyCanAllocate > 0 AND @n_QtyCanAllocate < @n_QtyAllocated 
      	 BEGIN
      	 	  SET @n_QtyToReduce = @n_QtyAllocated - @n_QtyCanAllocate

      	    DECLARE cur_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      	       SELECT PD.Pickdetailkey, PD.Qty, PD.UOM
      	       FROM PICKDETAIL PD (NOLOCK)
      	       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      	       WHERE PD.Orderkey = @c_Orderkey
      	       AND PD.Sku = @c_Sku    
      	       ORDER BY PD.UOM, LOC.LogicalLocation DESC, LOC.Loc DESC

            OPEN cur_PICKDET  
               
            FETCH NEXT FROM cur_PICKDET INTO @c_Pickdetailkey, @n_PickQty, @c_UOM
      	 	  
      	 	  WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyToReduce > 0
      	 	  BEGIN
      	 	  	 IF @c_UOM = '1'
      	 	  	 BEGIN
      	 	  	 	  IF @n_QtyToReduce >= @n_PickQty 
      	 	  	 	  BEGIN
            	       DELETE FROM PICKDETAIL 
            	       WHERE Pickdetailkey = @c_Pickdetailkey            
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3    
                        SELECT @n_Err = 63520    
                        SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA11)'
                     END     
                     
                     SET @n_QtyToReduce = @n_QtyToReduce - @n_PickQty
      	 	  	 	  END
      	 	  	 END      	 	  	
      	 	  	 
      	 	  	 IF @c_UOM = '2'
      	 	  	 BEGIN
      	 	  	    IF @n_QtyToReduce >= @n_PickQty 
      	 	  	    BEGIN
            	       DELETE FROM PICKDETAIL 
            	       WHERE Pickdetailkey = @c_Pickdetailkey            
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3    
                        SELECT @n_Err = 63530    
                        SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA11)'
                     END     
                     
                     SET @n_QtyToReduce = @n_QtyToReduce - @n_PickQty      	 	  	    	
      	 	  	    END
      	 	  	    ELSE IF @n_QtyToReduce > @n_CaseCnt
      	 	  	    BEGIN                             	 	  	    	  
      	 	  	    	  SET @n_UpdateQty = FLOOR(@n_QtyToReduce / @n_CaseCnt) * @n_Casecnt
      	 	  	    	  SET @n_UpdateUOMQty = FLOOR(@n_QtyToReduce / @n_CaseCnt)
      	 	  	    	  
      	 	  	    	  UPDATE PICKDETAIL WITH (ROWLOCK)
      	 	  	    	  SET Qty = Qty - @n_UpdateQty,
      	 	  	    	      UOMQty = UOMQty - @n_UpdateUOMQty
      	 	  	    	  WHERE Pickdetailkey = @c_Pickdetailkey

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3    
                        SELECT @n_Err = 63540    
                        SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while Updating pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA11)'
                     END     
                     
                     SET @n_QtyToReduce = @n_QtyToReduce - @n_UpdateQty      	 	  	    	      	 	  	    	  
      	 	  	    END
      	 	  	 END
      	 	  	 
      	 	  	 IF @c_UOM IN ('6','7')
      	 	  	 BEGIN
      	 	  	    IF @n_QtyToReduce >= @n_PickQty 
      	 	  	    BEGIN
            	       DELETE FROM PICKDETAIL 
            	       WHERE Pickdetailkey = @c_Pickdetailkey            
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3    
                        SELECT @n_Err = 63550    
                        SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA11)'
                     END     
                     
                     SET @n_QtyToReduce = @n_QtyToReduce - @n_PickQty      	 	  	    	
      	 	  	    END
      	 	  	    ELSE 
      	 	  	    BEGIN                             	 	  	    	        	 	  	    	  
      	 	  	    	  UPDATE PICKDETAIL WITH (ROWLOCK)
      	 	  	    	  SET Qty = Qty - @n_QtyToReduce,
      	 	  	    	      UOMQty = UOMQty - @n_QtyToReduce
      	 	  	    	  WHERE Pickdetailkey = @c_Pickdetailkey

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3    
                        SELECT @n_Err = 63560    
                        SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while Updating pickdetail table. Pickdetialkey: ' + RTRIM(@c_Pickdetailkey) + ' (ispPOA11)'
                     END     
                     
                     SET @n_QtyToReduce = 0  	    	      	 	  	    	  
      	 	  	    END      	 	  	 	
      	 	  	 END

               FETCH NEXT FROM cur_PICKDET INTO @c_Pickdetailkey, @n_PickQty, @c_UOM
      	 	  END
      	 	  CLOSE cur_PICKDET
      	 	  DEALLOCATE cur_PICKDET      	 	        	 	
      	 END 
      	       	       	       	       	 
      	 NEXT_SKU:
      	 
         FETCH NEXT FROM cur_ORDERSKU INTO @c_Sku, @c_Busr5, @c_Busr9, @n_OpenQty, @n_QtyAllocated, @n_CaseCnt, @n_Pallet   
      END
      CLOSE cur_ORDERSKU
      DEALLOCATE cur_ORDERSKU
   	 
   	  EXEC ispAsgnTNo2  
           @c_OrderKey   = @c_Orderkey
         , @c_LoadKey    = ''  
         , @b_Success    = @b_Success  OUTPUT      
         , @n_Err        = @n_Err      OUTPUT      
         , @c_ErrMsg     = @c_Errmsg   OUTPUT      
   	     	      
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @c_Storerkey, @c_Facility       
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA11'    
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