SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrOrderDetailDelete                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* PVCS Version: 1.13                                                   */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Purposes                                        */
/* 17-Jan-2003  Shong   SOS Ticket 9421, Order Header Gross Weight =    */
/*                      ZERO. Problem found in one update statement     */
/*                      which doesn't consider. OrderLine when deducting*/
/*                      Weigth from Order Header.                       */
/* 04-Apr-2008  Shong   Delete DEL_OrderDetail When Records exists and  */
/*                      Insert new records.                             */ 
/* 17-Jul-2009  TLTING  Add column UserDefine10 (tlting01)              */                                                      
/* 24-Aug-2009  TLTING  Add column EnteredQty (tlting02)                */ 
/* 28-Apr-2011  KHLim01 Insert Delete log                               */
/* 14-Jul-2011  KHLim02 GetRight for Delete log                         */
/* 14-Mar-2012  KHLim03 Update EditDate                                 */
/* 22-May-2012  TLTING02 Data integrity - insert dellog 4 status < '9'  */
/* 03-Jun-2013  YTWan   Delete OrderdetailRef when delete Orderdetail.  */
/*                      Add orderinfor and orderdetailref to Orders     */
/*                      screen. - table without screen. (Wan01)         */
/* 12-May-2014  YTWan   SOS#310515 - New Requirement Caculate           */
/*                      Orders.Capacity from Pack module (Wan02)        */
/* 11-June-2014 CSCHONG Add Lottable06-15 (CS01)                        */
/* 29-Sep-2018  TLTING  performance tune                                */
/* 07-May-2024  NJOW01  UWP-18748  Allow config to call custom sp       */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrOrderDetailDelete]
ON [dbo].[ORDERDETAIL]
FOR DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
   @n_err              int,       -- Error number returned by stored procedure or this trigger
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
   @n_starttcnt        int,       -- Holds the current transaction count
   @n_cnt              int        -- Holds @@ROWCOUNT
  ,@c_authority        NVARCHAR(1)  -- KHLim02

   , @c_facility        NVARCHAR(5)    --(Wan02)
   , @c_Storerkey       NVARCHAR(15)   --(Wan02)
   , @c_OrdWgtVol       NVARCHAR(10)   --(Wan02)
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   /* #INCLUDE <TRODD1.SQL> */

   if (select count(*) from DELETED) = 
      (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
   
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
                   'DELETE'  -----> @c_Action can be INSERT, UPDATE, DELETE
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
   
   IF EXISTS ( SELECT 1 FROM DELETED WHERE [STATUS] < '9' ) AND (@n_continue = 1 or @n_continue=2)
   BEGIN
      -- Start (KHLim01) 
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 0         --    Start (KHLim02)
         EXECUTE nspGetRight  NULL,             -- facility  
                              NULL,             -- Storerkey  
                              NULL,             -- Sku  
                              'DataMartDELLOG', -- Configkey  
                              @b_success     OUTPUT, 
                              @c_authority   OUTPUT, 
                              @n_err         OUTPUT, 
                              @c_errmsg      OUTPUT  
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrOrderDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE 
         IF @c_authority = '1'         --    End   (KHLim02)
         BEGIN
            -- Orderdetail status not reliable - like Orders 'CANC' not update to OD
            INSERT INTO dbo.ORDERDETAIL_DELLOG ( OrderKey, OrderLineNumber )
            SELECT DELETED.OrderKey, DELETED.OrderLineNumber 
            FROM DELETED
               JOIN ORDERS O (NOLOCK) on O.Orderkey = DELETED.Orderkey
            WHERE O.[STATUS] < '9'

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table OrderDetail Failed. (ntrOrderDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END
            -- Orderdetail with Orders - us OD status.
            IF @n_cnt = 0
            BEGIN
               INSERT INTO dbo.ORDERDETAIL_DELLOG ( OrderKey, OrderLineNumber )
               SELECT OrderKey, OrderLineNumber 
               FROM DELETED
               WHERE [STATUS] < '9'

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table OrderDetail Failed. (ntrOrderDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
               END
            END
         END
      END
      -- End (KHLim01) 
   END

   -- Added By SHONG 
   -- Date: 13-Feb-2004
   -- SOS#19801 
   -- Do not allow to delete Cancel Orders if StorerConfig = NotAllowDelCancOrd is Turn ON
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS(SELECT 1 
                FROM  ORDERS (NOLOCK)
                JOIN  DELETED ON (ORDERS.ORDERKEY = DELETED.ORDERKEY)
                JOIN  StorerConfig (NOLOCK) ON (ORDERS.StorerKey = StorerConfig.StorerKey AND
                                                DELETED.StorerKey = StorerConfig.StorerKey AND
                                                StorerConfig.ConfigKey = 'NotAllowDelCancOrd' AND
                                                StorerConfig.sValue = '1')
                WHERE (ORDERS.SOStatus = 'CANC' OR ORDERS.Status = 'CANC')
                )
      BEGIN
         SELECT @n_continue = 3 , @n_err = 62604
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Canceled Order(s) Not Allow to Delete. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

 -- Added By SHONG
   -- Date: 21 May 2002
   -- CLOSE ORDER WHEN no Detail Line
   -- Begin
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL (NOLOCK), DELETED WHERE ORDERDETAIL.ORDERKEY = DELETED.ORDERKEY)
      BEGIN
         UPDATE ORDERS 
            SET Status = 'CANC', -- = '9', 
                SOStatus = 'CANC', -- Added by SHONG. SOS# 6845
                EditDate = GETDATE(), -- KHLim03
                TrafficCop = NULL
         FROM DELETED, StorerConfig (NOLOCK)
         WHERE ORDERS.OrderKey = DELETED.OrderKey
         AND   ORDERS.StorerKey = StorerConfig.StorerKey
         AND   StorerConfig.ConfigKey = 'OWITF'
         AND   StorerConfig.sValue = '1'
         AND   NOT EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE ORDERDETAIL.ORDERKEY = DELETED.ORDERKEY
               AND ORDERS.OrderKey = DELETED.OrderKey)
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ORDERS Failed. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   -- End

   -- trigantic tracking of deleted order: wally 25.jul.03
   -- start
   if @n_continue <> 4
   BEGIN
      IF EXISTS(SELECT 1 FROM DEL_ORDERDETAIL DO (NOLOCK)
                JOIN DELETED ON DO.OrderKey = DELETED.OrderKey AND DO.OrderLineNumber = DELETED.OrderLineNumber)
      BEGIN
         DELETE DEL_ORDERDETAIL 
         FROM   DEL_ORDERDETAIL DO 
         JOIN   DELETED ON DO.OrderKey = DELETED.OrderKey AND DO.OrderLineNumber = DELETED.OrderLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete DEL_ORDERDETAIL Failed. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END         
      END

      INSERT INTO DEL_ORDERDETAIL(OrderKey, OrderLineNumber, OrderDetailSysId, ExternOrderKey, ExternLineNo, 
                  Sku, StorerKey, ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty, ShippedQty, 
                  AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, UOM, PackKey, PickCode, 
                  CartonGroup, Lot, ID, Facility, Status, UnitPrice, Tax01, Tax02, ExtendedPrice, 
                  UpdateSource, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, EffectiveDate, 
                  AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, TariffKey, 
                  FreeGoodQty, GrossWeight, Capacity, LoadKey, MBOLKey, QtyToProcess, MinShelfLife, 
                  UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, 
                  UserDefine07, UserDefine08, UserDefine09, pokey, ExternPOKey, UserDefine10,
                  EnteredQty, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,Lottable11, Lottable12, Lottable13, Lottable14, Lottable15 )  --(CS01)
      SELECT OrderKey, OrderLineNumber, OrderDetailSysId, ExternOrderKey, ExternLineNo, 
                  Sku, StorerKey, ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty, ShippedQty, 
                  AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, UOM, PackKey, PickCode, 
                  CartonGroup, Lot, ID, Facility, Status, UnitPrice, Tax01, Tax02, ExtendedPrice, 
                  UpdateSource, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, EffectiveDate, 
                  getdate(), suser_sname(), getdate(), suser_sname(), TrafficCop, ArchiveCop, TariffKey, 
                  FreeGoodQty, GrossWeight, Capacity, LoadKey, MBOLKey, QtyToProcess, MinShelfLife, 
                  UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, 
                  UserDefine07, UserDefine08, UserDefine09, pokey, EXternPOKey, UserDefine10,    -- tlting01 
                  EnteredQty,Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,Lottable11, Lottable12, Lottable13, Lottable14, Lottable15                   -- tlting02  --CS01
      FROM DELETED
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert DEL_ORDERDETAIL Failed. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END         
   END
-- end

   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS ( SELECT * FROM deleted WHERE shippedqty <> 0 )
      BEGIN
         SELECT @n_continue = 3 , @n_err = 62604
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On ORDERDETAIL Failed Because lineitem(s) are shipped. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS ( SELECT  1 FROM PickDetail (NOLOCK), Deleted
            WHERE PickDetail.OrderKey=Deleted.OrderKey
            AND PickDetail.OrderLineNumber=Deleted.OrderLineNumber     )
      BEGIN
         DELETE PickDetail FROM PickDetail, Deleted
         WHERE PickDetail.OrderKey=Deleted.OrderKey
         AND PickDetail.OrderLineNumber=Deleted.OrderLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On ORDERDETAIL Failed. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS ( SELECT  1 FROM PreAllocatePickDetail (NOLOCK), Deleted
            WHERE PreAllocatePickDetail.OrderKey=Deleted.OrderKey
            AND PreAllocatePickDetail.OrderLineNumber=Deleted.OrderLineNumber     )
      BEGIN
         DELETE PreAllocatePickDetail FROM PreAllocatePickDetail, Deleted
         WHERE PreAllocatePickDetail.OrderKey=Deleted.OrderKey
         AND PreAllocatePickDetail.OrderLineNumber=Deleted.OrderLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62606   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On ORDERDETAIL Failed. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   --(Wan01) Start
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS ( SELECT  1 FROM OrderdetailRef (NOLOCK), Deleted
            WHERE OrderdetailRef.OrderKey=Deleted.OrderKey
            AND OrderdetailRef.OrderLineNumber=Deleted.OrderLineNumber     )
      BEGIN
         DELETE OrderdetailRef 
         FROM OrderdetailRef 
         JOIN Deleted ON (OrderdetailRef.OrderKey=Deleted.OrderKey
                      AND OrderdetailRef.OrderLineNumber=Deleted.OrderLineNumber)
         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err = 62607   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On ORDERDETAIL Failed. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   --(Wan01) End

   IF @n_continue = 1 or @n_continue=2
   BEGIN
      DECLARE @n_deletedcount int
      SELECT @n_deletedcount = (select count(1) FROM deleted)
      IF @n_deletedcount = 1
      BEGIN
         UPDATE ORDERS
         SET  OpenQty = ORDERS.OpenQty - DELETED.OpenQty
         FROM ORDERS,
         DELETED
         WHERE     ORDERS.OrderKey = DELETED.OrderKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      END
      ELSE
      BEGIN
         UPDATE ORDERS SET ORDERS.OpenQty
         = (Orders.Openqty
         -
         (Select Sum(DELETED.OpenQty) From DELETED
         Where DELETED.OrderKey = ORDERS.OrderKey)
         )
         FROM ORDERS,DELETED
         WHERE ORDERS.Orderkey IN (SELECT Distinct Orderkey From DELETED)
         AND ORDERS.Orderkey = DELETED.Orderkey
      END
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62605   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert failed on table ORDERS. (ntrOrderDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   /*---------------------------------------------Customistation Start -----------------------------------------------------------*/
   /*  Date : 15/9/99
       FBR : 005
       Author : HPH
       Purpose
       Parameters :
   -------------------------------------------------------------------------------------------------------------------------------*/

   -------------------------
   -- Fixed By SHONG 17-Jan-2003
   -- To Calclulate the Weight and Capacity for Order Header base on DELETED Orderdetail
   -- Begin
   --(Wan02) - START
   SELECT @c_facility = ORDERS.Facility
         ,@c_StorerKey= ORDERS.Storerkey
   FROM ORDERS WITH (NOLOCK)
   JOIN DELETED WITH (NOLOCK) ON (ORDERS.Orderkey = DELETED.Orderkey)

   Execute nspGetRight @c_facility 
        ,  @c_StorerKey                -- Storer
        ,  ''                          -- Sku
        ,  'WgtnVolCalcInOrd'          -- ConfigKey
        ,  @b_success               output  
        ,  @c_OrdWgtVol             output  
        ,  @n_err                   output  
        ,  @c_errmsg                output

   If @b_success <> 1
   Begin
      SET @n_continue = 3 
      SET @c_errmsg = CONVERT(CHAR(250),@n_err)
      SEt @n_err=62904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve of Right (WgtnVolCalcInOrd) Failed (ntrOrderDetailDelete)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
   End
   
   --(Wan02) - END
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      --(Wan02) - START
      CREATE TABLE #TMP_WGTCUBE
         (  Orderkey    NVARCHAR(10)
         ,  Weight      DECIMAL(15,5)  DEFAULT (0)
         ,  CBM         DECIMAL(15,5)  DEFAULT (0)
         )

      INSERT INTO #TMP_WGTCUBE
         (  Orderkey
         ,  Weight
         ,  CBM
         )
      SELECT DELETED.Orderkey
            ,Weight = ISNULL(SUM(DELETED.OpenQty * SKU.STDGROSSWGT), 0.00000)
            ,CBM    = ISNULL(SUM(CASE WHEN @c_OrdWgtVol = '2' AND PACK.CubeUOM1 > 0 AND PACK.CaseCnt > 0 
                                      THEN (DELETED.OpenQty * (PACK.CubeUOM1 / PACK.CaseCnt))
                                      ELSE (DELETED.OpenQty * SKU.STDCUBE)
                                      END), 0.00000)
      FROM DELETED
      JOIN SKU  WITH (NOLOCK) ON (DELETED.StorerKey = SKU.StorerKey)                                                  --(Wan02) 
                             AND(DELETED.SKU = SKU.SKU) 
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
      GROUP BY DELETED.Orderkey
      --(Wan02) - END
       SELECT @n_DeletedCount = (SELECT count(*) FROM DELETED)
       IF @n_DeletedCount = 1
       BEGIN
           UPDATE ORDERS
           SET  --ORDERS.GrossWeight = ORDERS.Capacity - (DELETED.OpenQty * SKU.STDGROSSWGT),                              --(Wan02)
                --ORDERS.Capacity = ORDERS.Capacity + (DELETED.OpenQty * SKU.STDCUBE) , TrafficCop = NULL                  --(Wan02)
                ORDERS.GrossWeight=CONVERT(FLOAT, CONVERT(DECIMAL(15,5), ORDERS.GrossWeight) - #TMP_WGTCUBE.Weight)        --(Wan02)
               ,ORDERS.Capacity   =CONVERT(FLOAT, CONVERT(DECIMAL(15,5), ORDERS.Capacity) - #TMP_WGTCUBE.CBM)              --(Wan02)                                                         --(Wan02)
               ,TrafficCop = NULL                                                                                          
               ,EditDate = GETDATE() -- KHLim03
           --FROM ORDERS, DELETED, SKU (NOLOCK)                                                                            --(Wan02)
           --WHERE ORDERS.OrderKey = DELETED.OrderKey                                                                      --(Wan02)      
           --AND   DELETED.StorerKey = SKU.StorerKey                                                                       --(Wan02)
           --AND   DELETED.SKU = SKU.SKU                                                                                   --(Wan02)
           FROM ORDERS                                                                                                     --(Wan02)   
           JOIN DELETED            ON (ORDERS.OrderKey = DELETED.OrderKey)                                                 --(Wan02) 
           JOIN SKU  WITH (NOLOCK) ON (DELETED.StorerKey = SKU.StorerKey)                                                  --(Wan02) 
                                   AND(DELETED.SKU = SKU.SKU)                                                              --(Wan02) 
           JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)                                                         --(Wan02) 
           JOIN #TMP_WGTCUBE ON (DELETED.Orderkey = #TMP_WGTCUBE.Orderkey)                                                 --(Wan02)    
                                                       
       END
       ELSE BEGIN
           UPDATE ORDERS 
               SET --GrossWeight = ORDERS.GrossWeight + (SELECT SUM(DELETED.OpenQty * SKU.STDGROSSWGT)                     --(Wan02)
                   --      FROM DELETED (NOLOCK), SKU (NOLOCK)                                                             --(Wan02)
                   --    WHERE DELETED.OrderKey = Orders.OrderKey                                                          --(Wan02)
                   --    AND  DELETED.Storerkey = SKU.Storerkey                                                            --(Wan02)
                   --    AND  DELETED.SKU = SKU.SKU),                                                                      --(Wan02)          
                   --Capacity = ORDERS.Capacity + (SELECT SUM(DELETED.OpenQty * SKU.STDCUBE)                               --(Wan02)
                   --    FROM DELETED (NOLOCK), SKU (NOLOCK)                                                               --(Wan02)
                   --    WHERE DELETED.OrderKey = Orders.OrderKey                                                          --(Wan02)
                   --    AND  DELETED.Storerkey = SKU.Storerkey                                                            --(Wan02)       
                   --    AND  DELETED.SKU = SKU.SKU)                                                                       --(Wan02)
                   ORDERS.GrossWeight=CONVERT(FLOAT, CONVERT(DECIMAL(15,5), ORDERS.GrossWeight) - #TMP_WGTCUBE.Weight)     --(Wan02)
                  ,ORDERS.Capacity   =CONVERT(FLOAT, CONVERT(DECIMAL(15,5), ORDERS.Capacity) - #TMP_WGTCUBE.CBM)           --(Wan02)                                                      --(Wan02)
                  ,TrafficCop = NULL 
                  ,EditDate = GETDATE() -- KHLim03
         --(Wan02) - START
         --  FROM ORDERS,DELETED
         --  WHERE ORDERS.Orderkey IN (Select Distinct Orderkey From DELETED) 
         --  AND ORDERS.Orderkey = DELETED.Orderkey
         FROM ORDERS
         JOIN DELETED ON (ORDERS.OrderKey = DELETED.OrderKey)
         JOIN #TMP_WGTCUBE ON (DELETED.Orderkey = #TMP_WGTCUBE.Orderkey)
         WHERE ORDERS.OrderKey IN (Select Distinct OrderKey From DELETED)
         --(Wan02) - END
       END
  
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
       IF @n_err <> 0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ORDERS Gross Weight and Volume Failed. (ntrOrderDetailDelete)" + " 
                  ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
   END
   -- End of Shong Fixed
 
   /* -------------------------------------------- Customisation of FBR005 ends --------------------------------------------*/

   /* #INCLUDE <TRODD2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrOrderDetailDelete"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO