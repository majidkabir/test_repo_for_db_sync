SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nsp_BackEndShipped4                                */
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
/* Date         Author       Purposes                                   */
/* 22-Mar-2005  Shong        Performance Tunning                        */
/*                                                                      */
/* 11-Jul-2005  Shong        Include SET ANSI_WARNINGS OFF              */
/*                                                                      */
/* 15-Aug-2005  Shong        Add new column to replace UserDefine10     */
/*                           due to Philippine already use that for     */
/*                           Other purposes. SOS#39344                  */
/* 03-Dec-2010  James        Delete TaskDetail (james01)                */
/* 15-Mar-2012  KHLim01      only PRINT message when debug mode turn on */
/* 15-May-2012  Shong        Delete RefKeyLookUp when Pickdetail record */
/*                           Deleted                                    */
/* 23-Apr-2013  Leong        Include debug mode (Leong01)               */
/* 24-Feb-2017  TLTING       Performance Tune - Editdate,editwho        */
/* 19-Nov-2018  TLTING       Remove OD Mbolkey link                     */  
/* 01-Nov-2020  SHONG        Prevent rollback to pickdetail update      */  
/*                           and Log Short Qty to ErrLog Table          */  
/************************************************************************/
CREATE PROCEDURE [dbo].[nsp_BackEndShipped4]
     @cStorerKey NVARCHAR(15),
     @cMBOLKey   NVARCHAR(10) -- For one storer, pass in the Storerkey; For All Storer, pass in '%'
   , @b_debug    INT = 0 -- Leong01
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickDetailKey  NVARCHAR (10),
           @c_XmitLogKey     NVARCHAR (10),
           @c_PickOrderLine  NVARCHAR (5),
           @n_Continue       INT ,
           @n_cnt            INT,
           @n_err            INT,
           @c_ErrMsg         NvarCHAR (255),
           @n_RowCnt         INT,
           @b_success        INT,
           @c_trmlogkey      NVARCHAR(10),
           @c_MBOLKey        NVARCHAR(10),
           @d_StartTime      datetime,
           @d_EndTime        datetime,
           @c_PrevMBOLkey    NVARCHAR(10),
           @f_Status         INT,
           @c_TaskDetailKey  NVARCHAR(10)      -- (james01)
          ,@b_OutofStock     INT = 0   

   SELECT @n_continue=1
       --,@b_debug=0 -- KHLim01

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
             ORDERDETAIL.MBOLKEY, 
             PICKDETAIL.TASKDETAILKEY     -- (james01)
      FROM ORDERDETAIL WITH (NOLOCK)
      JOIN PICKDETAIL WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                                         PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER )
      JOIN  MBOLDETAIL (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey   -- MBOLDETAIL.MBOLKey = ORDERDETAIL.MBOLKey  
      JOIN  MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      WHERE PICKDETAIL.Status < '9'
      and   Mbol.Mbolkey=@cMBOLKey
      AND   MBOL.Status = '9'
      ORDER BY ORDERDETAIL.MBOLKEY, PICKDETAIL.pickdetailkey

   BEGIN
     BEGIN TRAN
         -- SOS# 39344 Change UserDefine10 to ShipCounter
         -- No impact to the operation
         -- Update ShipCounter to show which attempt this was on executing.
         UPDATE MBOL WITH (ROWLOCK)
         SET MBOL.ShipCounter = ISNULL(LTRIM(ShipCounter),0)+1 ,
         Editdate = GETDATE(),         --(SW01)
         TrafficCop = NULL
         WHERE MBOLKEY = @cMbolkey
     COMMIT TRAN
   END

   OPEN CUR1

   SELECT @c_PickDetailKey = SPACE(10),
          @c_MBOLKey       = SPACE(10),
          @c_PrevMBOLkey   = SPACE(10),  
          @b_OutofStock    = 0   

   FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_MBOLKey, @c_TaskDetailKey

   SELECT @f_status = @@FETCH_STATUS
   SELECT @c_PrevMBOLkey = @c_MBOLKey

   WHILE @f_status <> -1 AND @n_continue = 1 
   BEGIN
      IF ISNULL(LTRIM(RTrim(@c_PickDetailKey)), '' ) = ''
         BREAK

      IF @c_MBOLKey <> @c_PrevMBOLkey
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

         IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK)   
                   WHERE LOT = @cLOT   
                     AND LOC = @cLOC   
                     AND ID  = @cID  
                     AND Qty < (@nQtyAllocated + @nQtyPicked) )  
         BEGIN  
            SET @n_err=72806   
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': (LOTxLOCxID.Qty < PickDetail.Qty) - PickDetailKey: ' + @c_PickDetailKey   
                        + ', MBOLKey: ' + @c_MBOLKey   
                        + ', LOC: ' + @cLOC  
                        + ', LOT: ' + @cLOT  
                        + ', Qty: ' + CAST( (@nQtyAllocated + @nQtyPicked) AS VARCHAR(5))    
                        + ' (nsp_BackEndShipped4)'   
            EXECUTE nsp_LogError @n_err, @c_errmsg, "nsp_BackEndShipped4"  
            SET @b_OutofStock = 1  
         END  
         ELSE   
         BEGIN  
            BEGIN TRAN  
  
            BEGIN TRY    
              UPDATE PICKDETAIL WITH (ROWLOCK)  
                  SET Status = '9',  
                     EditWho = SUSER_SNAME(),  
                     EditDate = GETDATE()  
               WHERE pickdetailkey = @c_PickDetailKey  
               AND   Status < '9'   
  
               SELECT @n_err = @@ERROR  
               IF @n_err = 0   
               BEGIN  
                  WHILE @@TRANCOUNT > 0  
                  COMMIT TRAN  
                  IF @b_debug = 1   -- KHLim01  
                  BEGIN  
                     PRINT 'Updated MBOL ' + @c_MBOLKey + ' PickDetailKey ' + @c_PickDetailKey + ' Start at ' + CONVERT(CHAR(10), @d_StartTime, 108) + ' End at ' + CONVERT(CHAR(10), Getdate(), 108)  
                  END  
               END   
            END TRY    
            BEGIN CATCH    
               SELECT @n_err = ERROR_NUMBER()  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  IF @b_debug = 1   
                  BEGIN  
                     SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update PickDetail Fail. PickDetailKey = " + @c_PickDetailKey   
                           + " (nsp_BackEndShipped4)" + " ( " + " SQLSvr Message=" + ERROR_MESSAGE() + " ) "  
                  END   
                  ELSE   
                  BEGIN  
                     SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update PickDetail Fail. PickDetailKey = " + @c_PickDetailKey   
                           + " (nsp_BackEndShipped4)"   
                  END   
                  ROLLBACK TRAN  
                  BREAK  
               END   
            END CATCH  
         END
      END
      ELSE
      BEGIN
         BEGIN TRAN

         UPDATE PICKDETAIL WITH (ROWLOCK)
            SET ArchiveCop = '9',
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
         WHERE pickdetailkey = @c_PickDetailKey
         AND   Qty = 0
         AND   Status < '9'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped4)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
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
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table PICKDETAIL. (nsp_BackEndShipped4)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
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
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table TASKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
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
               SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table REFKEYLOOKUP. (nsp_BackEndShipped4)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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

      FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_MBOLKey, @c_TaskDetailKey
      SELECT @f_status = @@FETCH_STATUS
   END -- While PickDetail Key

   CLOSE CUR1
   DEALLOCATE CUR1

   IF @n_continue = 1
   BEGIN
      UPDATE MBOLShipLog Set Status = '9'
      WHERE StorerKey = @cStorerKey
      AND   MBOLKey = @cMBOLKey
   END

   /* #INCLUDE <SPTPA01_2.SQL> */
   -- Error Occured - Process And Return   
   IF @n_continue = 3 OR @b_OutofStock = 1    
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, "nsp_BackEndShipped4"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END

GO