SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: ispPatchInventoryQty_byLot                                  */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: SHONG                                                    */  
/*                                                                      */  
/* Purpose: Patch the QtyAllocated and Qty Picked if it's not tally     */  
/*          with Pickdetail status                                      */  
/* Input Parameters: Lot                                                */  
/*                                                                      */  
/* Output Parameters: None                                              */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispPatchInventoryQty_byLot]     
   @c_LOT  NVARCHAR(10) = NULL
AS    
BEGIN    
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue       int ,    
           @n_cnt            int,    
           @n_err            int,    
           @c_ErrMsg         char (255),  
           @c_PickDetailKey  char (10),  
           @f_status         int   
  
   DECLARE @cOrderKey       NVARCHAR(10),
          @cSKU            NVARCHAR(20),    
          @cLOT             NVARCHAR(10),    
          @cLOC             NVARCHAR(10),    
          @cID              NVARCHAR(18),    -- tlting01  
          @nQtyAllocated    int,    
          @nQtyPicked       int,    
          @cOrderLineNumber NVARCHAR(5),  
          @cStorerKey       NVARCHAR(15),  
          @b_success        int     
  
   IF @c_LOT IS NOT NULL   
   BEGIN  
      DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR     
      SELECT PICKDETAIL.pickdetailkey  
      FROM PICKDETAIL WITH (NOLOCK)    
      WHERE Lot = @c_LOT   
   END   
   ELSE  
   BEGIN  
      RETURN   
   END   
  
   OPEN CUR1    
    
   SELECT @c_PickDetailKey = SPACE(10)  
      
   FETCH NEXT FROM CUR1 INTO @c_PickDetailKey   
  
   WHILE @@fetch_status <> -1        BEGIN    
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PickDetailKey)) IS NULL    
         BREAK    
  
      -- Modify by SHONG on 12-Jun-2003    
      -- For Performance Tuning    
      IF (SELECT Qty FROM PICKDETAIL (NOLOCK) WHERE pickdetailkey = @c_PickDetailKey) > 0     
      BEGIN   
    
         SELECT @cStorerKey = StorerKey,    
                @cSKU = SKU,    
                @cLOT = LOT,    
                @cLOC = LOC,    
                @cID  = ID,    
                @nQtyAllocated = CASE WHEN Status < '5' THEN Qty ELSE 0 END,    
                @nQtyPicked = CASE WHEN Status between '5' and '8' THEN Qty ELSE 0 END,    
                @cOrderKey = OrderKey,    
                @cOrderLineNumber = OrderLineNumber     
         FROM PickDetail (NOLOCK)    
         WHERE pickdetailkey = @c_PickDetailKey    
             
         IF EXISTS(SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT     
                  AND (QtyAllocated < @nQtyAllocated OR QtyPicked < @nQtyPicked) )    
         BEGIN    
            EXECUTE ispPatchLOTQty @cLOT    
         END    
         IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU and LOC = @cLOC     
                   AND (QtyAllocated < @nQtyAllocated OR QtyPicked < @nQtyPicked) )    
         BEGIN    
            EXECUTE ispPatchSKUxLOCQty @cStorerKey, @cSKU, @cLOC     
         END    
         IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOT = @cLOT AND LOC = @cLOC and ID = @cID     
                   AND (QtyAllocated < @nQtyAllocated OR QtyPicked < @nQtyPicked) )    
         BEGIN    
            EXECUTE ispPatchLOTxLOCxIDQty @cLOT, @cLOC, @cID     
         END    
         IF EXISTS(SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber    
                   AND (QtyAllocated < @nQtyAllocated OR QtyPicked < @nQtyPicked) )    
         BEGIN    
            EXECUTE ispPatchOrdDetailQty @cOrderKey, @cOrderLineNumber    
         END     
      END -- PickDetail.Qty > 0   
  
      FETCH NEXT FROM CUR1 INTO @c_PickDetailKey   
   END -- While  
   CLOSE CUR1  
   DEALLOCATE CUR1   
  
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPatchInventoryQty_byLot'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
  
END -- Procedure

GO