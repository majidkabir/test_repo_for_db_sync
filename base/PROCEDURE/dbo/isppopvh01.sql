SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/    
/* Stored Procedure: ispPOPVH01                                           */    
/* Creation Date: 28-SEP-2017                                             */    
/* Copyright: LFL                                                         */    
/* Written by:                                                            */    
/*                                                                        */    
/* Purpose: WMS-2819 CN PVH Post wave conso allocation for retail launch  */
/*          only to change full case(uom2) with multiple orders to conso  */
/*          carton (uom6) in order for release task pick to PTL.          */
/*          Set to storerconfig PostProcessingStrategyKey                 */ 
/*                                                                        */    
/* Called By:                                                             */    
/*                                                                        */    
/* PVCS Version: 1.0                                                      */    
/*                                                                        */    
/* Version: 1.0                                                           */    
/*                                                                        */    
/* Data Modifications:                                                    */    
/*                                                                        */    
/* Updates:                                                               */    
/* Date         Author    Ver.  Purposes                                  */
/* 11-Nov-2020  NJOW01    1.0   WMS-15565 Add condition only wholesales or*/
/*                              retail with wavetype 'PTS' and non TRF    */
/*                              to proceed                                */
/**************************************************************************/    
CREATE PROC [dbo].[ispPOPVH01]        
    @c_WaveKey                      NVARCHAR(10)
  , @c_UOM                          NVARCHAR(10)
  , @c_LocationTypeOverride         NVARCHAR(10)
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)
  , @b_Success                      INT           OUTPUT  
  , @n_Err                          INT           OUTPUT  
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT  
  , @b_Debug                        INT = 0
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE  
      @n_Continue    INT,  
      @n_StartTCnt   INT,
      @c_Storerkey   NVARCHAR(15), 
      @c_Sku         NVARCHAR(20), 
      @c_Lot         NVARCHAR(10), 
      @c_Loc         NVARCHAR(10), 
      @c_ID          NVARCHAR(18), 
      @c_Loadkey     NVARCHAR(10),
      @n_Qty         INT,
      @n_PickQty     INT,
      @c_PickDetailKey    NVARCHAR(18),
      @c_NewPickDetailKey NVARCHAR(18),
      @c_OrdType          NVARCHAR(10),  --1=Wholesales,ECOM Multi-order 2=Retail, new launch, replenishment, ecom single
      @c_SalesMan         NVARCHAR(30),
      @c_WaveType         NVARCHAR(18),
      @c_Orderkey         NVARCHAR(10)

   SELECT @n_continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = '',@n_StartTCnt = @@TRANCOUNT       
   
   SELECT TOP 1 @c_ordtype = CL.Short,
                @c_WaveType = W.WaveType,
                @c_SalesMan = O.Salesman          
   FROM WAVE W (NOLOCK)
   JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
   JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ORDERGROUP' AND O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey
   WHERE W.Wavekey = @c_Wavekey
    
   IF NOT(@c_ordtype IN('1','2') AND @c_WaveType = 'PTS' AND @c_Salesman <> 'TRF')
      GOTO QUIT
    
   /*IF NOT EXISTS (SELECT 1
                  FROM WAVE W (NOLOCK)
                  JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
                  JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ORDERGROUP' AND O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey
                  WHERE W.Wavekey = @c_Wavekey
                  AND CL.Short IN('1','2') --NJOW01
                  AND W.WaveType = 'PTS'  --NJOW01
                  AND ISNULL(O.Salesman,'') <> 'TRF'   --NJOW01
                  ) --if not wholdsales or retail with PTS
      GOTO QUIT
   */   
   
   IF @c_ordtype = '1'  --NJOW01
   BEGIN
      --Conso wave allocated full conso carton with multiple orders change from uom2 to uom6. a full carton is by order.   
      DECLARE CURSOR_PICKDETAILS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Orderkey, 
               SUM(PD.Qty) % CAST(PACK.Casecnt AS INT) --try to combine full conso carton by wave and find partial carton qty. Which mean the qty is conso with other order
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN PACK (NOLOCK)ON SKU.Packkey = PACK.Packkey
         WHERE WD.Wavekey = @c_Wavekey
         AND PD.UOM = '2' 
         AND PACK.Casecnt > 0
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Orderkey, PACK.CaseCnt
         HAVING SUM(PD.Qty) % CAST(PACK.Casecnt AS INT) <> 0
      
      OPEN CURSOR_PICKDETAILS
      
      FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_Orderkey, @n_Qty
             
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN         
         --find the pickdetail of the order and update from uom 2 to uom 6 as conso carton (full carton with multiple orders)
         DECLARE CURSOR_PICKDETCONSO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 	 
            SELECT PD.Pickdetailkey, PD.Qty
            FROM PICKDETAIL PD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
            WHERE PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND PD.Lot = @c_Lot
            AND PD.Loc = @c_Loc
            AND PD.Id = @c_ID
            AND O.Orderkey = @c_Orderkey
            AND PD.UOM = '2'
            ORDER BY PD.Qty
         
         OPEN CURSOR_PICKDETCONSO
       
         FETCH NEXT FROM CURSOR_PICKDETCONSO INTO @c_Pickdetailkey, @n_PickQty
         
         WHILE (@@FETCH_STATUS <> -1) AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN
         	
         	 IF @n_Qty >= @n_PickQty          
         	 BEGIN
      	        UPDATE PICKDETAIL WITH (ROWLOCK) 
      	        SET UOM = '6',
      	            Trafficcop = NULL
      	        WHERE Pickdetailkey = @c_Pickdetailkey
               
               SET @n_Err = @@ERROR
               
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 13010
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (ispPOPVH01)'
               END
               
               SET @n_Qty = @n_Qty - @n_PickQty
            END
            ELSE
            BEGIN            
               EXECUTE nspg_GetKey      
                  'PICKDETAILKEY',      
                  10,      
                  @c_NewPickdetailKey OUTPUT,         
                  @b_success OUTPUT,      
                  @n_err OUTPUT,      
                  @c_errmsg OUTPUT      
             
               IF NOT @b_success = 1      
               BEGIN
                  SELECT @n_continue = 3      
               END                  
               
               INSERT INTO PICKDETAIL (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                       TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
                               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                                      Storerkey, Sku, AltSku, '6', @n_Qty , @n_Qty, QtyMoved, Status,       
                                      '''', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey                                                           
                               FROM PICKDETAIL (NOLOCK)                                                                                             
                               WHERE PickdetailKey = @c_PickdetailKey                     
               
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 13020
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Insert PickDetail Failed. (ispPOPVH01)'
               END
               
               UPDATE PICKDETAIL WITH (ROWLOCK) 
               SET Qty =  Qty - @n_Qty,
               TrafficCop = NULL,
               Editdate = getdate(),
               UOMQTY = @n_PickQty - @n_Qty          
               WHERE Pickdetailkey = @c_PickdetailKey
      
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 13030
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (ispPOPVH01)'
               END
               
               SET @n_Qty = 0                                  
            END
                  	
            FETCH NEXT FROM CURSOR_PICKDETCONSO INTO @c_Pickdetailkey, @n_PickQty
         END
         CLOSE CURSOR_PICKDETCONSO
         DEALLOCATE CURSOR_PICKDETCONSO
                     	       	  
         FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_Orderkey, @n_Qty	
      END
      CLOSE CURSOR_PICKDETAILS
      DEALLOCATE CURSOR_PICKDETAILS
   END
   
   IF @c_ordtype = '2'
   BEGIN
      --Conso wave allocated full conso carton with multiple orders(different load) change from uom2 to uom6. a full order carton can conso by load (consignee + brand per load)   
      DECLARE CURSOR_PICKDETAILS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Loadkey, 
               SUM(PD.Qty) % CAST(PACK.Casecnt AS INT) --try to combine full conso carton by wave and find partial carton qty. Which mean the qty is conso with other load
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN PACK (NOLOCK)ON SKU.Packkey = PACK.Packkey
         WHERE WD.Wavekey = @c_Wavekey
         AND PD.UOM = '2' 
         AND PACK.Casecnt > 0
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Loadkey, PACK.CaseCnt
         HAVING SUM(PD.Qty) % CAST(PACK.Casecnt AS INT) <> 0
      
      OPEN CURSOR_PICKDETAILS
      
      FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_Loadkey, @n_Qty
             
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
         
         --find the pickdetail of the load and update from uom 2 to uom 6 as conso carton (full carton with multiple orders from different load (consignee+brand)
         DECLARE CURSOR_PICKDETCONSO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 	 
            SELECT PD.Pickdetailkey, PD.Qty
            FROM PICKDETAIL PD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
            WHERE PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND PD.Lot = @c_Lot
            AND PD.Loc = @c_Loc
            AND PD.Id = @c_ID
            AND O.Loadkey = @c_Loadkey
            AND PD.UOM = '2'
            ORDER BY PD.Qty
         
         OPEN CURSOR_PICKDETCONSO
       
         FETCH NEXT FROM CURSOR_PICKDETCONSO INTO @c_Pickdetailkey, @n_PickQty
         
         WHILE (@@FETCH_STATUS <> -1) AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN
         	
         	 IF @n_Qty >= @n_PickQty          
         	 BEGIN
      	        UPDATE PICKDETAIL WITH (ROWLOCK) 
      	        SET UOM = '6',
      	            Trafficcop = NULL
      	        WHERE Pickdetailkey = @c_Pickdetailkey
               
               SET @n_Err = @@ERROR
               
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 13010
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (ispPOPVH01)'
               END
               
               SET @n_Qty = @n_Qty - @n_PickQty
            END
            ELSE
            BEGIN            
               EXECUTE nspg_GetKey      
                  'PICKDETAILKEY',      
                  10,      
                  @c_NewPickdetailKey OUTPUT,         
                  @b_success OUTPUT,      
                  @n_err OUTPUT,      
                  @c_errmsg OUTPUT      
             
               IF NOT @b_success = 1      
               BEGIN
                  SELECT @n_continue = 3      
               END                  
               
               INSERT INTO PICKDETAIL (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                       TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
                               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                                      Storerkey, Sku, AltSku, '6', @n_Qty , @n_Qty, QtyMoved, Status,       
                                      '''', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey                                                           
                               FROM PICKDETAIL (NOLOCK)                                                                                             
                               WHERE PickdetailKey = @c_PickdetailKey                     
               
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 13020
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Insert PickDetail Failed. (ispPOPVH01)'
               END
               
               UPDATE PICKDETAIL WITH (ROWLOCK) 
               SET Qty =  Qty - @n_Qty,
               TrafficCop = NULL,
               Editdate = getdate(),
               UOMQTY = @n_PickQty - @n_Qty          
               WHERE Pickdetailkey = @c_PickdetailKey
      
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 13030
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (ispPOPVH01)'
               END
               
               SET @n_Qty = 0                                  
            END
                  	
            FETCH NEXT FROM CURSOR_PICKDETCONSO INTO @c_Pickdetailkey, @n_PickQty
         END
         CLOSE CURSOR_PICKDETCONSO
         DEALLOCATE CURSOR_PICKDETCONSO
                     	       	  
         FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_Loadkey, @n_Qty	
      END
      CLOSE CURSOR_PICKDETAILS
      DEALLOCATE CURSOR_PICKDETAILS
   END
    
QUIT:

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOPVH01'  
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