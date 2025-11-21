SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_BackEndShipped2                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Update PickDetail to Status 9 from backend                  */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 22-Mar-2005  Shong    1.1  Performance Tunning                       */
/* 14-09-2009   TLTING   1.2  ID field length	(tlting01)                */
/*                                                                      */
/************************************************************************/
CREATE PROCEDURE [dbo].[nsp_BackEndShipped2]  
   @cStorerKey NVARCHAR(15) -- For one storer, pass in the Storerkey; For All Storer, pass in '%'  
AS  
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 
  
   DECLARE @c_PickDetailKey   char (10),  
           @c_XmitLogKey     char (10),  
           @c_PickOrderLine  char (5),  
           @n_Continue       int ,  
           @n_cnt            int,  
           @n_err            int,  
           @c_ErrMsg         char (255),  
           @n_RowCnt         int,  
           @b_success        int,  
           @c_trmlogkey      NVARCHAR(10),  
           @c_MBOLKey        NVARCHAR(10),  
           @d_StartTime      datetime,  
           @d_EndTime        datetime,  
           @c_PrevMBOLkey    NVARCHAR(10),  
           @f_Status         int     
     
   SELECT @n_continue=1  
  
   DECLARE @cSKU NVARCHAR(20),  
          @cLOT NVARCHAR(10),  
          @cLOC NVARCHAR(10),  
          @cID  NVARCHAR(18),  			--tlting01
          @nQtyAllocated int,  
          @nQtyPicked    int,  
          @cOrderKey     NVARCHAR(10),  
          @cOrderLineNumber NVARCHAR(5)  
           
  
  
   IF @cStorerKey = '%'  
   BEGIN  
--       DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR   
--       SELECT PICKDETAIL.pickdetailkey,  
--              ORDERDETAIL.MBOLKEY, pickdetail.storerkey    
--       FROM PICKDETAIL WITH (NOLOCK)  
--       JOIN ORDERDETAIL WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
--                                          PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER )  
--       JOIN  MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = ORDERDETAIL.MBOLKey AND MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey 
--       JOIN  MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
--       WHERE PICKDETAIL.Status < '9'  
--       AND   MBOL.Status = '9' 

      DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR   
      SELECT PICKDETAIL.PICKDETAILKEY,  
             ORDERDETAIL.MBOLKEY 
      FROM ORDERDETAIL WITH (NOLOCK)  
      JOIN PICKDETAIL WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
                                         PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER )  
      JOIN  MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = ORDERDETAIL.MBOLKey AND MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey 
      JOIN  MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      WHERE PICKDETAIL.Status < '9'  
      AND   MBOL.Status = '9' 
      ORDER BY ORDERDETAIL.MBOLKEY, PICKDETAIL.pickdetailkey  

   END  
   ELSE  
   BEGIN  
      DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR   
      SELECT PICKDETAIL.PICKDETAILKEY,  
             ORDERDETAIL.MBOLKEY  
      FROM ORDERDETAIL WITH (NOLOCK)  
      JOIN PICKDETAIL WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
                                         PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER )  
      JOIN  MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = ORDERDETAIL.MBOLKey AND MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey 
      JOIN  MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      WHERE PICKDETAIL.Status < '9'  
      AND   MBOL.Status = '9' 
      AND   ORDERDETAIL.StorerKey = @cStorerKey 
      ORDER BY ORDERDETAIL.MBOLKEY, PICKDETAIL.pickdetailkey 
 
--          DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR 
--          SELECT PICKDETAIL.pickdetailkey,  
--                MBOL.MBOLKEY 
--          FROM MBOL (NOLOCK) 
--          JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
--          JOIN ORDERDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = ORDERDETAIL.MBOLKey AND MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey 
--          JOIN PICKDETAIL WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
--                                          PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER AND PICKDETAIL.Status < '9'  )  
--          WHERE MBOL.Status = '9' 
--            AND ORDERDETAIL.StorerKey = @cStorerKey
--          ORDER BY MBOL.MBOLKEY, PICKDETAIL.pickdetailkey   
   END  
     
   OPEN CUR1  
  
   SELECT @c_PickDetailKey = SPACE(10),  
          @c_MBOLKey = SPACE(10),  
          @c_PrevMBOLkey = SPACE(10)   
  
  
   FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_MBOLKey   
   SELECT @f_status = @@FETCH_STATUS  
   SELECT @c_PrevMBOLkey = @c_MBOLKey   
  
   WHILE @f_status <> -1   
   BEGIN  
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PickDetailKey)) IS NULL  
         BREAK  
  
      IF @c_MBOLKey <> @c_PrevMBOLkey  
         BREAK   
                
      SELECT @d_StartTime = GetDate()  
  
      -- Modify by SHONG on 12-Jun-2003  
      -- For Performance Tuning  
      IF (SELECT Qty FROM PICKDETAIL (NOLOCK) WHERE pickdetailkey = @c_PickDetailKey) > 0   
      BEGIN  
         print 'shipping pickdetail : ' + @c_PickDetailKey  
  
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
               
         BEGIN TRAN  
     
         UPDATE PICKDETAIL WITH (ROWLOCK)   
            SET Status = '9'  
         WHERE pickdetailkey = @c_PickDetailKey  
         AND   Status < '9'  
  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
            ROLLBACK TRAN  
            BREAK  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0   
            COMMIT TRAN  
            PRINT 'Updated MBOL ' + @c_MBOLKey + ' PickDetailKey ' + @c_PickDetailKey + ' Start at ' + CONVERT(char(10), @d_StartTime, 108) + ' End at ' + CONVERT(char(10), Getdate(), 108)              
         END  
      END  
      ELSE  
      BEGIN  
         BEGIN TRAN   
  
         UPDATE PICKDETAIL WITH (ROWLOCK)   
            SET ArchiveCop = '9'  
         WHERE pickdetailkey = @c_PickDetailKey  
         AND   Qty = 0 
         AND   Status < '9'   

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
            ROLLBACK TRAN  
            BREAK  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0   
               COMMIT TRAN  
  
            BEGIN TRAN   
  
            DELETE PICKDETAIL   
            WHERE pickdetailkey = @c_PickDetailKey              
            AND   ArchiveCop = '9' 
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table PICKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
               ROLLBACK TRAN  
               BREAK  
            END  
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0   
               COMMIT TRAN  
            END   
         END  
      END   
  
      SELECT @c_PrevMBOLkey = @c_MBOLKey   
  
      FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_MBOLKey   
      SELECT @f_status = @@FETCH_STATUS  
   END -- While PickDetail Key  
  
   CLOSE CUR1   
   DEALLOCATE CUR1  
  
   /* #INCLUDE <SPTPA01_2.SQL> */    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      execute nsp_logerror @n_err, @c_errmsg, "nsp_BackEndShipped"    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
END  

GO