SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPSTALC1                                         */    
/* Creation Date: 05-Dec-2012                                           */    
/* Copyright: IDS                                                       */    
/* Written by: SHONG                                                    */    
/*                                                                      */    
/* Purpose: FBR 263231                                                  */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver  Purposes                                   */    
/*                                                                      */    
/************************************************************************/    
CREATE PROC [dbo].[ispPSTALC1] (   
   @c_LoadKey NVARCHAR(10),  
   @b_Success INT OUTPUT,  
   @n_ErrNo   INT OUTPUT,  
   @c_ErrMsg  NVARCHAR(215) OUTPUT,  
   @b_Debug   INT = 0 )  
AS     
BEGIN  
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
           
   DECLARE @c_StorerKey       NVARCHAR(15)  
          ,@c_SKU             NVARCHAR(20)  
          ,@n_ShortQty        INT  
          ,@n_Continue        INT  
          ,@c_OrderKey        NVARCHAR(10)  
          ,@c_OrderLineNumber NVARCHAR(5)  
          ,@n_QtyToDeduct     INT  
            
          ,@c_FromOrderKey         NVARCHAR(10)  
          ,@c_FromOrderLineNumber  NVARCHAR(5)  
          ,@c_ToOrderKey           NVARCHAR(10)  
          ,@c_ToOrderLineNumber    NVARCHAR(5)  
          ,@c_ToPickDetailKey      NVARCHAR(10)  
            
          ,@n_QtyToAdd             INT  
          ,@n_NoOfOrders           INT  
          ,@n_BatchShort           INT   
          ,@c_FromPickDetKey       NVARCHAR(10)  
          ,@c_LOT                  NVARCHAR(10)  
          ,@c_LOC                  NVARCHAR(10)  
          ,@c_ID                   NVARCHAR(18)  
          ,@n_PickDetQty           INT  
          ,@n_QtyToTake            INT  
          ,@n_StartTCnt            INT  
          ,@n_ExceedQty            INT 
          ,@n_UnitPerLot           INT  
            
  
   SET @n_Continue = 1  
   SET @b_Success = 1  
   SET @n_StartTCnt=@@TRANCOUNT  
  
   BEGIN TRANSACTION   
                         
   IF EXISTS(SELECT 1 FROM ORDERS o WITH (NOLOCK)  
             JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey  
             WHERE lpd.LoadKey = @c_LoadKey  
             AND o.[Status] BETWEEN '3' AND '9')  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 61000  
      SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Order Pick In Progress, Cannot Proceed'  
      GOTO EXIT_SP  
   END            
  
   CREATE TABLE #t_OrderDetail  
      (OrderKey         NVARCHAR(10),  
       OrderLineNumber  NVARCHAR(5),  
       StorerKey        NVARCHAR(15),  
       SKU              NVARCHAR(20),  
       OpenQty          INT,  
       QtyAllocated     INT,  
       AdjustedAllocQty INT)  
       
   DECLARE CUR_ShortQtyAllocation CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT o.StorerKey, o.Sku, QtyShort = SUM(o.OpenQty) - SUM(o.QtyAllocated), 
          CASE WHEN ISNUMERIC(SKU.Busr10) = 1 THEN 
              CONVERT(INT, SKU.Busr10)
          ELSE 1 END              
   FROM ORDERDETAIL o WITH (NOLOCK)  
   JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey   
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = O.OrderKey
   JOIN SKU WITH (NOLOCK) ON o.Storerkey = SKU.Storerkey AND o.Sku = SKU.SKU   
   WHERE lpd.LoadKey = @c_LoadKey    
   AND oh.[Status] < '3'  
   GROUP BY lpd.LoadKey, o.StorerKey, o.Sku,           
            CASE WHEN ISNUMERIC(SKU.Busr10) = 1 THEN 
                 CONVERT(INT, SKU.Busr10)
            ELSE 1 END              
   HAVING (SUM(o.OpenQty) - SUM(o.QtyAllocated)) > 0  AND SUM(o.QtyAllocated) > 0    
  
   OPEN CUR_ShortQtyAllocation  
  
   FETCH NEXT FROM CUR_ShortQtyAllocation INTO @c_StorerKey, @c_SKU, @n_ShortQty, @n_UnitPerLot
   WHILE @@FETCH_STATUS <> -1   
   BEGIN  
   	  IF ISNULL(@n_UnitPerLot,0) = 0
   	     SET @n_UnitPerLot = 1
   	     
      INSERT INTO #t_OrderDetail(OrderKey, OrderLineNumber, StorerKey, SKU, OpenQty,  
                  QtyAllocated, AdjustedAllocQty)  
      SELECT o.OrderKey, o.OrderLineNumber, o.StorerKey, o.Sku, o.OpenQty, o.QtyAllocated, 0   
      FROM ORDERDETAIL o WITH (NOLOCK)  
      JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey   
      JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = O.OrderKey   
      WHERE lpd.LoadKey = @c_LoadKey    
      AND   o.StorerKey = @c_StorerKey  
      AND   o.Sku = @c_SKU   
      AND   oh.[Status] < '3'   
        
      -- If only 1 line, no need to process  
      SELECT @n_NoOfOrders = COUNT(DISTINCT OrderKey) FROM #t_OrderDetail  
      IF (@n_NoOfOrders) = 1  
         SET @n_ShortQty = 0   
        
      IF @b_Debug = 1  
      BEGIN  
         SELECT @n_ShortQty '@n_ShortQty', @n_NoOfOrders '@n_NoOfOrders'  
      END  
      IF FLOOR(@n_ShortQty / @n_UnitPerLot) > @n_NoOfOrders  
      BEGIN  
        SET @n_BatchShort = (@n_ShortQty - ( @n_ShortQty % (@n_NoOfOrders * @n_UnitPerLot) )) / @n_NoOfOrders  
        SET @n_ShortQty =  ( @n_ShortQty % (@n_NoOfOrders * @n_UnitPerLot) )                         
      END  
      ELSE    
         SET @n_BatchShort = 0   
  
      IF @b_Debug = 1  
      BEGIN  
         SELECT @n_ShortQty '@n_ShortQty', @n_NoOfOrders '@n_NoOfOrders', @n_BatchShort '@n_BatchShort', @n_UnitPerLot '@n_UnitPerLot'  
      END  
  
           
      IF @n_BatchShort > 0   
      BEGIN  
         UPDATE #t_OrderDetail   
               SET AdjustedAllocQty = AdjustedAllocQty + @n_BatchShort  
      END     
  
--      IF @b_Debug = 1  
--      BEGIN  
--         SELECT * FROM #t_OrderDetail     
--      END  
  
        
      SET @n_ExceedQty = 0   
        
      SELECT @n_ExceedQty = SUM(AdjustedAllocQty) - SUM(OpenQty)  
      FROM #t_OrderDetail  
      WHERE AdjustedAllocQty > OpenQty  
  
              
      IF @n_ExceedQty > 0   
      BEGIN  
         SET @n_ShortQty = @n_ShortQty + @n_ExceedQty   
      END  
        
      UPDATE #t_OrderDetail   
         SET AdjustedAllocQty = OpenQty  
      WHERE AdjustedAllocQty > OpenQty   
        
  
      WHILE @n_ShortQty > 0   
      BEGIN  
         DECLARE CUR_OrderDetAlloc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT tod.OrderKey, tod.OrderLineNumber  
         FROM #t_OrderDetail tod  
         ORDER BY tod.OpenQty   
           
         OPEN CUR_OrderDetAlloc   
           
         FETCH NEXT FROM CUR_OrderDetAlloc INTO @c_OrderKey, @c_OrderLineNumber   
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF EXISTS(SELECT 1 FROM #t_OrderDetail   
                      WHERE OpenQty > AdjustedAllocQty   
                      AND  (OpenQty - AdjustedAllocQty) >= @n_UnitPerLot
                      AND   OrderKey = @c_OrderKey   
                      AND   OrderLineNumber = @c_OrderLineNumber )  
            BEGIN  
               UPDATE #t_OrderDetail   
                  SET AdjustedAllocQty = AdjustedAllocQty + @n_UnitPerLot   
               WHERE OrderKey = @c_OrderKey   
               AND   OrderLineNumber = @c_OrderLineNumber  
                 
               SET @n_ShortQty = @n_ShortQty - @n_UnitPerLot                 
            END  
              
            IF @n_ShortQty = 0   
               BREAK  
                  
            FETCH NEXT FROM CUR_OrderDetAlloc INTO @c_OrderKey, @c_OrderLineNumber   
         END  
         CLOSE CUR_OrderDetAlloc  
         DEALLOCATE CUR_OrderDetAlloc  
      END -- WHILE @n_ShortQty > 0   
  
      IF @b_Debug = 1  
      BEGIN  
         SELECT * FROM #t_OrderDetail     
      END  
           
      WHILE 1=1  
      BEGIN  
         SET @c_FromOrderKey = ''  
         SET @c_FromOrderLineNumber = ''  
         SET @n_QtyToDeduct = 0   
           
         -- Take 1st line With Extra Qty   
         SELECT TOP 1   
            @c_FromOrderKey        = OrderKey,   
            @c_FromOrderLineNumber = OrderLineNumber,  
            @n_QtyToDeduct         = QtyAllocated - (OpenQty - AdjustedAllocQty)  
         FROM #t_OrderDetail   
         WHERE QtyAllocated > (OpenQty - AdjustedAllocQty)    
         AND QtyAllocated > 0   
         IF @@ROWCOUNT = 0  
            BREAK   
  
         IF @b_Debug = 1  
         BEGIN  
            SELECT @c_FromOrderKey '@c_FromOrderKey', @c_FromOrderLineNumber '@c_FromOrderLineNumber', @n_QtyToDeduct '@n_QtyToDeduct'  
         END        
           
         SET @c_ToOrderKey = ''  
         SET @c_ToOrderLineNumber = ''  
         SET @n_QtyToAdd = 0   
           
         -- Select Order Line that Required Qty = Extra Qty  
         SELECT TOP 1   
            @c_ToOrderKey        = OrderKey,   
            @c_ToOrderLineNumber = OrderLineNumber,  
            @n_QtyToAdd          = (OpenQty - AdjustedAllocQty) - QtyAllocated  
         FROM #t_OrderDetail   
         WHERE (OpenQty - AdjustedAllocQty) > QtyAllocated   
         AND   QtyAllocated - (OpenQty - AdjustedAllocQty) = @n_QtyToDeduct   
         AND   OrderKey <> @c_FromOrderKey   
         IF @@ROWCOUNT = 0  
         BEGIN  
            SELECT TOP 1   
               @c_ToOrderKey        = OrderKey,   
               @c_ToOrderLineNumber = OrderLineNumber,  
               @n_QtyToAdd          = (OpenQty - AdjustedAllocQty) - QtyAllocated  
            FROM #t_OrderDetail   
            WHERE (OpenQty - AdjustedAllocQty) > QtyAllocated   
            AND   OrderKey <> @c_FromOrderKey                                   
         END             
         IF @@ROWCOUNT = 0  
            BREAK  
              
         IF @b_Debug = 1  
         BEGIN  
            SELECT @c_ToOrderKey '@c_ToOrderKey', @c_ToOrderLineNumber '@c_ToOrderLineNumber', @n_QtyToAdd '@n_QtyToAdd'  
         END     
           
         -- Update PICKDETAIL Here  
         DECLARE CUR_FROM_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT p.PickDetailKey, p.Lot, p.LOC, P.ID, p.Qty   
         FROM PICKDETAIL p WITH (NOLOCK)  
         WHERE p.OrderKey = @c_FromOrderKey   
         AND   p.OrderLineNumber = @c_FromOrderLineNumber  
           
         OPEN CUR_FROM_PICKDETAIL  
         FETCH NEXT FROM CUR_FROM_PICKDETAIL INTO @c_FromPickDetKey, @c_LOT, @c_LOC, @c_ID, @n_PickDetQty  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
              
            IF @n_QtyToDeduct >= @n_PickDetQty    
            BEGIN  
               SET @n_QtyToTake = @n_PickDetQty  
                 
               UPDATE PICKDETAIL   
                  SET OrderKey = @c_ToOrderKey, OrderLineNumber = @c_ToOrderLineNumber  
               WHERE PickDetailKey = @c_FromPickDetKey  
               IF @@ERROR<> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_ErrNo = 61002  
                  SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update PickDetail Failed'  
                  GOTO EXIT_SP                    
               END    
                 
               UPDATE #t_OrderDetail  
               SET QtyAllocated = QtyAllocated - @n_QtyToTake  
               WHERE OrderKey = @c_FromOrderKey  
               AND OrderLineNumber = @c_FromOrderLineNumber  
                 
               UPDATE #t_OrderDetail  
               SET QtyAllocated = QtyAllocated + @n_QtyToTake  
               WHERE OrderKey = @c_ToOrderKey  
               AND OrderLineNumber = @c_ToOrderLineNumber  
                 
               SET @n_QtyToDeduct = @n_QtyToDeduct - @n_QtyToTake                  
                 
               GOTO PROCESS_NEXT   
            END  
            ELSE
            BEGIN     
               SET @n_QtyToTake = @n_QtyToDeduct  
  
               SET @c_ToPickDetailKey = ''  
               SELECT TOP 1   
                    @c_ToPickDetailKey = p.PickDetailKey   
               FROM PICKDETAIL p WITH (NOLOCK)  
               WHERE p.OrderKey = @c_ToOrderKey  
               AND   p.OrderLineNumber = @c_ToOrderLineNumber  
               AND   p.Lot = @c_LOT   
               AND   p.Loc = @c_LOC  
               AND   p.ID  = @c_ID  
                 
               IF ISNULL(RTRIM(@c_ToPickDetailKey), '') <> ''  
               BEGIN  
                  UPDATE PICKDETAIL   
          SET Qty = Qty - @n_QtyToTake,   
                         TrafficCop = NULL,  
                         EditDate = GETDATE()       
                  WHERE PickDetailKey = @c_FromPickDetKey  
                  IF @@ERROR<> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_ErrNo = 61003  
                     SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update PickDetail Failed'  
                     GOTO EXIT_SP                    
                  END    
  
                  UPDATE PICKDETAIL   
                     SET Qty = Qty + @n_QtyToTake,  
                         TrafficCop = NULL,                       
                         EditDate = GETDATE()                        
                  WHERE PickDetailKey = @c_ToPickDetailKey       
                  IF @@ERROR<> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_ErrNo = 61004  
                     SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update PickDetail Failed'  
                     GOTO EXIT_SP                    
                  END    
                    
               END -- IF ISNULL(RTRIM(@c_ToPickDetailKey), '') <> ''  
               ELSE  
               BEGIN  
            
                  EXECUTE dbo.nspg_GetKey    
                     'PICKDETAILKEY',     
                     10 ,    
                     @c_ToPickDetailKey OUTPUT,    
                     @b_success         OUTPUT,    
                     @n_ErrNo           OUTPUT,    
                     @c_ErrMsg          OUTPUT    
                  IF @b_success <> 1    
                  BEGIN    
                     SET @n_ErrNo = 61005    
                     SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+' Generate PickDetailKey Failed'  
                     GOTO EXIT_SP    
                  END    
                             
                  INSERT INTO dbo.PICKDETAIL (    
                              CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,     
                              UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,     
                              ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                              EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,     
                              PickDetailKey,     
                              QTY,     
                              TrafficCop,    
                              OptimizeCop)    
                           SELECT     
                              CaseID, PickHeaderKey, @c_ToOrderKey, @c_ToOrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,     
                              @n_QtyToTake, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,     
                              CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                              EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,     
                              @c_ToPickDetailKey,     
                              @n_QtyToTake, -- QTY    
                              NULL,   
                              '1'  --OptimizeCop    
                           FROM dbo.PickDetail WITH (NOLOCK)     
                     WHERE PickDetailKey = @c_FromPickDetKey   
                  IF @@ERROR<> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_ErrNo = 61005  
                     SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Insert PickDetail Failed'  
                     GOTO EXIT_SP                    
                  END                         
                       
                  UPDATE PICKDETAIL   
                     SET Qty = Qty - @n_QtyToTake,   
                         TrafficCop = NULL,  
                         EditDate = GETDATE()       
                  WHERE PickDetailKey = @c_FromPickDetKey                      IF @@ERROR<> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_ErrNo = 61006  
                     SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update PickDetail Failed'  
                     GOTO EXIT_SP                    
                  END                                                                       
               END -- IF ISNULL(RTRIM(@c_ToPickDetailKey), '') = ''  
                 
               UPDATE ORDERDETAIL   
                  SET QtyAllocated = QtyAllocated - @n_QtyToTake,    
                      [Status]     = CASE WHEN (QtyAllocated - @n_QtyToTake) = 0 THEN '0'    
                                          WHEN (OpenQty) = (QtyPicked + (QtyAllocated - @n_QtyToTake))    
                                             THEN '2'    
                                          ELSE '1'    
                                     END,    
                      EditDate = GETDATE(),    
                      TrafficCop   = NULL    
               WHERE OrderKey = @c_FromOrderKey  
               AND   OrderLineNumber = @c_FromOrderLineNumber           
               IF @@ERROR<> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_ErrNo = 61006  
                  SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update PickDetail Failed'  
                  GOTO EXIT_SP                    
               END    
                 
               UPDATE ORDERDETAIL   
                  SET QtyAllocated = QtyAllocated + @n_QtyToTake,    
                      [Status]     = CASE WHEN (QtyAllocated -+ @n_QtyToTake) = 0 THEN '0'    
                                          WHEN (OpenQty + (@n_QtyToTake)) =    
                                               (QtyPicked + (QtyAllocated + @n_QtyToTake))    
                                          THEN '2'    
                                          ELSE '1'    
                                     END,    
                      EditDate = GETDATE(),    
                      TrafficCop   = NULL    
               WHERE OrderKey = @c_ToOrderKey  
               AND   OrderLineNumber = @c_ToOrderLineNumber                                      
               IF @@ERROR<> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_ErrNo = 61007  
                  SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update PickDetail Failed'  
                  GOTO EXIT_SP                    
               END    
                 
               UPDATE ORDERS   
               SET STATUS = [Status]  
               WHERE OrderKey IN (@c_FromOrderKey, @c_ToOrderKey)  
               IF @@ERROR<> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_ErrNo = 61008  
                  SET @c_ErrMsg = 'NSQL'+CONVERT(NVARChar(5),@n_ErrNo)+ ' Update Orders Failed'  
                  GOTO EXIT_SP                    
               END                   
                 
               UPDATE #t_OrderDetail  
               SET QtyAllocated = QtyAllocated - @n_QtyToTake  
               WHERE OrderKey = @c_FromOrderKey  
               AND OrderLineNumber = @c_FromOrderLineNumber  
                 
               UPDATE #t_OrderDetail  
               SET QtyAllocated = QtyAllocated + @n_QtyToTake  
               WHERE OrderKey = @c_ToOrderKey  
               AND OrderLineNumber = @c_ToOrderLineNumber  
                                   
               SET @n_QtyToDeduct = @n_QtyToDeduct - @n_QtyToTake                   
            END  
              
            PROCESS_NEXT:  
            IF @n_QtyToDeduct = 0   
               BREAK  
                     
            FETCH NEXT FROM CUR_FROM_PICKDETAIL INTO @c_FromPickDetKey, @c_LOT, @c_LOC, @c_ID, @n_PickDetQty  
         END         
         CLOSE CUR_FROM_PICKDETAIL  
         DEALLOCATE CUR_FROM_PICKDETAIL    
           
      END          
       
      TRUNCATE TABLE #t_OrderDetail  
        
      FETCH NEXT FROM CUR_ShortQtyAllocation INTO @c_StorerKey, @c_SKU, @n_ShortQty, @n_UnitPerLot  
   END  
   CLOSE CUR_ShortQtyAllocation  
   DEALLOCATE CUR_ShortQtyAllocation  
      
  
   EXIT_SP:  
   IF @n_Continue = 1 or @n_Continue = 2    
   BEGIN    
      COMMIT TRAN    
   END    
   ELSE    
   BEGIN  
      SET @b_Success = 0          
      ROLLBACK TRAN    
   END      
END -- Procedure  


GO