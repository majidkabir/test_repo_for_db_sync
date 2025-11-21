SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nsp_BackEndShipped5                                */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Update PickDetail to Status 9 from backend                  */  
/*          For VF Shipped Cancel Orders                                */  
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
/* Date         Author       Purposes                                   */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[nsp_BackEndShipped5]  
     @cStorerKey NVARCHAR(15),  
     @b_debug    INT = 0 -- Leong01  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_PickDetailKey  CHAR (10),  
           @c_XmitLogKey     CHAR (10),  
           @c_PickOrderLine  CHAR (5),  
           @n_Continue       INT ,  
           @n_cnt            INT,  
           @n_err            INT,  
           @c_ErrMsg         CHAR (255),  
           @n_RowCnt         INT,  
           @b_success        INT,  
           @c_trmlogkey      NVARCHAR(10),  
           @d_StartTime      datetime,  
           @d_EndTime        datetime,  
           @f_Status         INT,  
           @c_TaskDetailKey  NVARCHAR(10)      -- (james01)  
  
   SELECT @n_continue=1   
  
   DECLARE @cSKU             NVARCHAR(20),  
           @cLOT             NVARCHAR(10),  
           @cLOC             NVARCHAR(10),  
           @cID              NVARCHAR(18),  
           @nQtyAllocated    INT,  
           @nQtyPicked       INT,  
           @cOrderKey        NVARCHAR(10),  
           @cOrderLineNumber NVARCHAR(5)  
  
      DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PICKDETAIL.PICKDETAILKEY,  
             PICKDETAIL.TASKDETAILKEY     -- (james01)  
      FROM ORDERS WITH (NOLOCK)  
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey )  
      JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
                                         PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER )  
      WHERE PICKDETAIL.Status < '9'  
      AND   PICKDETAIL.ShipFlag = 'Y'  
      and   ORDERS.Storerkey=@cStorerKey  
      AND   ORDERS.SOStatus = 'CANC'  
      AND   ORDERS.TYPE = 'NIF'    
      AND   ORDERS.STATUS = '9'  
      ORDER BY PICKDETAIL.pickdetailkey  
  
   OPEN CUR1  
  
   SELECT @c_PickDetailKey = SPACE(10)  
  
   FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_TaskDetailKey  
  
   SELECT @f_status = @@FETCH_STATUS  
  
   WHILE @f_status <> -1  
   BEGIN  
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PickDetailKey)) IS NULL  
         BREAK  
  
      SELECT @d_StartTime = GetDate()  
  
      -- Modify by SHONG on 12-Jun-2003  
      -- For Performance Tuning  
      IF (SELECT Qty FROM PICKDETAIL (NOLOCK) WHERE pickdetailkey = @c_PickDetailKey) > 0  
      BEGIN  
         IF @b_debug = 1   -- KHLim01  
         BEGIN  
            PRINT 'Shipping PickDetail : ' + @c_PickDetailKey  
         END  
  
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
            SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped5)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
            ROLLBACK TRAN  
            BREAK  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0  
            COMMIT TRAN  
            IF @b_debug = 1   -- KHLim01  
            BEGIN  
               PRINT 'Updated PickDetailKey ' + @c_PickDetailKey + ' Start at ' + CONVERT(CHAR(10), @d_StartTime, 108) + ' End at ' + CONVERT(CHAR(10), Getdate(), 108)  
            END  
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
            SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped5)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
            ROLLBACK TRAN  
            BREAK  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0                 COMMIT TRAN  
  
            BEGIN TRAN  
  
            DELETE PICKDETAIL  
            WHERE pickdetailkey = @c_PickDetailKey  
            AND   ArchiveCop = '9'  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table PICKDETAIL. (nsp_BackEndShipped5)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
               ROLLBACK TRAN  
               BREAK  
            END  
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
               COMMIT TRAN  
  
               -- james01  
               IF ISNULL(RTRIM(LTRIM(@c_TaskDetailKey)), '') <> ''  
               BEGIN  
                  IF NOT EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE TASKDETAILKEY = @c_Taskdetailkey) AND  
                     NOT EXISTS (SELECT 1 FROM TASKDETAIL (NOLOCK) WHERE TASKDETAILKEY = @c_Taskdetailkey AND STATUS = '9')  
                  BEGIN  
                     BEGIN TRAN  
                     DELETE TASKDETAIL  
                     WHERE TASKDETAILKEY = @c_Taskdetailkey  
                     AND [Status] <> '9'  
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table TASKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
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
            END  
  
            DELETE REFKEYLOOKUP  
            WHERE PickDetailKey = @c_PickDetailKey  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72808   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table REFKEYLOOKUP. (nsp_BackEndShipped5)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
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
  
      FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_TaskDetailKey  
      SELECT @f_status = @@FETCH_STATUS  
   END -- While PickDetail Key  
  
   CLOSE CUR1  
   DEALLOCATE CUR1  
  
END  

GO