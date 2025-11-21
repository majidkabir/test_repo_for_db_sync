SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrOrderDetailUpdate                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Purposes                                       */
/* 13-Apr-2006  SHONG    Performance Tuning (SHONG_20060413)            */
/* 10-May-2006  MaryVong Add in RDT compatible error message            */
/* 05-Apr-2007  MaryVong SOS72718 Add new configkey "NotUpdateUsrDf03"  */
/* 01-Apr-2009  Vicky    SOS#133155 - Adjustedqty should be updated when*/
/*                       there is a change of OpenQty (Vicky01)         */
/* 04-Mar-2010  TLTING   SOS143271 Update externorderkey                */
/* 20-Oct-2010  TLTING   Performance Tune                               */
/* 21-Dec-2010  SHONG    Performance Tuning                             */
/* 03-May-2012  TLTING01 Update Editdate & Editwho                      */
/* 22-May-2012  TLTING01 DM Integrity issue - Update editdate for       */
/*                       status < '9'                                   */
/* 09-Jul-2013  TLTING02 Deadlock Tune                                  */
/* 10-Jul-2013  SHONG    Deadlock Tune                                  */
/* 28-Oct-2013  TLTING   Review Editdate column update                  */
/* 15-Jun-2015  TLTING   Bug fix - add nolock - Deadlock Tune           */
/* 28-Jul-2017  TLTING03 Performance tune                               */
/* 16-Oct-2017  SHONG    Performance Tuning (SWT01)                     */
/* 26-Oct-2017  SHONG    Performance Tuning (SWT02)                     */
/* 07-May-2024  NJOW01   UWP-18748  Allow config to call custom sp      */
/* 06-09-2024   PPA371   Validate if status is cancel                   */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrOrderDetailUpdate]        
ON [dbo].[ORDERDETAIL]
FOR Update
AS
BEGIN
   /* Return Immediately If No Rows Affected */
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   /* End Return Immediately If No Rows Affected */

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     int,       -- Populated by calls to stored procedures - was the proc successful?
      @n_err              int,       -- Error number returned by stored procedure or this trigger
      @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
      @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
      @n_starttcnt        int,       -- Holds the current transaction count
      @n_cnt              int        -- Holds the number of rows affected by the Update statement that fired this trigger.

   DECLARE @n_DeletedCount int,
      @c_Storerkey         NVARCHAR(15),
      @c_NotUpdUD03        NVARCHAR(1),  -- SOS72718
      @c_OrderKey          NVARCHAR(10)

      , @CUR_UPD           CURSOR                                                   --2024-09-09

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   /* Abort Trigger if called From An Insert Trigger */
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4 /* No Error But Skip Processing */
   END
   /* End Abort If Called From An Insert */

   -- tlting01
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED
               WHERE INSERTED.OrderKey = DELETED.OrderKey
               AND INSERTED.OrderLineNumber = DELETED.OrderLineNumber
               AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) )
   BEGIN
      IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
      BEGIN
         -- TLTING01
         UPDATE ORDERDETAIL with (ROWLOCK)
         SET EditDate   = GETDATE(),
             EditWho    = Suser_sname(),
             TrafficCop = NULL
         FROM ORDERDETAIL
         JOIN INSERTED ON ORDERDETAIL.OrderKey = INSERTED.Orderkey
                        AND ORDERDETAIL.OrderLineNumber = INSERTED.OrderLineNumber
         WHERE ORDERDETAIL.[status] < '9'
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61747 --63014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERDETAIL. (ntrOrderDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END
   END

   /* Abort Trigger if called From An Insert Trigger */
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4 /* No Error But Skip Processing */
   END
   /* End Abort If Called From An Insert */

   /* Execute Preprocess */
   /* #INCLUDE <TRODU1.SQL> */
   /* End Execute Preprocess */

   --NJOW01
   IF @n_continue=1 or @n_continue=2          
   BEGIN   	  
      IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'OrderDetailTrigger_SP')   -----> Current table trigger storerconfig
      BEGIN        	  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

      	 SELECT * 
      	 INTO #INSERTED
      	 FROM INSERTED
          
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED

      	 SELECT * 
      	 INTO #DELETED
      	 FROM DELETED

         EXECUTE dbo.isp_OrdertDetailTrigger_Wrapper ----->wrapper for current table trigger
                   'UPDATE'  -----> @c_Action can be INSERT, UPDATE, DELETE
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  

         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrOrderDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END         
    
-- start tlting sos143271
   -- To trigger Order Status
   IF UPDATE(ExternOrderkey) AND -- (tlting01)
      EXISTS ( SELECT 1 FROM ORDERS with (NOLOCK)
         JOIN INSERTED ON ORDERS.OrderKey = INSERTED.Orderkey
         WHERE ORDERS.ExternOrderKey <> INSERTED.ExternOrderkey )
   BEGIN
      UPDATE ORDERS with (ROWLOCK)
      SET ExternOrderkey = INSERTED.ExternOrderkey,
         EditDate = GETDATE(), EditWho=SUSER_SNAME(),    --tlting
         TrafficCop = NULL
      FROM ORDERS
      JOIN INSERTED ON ORDERS.OrderKey = INSERTED.Orderkey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61744 --63014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (ntrOrderDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END
   END
-- END tlting SOS143271


   /* Main Processing */
   IF (@n_continue = 1 or @n_continue=2)
   BEGIN
      /*Cannot Reduce The ShippedQTY Column*/
      IF UPDATE (ShippedQty) -- SWT01
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM INSERTED INS_REC
                     JOIN DELETED  DEL_REC ON (INS_REC.Orderkey = DEL_REC.OrderKey AND
                                      INS_REC.Orderlinenumber = DEL_REC.orderlinenumber)
                     WHERE INS_REC.Shippedqty < DEL_REC.Shippedqty )
         BEGIN
            SELECT @n_continue = 3, @n_err = 61741 --63004
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Reduction Of Shipped QTY Not Allowed! (ntrOrderDetailUpdate)"
                  + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
      /*End Cannot Reduce The ShippedQTY Column*/


      /*Cannot cancel the order details status Column PPA371*/

      IF @n_continue IN (1,2) AND UPDATE (status)                                   --2024-09-09
      BEGIN
         IF EXISTS(SELECT 1 FROM PICKDETAIL with (NOLOCK)
                   JOIN INSERTED ON PICKDETAIL.OrderKey = INSERTED.Orderkey
                   WHERE PICKDETAIL.OrderLineNumber = INSERTED.OrderLineNumber
                   AND INSERTED.[Status] = 'CANC'
                   )
         BEGIN
            SELECT @n_continue = 3, @n_err = 61748
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":  Order detail is not normal staus and is not allowed to cancel! (ntrOrderDetailUpdate)"
                  + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END

         IF @n_continue IN (1,2)
         BEGIN
            IF EXISTS(SELECT 1 FROM INSERTED
                      JOIN StorerSODefault sod (NOLOCK) ON sod.Storerkey = INSERTED.Storerkey
                      JOIN ORDERDETAIL od (NOLOCK) ON  od.Orderkey = INSERTED.ORderkey
                                                   AND od.OrderLineNumber = INSERTED.OrderLineNumber
                      WHERE INSERTED.[Status] = 'CANC'
                      AND INSERTED.CancelReasonCode = ''
                      AND sod.ReasonCodeReqForSOCancel = 'Yes'
                     )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 61748
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cancel ReasonCode is required. (ntrOrderDetailUpdate)'
            END
         END
		 IF Exists(select 1 from inserted join deleted on (INSERTED.orderkey = DELETED.orderkey AND INSERTED.orderlinenumber = DELETED.orderlinenumber)
					where inserted.Status='CANC' and deleted.Status<>'CANC')
		 BEGIN
			UPDATE ORDERDETAIL WITH (ROWLOCK)
			SET OpenQty=0,TrafficCop=NULL
			FROM ORDERDETAIL
			JOIN INSERTED ON (ORDERDETAIL.orderkey = INSERTED.orderkey AND ORDERDETAIL.orderlinenumber = INSERTED.orderlinenumber )
			JOIN DELETED ON (INSERTED.orderkey = DELETED.orderkey AND INSERTED.orderlinenumber = DELETED.orderlinenumber)
			where inserted.Status='CANC' and deleted.Status<>'CANC'
		 END

      END                                                                           --2024-09-09
      /*End Cannot cancel the order details status Column PPA371*/

      /* Update The OriginalQTY column if the shippedqty column Is 0 */
      IF ( @n_continue = 1 or @n_continue = 2)
      BEGIN
         IF UPDATE (shippedqty) OR UPDATE(openqty) OR UPDATE(QtyAllocated) OR UPDATE(QtyPicked)
         BEGIN
            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET originalqty = CASE WHEN INSERTED.shippedqty = 0 AND DELETED.shippedqty=0
                                   THEN ORDERDETAIL.openqty
                                   ELSE INSERTED.originalqty
                              END,
               Adjustedqty = CASE WHEN ( INSERTED.shippedqty <> 0 or DELETED.shippedqty <> 0) AND
                                    ( INSERTED.shippedqty + INSERTED.openqty +INSERTED.AdjustedQty <> DELETED.shippedqty + DELETED.openqty+DELETED.Adjustedqty)
                                  THEN (INSERTED.openqty + INSERTED.shippedqty) - orderdetail.originalqty
                                  ELSE INSERTED.Adjustedqty
                             END,
              [Status] = CASE WHEN INSERTED.OriginalQty + INSERTED.AdjustedQty + INSERTED.FreeGoodQty = INSERTED.ShippedQty AND INSERTED.ShippedQty <> 0
                                 THEN '9' -- Shipped
                              WHEN INSERTED.ShippedQty > 0
                                 THEN '9' -- Shipped
                              --WHEN INSERTED.OpenQty = 0   AND INSERTED.Status < '9'
                              WHEN (INSERTED.QtyAllocated + INSERTED.QtyPicked) = 0   AND INSERTED.Status < '5'
                                 THEN '0' -- Normal
                              WHEN (INSERTED.OpenQty = INSERTED.QtyAllocated ) AND INSERTED.QtyPicked = 0 AND DELETED.Status < '3'
                                 THEN '2' -- Fully Allocated
                              WHEN ((INSERTED.OpenQty <> (INSERTED.QtyAllocated + INSERTED.QtyPicked)) AND INSERTED.QtyPicked = 0
                                     AND INSERTED.ShippedQty = 0 AND INSERTED.QtyAllocated = 0)
                                 THEN '0' -- Normal
                              WHEN ((INSERTED.OpenQty <> (INSERTED.QtyAllocated + INSERTED.QtyPicked)) AND INSERTED.QtyPicked = 0 AND INSERTED.ShippedQty = 0 )
                                    AND DELETED.Status < '3'
                                 THEN '1'
                              WHEN (INSERTED.QtyAllocated > 0 AND INSERTED.QtyPicked > 0 AND (INSERTED.QtyAllocated <> INSERTED.QtyPicked) )
                                    AND DELETED.Status < '4'
                                 THEN '3'
                            WHEN INSERTED.QtyAllocated = 0 AND INSERTED.QtyPicked > 0 And INSERTED.Status <> '9'
                                 THEN '5'
                           ELSE INSERTED.Status
                       END,
               EditDate = GETDATE(), EditWho=Suser_sname()
            FROM ORDERDETAIL
            JOIN INSERTED ON (ORDERDETAIL.orderkey = INSERTED.orderkey AND ORDERDETAIL.orderlinenumber = INSERTED.orderlinenumber )
            JOIN DELETED ON (INSERTED.orderkey = DELETED.orderkey AND INSERTED.orderlinenumber = DELETED.orderlinenumber)

            SELECT @n_err=@@ERROR, @n_cnt=@@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               /* Trap SQL Server Error */
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61742 --63005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On ORDERDETAIL Failed. (ntrOrderDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               /* End Trap SQL Server Error */
            END
         END
      END -- IF ( @n_continue = 1 or @n_continue = 2)
      /* End Removed BY NB 08/14/95 */
      /* End Update the originalQTY column if the shippedqty column is 0 */

      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         -- SOS72718 If enable this configkey, do not update Orders.UserDefine03 when confirm Picked or Packed
         SELECT @c_Storerkey = Storerkey
         FROM  INSERTED

         SET @b_success = 0
         EXECUTE nspGetRight null,  -- facility
               @c_Storerkey,        -- Storerkey
               null,                -- Sku
               'NotUpdateUsrDf03',  -- Configkey
               @b_success     output,
               @c_NotUpdUD03  output,
               @n_err         output,
               @c_errmsg      output
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 61746, @c_errmsg = 'ntrOrderDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_NotUpdUD03 <> '1'
         BEGIN

            -- StartHere (SHONG_20060413)
            IF UPDATE(QtyPicked)
            AND EXISTS(SELECT 1 FROM INSERTED WHERE UnitPrice > 0)
            AND EXISTS(SELECT 1 FROM INSERTED
                        JOIN ORDERS with (NOLOCK) on ORDERS.ORDERKEY = INSERTED.ORDERKEY
                      WHERE  ISNUMERIC(ISNULL(RTRIM(ORDERS.UserDefine03), 0) ) = 1)
            AND EXISTS ( SELECT 1
                  FROM DELETED
                  JOIN INSERTED ON INSERTED.Orderkey = DELETED.Orderkey
                  AND INSERTED.OrderLineNumber = DELETED.OrderLineNumber
                  AND ( INSERTED.QtyPicked <> DELETED.QtyPicked
                  OR INSERTED.UnitPrice <> DELETED.UnitPrice )    ) -- tlting Performance Tuning
            BEGIN
               SELECT @n_DeletedCount = (select count(*) FROM DELETED)
               IF @n_DeletedCount = 1
               BEGIN
                  /* Only one row updated in the detail table. */
                  UPDATE ORDERS  WITH (ROWLOCK)
                  SET  UserDefine03 = CAST( CAST(ORDERS.UserDefine03 as float) +
                  (INSERTED.QtyPicked * INSERTED.UnitPrice) -
                  (DELETED.QtyPicked * DELETED.UnitPrice) as NVARCHAR(18)),    -- bug fix
                  EditDate = GETDATE(), EditWho=SUSER_SNAME(),     --tlting
                  TrafficCop = NULL
                  FROM ORDERS
                  JOIN INSERTED ON (INSERTED.OrderKey = ORDERS.OrderKey)
                  JOIN DELETED  ON (DELETED.OrderKey = ORDERS.OrderKey AND DELETED.OrderKey = INSERTED.OrderKey)
               END -- @n_DeletedCount = 1
               ELSE
               BEGIN
                  /* Multiple rows in the detail table were updated */
                  /* Sum up the details.openqty and update the openqty on the header */
                  DECLARE @Ord_TotPrice TABLE (OrderKey NVARCHAR(10), TotPrice float)

                  INSERT INTO @Ord_TotPrice
                  SELECT DELETED.OrderKey, Sum(INSERTED.QtyPicked * INSERTED.UnitPrice) - SUM(DELETED.QtyPicked * DELETED.UnitPrice)
                  FROM DELETED
                  JOIN INSERTED ON INSERTED.Orderkey = DELETED.Orderkey
                  AND INSERTED.OrderLineNumber = DELETED.OrderLineNumber
                  GROUP BY DELETED.OrderKey

                  IF EXISTS(SELECT 1 FROM @Ord_TotPrice WHERE TotPrice <> 0)
                  BEGIN
                     UPDATE ORDERS WITH (ROWLOCK) SET UserDefine03 = UserDefine03 + TotPrice,    -- bug fix
                        EditDate = GETDATE(), EditWho=SUSER_SNAME(),
                        TrafficCop = NULL
                     FROM ORDERS, @Ord_TotPrice AS OrdPrice
                     WHERE ORDERS.Orderkey = OrdPrice.Orderkey
                     AND ISNUMERIC(UserDefine03 ) = 1
                  END
               END
               -- EndHere (SHONG_20060413)
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  /* Trap SQL Server Error */
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61743 --63014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (ntrOrderDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  /* End Trap SQL Server Error */
               END
            END -- UPDATE(QtyPicked)
         END -- @c_NotUpdUD03 <> '1'
      END


      IF (@n_continue = 1 or @n_continue=2)
      BEGIN
         -- To trigger Order Status
         IF ( UPDATE(QtyAllocated) OR UPDATE(QtyPicked) ) -- (SHONG_20060413)
            AND NOT UPDATE(OpenQty)
         BEGIN
            SET @c_OrderKey = ''

            -- SWT02 performance tuning
            DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT INSERTED.OrderKey
            FROM INSERTED
            JOIN DELETED ON INSERTED.OrderKey = DELETED.Orderkey AND
                            INSERTED.OrderLineNumber = DELETED.OrderLineNumber
            GROUP BY INSERTED.OrderKey
            HAVING (SUM(INSERTED.QtyAllocated) <> SUM(DELETED.QtyAllocated)) OR
                   (SUM(INSERTED.QtyPicked) <> SUM(DELETED.QtyPicked))

            OPEN CUR_ORDERKEY

            FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE ORDERS  With (ROWLOCK)
                  SET EditDate = GETDATE(), EditWho=Suser_sname()
               WHERE OrderKey = @c_OrderKey

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61744
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (ntrOrderDetailUpdate)"
                  + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END

            	FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey
            END
            CLOSE CUR_ORDERKEY
            DEALLOCATE CUR_ORDERKEY
         END
      END
      /* Update ORDERS.OpenQty */
      IF (@n_continue = 1 or @n_continue=2)
      BEGIN
         -- Added By SHONG On 10-Jul-2013
         -- Performance Tuning
         IF UPDATE(OpenQty)
         -- SWT01
         --AND EXISTS(SELECT 1 FROM INSERTED
         --     JOIN DELETED ON INSERTED.Orderkey = DELETED.Orderkey
         --          AND INSERTED.OrderLineNumber = DELETED.OrderLineNumber
         --     WHERE INSERTED.OpenQty <> DELETED.OpenQty)
         BEGIN
            SELECT @n_DeletedCount = (select count(*) FROM DELETED)
            IF @n_DeletedCount = 1
            BEGIN
               /* Only one row updated in the detail table. */
               UPDATE ORDERS WITH (ROWLOCK)
               SET  OpenQty = ORDERS.OpenQty + INSERTED.OpenQty - DELETED.OpenQty,
                  EditDate = GETDATE(),   --tlting
                  EditWho = SUSER_SNAME()
               FROM ORDERS, INSERTED, DELETED
               WHERE ORDERS.OrderKey = INSERTED.OrderKey
                 AND INSERTED.OrderKey = DELETED.OrderKey
            END
            ELSE
            BEGIN
               /* Multiple rows in the detail table were updated */
               /* Sum up the details.openqty and update the openqty on the header */
               UPDATE ORDERS WITH (ROWLOCK)
               SET ORDERS.OpenQty
               = (Orders.Openqty
               -
               (Select Sum(DELETED.OpenQty) From DELETED
               Where DELETED.OrderKey = ORDERS.OrderKey)
               +
               (Select Sum(INSERTED.OpenQty) From INSERTED
               Where INSERTED.OrderKey = ORDERS.OrderKey)
               ),
               EditDate = GETDATE(),   --tlting
               EditWho = SUSER_SNAME()
               FROM ORDERS,DELETED,INSERTED
               WHERE ORDERS.Orderkey IN (SELECT Distinct Orderkey From DELETED)
               AND ORDERS.Orderkey = DELETED.Orderkey
               AND ORDERS.Orderkey = INSERTED.Orderkey
               AND INSERTED.Orderkey = DELETED.Orderkey
               AND INSERTED.OrderLineNumber = DELETED.OrderLineNumber
            END

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               /* Trap SQL Server Error */
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61745 --63014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (ntrOrderDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               /* End Trap SQL Server Error */
         END
         END -- update (openqty)
      END

   END
   /* Main Processing ends */

   /* Post Process Starts */
   IF (@n_continue = 1 or @n_continue=2)
   BEGIN
      IF EXISTS ( SELECT 1 FROM ORDERDETAIL with (NOLOCK)
                  JOIN INSERTED ON ORDERDETAIL.OrderKey = INSERTED.Orderkey
                                AND ORDERDETAIL.OrderLineNumber = INSERTED.OrderLineNumber
                  WHERE ORDERDETAIL.STATUS in ( '9' , 'CANC') )
             AND NOT UPDATE(EditDate)
      BEGIN
         -- TLTING01
         UPDATE ORDERDETAIL with (ROWLOCK)
         SET EditDate   = GETDATE(),
             EditWho    = Suser_sname(),
             TrafficCop = NULL
         FROM ORDERDETAIL
         JOIN INSERTED ON ORDERDETAIL.OrderKey = INSERTED.Orderkey
                        AND ORDERDETAIL.OrderLineNumber = INSERTED.OrderLineNumber
         WHERE ORDERDETAIL.STATUS in ( '9' , 'CANC')
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61746 --63014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERDETAIL. (ntrOrderDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END
      --2024-09-09 - START
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.[Status] = 'CANC')
         BEGIN
            SET @CUR_UPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT od.Orderkey
            FROM INSERTED i
            JOIN ORDERDETAIL od (NOLOCK) ON  od.Orderkey = i.Orderkey
            WHERE i.[Status] = 'CANC'
            GROUP BY od.Orderkey
            HAVING COUNT(1) = SUM(CASE WHEN od.[Status] = 'CANC' THEN 1 ELSE 0 END)
            ORDER BY od.Orderkey

            OPEN @CUR_UPD

            FETCH NEXT FROM @CUR_UPD INTO @c_Orderkey

            WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
            BEGIN
               UPDATE ORDERS WITH (ROWLOCK)
                  SET [Status] = 'CANC'
                     ,SOStatus = 'CANC'
                     ,Trafficcop = NULL
               WHERE Orderkey = @c_Orderkey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
               END

               FETCH NEXT FROM @CUR_UPD INTO @c_Orderkey
            END
            CLOSE @CUR_UPD
            DEALLOCATE @CUR_UPD

            IF @n_Continue IN (1,2)
            BEGIN
				   INSERT INTO [dbo].[ORDERDETAIL_CANCLOG]
				   ([OrderKey],[OrderLineNumber],[OrderDetailSysId]
               ,[ExternOrderKey],[ExternLineNo]
				   ,[Sku],[StorerKey],[ManufacturerSku],[RetailSku],[AltSku]
				   ,[OriginalQty],[OpenQty],[ShippedQty],[AdjustedQty]
				   ,[QtyPreAllocated],[QtyAllocated],[QtyPicked],[UOM],[PackKey],[PickCode]
				   ,[CartonGroup],[Lot],[ID],[Facility],[Status]
               ,[UnitPrice],[Tax01],[Tax02],[ExtendedPrice],[UpdateSource]
               ,[Lottable01],[Lottable02],[Lottable03],[Lottable04],[Lottable05]
               ,[EffectiveDate],[AddDate],[AddWho],[EditDate],[EditWho],[TrafficCop],[ArchiveCop]
               ,[TariffKey],[FreeGoodQty]
				   ,[GrossWeight],[Capacity],[LoadKey],[MBOLKey],[QtyToProcess],[MinShelfLife]
               ,[UserDefine01],[UserDefine02],[UserDefine03],[UserDefine04],[UserDefine05]
               ,[UserDefine06],[UserDefine07],[UserDefine08],[UserDefine09],[POkey],[ExternPOKey],[UserDefine10]
               ,[EnteredQTY],[ConsoOrderKey],[ExternConsoOrderKey],[ConsoOrderLineNo]
               ,[Lottable06],[Lottable07],[Lottable08],[Lottable09],[Lottable10]
               ,[Lottable11],[Lottable12],[Lottable13],[Lottable14],[Lottable15]
               ,[Notes],[Notes2],[Channel],[HashValue],[SalesChannel],[CancelReasonCode])
	            SELECT d.[OrderKey],d.[OrderLineNumber],d.[OrderDetailSysId]
               ,d.[ExternOrderKey],d.[ExternLineNo]
				   ,d.[Sku],d.[StorerKey],d.[ManufacturerSku],d.[RetailSku],d.[AltSku]
				   ,d.[OriginalQty],0,d.[ShippedQty],d.[AdjustedQty]
				   ,d.[QtyPreAllocated],d.[QtyAllocated],d.[QtyPicked],d.[UOM],d.[PackKey],d.[PickCode]
				   ,d.[CartonGroup],d.[Lot],d.[ID],d.[Facility],i.[Status]
               ,d.[UnitPrice],d.[Tax01],d.[Tax02],d.[ExtendedPrice],d.[UpdateSource]
               ,d.[Lottable01],d.[Lottable02],d.[Lottable03],d.[Lottable04],d.[Lottable05]
               ,d.[EffectiveDate],d.[AddDate],d.[AddWho],d.[EditDate],d.[EditWho],d.[TrafficCop],d.[ArchiveCop]
               ,d.[TariffKey],d.[FreeGoodQty]
				   ,d.[GrossWeight],d.[Capacity],d.[LoadKey],d.[MBOLKey],d.[QtyToProcess],d.[MinShelfLife]
               ,d.[UserDefine01],d.[UserDefine02],d.[UserDefine03],d.[UserDefine04],d.[UserDefine05]
               ,d.[UserDefine06],d.[UserDefine07],d.[UserDefine08],d.[UserDefine09],d.[POkey],d.[ExternPOKey],d.[UserDefine10]
               ,d.[EnteredQTY],d.[ConsoOrderKey],d.[ExternConsoOrderKey],d.[ConsoOrderLineNo]
               ,d.[Lottable06],d.[Lottable07],d.[Lottable08],d.[Lottable09],d.[Lottable10]
               ,d.[Lottable11],d.[Lottable12],d.[Lottable13],d.[Lottable14],d.[Lottable15]
               ,d.[Notes],d.[Notes2],d.[Channel],d.[HashValue],d.[SalesChannel],d.[CancelReasonCode]
   			   FROM INSERTED i
               JOIN DELETED d (NOLOCK) ON d.Orderkey = i.Orderkey
                                       AND d.OrderlineNumber = i.OrderLinenumber
               WHERE i.[Status] = 'CANC'
               AND d.[Status] <> 'CANC'
            END
         END
      END
      --2024-09-09 - END
   END
   /* #INCLUDE <TRODU2.SQL> */
   /* Post Process Ends */

   /* Return Statement */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrOrderDetailUpdate'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
     /* End Return Statement */
END
GO