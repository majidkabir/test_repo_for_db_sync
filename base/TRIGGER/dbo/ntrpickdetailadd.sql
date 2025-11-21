SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPickDetailAdd                                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When records Added                                        */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 10-Apr-2009  SHONG         Added ConfigKey "ForceAllocLottable"      */
/*                            Prevent user to choose wrong Lottable     */
/* 11-Sep-2010  SHONG         Prevent Overallocation for non pick loc   */
/*                            AND Diff Facility with Orders             */
/* 06-May-2011  Shong         Fixing bug for Preallocate Detail Off set */
/*                            issues SHONG01                            */
/* 24-Jun-2011  NJOW01        Allow over allocation for dynamic         */
/*                            permenent loc                             */
/* 02-Dec-2011  MCTang        Add WAVEUPDLOG for WCS-WAVE Status Change */
/*                            Export(MC01)                              */
/* 22-May-2012  KHLim01       Update LOT & LOTxLOCxID.EditDate          */
/* 05-Jun-2013  James         SOS276541 - Prevent allocation from       */
/*                            WS01 - Temporarily (james01)              */
/* 03-Jun-2014  Leong         SOS# 312878 - Enhance to unique @n_err.   */
/* 29-Jun-2015  NJOW02        342109-Update SKUXLOC cater for DYNPPICK  */
/* 15-Sep-2015  NJOW03        352837 - update pickslip# to pickdetail   */
/* 20-Sep-2016  TLTING        Change SET ROWCOUNT 1 to TOP 1            */
/* 28-Oct-2016  SHONG02       Performance Tuning Update OrderDetail     */
/* 28-Sep-2017  TLTING01      Performance Tuning Update OrderDetail     */
/* 20-Sep-2017  SHONG03       Change update sequence to prevent Deadlock*/
/* 06-Feb-2018  SHONG04       Added Channel Management Logic            */
/* 28-Sep-2018  TLTING  1.1   remove #tmp , remmove update row lock     */
/* 23-JUL-2019  Wan01   3.8   ChannelInventoryMgmt use fnc_SelectGetRight*/
/* 03-Aug-2021  Wan02   3.0   consistence with Pickdetail Update -Check */
/*                            no over allocate when AllowOverAllocations*/
/*                            turn off                                  */
/* 28-Sep-2021  SYChua        Fix: Added CLOSE and DEALLOCATE statement */
/*                            for cursor: CUR_CHANNEL_MGMT  (SY01)      */
/************************************************************************/
CREATE  TRIGGER [dbo].[ntrPickDetailAdd]
ON  [dbo].[PICKDETAIL]
FOR INSERT
AS
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
     @b_Success         INT           -- Populated by calls to stored procedures - was the proc successful?
   , @n_err             INT           -- Error number returned by stored procedure OR this trigger
   , @n_err2            INT           -- For Additional Error Detection
   , @c_errmsg          NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
   , @n_Continue        INT
   , @n_starttcnt       INT           -- Holds the current transaction count
   , @c_preprocess      NVARCHAR(250) -- preprocess
   , @c_pstprocess      NVARCHAR(250) -- post process
   , @n_cnt             INT
   , @n_PickDetailSysId INT
   , @c_facility        NVARCHAR(5)
   , @c_Storerkey       NVARCHAR(15)
   , @c_UpdPickslipToPickDet NVARCHAR(10)  --NJOW03
   , @c_Pickheaderkey   NVARCHAR(10) --NJOW03
   , @c_PrevOrderKey    NVARCHAR(10) --NJOW03
   , @c_OrderLineNumber NVARCHAR(5)
   , @n_InsertedRows    INT = 0


SELECT @n_InsertedRows = COUNT(*)
FROM   INSERTED

SELECT @n_Continue = 1, @n_starttcnt = @@TRANCOUNT
DECLARE @c_AllowOverAllocations NVARCHAR(1) -- Flag to see if overallocations are allowed.
/* #INCLUDE <TRPDA1.SQL> */
DECLARE @b_debug INT
SELECT @b_debug = 0

DECLARE @c_LOC_LocationType NVARCHAR(10)  --NJOW01

-- Added By SHONG
-- 30t Apr 2003
-- Do Nothing when ArchiveCop = '9'
IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_Continue = 4
   END
END
-- End 30th Apr 2003


IF (SELECT COUNT(*) FROM INSERTED WHERE OptimizeCop is not NULL ) > 0
BEGIN
   -- SHONG03 Bug Fixing
   UPDATE PICKDETAIL
      SET OptimizeCop = NULL, TrafficCop = NULL
   FROM PICKDETAIL
   JOIN INSERTED ON PICKDETAIL.PickDetailKey = INSERTED.PickDetailKey

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Trigger On PickDetail Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   ELSE
   BEGIN
      SELECT @n_Continue = 4
   END
END


-- Add by June 1.JUL.02 for IDSV5, extract from IDSSG *** Start
-- Added By SHONG
-- To Force not to accept STATUS equal to PICKED, when INSERTED
IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   IF EXISTS(SELECT PickDetailKey FROM INSERTED WHERE STATUS IN ('3','4','5','6','7','8','9'))
   BEGIN
      SELECT @n_Continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Trigger On PickDetail Failed. Status Must Equal to NORMAL (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END -- Add by June 1.JUL.02 for IDSV5, extract from IDSSG *** End
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   DECLARE @c_OrderKey         NVARCHAR(10),
           @c_Line             NVARCHAR(5),
           @c_LOT              NVARCHAR(10),
           @c_Lottable01_order NVARCHAR(18),
           @c_Lottable02_order NVARCHAR(18),
           @c_Lottable03_order NVARCHAR(18),
           @c_Lottable01       NVARCHAR(18),
           @c_Lottable02       NVARCHAR(18),
           @c_Lottable03       NVARCHAR(18)

   SELECT @c_OrderKey  = OrderKey,
          @c_Line      = OrderLineNumber,
          @c_LOT       = LOT,
          @c_StorerKey = StorerKey
   FROM INSERTED

   IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
             WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ForceAllocLottable' AND sValue = '1')
   BEGIN
      SELECT @c_Lottable01_order = Lottable01,
             @c_Lottable02_order = Lottable02,
             @c_Lottable03_order = Lottable03
      FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey        = @c_OrderKey
        AND OrderLineNumber = @c_Line

      SELECT @c_Lottable01 = Lottable01,
             @c_Lottable02 = Lottable02,
             @c_Lottable03 = Lottable03
      FROM LOTATTRIBUTE (NOLOCK)
      WHERE lot = @c_LOT

      IF ( ISNULL(@c_Lottable01_order, '') <> '' AND @c_Lottable01_order <> @c_Lottable01) OR
         ( ISNULL(@c_Lottable02_order, '') <> '' AND @c_Lottable02_order <> @c_Lottable02) OR
         ( ISNULL(@c_Lottable03_order, '') <> '' AND @c_Lottable03_order <> @c_Lottable03)
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63113   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LOT CHOSEN IS INVALID! Lot Attributes Does Not Match'
      END
   END
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   DECLARE @c_PrevStorerKey   NVARCHAR(15),
           @c_PrevFacility    NVARCHAR(10),
           @n_SL_QtyAllocated INT,
           @n_SL_QtyPicked    INT,
           @n_SL_Qty          INT,
           @c_LOC             NVARCHAR(10),
           @c_LocationType    NVARCHAR(10),
           @n_Qty             INT,
           @c_SKU             NVARCHAR(20)

   SET @c_PrevStorerKey = ''
   SET @c_PrevFacility  = ''
   SET @c_PrevOrderKey = '' --NJOW03

   DECLARE Cursor_SKUxLOC_Check CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT INSERTED.OrderKey, LOC.FACILITY, INSERTED.Loc, INSERTED.StorerKey, INSERTED.SKU, SUM(INSERTED.Qty)
      FROM INSERTED
      JOIN  LOC (NOLOCK) ON LOC.LOC = INSERTED.Loc
      JOIN  SKUxLOC WITH (NOLOCK) ON SKUxLOC.StorerKey = INSERTED.StorerKey AND
            SKUxLOC.SKU = INSERTED.SKU AND
            SKUxLOC.LOC = INSERTED.Loc
      GROUP BY INSERTED.OrderKey, LOC.FACILITY, INSERTED.Loc, INSERTED.StorerKey, INSERTED.SKU
      ORDER BY LOC.FACILITY, INSERTED.StorerKey, INSERTED.OrderKey

   OPEN Cursor_SKUxLOC_Check

   FETCH NEXT FROM Cursor_SKUxLOC_Check INTO
                   @c_OrderKey, @c_Facility, @c_LOC, @c_StorerKey, @c_SKU, @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_PrevStorerKey <> @c_StorerKey OR @c_PrevFacility <> @c_Facility
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspGetRight @c_facility, -- facility
                             @c_Storerkey,    -- StorerKey
                             NULL,   -- Sku
                             'ALLOWOVERALLOCATIONS', -- Configkey
                             @b_success    OUTPUT,
                             @c_AllowOverAllocations OUTPUT,
                             @n_err        OUTPUT,
                             @c_errmsg     OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailAdd' + ISNULL(RTrim(@c_errmsg),'')
         END

         SET @c_PrevStorerKey = @c_StorerKey
         SET @c_PrevFacility  = @c_Facility

         IF NOT EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND
                       Facility = @c_Facility)
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err = 63114   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(varchar(5),@n_err)+'Location Facility NOT Match with Order Facility (ntrPickDetailAdd)'
         END

         --NJOW03
         SELECT @c_UpdPickslipToPickDet = ''
         SELECT @b_success = 0
         EXECUTE nspGetRight @c_facility, -- facility
                             @c_Storerkey,    -- StorerKey
                             NULL,   -- Sku
                             'UpdPickslipToPickDet', -- Configkey
                             @b_success    OUTPUT,
                             @c_UpdPickslipToPickDet OUTPUT,
                             @n_err        OUTPUT,
                             @c_errmsg     OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailAdd' + ISNULL(RTrim(@c_errmsg),'')
         END
      END -- @c_PrevStorerKey <> @c_StorerKey OR @c_PrevFacility <> @c_Facility

     SET @n_SL_Qty=0
      SET @n_SL_QtyAllocated = 0
      SET @n_SL_QtyPicked = 0

      SELECT @n_SL_QtyAllocated = QtyAllocated, @n_SL_QtyPicked = QtyPicked, @n_SL_Qty = Qty,
             @c_LocationType = LocationType
      FROM SKUxLOC WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU
      AND LOC = @c_LOC

      --NJOW01
      SELECT @c_LOC_LocationType = LocationType
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @c_LOC

      IF @n_SL_Qty < (@n_SL_QtyAllocated + @n_SL_QtyPicked + @n_Qty)
      BEGIN
         IF @c_AllowOverAllocations <> '1' AND (@c_LOC_LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK'))  --NJOW01
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err = 63115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(varchar(5),@n_err)+'Over Allocation NOT Allow (ntrPickDetailAdd)'
         END
         ELSE IF @c_LocationType NOT IN ('PICK', 'CASE') AND (@c_LOC_LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK'))  --NJOW01
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err = 63116   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(varchar(5),@n_err)+'Over Allocation NOT Allow for Non Pick Location (ntrPickDetailAdd)'
         END
      END

      --NJOW03
      IF @n_Continue IN (1,2) AND @c_UpdPickslipToPickDet = '1'
      BEGIN
          IF @c_PrevOrderKey <> @c_OrderKey
          BEGIN
             SET @c_Pickheaderkey = ''

             SELECT TOP 1 @c_Pickheaderkey = Pickheaderkey
             FROM PICKHEADER (NOLOCK)
             WHERE OrderKey = @c_OrderKey

             IF ISNULL(@c_Pickheaderkey ,'') = ''
             BEGIN
                 SELECT TOP 1 @c_Pickheaderkey  = PH.Pickheaderkey
                 FROM PICKHEADER PH (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON PH.ExternOrderKey = O.Loadkey
                 WHERE ISNULL(PH.OrderKey,'') = ''
                 AND ISNULL(O.Loadkey,'') <> ''
                 AND O.OrderKey = @c_OrderKey
             END

             IF ISNULL(@c_Pickheaderkey,'') <> ''
             BEGIN
                UPDATE PICKDETAIL
                SET PICKDETAIL.Pickslipno = @c_Pickheaderkey,
                    PICKDETAIL.TrafficCop = NULL
                FROM PICKDETAIL
                JOIN INSERTED I ON PICKDETAIL.PickDetailKey = I.PickDetailKey
                WHERE I.OrderKey = @c_OrderKey
             END
          END
      END
      SET @c_PrevOrderKey = @c_OrderKey

      FETCH NEXT FROM Cursor_SKUxLOC_Check INTO
                      @c_OrderKey, @c_Facility, @c_LOC, @c_StorerKey, @c_SKU, @n_Qty
   END -- WHILE
   CLOSE Cursor_SKUxLOC_Check
   DEALLOCATE Cursor_SKUxLOC_Check
END

--  IF @n_Continue = 1 OR @n_Continue = 2
--  BEGIN
--      IF EXISTS (SELECT 1 FROM INSERTED WHERE Status = '0')
--      BEGIN
--          Update PickDetail WITH (ROWLOCK) SET status="0" , TrafficCop = NULL
--          FROM PickDetail, INSERTED, DELETED
--          WHERE PickDetail.PickDetailKey = INSERTED.PickDetailKey
--            AND PICKDETAIL.PickDetailKey = DELETED.PickDetailKey
--            AND INSERTED.PickDetailKey = DELETED.PickDetailKey
--          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--          IF @n_err <> 0
--          BEGIN
--              SELECT @n_Continue = 3
--              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63105   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Trigger On PickDetail Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
--          END
--      END
--  END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   DECLARE @c_sPickDetailKey            NVARCHAR(20),
           @c_sOrderKey                 NVARCHAR(10),
           @c_sOrderLineNumber          NVARCHAR(5),
           @c_sLot                      NVARCHAR(10),
           @c_sPreAllocatePickDetailKey NVARCHAR(10)

   DECLARE @n_sPreAllocatePickDetailQty INT,
           @n_sPickDetailQty            INT,
           @n_sQtyToReduce              INT

   SELECT @c_sPickDetailKey = SPACE(20)

   WHILE (1=1)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'Data From INSERTED'
      END

      SELECT TOP 1 @c_sPickDetailKey = PickDetailKey, @n_sPickDetailQty = QTY, @c_sOrderKey = OrderKey,
             @c_sOrderLineNumber = OrderLineNumber, @c_sLot = LOT
      FROM INSERTED
      WHERE PickDetailKey > @c_sPickDetailKey AND QTY > 0
      ORDER BY PickDetailKey

      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END

      SELECT @c_sPreAllocatePickDetailKey = SPACE(10)
      WHILE (1=1)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Data From PreAllocatePickDetail'
         END

         SELECT TOP 1
             @c_sPreAllocatePickDetailKey = PreAllocatePickDetailKey,
             @n_sPreAllocatePickDetailQty = qty
         FROM PreAllocatePickDetail (NOLOCK)
         WHERE PreAllocatePickDetailKey > @c_sPreAllocatePickDetailKey
         AND OrderKey = @c_sOrderKey
         AND OrderLineNumber = @c_sOrderLineNumber
         AND LOT = @c_sLot AND QTY > 0
         ORDER BY PreAllocatePickDetailKey

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         IF @b_debug = 1
         BEGIN
            SELECT 'PreKey, PreQty, PickQty',@c_sPreAllocatePickDetailKey , @n_sPreAllocatePickDetailQty, @n_sPickDetailQty
         END

         IF @n_sPickDetailQty > @n_sPreAllocatePickDetailQty
         BEGIN
            --SELECT @n_sQtyToReduce = @n_sPickDetailQty - @n_sPreAllocatePickDetailQty
            --SHONG01
            SET @n_sQtyToReduce = @n_sPreAllocatePickDetailQty
            SELECT @n_sPickDetailQty = @n_sPickDetailQty - @n_sQtyToReduce
         END
         ELSE
         BEGIN
            SELECT @n_sQtyToReduce = @n_sPickDetailQty
            SELECT @n_sPickDetailQty = @n_sPickDetailQty - @n_sQtyToReduce
         END

         IF @b_debug = 1
         BEGIN
            SELECT 'qty to reduce', @c_sPreAllocatePickDetailKey, @n_sQtyToReduce
         END

         UPDATE PreAllocatePickDetail
         SET QTY = QTY - @n_sQtyToReduce,
             Editdate = GETDATE(),
             Editwho = SUSER_SNAME()
         WHERE PreAllocatePickDetailKey = @c_sPreAllocatePickDetailKey

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63117   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PickDetail Could Not Update PreAllocatePickDetail. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END

         IF @n_sPickDetailQty <=0
         BEGIN
            BREAK
         END
      END
   END
END

-- SHONG04 Channel Management
IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   SELECT TOP 1 @c_StorerKey = StorerKey
   FROM INSERTED

   IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
             WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ChannelInventoryMgmt' AND sValue = '1')
   BEGIN
      DECLARE @n_Channel_ID     BIGINT,
              @c_Channel        NVARCHAR(20),
              @c_cStorerKey     NVARCHAR(15),
              @c_cFacility      NVARCHAR(10),
              @c_cLOT           NVARCHAR(10),
              @c_cSKU           NVARCHAR(20),
              @n_cQty           INT,
              @c_cPickDetailKey NVARCHAR(10)

      DECLARE CUR_CHANNEL_MGMT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT INSERTED.PickDetailKey,
             INSERTED.Storerkey,
             INSERTED.Sku,
             LOC.Facility,
             ISNULL(OD.Channel,''),
             INSERTED.Lot,
             ISNULL(INSERTED.Channel_ID,0),
             INSERTED.Qty
      FROM INSERTED WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = INSERTED.Loc
      CROSS APPLY fnc_SelectGetRight (LOC.Facility, INSERTED.Storerkey, '', 'ChannelInventoryMgmt') SC--(Wan01)
      --JOIN StorerConfig AS sc WITH(NOLOCK) ON INSERTED.Storerkey = SC.StorerKey                     --(Wan01)
      --          AND SC.ConfigKey = 'ChannelInventoryMgmt' AND SC.sValue = '1'                       --(Wan01)
      JOIN ORDERDETAIL AS OD WITH(NOLOCK)
             ON  OD.OrderKey = INSERTED.OrderKey AND OD.OrderLineNumber = INSERTED.OrderLineNumber
      WHERE SC.Authority = '1'                                                                        --(Wan01)

      OPEN CUR_CHANNEL_MGMT

      FETCH NEXT FROM CUR_CHANNEL_MGMT INTO @c_cPickDetailKey, @c_cStorerKey, @c_cSKU, @c_cFacility, @c_Channel, @c_cLOT, @n_Channel_ID, @n_cQty

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL(RTRIM(@c_Channel),'') = ''
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63125
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                  + ': Order Detail Channel Cannot be BLANK. (ntrPickDetailAdd)'
                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            BREAK
         END
         IF @n_Channel_ID = 0
         BEGIN
            EXEC isp_ChannelGetID
                @c_StorerKey   = @c_cStorerKey
               ,@c_Sku         = @c_cSKU
               ,@c_Facility    = @c_cFacility
               ,@c_Channel     = @c_Channel
               ,@c_LOT         = @c_cLOT
               ,@n_Channel_ID  = @n_Channel_ID OUTPUT

         END
         IF ISNULL(@n_Channel_ID,0) > 0
         BEGIN
            IF EXISTS(SELECT 1 FROM ChannelInv AS ci WITH(NOLOCK)
                      WHERE ci.Channel_ID = @n_Channel_ID
                      AND ci.Qty < ci.QtyAllocated + @n_cQty)
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63126
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                     + ': Update Channel Inventory Failed, Channel Qty less than Qty Allocated. (ntrPickDetailAdd)'
                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
            ELSE
            BEGIN
               UPDATE ChannelInv
                  SET QtyAllocated = QtyAllocated + @n_cQty,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
               WHERE Channel_ID = @n_Channel_ID

               UPDATE PICKDETAIL
                  SET Channel_ID = @n_Channel_ID,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @c_cPickDetailKey
            END
         END

         FETCH NEXT FROM CUR_CHANNEL_MGMT INTO @c_cPickDetailKey, @c_cStorerKey, @c_cSKU, @c_cFacility, @c_Channel, @c_cLOT, @n_Channel_ID, @n_cQty
      END -- While
      CLOSE CUR_CHANNEL_MGMT            --SY01
      DEALLOCATE CUR_CHANNEL_MGMT       --SY01
   END
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   IF @b_debug = 1
   BEGIN
      SELECT 'Update Data In LOT'
   END

   IF @n_InsertedRows = 1
   BEGIN
      UPDATE LOT
      SET  QtyAllocated = (LOT.QtyAllocated + INSERTED.Qty),
           EditDate = GETDATE(),
           EditWho = SUSER_SNAME(),
           TrafficCop = NULL
      FROM LOT
      JOIN INSERTED ON INSERTED.LOT = LOT.LOT

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   END
   ELSE
   BEGIN
      DECLARE  @tLOT TABLE   (
         LOT          NVARCHAR(10) NOT NULL,
         QtyAllocated INT
         PRIMARY KEY CLUSTERED (LOT)
       )

      INSERT INTO @tLOT  ( LOT, QtyAllocated )
      SELECT LOT,
             SUM (Qty) AS QtyAllocated
      FROM INSERTED
      GROUP BY LOT

      UPDATE LOT
      SET  QtyAllocated = (LOT.QtyAllocated + tL.QtyAllocated),
           EditDate = GETDATE(),   --tlting
           EditWho = SUSER_SNAME(),
           TrafficCop = NULL
      FROM LOT
      JOIN @tLOT tL ON tL.LOT = LOT.LOT

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   END
   IF @n_err <> 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PickDetail Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END

IF (@n_Continue = 1 OR @n_Continue = 2)
BEGIN
   IF @b_debug = 1
   BEGIN
      SELECT 'Update Data In LOTxLOCxID'
   END

   IF @n_InsertedRows = 1
   BEGIN
      UPDATE LOTxLOCxID
      SET  QtyAllocated = (LOTxLOCxID.QtyAllocated + INSERTED.Qty),
           QtyExpected  = CASE WHEN (SL.LocationType NOT IN ('CASE','PICK') AND
                                     LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')) THEN 0
                               WHEN (( LOTxLOCxID.QtyAllocated + INSERTED.Qty) +
                                       LOTxLOCxID.QtyPicked ) > LOTxLOCxID.Qty
                               THEN (( LOTxLOCxID.QtyAllocated +  INSERTED.Qty) +
                                       LOTxLOCxID.QtyPicked - LOTxLOCxID.Qty )
                               ELSE 0
                          END,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
      FROM LOTxLOCxID
      JOIN INSERTED ON INSERTED.LOT = LOTxLOCxID.LOT AND
                       INSERTED.LOC = LOTxLOCxID.LOC AND
                       INSERTED.ID = LOTxLOCxID.ID
      JOIN SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey
                     AND SL.SKU = LOTxLOCxID.SKU
                     AND SL.LOC = LOTxLOCxID.LOC
      JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = LOTxLOCxID.LOC

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   END
   ELSE
   BEGIN

      DECLARE @tLOTxLOCxID TABLE   (
         LOT          NVARCHAR(10) NOT NULL,
         LOC          NVARCHAR(10) NOT NULL,
         ID           NVARCHAR(18) NOT NULL,
         QtyAllocated int DEFAULT (0)
         PRIMARY KEY CLUSTERED (LOT, LOC, ID)
         )

      INSERT INTO @tLOTxLOCxID  ( LOT, LOC, ID, QtyAllocated )
      SELECT LOT, LOC, ID,
             SUM (Qty) AS QtyAllocated
      FROM INSERTED
      GROUP BY LOT, LOC, ID

      UPDATE LOTxLOCxID
      SET  QtyAllocated = (LOTxLOCxID.QtyAllocated + tLLI.QtyAllocated),
           QtyExpected  = CASE WHEN (SL.LocationType NOT IN ('CASE','PICK') AND
                                     LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')) THEN 0
                               WHEN (( LOTxLOCxID.QtyAllocated + tLLI.QtyAllocated) +
                                       LOTxLOCxID.QtyPicked ) > LOTxLOCxID.Qty
                               THEN (( LOTxLOCxID.QtyAllocated +  tLLI.QtyAllocated) +
                                       LOTxLOCxID.QtyPicked - LOTxLOCxID.Qty )
                               ELSE 0
                          END,
            EditDate = GETDATE(),
  EditWho = SUSER_SNAME()
      FROM LOTxLOCxID
      JOIN @tLOTxLOCxID tLLI ON tLLI.LOT = LOTxLOCxID.LOT AND
                                tLLI.LOC = LOTxLOCxID.LOC AND
                                tLLI.ID = LOTxLOCxID.ID
      JOIN SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey
                     AND SL.SKU = LOTxLOCxID.SKU
                     AND SL.LOC = LOTxLOCxID.LOC
      JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = LOTxLOCxID.LOC

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   END

   IF @n_err <> 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PickDetail Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END

IF (@n_Continue = 1 OR @n_Continue = 2)
BEGIN
   IF @b_debug = 1
   BEGIN
      SELECT 'Update Data In SKUxLOC'
   END

   IF @n_InsertedRows = 1
   BEGIN
      UPDATE SKUxLOC
      SET  QtyAllocated = (SKUxLOC.QtyAllocated + INSERTED.Qty),
           QtyExpected  = CASE WHEN SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                    INSERTED.Qty > (SKUxLOC.Qty )
                               THEN ( SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                      INSERTED.Qty ) - (SKUxLOC.Qty)
                               ELSE 0
                          END,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
      FROM SKUxLOC
      JOIN INSERTED ON INSERTED.StorerKey = SKUxLOC.StorerKey
                   AND INSERTED.SKU = SKUxLOC.SKU
                   AND INSERTED.LOC = SKUxLOC.LOC

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   END
   ELSE
   BEGIN
      DECLARE  @tSKUxLOC Table   (
         StorerKey    NVARCHAR(15) NOT NULL,
         SKU          NVARCHAR(20) NOT NULL,
         LOC          NVARCHAR(10) NOT NULL,
         QtyAllocated int DEFAULT (0)
         PRIMARY KEY CLUSTERED (StorerKey, SKU, LOC)
         )

      INSERT INTO @tSKUxLOC ( StorerKey, SKU, LOC, QtyAllocated )
      SELECT StorerKey, SKU, LOC,
             SUM (Qty) AS QtyAllocated
      FROM INSERTED
      GROUP BY StorerKey, SKU, LOC

      UPDATE SKUxLOC
      SET  QtyAllocated = (SKUxLOC.QtyAllocated + tSL.QtyAllocated),
           QtyExpected  = CASE WHEN SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                    tSL.QtyAllocated > (SKUxLOC.Qty )
                               THEN ( SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                      tSL.QtyAllocated ) - (SKUxLOC.Qty)
                               ELSE 0
                          END,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
      FROM SKUxLOC
      JOIN @tSKUxLOC tSL ON tSL.StorerKey = SKUxLOC.StorerKey
                        AND tSL.SKU = SKUxLOC.SKU
                        AND tSL.LOC = SKUxLOC.LOC

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   END
   IF @n_err <> 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63121   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PickDetail Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   IF @b_debug = 1
   BEGIN
      SELECT 'Update Data In ORDERDETAIL'
   END

   -- TLTING01
   DECLARE Cursor_item CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  INSERTED.OrderKey, INSERTED.OrderLineNumber, SUM(INSERTED.Qty) Qty
   FROM INSERTED
   GROUP BY INSERTED.OrderKey, INSERTED.OrderLineNumber

   OPEN Cursor_item

   FETCH NEXT FROM Cursor_item INTO @c_OrderKey, @c_OrderLineNumber, @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- SHONG02
      UPDATE OrderDetail
      SET OrderDetail.QtyAllocated = OrderDetail.QtyAllocated + @n_Qty,
          OrderDetail.Editdate = GETDATE(),
          OrderDetail.Editwho = SUSER_SNAME()
      WHERE OrderDetail.OrderKey = @c_OrderKey
      AND OrderDetail.OrderLineNumber = @c_OrderLineNumber

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63118   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On ORDERDETAIL Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END

      FETCH NEXT FROM Cursor_item INTO @c_OrderKey, @c_OrderLineNumber, @n_Qty
   END -- WHILE
   CLOSE Cursor_item
   DEALLOCATE Cursor_item
END

-- UnComment By SHONG
-- Need to refresh when doing manual allocation
-- Only Manual Allocation
IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   -- this option only valid when manual allocation
   IF EXISTS (SELECT 1 FROM INSERTED WHERE PickMethod = '' OR CaseID <> '' OR TrafficCop <> 'U' )
   BEGIN
      UPDATE ORDERS
      SET EditDate = GETDATE()
      FROM ORDERS, INSERTED
      WHERE ORDERS.OrderKey = INSERTED.OrderKey

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63119   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On ORDERS Failed. (ntrPickDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   IF @c_AllowOverAllocations = "1"
   BEGIN
      IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK), INSERTED, SKUxLOC (NOLOCK), LOC (NOLOCK) --NJOW02
                WHERE INSERTED.Lot = LOTxLOCxID.Lot
                AND INSERTED.Loc = LOTxLOCxID.Loc
                AND INSERTED.Id = LOTxLOCxID.Id
                AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey
                AND LOTxLOCxID.SKU = SKUxLOC.SKU
                AND LOTxLOCxID.Loc = SKUxLOC.LOC
                AND LOTxLOCxID.Loc = LOC.Loc --NJOW01
                AND SKUxLOC.LOCATIONTYPE <> "PICK"
                AND SKUxLOC.LOCATIONTYPE <> "CASE"
                AND LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK') --NJOW02
                AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED) > LOTxLOCxID.QTY)
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 63124
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": An Attempt Was Made To OverAllocate A Location That Is Not a Case Pick OR Piece Pick Location. (ntrPickDetailAdd)"
      END
   END
   ELSE IF @c_AllowOverAllocations = "0"        --(Wan02) - START
   BEGIN
      IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK)
                JOIN INSERTED ON  INSERTED.Lot = LOTxLOCxID.Lot
                              AND INSERTED.Loc= LOTxLOCxID.Loc
                              AND INSERTED.Id = LOTxLOCxID.Id
                WHERE (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED) > LOTxLOCxID.QTY)
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 63127
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": An Attempt Was Made by OverAllocate is Turn OFF. (ntrPickDetailAdd)"
      END                                       --(Wan02) - END
   END
END

-- MC01-S
IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
          WHERE StorerKey = @c_StorerKey AND ConfigKey = 'WAVEUPDLOG' AND sValue = '1')
BEGIN
  INSERT INTO PickDetail_Log (OrderKey ,OrderLineNumber ,WaveKey ,StorerKey
                              ,B_SKU, B_LOT, B_LOC, B_ID, B_QTY
                              ,A_SKU, A_LOT, A_LOC, A_ID, A_QTY
                              ,Status, PickDetailKey)
   SELECT INSERTED.OrderKey, INSERTED.OrderLineNumber, WaveDetail.Wavekey, INSERTED.StorerKey
         , '', '', '', '', 0
         , INSERTED.Sku, INSERTED.Lot, INSERTED.Loc, INSERTED.Id, INSERTED.Qty
         ,'0', INSERTED.PickDetailKey
   FROM INSERTED
   JOIN WaveDetail WITH (NOLOCK) ON ( WaveDetail.OrderKey = INSERTED.OrderKey )
   WHERE EXISTS ( SELECT 1 FROM Transmitlog3 WITH (NOLOCK)
                  WHERE Tablename = 'WAVERESLOG'
                  AND Key1 = WaveDetail.Wavekey
                  AND Key3 = INSERTED.StorerKey
                  AND TransmitFlag > '0' )

END -- IF EXISTS(StorerConfig - 'WAVEUPDLOG')
-- MC01-E

SET NOCOUNT OFF
/* #INCLUDE <TRPDA2.SQL> */
IF @n_Continue = 3  -- Error Occured - Process AND Return
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPickDetailAdd"
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

GO