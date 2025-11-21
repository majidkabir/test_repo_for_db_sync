SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************************/    
/* Store Procedure:  isp_ProcessShortPickReAllocate                                                */    
/* Creation Date: 04-May-2020                                                                      */    
/* Copyright: LFL                                                                                  */    
/* Written by: Shong                                                                               */    
/*                                                                                                 */    
/* Purpose: In Case of Short Pick, system help to put all inveotory on-hold                        */    
/*          And re-do allocation to get another location                                           */    
/*                                                                                                 */    
/*                                                                                                 */    
/* Output Parameters: @b_Success       - Success Flag  = 0                                         */    
/*                    @n_Err           - Error Code    = 0                                         */    
/*                    @c_ErrMsg        - Error Message = ''                                        */    
/*                                                                                                 */    
/* Called By: Q-Commander                                                                          */    
/*                                                                                                 */    
/* Version: 1.0                                                                                    */    
/*                                                                                                 */    
/* Data Modifications:                                                                             */    
/*                                                                                                 */    
/* Updates:                                                                                        */    
/* Date        Author         Ver.  Purposes                                                       */    
/* 30-Nov-2020 SHONG          1.1   Calling nspInventoryHoldWrapper instead of nspInventoryHold    */    
/* 04-Mar-2021 AdrianAY       1.2   Fixed bug (AY01)                                               */    
/* 24-May-2021 Shong          1.3   WMS-18037 Remove hard code hold type, getting from StorerConfig*/    
/* 23-Nov-2022 James          1.4   WMS-20611 Update order status to 2 after reallocate (james01)  */    
/* 02-Feb-2023 James          1.5   Short pick all orders within the hold loc (james02)            */    
/* 23-Mar-2023 LZG            1.6   Ignore OrderKey and OrderLineNumber when shorting to short all */    
/*                                  orders with same criteria, follow original design (ZG01)       */    
/* 14-Jul-2023 James          1.7   Set orders status 0 when nothing allocated (james03)           */  
/***************************************************************************************************/    
CREATE   PROC [dbo].[isp_ProcessShortPickReAllocate] (    
       @c_Orderkey         NVARCHAR(10)    
     , @c_OrderLineNumber  NVARCHAR(5)    
     , @c_SKU              NVARCHAR(20)    
     , @c_LOC              NVARCHAR(10)    
     , @b_Debug            INT            = 0    
     , @b_Success          INT            = 0   OUTPUT    
     , @n_Err              INT            = 0   OUTPUT    
     , @c_ErrMsg           NVARCHAR(215)  = ''  OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
                      
   /*********************************************/    
   /* Variables Declaration (Start)             */    
   /*********************************************/    
   --General    
   DECLARE @n_Continue                 INT    
         , @n_StartTCnt                INT    
         , @n_RowCNT                   INT    
         , @c_PickDetailKey       NVARCHAR(18) = ''    
         , @c_StorerKey                NVARCHAR(15) = ''    
         , @c_HoldID                   NVARCHAR(18) = ''    
         , @c_HoldLOC                  NVARCHAR(10) = ''    
         , @c_LOT                      NVARCHAR(10) = ''    
         , @c_ID                       NVARCHAR(18) = ''    
         , @n_QtyToMove                INT = 0    
         , @c_PackKey                  NVARCHAR(10) = ''    
         , @c_UOM                      NVARCHAR(10) = ''    
         , @c_SourceKey                NVARCHAR(50) = ''    
         , @c_ItrnKey                  NVARCHAR(10) = ''    
         , @d_EffectiveDate            DATETIME = GETDATE()    
         , @c_LoseID                   NVARCHAR(1) = 0    
         , @c_HoldType                 NVARCHAR(10) = N''    
         , @c_OrdStatus                NVARCHAR( 10) = ''  
      
   DECLARE @curShortPick   CURSOR    
                         
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @b_Success = 0    
   SET @n_RowCNT  = 0    
   SET @n_Err     = 0    
   SET @c_ErrMsg  = ''    
   SET @c_SourceKey = @c_Orderkey + @c_OrderLineNumber    
              
   BEGIN TRAN;    
        
   SELECT @c_StorerKey = o.StorerKey    
   FROM dbo.ORDERS AS o WITH(NOLOCK)    
   WHERE o.OrderKey = @c_Orderkey    
           
   -- WMS-18037 -- Defaul to hold by LOC    
   SET @c_HoldType = 'LOC'    
   SELECT @c_HoldType = ISNULL(SC.SValue,'')    
   FROM dbo.StorerConfig AS SC WITH (NOLOCK)    
   WHERE SC.StorerKey = @c_StorerKey    
   AND SC.ConfigKey = 'ReAlcHold'    
        
   IF @c_HoldType NOT IN ('LOC', 'ID')    
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @n_err = 64504    
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Wrong StorerConfig Value (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
      GOTO QUIT_SP    
   END    
           
        
   IF NOT EXISTS(SELECT 1    
                 FROM dbo.PICKDETAIL AS p WITH(NOLOCK)    
                 WHERE p.OrderKey=@c_Orderkey    
                 AND p.OrderLineNumber=@c_OrderLineNumber    
                 AND p.Sku = @c_SKU    
                 AND p.Loc = @c_LOC    
                 AND p.Qty > 0    
                 AND p.[Status] < '5')    
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @n_err = 64503    
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No Record Found (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
      GOTO QUIT_SP    
   END    
           
   IF @c_HoldType = 'ID'    
      BEGIN    
      SET @c_LoseID = ''    
                 
      SELECT @c_LoseID = ISNULL(l.LoseId,'')    
      FROM dbo.LOC AS l WITH(NOLOCK)    
      WHERE LOC = @c_LOC    
                 
      IF @c_LoseID = ''    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 64501    
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Location Not exists! (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP    
      END    
              
      IF @c_LoseID = '1'    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 64502    
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Location Lose ID = 1 (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP    
      END    
   END    
                                        
   IF OBJECT_ID('tempdb..#t_AllocOrders') IS NOT NULL    
      DROP TABLE #t_AllocOrders    
                    
   CREATE TABLE #t_AllocOrders (    
      OrderKey NVARCHAR(10) )    
              
   -- Un-allocated Orders    
   -- Update PickDetail.Qty to Zero    
   -- Only for PickDetail.Status < '5'    
   DECLARE CUR_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT p.OrderKey, PickDetailKey    
   FROM dbo.PICKDETAIL AS p WITH(NOLOCK)    
   WHERE p.Storerkey = @c_StorerKey    
   AND   p.Sku = @c_SKU    
   AND   p.Loc = @c_LOC    
   AND   p.[Status] IN ('0','1','2','3','4')    
   --AND   p.OrderKey = @c_Orderkey                -- ZG01    
   --AND   p.OrderLineNumber = @c_OrderLineNumber  -- ZG01    
        
   OPEN CUR_PickDetailKey    
                 
   FETCH FROM CUR_PickDetailKey INTO @c_Orderkey, @c_PickDetailKey    
                 
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      IF NOT EXISTS(SELECT 1 FROM #t_AllocOrders AS tao WITH(NOLOCK)    
                    WHERE tao.OrderKey = @c_Orderkey)    
      BEGIN    
         INSERT INTO #t_AllocOrders (OrderKey) VALUES (@c_Orderkey)    
      END    
            
      IF @b_Debug = 1    
         SELECT @c_Orderkey '@c_Orderkey', @c_PickDetailKey '@c_PickDetailKey'    
               
      UPDATE dbo.PICKDETAIL WITH (ROWLOCK)    
         SET Qty = 0, QtyMoved = Qty, Status = '4'  -- AY01    
      WHERE PickDetailKey = @c_PickDetailKey    
                 
      FETCH FROM CUR_PickDetailKey INTO @c_Orderkey, @c_PickDetailKey    
   END    
                 
   CLOSE CUR_PickDetailKey    
   DEALLOCATE CUR_PickDetailKey    
         
   DECLARE @n_isInventoryHold INT = 0    
         
   -- WMS-18037    
   IF @c_HoldType='ID'    
   BEGIN    
      SET @c_HoldLOC = ''    
      SET @c_HoldID = RTRIM(@c_LOC) + '-HOLD'    
      -- If ID not exsting, Insert new record    
      IF NOT EXISTS(SELECT 1 FROM dbo.ID AS i WITH(NOLOCK)    
                    WHERE ID = @c_HoldID)    
      BEGIN    
         INSERT INTO dbo.ID( Id, Qty, [Status] )    
         VALUES (@c_HoldID, 0, 'OK')    
      END    
      
      IF EXISTS ( SELECT 1    
         FROM dbo.INVENTORYHOLD WITH (NOLOCK)    
         WHERE Id = @c_HoldID    
         AND   Storerkey = CASE WHEN StorerKey <> '' THEN @c_StorerKey ELSE '' END    
         AND   Hold = '1')    
         SET @n_isInventoryHold = 1    
   END    
   ELSE    
   BEGIN    
      SET @c_HoldID = ''    
      SET @c_HoldLOC = @c_LOC    
      
      IF EXISTS ( SELECT 1    
         FROM dbo.INVENTORYHOLD WITH (NOLOCK)    
         WHERE Id = @c_HoldID    
         AND   Storerkey = CASE WHEN StorerKey <> '' THEN @c_StorerKey ELSE '' END    
         AND   Hold = '1')    
         SET @n_isInventoryHold = 1    
   END    
         
   -- If inventory already on hold, unhold first then rehold again    
   -- Then the loc.status only can be put on hold    
   -- Prevent the loc to be reallocated below    
   IF @n_isInventoryHold = 1    
   BEGIN    
      EXEC dbo.nspInventoryHoldWrapper    
           @c_lot = ''    
          ,@c_Loc = @c_HoldLOC -- WMS-18037    
          ,@c_ID  = @c_HoldID    
          ,@c_StorerKey    = @c_StorerKey    
          ,@c_SKU          = ''    
          ,@c_Lottable01   = ''    
          ,@c_Lottable02   = ''    
          ,@c_Lottable03   = ''    
          ,@dt_Lottable04  = NULL    
          ,@dt_Lottable05  = NULL    
          ,@c_Lottable06   = ''    
          ,@c_Lottable07   = ''    
          ,@c_Lottable08   = ''    
          ,@c_Lottable09   = ''    
          ,@c_Lottable10   = ''    
          ,@c_Lottable11   = ''    
          ,@c_Lottable12   = ''    
          ,@dt_Lottable13  = NULL    
          ,@dt_Lottable14  = NULL    
          ,@dt_Lottable15  = NULL    
          ,@c_Status = 'SHORT'    
          ,@c_Hold = '0'    
          ,@b_success = @b_Success OUTPUT    
          ,@n_Err = @n_Err OUTPUT    
          ,@c_Errmsg = @c_ErrMsg OUTPUT    
          ,@c_Remark  = ''    
   END    
      
   EXEC dbo.nspInventoryHoldWrapper    
        @c_lot = ''    
       ,@c_Loc = @c_HoldLOC -- WMS-18037    
       ,@c_ID  = @c_HoldID    
       ,@c_StorerKey    = @c_StorerKey    
       ,@c_SKU          = ''    
       ,@c_Lottable01   = ''    
       ,@c_Lottable02   = ''    
       ,@c_Lottable03   = ''    
       ,@dt_Lottable04  = NULL    
   ,@dt_Lottable05  = NULL    
       ,@c_Lottable06   = ''    
       ,@c_Lottable07   = ''    
       ,@c_Lottable08   = ''    
       ,@c_Lottable09   = ''    
       ,@c_Lottable10   = ''    
       ,@c_Lottable11   = ''    
       ,@c_Lottable12   = ''    
       ,@dt_Lottable13  = NULL    
       ,@dt_Lottable14  = NULL    
       ,@dt_Lottable15  = NULL    
       ,@c_Status = 'SHORT'    
       ,@c_Hold = '1'    
       ,@b_success = @b_Success OUTPUT    
       ,@n_Err = @n_Err OUTPUT    
       ,@c_Errmsg = @c_ErrMsg OUTPUT    
       ,@c_Remark  = ''    
                    
   -- Execute Move    
   SELECT @c_PackKey = '', @c_UOM = ''    
              
   SELECT @c_PackKey = SKU.PackKey,    
        @c_UOM = PACK.PackUOM3    
   FROM dbo.SKU AS SKU WITH (NOLOCK)    
   JOIN dbo.PACK AS PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey    
   AND  SKU.STORERKEY = @c_StorerKey    
   AND  SKU.SKU       = @c_SKU    
        
   IF @c_HoldType='ID'    
   BEGIN    
       DECLARE CUR_INV_MOVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
       SELECT Lot, Loc, Id, (Qty - QtyPicked)    
       FROM dbo.LOTxLOCxID AS LLI WITH (NOLOCK)    
       WHERE LLI.StorerKey = @c_StorerKey    
       AND LLI.Sku = @c_SKU    
       AND LLI.Loc = @c_LOC    
       AND LLI.Qty > 0    
       AND LLI.QtyAllocated = 0    
                     
       OPEN CUR_INV_MOVE    
                     
       FETCH FROM CUR_INV_MOVE INTO @c_Lot, @c_Loc, @c_Id, @n_QtyToMove    
                     
       WHILE @@FETCH_STATUS = 0    
       BEGIN    
          SELECT @b_success = 1    
                  
          EXEC dbo.nspItrnAddMove    
             @n_ItrnSysId = null,    
             @c_StorerKey = @c_StorerKey,    
             @c_Sku       = @c_Sku,    
             @c_Lot       = @c_Lot,    
             @c_FromLoc   = @c_Loc,    
             @c_FromID    = @c_ID,    
             @c_ToLoc     = @c_Loc,    
             @c_ToID      = @c_HoldID ,    
             @c_Status    = '',    
             @c_lottable01 = '',    
             @c_lottable02 = '',    
             @c_lottable03 = '',    
             @d_lottable04 = null,    
             @d_lottable05 = null,    
             @c_lottable06 = '',    
             @c_lottable07 = '',    
             @c_lottable08 = '',    
             @c_lottable09 = '',    
             @c_lottable10 = '',    
             @c_lottable11 = '',    
             @c_lottable12 = '',    
             @d_lottable13 = null,    
             @d_lottable14 = null,    
             @d_lottable15 = null,    
             @n_casecnt = 0,    
             @n_innerpack = 0,    
             @n_qty = @n_QtyToMove,    
             @n_pallet = 0,    
             @f_cube = 0,    
             @f_grosswgt = 0,    
             @f_netwgt = 0,    
             @f_otherunit1 = 0,    
             @f_otherunit2 = 0,    
             @c_SourceKey = @c_SourceKey,    
             @c_SourceType = 'isp_ProcessShortPickReAllocate',    
             @c_PackKey = @c_PackKey,    
             @c_UOM = @c_UOM,    
             @b_UOMCalc = 0,    
             @d_EffectiveDate = @d_EffectiveDate,    
             @c_itrnkey = @c_ItrnKey OUTPUT,    
             @b_Success = @b_Success OUTPUT,    
             @n_err     = @n_err OUTPUT,    
             @c_errmsg  = @c_errmsg OUTPUT,    
             @c_MoveRefKey = '',    
             @c_Channel = '',    
             @n_Channel_ID = 0    
                           
          IF NOT @b_success = 1    
          BEGIN    
             SELECT @n_continue = 3    
             SELECT @n_err = 64504    
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Move Fail (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
             GOTO QUIT_SP    
          END    
                     
          FETCH FROM CUR_INV_MOVE INTO @c_Lot, @c_Loc, @c_Id, @n_QtyToMove    
       END    
                     
       CLOSE CUR_INV_MOVE    
       DEALLOCATE CUR_INV_MOVE    
   END  -- @c_HoldType='ID'    
   ELSE    
   BEGIN    
    -- Hold by loc, short pick the rest of the pickdetail within same loc    
      SET @curShortPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      SELECT PickDetailKey    
      FROM dbo.PICKDETAIL WITH (NOLOCK)    
      WHERE Storerkey = @c_StorerKey    
      AND   Loc = @c_HoldLOC    
      AND   [Status] = '0'    
      ORDER BY 1    
      OPEN @curShortPick    
      FETCH NEXT FROM @curShortPick INTO @c_PickDetailKey    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)    
            SET Qty = 0, QtyMoved = Qty, Status = '4'    
         WHERE PickDetailKey = @c_PickDetailKey    
             
       FETCH NEXT FROM @curShortPick INTO @c_PickDetailKey    
      END    
   END    
                  
   -- Allocate Order Again    
   DECLARE CUR_ALLOC_ORDERS CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT OrderKey    
   FROM #t_AllocOrders    
             
   OPEN CUR_ALLOC_ORDERS    
                 
   FETCH FROM CUR_ALLOC_ORDERS INTO @c_OrderKey    
                 
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      IF @b_Debug=1    
      BEGIN    
         PRINT '>>> Allocate Order# ' + @c_Orderkey    
      END    
                    
      EXEC nsp_OrderProcessing_Wrapper    
         @c_OrderKey = @c_OrderKey,    
         @c_oskey = '',    
         @c_docarton = 'N',    
         @c_doroute = 'N',    
         @c_tblprefix = '',    
         @c_extendparms = ''    
                 
      FETCH FROM CUR_ALLOC_ORDERS INTO @c_OrderKey    
   END    
                 
   CLOSE CUR_ALLOC_ORDERS    
   DEALLOCATE CUR_ALLOC_ORDERS    
     
   IF EXISTS ( SELECT 1 FROM ORDERDETAIL WITH (NOLOCK)    
               WHERE OrderKey = @c_Orderkey    
               AND   OrderLineNumber = @c_OrderLineNumber    
               AND   (QtyAllocated + QtyPicked = 0))   
      SET @c_OrdStatus = '0'  -- Nothing allocated  
     
   IF @c_OrdStatus = ''   
   BEGIN  
      IF EXISTS ( SELECT 1 FROM ORDERDETAIL WITH (NOLOCK)    
               WHERE OrderKey = @c_Orderkey    
               AND   OrderLineNumber = @c_OrderLineNumber    
               AND   OpenQty > QtyAllocated)    
         SET @c_OrdStatus = '1'    
      ELSE    
         SET @c_OrdStatus = '2'    
   END  
     
   UPDATE dbo.ORDERDETAIL SET    
      STATUS = @c_OrdStatus,    
      TrafficCop = NULL,    
      EditWho = SUSER_SNAME(),    
      EditDate = GETDATE()    
   WHERE OrderKey = @c_Orderkey    
   AND   OrderLineNumber = @c_OrderLineNumber    
      
   IF @@ERROR <> 0    
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @n_err = 64505    
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Move Fail (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
      GOTO QUIT_SP    
   END    
  
   IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL WITH (NOLOCK)  
               WHERE OrderKey = @c_Orderkey  
               GROUP BY OrderKey  
               HAVING SUM( QtyAllocated + QtyPicked) = 0)  
      SET @c_OrdStatus = '0'  
   ELSE  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE OrderKey = @c_Orderkey AND [Status] = '5')    
         SET @c_OrdStatus = '3'    
      ELSE    
      	SELECT @c_OrdStatus = CASE WHEN SUM( QtyAllocated + QtyPicked) = SUM( OriginalQty) THEN '2' ELSE '1' end
      	FROM dbo.ORDERDETAIL WITH (NOLOCK)
      	WHERE OrderKey = @c_Orderkey  
         GROUP BY OrderKey  
         --SET @c_OrdStatus = '2'    
   END  
           
   UPDATE dbo.ORDERS SET    
      STATUS = @c_OrdStatus,    
      TrafficCop = NULL,    
      EditWho = SUSER_SNAME(),    
      EditDate = GETDATE()    
   WHERE OrderKey = @c_Orderkey    
      
   IF @@ERROR <> 0    
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @n_err = 64506    
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Move Fail (isp_ProcessShortPickReAllocate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '    
      GOTO QUIT_SP    
   END    
      
QUIT_SP:    
              
   IF @b_Debug=1    
   BEGIN    
      PRINT '@n_Continue: ' + CAST(@n_Continue AS VARCHAR)    
      PRINT '@@TRANCOUNT: ' + CAST(@@TRANCOUNT AS VARCHAR)    
      PRINT '@n_StartTCnt: ' + CAST(@n_StartTCnt AS VARCHAR)    
   END    
              
/* #INCLUDE <SPTPA01_2.SQL> */    
   IF @n_Continue=3  -- Error Occured    
   BEGIN    
      SELECT @b_Success = 0    
      IF @@TRANCOUNT > @n_StartTCnt    
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
SET QUOTED_IDENTIFIER OFF

GO