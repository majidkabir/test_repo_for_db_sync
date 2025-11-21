SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPOPVH02                                         */    
/* Creation Date: 09-OCT-2018                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-6244 PVH HK Casectn by id. (For HK only)                */
/*          Original Ticket:                                            */
/*          WMS-2819 CN PVH Post wave conso allocation for retail launch*/
/*          only to change full case(uom2) with multiple orders to conso*/
/*          carton (uom6) in order for release task pick to PTL.        */
/*          Set to storerconfig PostProcessingStrategyKey               */ 
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/    
CREATE PROC [dbo].[ispPOPVH02]        
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
      @c_NewPickDetailKey NVARCHAR(18)
  
   SELECT @n_continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = '',@n_StartTCnt = @@TRANCOUNT       
    
   IF NOT EXISTS (SELECT 1
                  FROM ORDERS O (NOLOCK)
                  JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ORDERGROUP' AND O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey
                  WHERE O.Userdefine09 = @c_Wavekey
                  AND CL.Short = '2') --if not retail new launch
      GOTO QUIT
   
   --Conso wave allocated full conso carton with multiple orders(different load) change from uom2 to uom6. a full order carton can conso by load (consignee + brand per load)   
   DECLARE CURSOR_PICKDETAILS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Loadkey, 
            SUM(PD.Qty) % LLI.Qty --try to combine full conso carton by load and find partial carton qty. Which mean the qty is conso with other load
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK)ON SKU.Packkey = PACK.Packkey
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      WHERE WD.Wavekey = @c_Wavekey
      AND PD.UOM = '2' 
      --AND PACK.Casecnt > 0
      GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Loadkey, LLI.Qty--, PACK.CaseCnt
      HAVING SUM(PD.Qty) % LLI.Qty <> 0
   
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
                               ': Update PickDetail Failed. (ispPOPVH02)'
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
                               ': Insert PickDetail Failed. (ispPOPVH02)'
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
                               ': Update PickDetail Failed. (ispPOPVH02)'
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOPVH02'  
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