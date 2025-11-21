SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* SP: ispGenTransferFacilityOrders                                     */  
/* Creation Date: 28.Aug.2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Create Shipment Orders for Warehouse Transfer               */  
/*                                                                      */  
/* Usage: Use For Warehouse transfering                                 */  
/*                                                                      */  
/* Called By: Brio Report                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */   
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */ 
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */ 
/************************************************************************/    
CREATE PROC [dbo].[ispGenTransferFacilityOrders]   
(  
   @c_StorerKey          NVARCHAR(15),  
   @c_Facility           NVARCHAR(5),  
   @c_LocAisle           NVARCHAR(10) = '',  
   @n_LocCount           INT = 0,  
   @c_ParmLocationFlag   NVARCHAR(10) = '-',  
   @c_ParmLottable02     NVARCHAR(18) = '-',  
   @c_ParmLottable03     NVARCHAR(18) = '-'  
)  
AS   
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 
     
   DECLARE @c_SKU             NVARCHAR(20),  
           @c_Loc             NVARCHAR(10),  
           @c_LocationType    NVARCHAR(10),  
           @c_ExternOrderKey  NVARCHAR(50),    --tlting_ext
           @n_OrderCnt        INT,   
           @c_Orderkey        NVARCHAR(10),  
           @b_Success         INT,  
           @n_Err             INT,  
           @c_ErrMsg          NVARCHAR(215),  
           @c_Pickslipno      NVARCHAR(10),  
           @c_LocationFlag    NVARCHAR(10),  
           @c_Lottable02      NVARCHAR(18),  
           @c_Lottable03      NVARCHAR(18),  
           @n_LocInserted     INT,  
           @n_LocBatch        INT,  
           @n_OpenQty         INT,  
           @c_OrderLine       NVARCHAR(5),  
           @c_UOM             NVARCHAR(10),  
           @c_PackKey         NVARCHAR(10),  
           @c_LOT             NVARCHAR(10),   
           @c_ID              NVARCHAR(18),   
           @n_Qty             INT,   
           @c_PickDetailKey   NVARCHAR(10)   
   
   IF ISNULL(RTRIM(@c_LocAisle),'') = '' 
   BEGIN
      RETURN
   END      
       
   SET @n_LocBatch = 1  
   SET @n_LocInserted = 0  
   SET @c_ExternOrderKey = 'VFTRF_' + CONVERT(VARCHAR(10), GETDATE(), 112) + '_' + @c_LocAisle  
     
   SET @n_OrderCnt = 0  
   SELECT @n_OrderCnt = COUNT(*) FROM ORDERS WITH (NOLOCK)   
   WHERE StorerKey = @c_StorerKey  
   AND   ExternOrderKey LIKE RTRIM(@c_ExternOrderKey) + '%'  
  
--SELECT @c_ParmLocationFlag '@c_ParmLocationFlag', @c_ParmLottable02 '@c_ParmLottable02',   
--@c_ParmLottable03 '@c_ParmLottable03', @c_LocAisle '@c_LocAisle'  
  
   DECLARE @t_GroupHeader TABLE   
      (PickSlip       NVARCHAR(10),   
       OrderKey       NVARCHAR(10),  
       ExternOrderKey NVARCHAR(50),     --tlting_ext
       LocationType   NVARCHAR(10),   
       LocationFlag   NVARCHAR(10),   
       Lottable02     NVARCHAR(18),   
       Lottable03     NVARCHAR(18),  
       LocBatch       INT)  
             
   DECLARE C_InventoryCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT L.LocationType, L.LocationFlag, LA.Lottable02,   
          la.Lottable03, lli.SKU, L.Loc, SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS Qty   
   FROM LOTxLOCxID lli (NOLOCK)  
   JOIN LOC l (NOLOCK) ON l.Loc = lli.Loc   
   JOIN LOTATTRIBUTE LA (NOLOCK) ON la.Lot = lli.Lot   
   WHERE lli.StorerKey = @c_StorerKey   
   AND   (l.LocAisle = @c_LocAisle)   
   AND   (l.Facility = @c_Facility)  
   AND   (l.LocationFlag = @c_ParmLocationFlag OR @c_ParmLocationFlag = '-')   
   AND   (LA.Lottable02 = @c_ParmLottable02 OR @c_ParmLottable02 = '-')   
   AND   (LA.Lottable03 = @c_ParmLottable03 OR @c_ParmLottable03 = '-')   
   GROUP BY L.LocationType, L.LocationFlag, LA.Lottable02, la.Lottable03, lli.SKU, L.Loc   
   HAVING SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) > 0   
   ORDER BY L.LocationType, L.LocationFlag, L.Loc, LA.Lottable02, la.Lottable03   
     
     
   OPEN C_InventoryCursor  
     
   FETCH NEXT FROM C_InventoryCursor INTO @c_LocationType, @c_LocationFlag, @c_Lottable02,  
                                          @c_Lottable03, @c_SKU, @c_Loc, @n_OpenQty  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF @n_LocCount > 0   
      BEGIN  
         -- If new LOC
         IF NOT EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE OrderKey = @c_Orderkey AND LOC = @c_Loc)
         BEGIN
            IF (SELECT COUNT( DISTINCT LOC) FROM PICKDETAIL (NOLOCK) WHERE OrderKey = @c_Orderkey) >= @n_LocCount
            BEGIN  
               SET @n_LocBatch = @n_LocBatch + 1  
            END           
         END
      END  
        
--      SELECT @c_LocationType '@c_LocationType', @c_LocationFlag '@c_LocationFlag',   
--      @c_Lottable02 '@c_Lottable02', @c_Lottable03 '@c_Lottable03', @n_LocBatch '@n_LocBatch'  
--        
--      SELECT * FROM @t_GroupHeader  
        
      IF NOT EXISTS (SELECT 1 FROM @t_GroupHeader   
                     WHERE LocationType = @c_LocationType   
                     AND   LocationFlag = @c_LocationFlag   
                     AND   Lottable02   = @c_Lottable02   
                     AND   Lottable03   = @c_Lottable03  
                     AND   LocBatch     = @n_LocBatch)  
      BEGIN  
  
          EXECUTE dbo.nspg_getkey     
             'ORDER' ,     
              10 ,     
              @c_Orderkey OUTPUT ,     
              @b_success  OUTPUT,     
              @n_err      OUTPUT,     
              @c_errmsg   OUTPUT            
            
          IF @b_Success = 1  
          BEGIN  
     EXECUTE nspg_GetKey  
     'PICKSLIP',  
     9,  
     @c_Pickslipno OUTPUT,  
     @b_success OUTPUT,  
     @n_err OUTPUT,  
     @c_errmsg OUTPUT  
     
     SELECT @c_Pickslipno = 'P' + @c_Pickslipno  
  
             SET @n_OrderCnt = @n_OrderCnt + 1    
               
             SET @c_ExternOrderKey = 'VFTRF_' + CONVERT(VARCHAR(10), GETDATE(), 112) + '_' + @c_LocAisle   
                       + '_' + RIGHT('0' + CAST(@n_OrderCnt AS VARCHAR(2)),2)  
                            
             INSERT INTO @t_GroupHeader (PickSlip, OrderKey, ExternOrderKey,  
                         LocationType, LocationFlag, Lottable02, Lottable03, LocBatch)  
             VALUES(@c_Pickslipno, @c_Orderkey,  @c_ExternOrderKey, @c_LocationType,   
                    @c_LocationFlag, @c_Lottable02, @c_Lottable03, @n_LocBatch)  
                      
             INSERT INTO ORDERS (OrderKey, StorerKey, ExternOrderKey, OrderDate,  
                         DeliveryDate, [Status], [Type], OrderGroup, Notes, Notes2)  
             VALUES(@c_Orderkey, @c_StorerKey, @c_ExternOrderKey, CONVERT(VARCHAR(18), GETDATE(), 112),  
                 CONVERT(VARCHAR(18), GETDATE(), 112),'0', 'VANSTRF', '',  
                 ('Location Aisle: ' + @c_LocAisle +   
                 ', LocationCount: ' + CONVERT(VARCHAR(10), @n_LocCount) +  
                 ', LocationFlag: ' + @c_ParmLocationFlag +   
                 ', Lottable02: ' + @c_ParmLottable02 +   
                 ', Lottable03: ' + @c_ParmLottable03),  
                 ('Location Flag: ' + @c_LocationFlag +   
                 ', Lottable02: ' + @c_Lottable02 +   
                 ', Lottable03: ' + @c_Lottable03 +   
                 ', Location Type: ' + @c_LocationType))  
  
             INSERT INTO PICKHEADER      
               (PickHeaderKey, Wavekey, Orderkey, PickType, Zone, TrafficCop)      
             VALUES      
               (@c_Pickslipno, '', @c_OrderKey, '0' ,'8','')        
               
  
          END  
          SET @n_LocInserted = 0   
      END  
      SET @n_LocInserted =  @n_LocInserted + 1  
        
      SET @c_OrderLine = RIGHT('0000' + CONVERT(VARCHAR(5), @n_LocInserted), 5)   
        
      SELECT @c_UOM = p.PackUOM3,   
             @c_PackKey = p.PackKey  
      FROM PACK p WITH (NOLOCK)   
      JOIN SKU s WITH (NOLOCK) ON s.PackKey = p.PackKey  
      WHERE s.StorerKey = @c_StorerKey   
      AND s.Sku = @c_SKU  
        
      INSERT INTO ORDERDETAIL(OrderKey, OrderLineNumber, ExternOrderKey,  
                  ExternLineNo, Sku, StorerKey, OpenQty, UOM, PackKey, Lottable02,  
                  Lottable03)  
      VALUES(@c_Orderkey, @c_OrderLine, @c_ExternOrderKey, CONVERT(VARCHAR(5), @n_LocInserted),  
         @c_sku, @c_StorerKey, @n_OpenQty, @c_UOM, @c_PackKey, @c_Lottable02, @c_Lottable03)  
        
      DECLARE C_LOTxLOCxID_Result CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LLI.LOT, LLI.ID, (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated)  
      FROM LOTxLOCxID LLI WITH (NOLOCK)  
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = LLI.Lot  
      WHERE LLI.StorerKey = @c_StorerKey   
      AND LLI.Sku = @c_SKU   
      AND LA.Lottable02 = @c_Lottable02   
      AND LA.Lottable03 = @c_Lottable03   
      AND LLI.Loc = @c_Loc   
      AND (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0   
        
      OPEN C_LOTxLOCxID_Result   
      FETCH NEXT FROM C_LOTxLOCxID_Result INTO @c_LOT, @c_ID, @n_Qty  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         EXECUTE nspg_GetKey    
         'PICKDETAILKEY',    
         10,    
         @c_PickDetailKey OUTPUT,    
         @b_Success      OUTPUT,    
         @n_Err          OUTPUT,    
         @c_ErrMsg       OUTPUT    
  
         INSERT INTO PICKDETAIL    
         (PickDetailKey,  PickHeaderKey, OrderKey, OrderLineNumber, Lot,     
          Storerkey, Sku, UOM, UOMQty, Qty, [Status], Loc, ID, PackKey, PickSlipNo )    
         VALUES  
         (@c_PickDetailKey, '', @c_Orderkey, @c_OrderLine, @c_LOT, @c_StorerKey,   
          @c_SKU, '6', @n_Qty, @n_Qty, '0', @c_Loc, @c_ID, @c_PackKey, @c_Pickslipno)  
  
                
         FETCH NEXT FROM C_LOTxLOCxID_Result INTO @c_LOT, @c_ID, @n_Qty  
      END  
      CLOSE C_LOTxLOCxID_Result   
      DEALLOCATE C_LOTxLOCxID_Result  
                    
      FETCH NEXT FROM C_InventoryCursor INTO @c_LocationType, @c_LocationFlag, @c_Lottable02,  
                                             @c_Lottable03, @c_SKU, @c_Loc, @n_OpenQty     
   END  
   CLOSE C_InventoryCursor   
   DEALLOCATE C_InventoryCursor  
     
   SELECT T.OrderKey, T.ExternOrderKey, ORDERS.Notes2               
   FROM @t_GroupHeader T  
   JOIN ORDERS (NOLOCK) ON T.OrderKey = ORDERS.OrderKey  
        
END -- procedure

GO