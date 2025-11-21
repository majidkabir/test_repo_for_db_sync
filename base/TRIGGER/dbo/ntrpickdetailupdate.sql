SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPickDetailUpdate                                         */
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
/* PVCS Version: 3.9                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 13-Apr-2006  SHONG   1.0   Performance Tuning (SHONG_13042006)       */
/* 22-Nov-2006  SHONG   1.0   Not allow ship without MBOL if Backend    */
/*                            Ship turn on.                             */
/* 22-Jul-2008  SHONG   1.0   No update on QtyPickInprogress            */
/* 16-Sep-2008  SHONG   1.0   New Release                               */
/* 17-Mar-2009  TLTING  1.1   Change user_name() to SUSER_SNAME()       */
/* 28-May-2009  SHONG   1.2   Bug Fixing for Status 4                   */
/* 07-Apr-2009  ACM     1.3   SOS#131697 Pass 5 Lottable To ITRN        */
/* 08-Oct-2010  Shong   1.4   Add New StorerConfigKey Control (Shong01) */
/*                            DropId for ECOM <> Blank and Match to     */
/*                            TaskDetail.DropId                         */
/* 10-Nov-2010  TLTING  1.5   Avoid Update after ship (tlting01)        */
/*                            Do not use variable table                 */
/* 02-Dec-2010  James   1.5   Not allow to change Pickdetail status/qty */
/*                            if orders status/sostatus is CANC(james01)*/
/* 28-Dec-2010  SHONG   1.5   Set LOTxLOCxID.QtyExpected = 0 WHEN Loc   */
/*                            Type <> PICK/CASE (SHONG01)               */
/* 27-Jan-2011  TLTING  1.6   Set LOTxLOCxID.QtyExpected = 0 WHEN Loc   */
/*                            Type <> DYNPICKP/DYNPICKR (TLTING01)      */
/* 24-Jun-2011  NJOW01  1.7   Allow over allocation for dynamic         */
/*                            permenent loc                             */
/* 16-Aug-2011  James   1.7   SOS223517 - To have dropid in pickdetail  */
/*                            if status picked (james02)                */
/* 02-Dec-2011  MCTang  1.7   Add WAVEUPDLOG for WCS-WAVE Status Change */
/*                            Export(MC01)                           */
/* 16-Jan-2012  TLTING  1.7   SOS# 233330 - Convert error msg to RDT    */
/*                            compatible (Msg Range: 61601 - 61650)     */
/* 18-Apr-2012  Leong   1.8   SOS# 241911 - Additional DropId checking  */
/* 22-May-2012  TLTING  1.8   DM Integrity issue - Update editdate for  */
/*                            status < '9'(TLTING01)                    */
/* 08-Jun-2012  TLTING  1.8   Deadlock tune - add nolock Orders         */
/* 30-Oct-2012  NJOW02  1.9   259289-StorerConfig to populate ID to     */
/*                            DropID in PickDetail SC='IDToDropID'      */
/* 18-JUL-2012  YTWan   2.0   SOS#248737:06700-Diversey Hygience TH_CR_ */
/*                            Allocation Strategy.(Wan01)               */
/* 17-Dec-2012  Leong   2.0   SOS# 264916 - Include pickdetailkey when  */
/*                                          item already shipped.       */
/* 10-May-2013  Leong         SOS#278118 - Prompt error when user update*/
/*                                         Loc = 'WS01'.                */
/*                                       - (Temp. for IDSUK only)       */
/* 15-MAY-2013  YTWan   2.1   SOS#276826-VFDC SO Cancel.(Wan02)         */
/* 28-Oct-2013  TLTING  2.2   Review Editdate column update             */
/* 25-Nov-2013  CSCHONG 2.3   Add Lottable06-15 (CS01)                  */
/* 26-Jan-2015  NJOW03  2.4   331723-Auto-Move Short Pick               */
/* 15-Apr-2015  TLTING  2.5   SQL2012 Bug fix                           */
/* 19-Aug-2015  SHONG01 2.6   Added Backend Pick Confirm                */
/* 19-Aug-2015  James   2.7   Bug fix (james02)                         */
/* 29-Aug-2015  NJOW04  2.8   315021-Call pickdetail update custom sp   */
/* 21-Jun-2016  SHONG   2.9   IN00071638 - Added ConfigKey              */
/*                            "ForceAllocLottable"                      */
/* 20-Sep-2016  TLTING  3.0   Change SET ROWCOUNT 1 to TOP 1            */
/* 15-Feb-2017  TLTING  3.1   Add Continue 3 skip                       */
/* 15-Feb-2017  Ung     3.2   RDT compatible errno                      */
/* 10-Jan-2017  NJOW05  3.3   WMS-684 AllocateByConsNewExpiry include Y */
/*                            value at susr1 and change to looping      */
/* 16-Oct-2017  SHONG   3.4   Performance Tuning (SWT01)                */
/* 06-Feb-2018  SWT02   3.5   Added Channel Management Logic            */
/* 16-May-2018  TLTING02 3.6  Check no over allocate when               */
/*                            AllowOverAllocations turn off             */
/* 28-Sep-2018  TLTIN   3.6   remove #tmp , remmove update row lock     */
/* 16-May-2019  CheeMun 3.7   INC0683213 - Cater for ShowPicks update   */
/*                            status syn ChannelInv.QtyAllocated        */ 
/* 23-JUL-2019  Wan03   3.8   ChannelInventoryMgmt use fnc_SelectGetRight*/
/* 04-MAR-2021  Wan04   3.9   WMS-16390 - [CN] NIKE_O2_Ecompacking_Check*/
/*                            _Pickdetail_status_CR                     */
/* 2024-11-26   Wan05   4.0   UWP-23317 - [FCR-618  819] Unpick SerialNo*/
/* 2024-11-26   Wan06   4.1   [FCR-618] - Fixed if change on lot,id,qty &*/
/*                            Status                                    */
/************************************************************************/
CREATE   TRIGGER [dbo].[ntrPickDetailUpdate]
ON  [dbo].[PICKDETAIL]
FOR UPDATE
AS
IF @@ROWCOUNT = 0
BEGIN
   RETURN
END

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @b_debug int
SELECT @b_debug = 0

DECLARE
@b_Success                      int
,         @n_err                int
,         @n_err2               int
,         @c_errmsg             NVARCHAR(250)
,         @n_Continue           int
,         @n_starttcnt          int
,         @c_preprocess         NVARCHAR(250)
,         @c_pstprocess         NVARCHAR(250)
,         @n_cnt                int
,         @n_PickDetailSysId    int
,         @c_facility           NVARCHAR(5)   -- Added for IDSV5 by June 26.Jun.02
,         @c_authority          NVARCHAR(10)   -- Added for IDSV5 by June 26.Jun.02  --NJOW03
,         @c_StorerKey          NVARCHAR(15)
,         @c_pckdtl_loc         NVARCHAR(10) -- added to remove the max function
,         @c_lottable01         NVARCHAR(18)
,         @c_lottable02         NVARCHAR(18)
,         @c_lottable03         NVARCHAR(18)
,         @d_lottable04         datetime
,         @d_lottable05         datetime
,         @c_lottable06         NVARCHAR(30)          --(CS01)
,         @c_lottable07         NVARCHAR(30)          --(CS01)
,         @c_lottable08         NVARCHAR(30)          --(CS01)
,         @c_lottable09         NVARCHAR(30)          --(CS01)
,         @c_lottable10         NVARCHAR(30)          --(CS01)
,         @c_lottable11         NVARCHAR(30)          --(CS01)
,         @c_lottable12         NVARCHAR(30)          --(CS01)
,         @d_lottable13         datetime              --(CS01)
,         @d_lottable14         datetime              --(CS01)
,         @d_lottable15         datetime              --(CS01)

DECLARE   @cPickDetailKey NVARCHAR(10)     -- (james02)
        , @cPD_DropID     NVARCHAR(18)     -- (james02)
        , @cTD_DropID     NVARCHAR(18)     -- (james02)
        , @cTaskDetailKey NVARCHAR(10)     -- (james02)
        , @c_PDKey        NVARCHAR(10)     -- SOS# 264916
        
        , @c_EPACK4PickedOrder         NVARCHAR(30)   --(Wan04)
        , @n_PickSerialNoKey           BIGINT = 0     --(Wan05)
        , @CUR_SNDEL                   CURSOR         --(Wan05)

--(Wan01) - START
         ,@c_AllocateByConsNewExpiry   NVARCHAR(10)
         ,@c_Consigneekey              NVARCHAR(15)
         ,@c_Sku                       NVARCHAR(20)

SET @c_AllocateByConsNewExpiry= ''
SET @c_Consigneekey           = ''
SET @c_Sku                    = ''

--(Wan01) - END
SELECT @n_Continue=1, @n_starttcnt=@@TRANCOUNT

IF UPDATE(ArchiveCop)
BEGIN
   SELECT @n_Continue = 4
   GOTO QUIT
END

IF (@n_Continue = 1 OR @n_Continue = 2) AND UPDATE(LOC) -- SOS#278118
BEGIN
   DECLARE @c_HoldLoc NVARCHAR(10), @c_PD_StorerKey NVARCHAR(15)
   SELECT @c_PDKey = '', @c_HoldLoc = '', @c_PD_StorerKey = ''

   SELECT @c_PDKey = INSERTED.PickDetailKey
        , @c_HoldLoc = INSERTED.Loc
        , @c_PD_StorerKey = INSERTED.StorerKey
   FROM INSERTED
   JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = INSERTED.PickDetailKey)

   IF EXISTS ( SELECT 1 FROM CodeLkUp WITH (NOLOCK)
               WHERE ListName = 'HOLDLOC'
               AND Code = ISNULL(RTRIM(@c_HoldLoc),'')
               AND StorerKey = ISNULL(RTRIM(@c_PD_StorerKey),'') )
   BEGIN
      IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE Loc = ISNULL(RTRIM(@c_HoldLoc),'')
                 AND LocationFlag = 'HOLD')
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 61601
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Nchar(5),@n_err)+': Update denied. Not allow change location to ' + ISNULL(RTRIM(@c_HoldLoc),'') + '. PickDetailKey: ' + ISNULL(RTRIM(@c_PDKey),'') + ' (ntrPickDetailUpdate)'
         GOTO QUIT
      END
   END
END

-- tlting01
IF EXISTS ( SELECT 1 FROM INSERTED, DELETED
            WHERE INSERTED.PickDetailKey = DELETED.PickDetailKey
            AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' )  )
      AND ( @n_continue = 1 OR @n_continue = 2 )
      AND NOT UPDATE(EditDate)
BEGIN
   UPDATE PICKDETAIL  
   SET EditDate = GETDATE(), EditWho=SUSER_SNAME(),
         TrafficCop = NULL
   FROM PICKDETAIL,INSERTED
   WHERE PICKDETAIL.PickDetailKey=INSERTED.PickDetailKey
   AND PICKDETAIL.[status] < '9'
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61602
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On PickDetail. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
   END
END

IF UPDATE(TrafficCop)
BEGIN
   SELECT @n_Continue = 4
   GOTO QUIT
END

--NJOW04
IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF EXISTS (SELECT 1 FROM INSERTED i
              JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey
              JOIN sys.objects sys with (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
              WHERE  s.configkey = 'PickDetailTrigger_SP')
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

      EXECUTE dbo.isp_PickDetailTrigger_Wrapper
               'UPDATE' --@c_Action
              , @b_Success  OUTPUT
              , @n_Err      OUTPUT
              , @c_ErrMsg   OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrPickDetailUpdate' + RTrim(@c_errmsg)
      END

      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED
   END
END

-- SHONG01
IF UPDATE(ShipFlag) AND (@n_Continue=1 or @n_Continue=2)
BEGIN
   DECLARE @c_OrderKey NVARCHAR(10)

   IF EXISTS(SELECT 1 FROM INSERTED WHERE ShipFlag='P' AND STATUS < '4')
   BEGIN
      DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ORDERKEY FROM INSERTED
      WHERE  ShipFlag='P' AND STATUS < '4'

      OPEN CUR_ORDERS
      FETCH NEXT FROM CUR_ORDERS INTO @c_OrderKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC isp_ConfirmPick @c_OrderKey=@c_OrderKey, @c_LoadKey = '',
              @b_Success=@b_Success OUTPUT, @n_err=@n_err OUTPUT, @c_errmsg = @c_errmsg OUTPUT

         FETCH NEXT FROM CUR_ORDERS INTO @c_OrderKey
      END
      CLOSE CUR_ORDERS
      DEALLOCATE CUR_ORDERS
   END
END
-- tlting01
IF (@n_Continue=1 or @n_Continue=2)
BEGIN
   -- (SWT01) Performance Tuning 
   --IF NOT EXISTS ( SELECT 1 -- not changing ShipFlag
   --                 FROM  INSERTED, DELETED
   --                 WHERE INSERTED.PICKDETAILKEY = DELETED.PICKDETAILKEY
   --                 AND   INSERTED.ShipFlag <> DELETED.ShipFlag )
   --                 AND   NOT EXISTS ( SELECT 1  -- not changing [Status]
   --                                    FROM INSERTED, DELETED
   --                                    WHERE INSERTED.PICKDETAILKEY = DELETED.PICKDETAILKEY
   --                                    AND INSERTED.[Status] <> DELETED.[Status] )
   --                                    AND EXISTS( SELECT 1 -- user shipped
   --                                                FROM INSERTED
   --                                                WHERE ShipFlag = 'Y' OR [Status] = '9'  )
   IF NOT UPDATE(ShipFlag) AND 
      NOT UPDATE(Status) AND 
      EXISTS(SELECT 1 FROM INSERTED WHERE ShipFlag = 'Y' OR [Status] = '9')   
   BEGIN
      SET @c_PDKey = '' -- SOS# 264916
      
      SELECT TOP 1 
           @c_PDKey = INSERTED.PickDetailKey
      FROM INSERTED
            
      SELECT @n_Continue = 3 , @n_err = 61603
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update denied. Item Already Shipped. PickDetailKey: ' + ISNULL(RTRIM(@c_PDKey),'') + ' (ntrPickDetailUpdate)'
      GOTO QUIT
   END
END

--IN00071638
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF UPDATE(LOT)
   BEGIN
      IF EXISTS(
         SELECT 1
         FROM INSERTED P WITH (NOLOCK)
         JOIN LOTATTRIBUTE AS LA (NOLOCK) ON LA.Lot = p.Lot
         JOIN StorerConfig SC WITH (NOLOCK) ON SC.StorerKey = P.StorerKey
                                     AND ConfigKey = 'ForceAllocLottable'
                                     AND sValue = '1'
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = p.OrderKey AND OD.OrderLineNumber = p.OrderLineNumber
         WHERE ((OD.Lottable01 <> LA.Lottable01 AND (OD.Lottable01 IS NOT NULL AND OD.Lottable01 <> '')) OR
                (OD.Lottable02 <> LA.Lottable02 AND (OD.Lottable02 IS NOT NULL AND OD.Lottable02 <> '')) OR
                (OD.Lottable03 <> LA.Lottable03 AND (OD.Lottable03 IS NOT NULL AND OD.Lottable03 <> '')))
         )
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61604   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LOT CHOSEN IS INVALID! Lot Attributes Does Not Match'
      END
   END
END

-- (Shong01)
IF (@n_Continue=1 or @n_Continue=2)
   AND UPDATE(Status)
   AND EXISTS(SELECT 1 FROM INSERTED WHERE STATUS='5')
BEGIN
  IF EXISTS(SELECT 1
             FROM   INSERTED
             JOIN   DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey
             JOIN   STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey
                    AND STORERCONFIG.ConfigKey = 'PKDetEcomDropIdRequired' AND STORERCONFIG.SValue='1'
             JOIN   TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = INSERTED.TaskDetailKey
                   /* AND TASKDETAIL.TaskType='PK'  --SOS223517 Start
                    AND TASKDETAIL.PickMethod IN ('DOUBLES','SINGLES','MULTIS') */
                    AND TASKDETAIL.TaskType in('PK', 'SPK')
                    AND TASKDETAIL.pickmethod in ('DOUBLES', 'SINGLES', 'MULTIS', 'PIECE') --SOS223517 END
             WHERE INSERTED.Status = '5' AND DELETED.STATUS < '5'
             AND   ( ISNULL(RTRIM(INSERTED.DropID),'')  = '' OR
                     ISNULL(RTRIM(INSERTED.DropID),'') <> TASKDETAIL.DropID ) )
             -- Comment by james02
             -- AND ( ISNULL(RTRIM(@cPD_DropID),'') <> ISNULL(RTRIM(@cTD_DropID),'') OR ISNULL(RTRIM(@cPD_DropID),'') = '' ) -- SOS# 241911
   BEGIN
      -- for debug purpose (james01)
      SET @cPickDetailKey = ''
      SET @cPD_DropID = ''
      SET @cTD_DropID = ''
      SELECT
         @cPickDetailKey = INSERTED.PickDetailKey,
         @cPD_DropID = INSERTED.DropID,
         @cTD_DropID = TASKDETAIL.DropID
      FROM INSERTED
      JOIN TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = INSERTED.TaskDetailKey
      WHERE INSERTED.Status = '5'

      SELECT @n_Continue = 3 , @n_err = 61605
      --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DropID for ECOM Orders Cannot be BLANK/Not Match. (ntrPickDetailUpdate)' --SOS223517
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DropID for Orders Cannot be BLANK/Not Match. (ntrPickDetailUpdate) PDKEY: ' + @cPickDetailKey + ' PD.DID: ' + @cPD_DropID + ' TD.DID: ' + @cTD_DropID
      GOTO QUIT
   END

   --(Wan01) - START
   SELECT TOP 1
         @c_Storerkey = RTRIM(Storerkey)
   FROM INSERTED

   SET @b_success = 0
   EXECUTE dbo.nspGetRight @c_facility
         ,  @c_Storerkey                     -- Storerkey
         ,  NULL                             -- Sku
         ,  'AllocateByConsNewExpiry'        -- Configkey
         ,  @b_Success                 OUTPUT
         ,  @c_AllocateByConsNewExpiry OUTPUT
         ,  @n_Err                     OUTPUT
         ,  @c_errmsg                  OUTPUT

   IF @c_AllocateByConsNewExpiry = '1'                  
      AND EXISTS (SELECT 1
                  FROM INSERTED
                  JOIN ORDERS WITH (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey)
                  JOIN STORER WITH (NOLOCK) ON (ORDERS.Consigneekey = STORER.Storerkey)
                  AND STORER.SUSR1 IN('nspPRTH01','Y')) --NJOW05
                  
   BEGIN
     --NJOW05
      DECLARE CUR_Consignee CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')
               ,ISNULL(RTRIM(INSERTED.Sku),'')
               ,ISNULL(RTRIM(INSERTED.Storerkey),'')
               ,ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04,120),'1900-01-01')
         FROM INSERTED
         JOIN ORDERS       WITH (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (INSERTED.Lot = LOTATTRIBUTE.Lot)
         JOIN STORER       WITH (NOLOCK) ON (ORDERS.Consigneekey = STORER.Storerkey)
                                             AND STORER.SUSR1 IN('nspPRTH01','Y') 
         
      OPEN CUR_Consignee
      FETCH NEXT FROM CUR_Consignee INTO @c_Consigneekey, @c_Sku, @c_Storerkey, @d_Lottable04 
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM CONSIGNEESKU WITH (NOLOCK)
                     WHERE Consigneekey = @c_Consigneekey
                     AND   ConsigneeSku = @c_Sku )
         BEGIN
            UPDATE CONSIGNEESKU 
            SET AddDate = @d_Lottable04
               ,EditWho = SUSER_SNAME()
               ,EditDate= GETDATE()
            WHERE Consigneekey = @c_Consigneekey
            AND   ConsigneeSku = @c_Sku
            AND   AddDate < @d_Lottable04
         
            SET @n_err = @@ERROR
            SET @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63211
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CONSIGNEESKU Table Failed. (ntrPickDetailUpdate)'
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            INSERT INTO CONSIGNEESKU (Consigneekey, ConsigneeSku, Storerkey, Sku, AddDate)
            VALUES (@c_Consigneekey, @c_Sku, @c_Storerkey, @c_Sku, @d_Lottable04)
         
            SET @n_err = @@ERROR
            SET @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63212
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into CONSIGNEESKU Failed. (ntrPickDetailUpdate)'
               GOTO QUIT
            END
         END         
         FETCH NEXT FROM CUR_Consignee INTO @c_Consigneekey, @c_Sku, @c_Storerkey, @d_Lottable04 
      END
      CLOSE CUR_Consignee
      DEALLOCATE CUR_Consignee      
      
      /*    
      SELECT @c_Consigneekey = ISNULL(RTRIM(ORDERS.Consigneekey),'')
            ,@c_Sku          = ISNULL(RTRIM(INSERTED.Sku),'')
            ,@c_Storerkey    = ISNULL(RTRIM(INSERTED.Storerkey),'')
            ,@d_Lottable04   = ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04,120),'1900-01-01')
      FROM INSERTED
      JOIN ORDERS       WITH (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey)
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON (INSERTED.Lot = LOTATTRIBUTE.Lot)

      IF EXISTS ( SELECT 1
                  FROM CONSIGNEESKU WITH (NOLOCK)
                  WHERE Consigneekey = @c_Consigneekey
                  AND   ConsigneeSku = @c_Sku )
      BEGIN       
         UPDATE CONSIGNEESKU WITH (ROWLOCK)
         SET AddDate = @d_Lottable04
            ,EditWho = SUSER_SNAME()
            ,EditDate= GETDATE()
         WHERE Consigneekey = @c_Consigneekey
         AND   ConsigneeSku = @c_Sku
         AND   AddDate < @d_Lottable04

         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 61606
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CONSIGNEESKU Table Failed. (ntrPickDetailUpdate)'
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         INSERT INTO CONSIGNEESKU (Consigneekey, ConsigneeSku, Storerkey, Sku, AddDate)
         VALUES (@c_Consigneekey, @c_Sku, @c_Storerkey, @c_Sku, @d_Lottable04)

         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 61607
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into CONSIGNEESKU Failed. (ntrPickDetailUpdate)'
            GOTO QUIT
         END
      END
      */
   END
   --(Wan01) - END
   /*
   IF EXISTS(SELECT 1 FROM INSERTED
             JOIN DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey
             JOIN   TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = INSERTED.TaskDetailKey
                    AND TASKDETAIL.TaskType='PK'
                    AND TASKDETAIL.PickMethod IN ('DOUBLES','SINGLES','MULTIS')
             WHERE INSERTED.Status = '5' AND DELETED.STATUS < '5')
   BEGIN
      UPDATE TASKDETAIL
         SET [STATUS] = '9', TASKDETAIL.UserKey = 'wms.' + SUSER_SNAME(), TASKDETAIL.TrafficCop = NULL
      FROM TASKDETAIL
       JOIN   INSERTED WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = INSERTED.TaskDetailKey
              AND TASKDETAIL.TaskType='PK'
              AND TASKDETAIL.PickMethod IN ('DOUBLES','SINGLES','MULTIS')
       JOIN   DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey
      WHERE INSERTED.Status = '5' AND DELETED.STATUS < '5'
   END
   ELSE
   IF EXISTS(SELECT 1 FROM INSERTED
             JOIN DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey
             JOIN   TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = INSERTED.TaskDetailKey
                    AND TASKDETAIL.TaskType='PK'
                    AND TASKDETAIL.PickMethod IN ('PIECE','CASE')
             WHERE INSERTED.Status = '5' AND DELETED.STATUS < '5')
   BEGIN
      DECLARE @cTaskDetailKey NVARCHAR(10)

      DECLARE CUR_TaskDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT INSERTED.TaskDetailKey
      FROM INSERTED
      JOIN DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey
      JOIN   TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = INSERTED.TaskDetailKey
             AND TASKDETAIL.TaskType='PK'
             AND TASKDETAIL.PickMethod IN ('PIECE','CASE')
      WHERE INSERTED.Status = '5' AND DELETED.STATUS < '5'

      OPEN  CUR_TaskDetailKey
      FETCH NEXT FROM CUR_TaskDetailKey INTO @cTaskDetailKey
      BEGIN
          IF NOT EXISTS(SELECT 1 FROM PICKDETAIL p (NOLOCK)
                        WHERE p.TaskDetailKey = @cTaskDetailKey
                        AND   P.Status < '5')
          BEGIN
             UPDATE TASKDETAIL WITH (ROWLOCK)
         SET [STATUS] = '9', TASKDETAIL.UserKey = 'wms.' + SUSER_SNAME(), TASKDETAIL.TrafficCop = NULL
             WHERE TaskDetailKey = @cTaskDetailKey
          END
      END
      CLOSE CUR_TaskDetailKey
      DEALLOCATE CUR_TaskDetailKey

   END
   */
END

-- SOS 14880: prevent updates of pick confirmed detail if PICK-TRF is on
IF (@n_Continue=1 or @n_Continue=2) and UPDATE(qty)
BEGIN
   if EXISTS (SELECT 1
              FROM  DELETED d JOIN StorerConfig s (NOLOCK)
              ON    d.StorerKey = s.StorerKey
              WHERE s.Configkey = 'PICK-TRF'
              AND   s.sValue = '1'
              AND   d.Status = '5') AND
      EXISTS (SELECT 1
              FROM  INSERTED i JOIN StorerConfig s (NOLOCK)
              ON    i.StorerKey = s.StorerKey
              WHERE s.Configkey = 'PICK-TRF'
              AND   s.sValue = '1'
              AND   i.qty = 0 )
   BEGIN
      SELECT @n_Continue = 3 , @n_err = 61608
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update on QTY not Allowed After Pick Confirmed - Update Failed. (ntrPickDetailUpdate)'
      GOTO QUIT
   END

   --(Wan02) - START
   IF NOT EXISTS ( SELECT 1
                  FROM STORERCONFIG WITH (NOLOCK)
                  JOIN ORDERS WITH (NOLOCK) ON (STORERCONFIG.Storerkey = ORDERS.Storerkey)
                                            AND(STORERCONFIG.Facility = ORDERS.Facility OR STORERCONFIG.facility = '')
                  JOIN INSERTED ON (ORDERS.Orderkey = INSERTED.Orderkey)
                  WHERE STORERCONFIG.Configkey = 'ValidateSOStatus_SP'
                  AND   STORERCONFIG.SValue = 'ispVSOST01' )
   BEGIN
      -- james01
      IF EXISTS (SELECT 1 FROM INSERTED
                 JOIN Orders WITH (NOLOCK) ON INSERTED.OrderKey = Orders.OrderKey
                 WHERE (Orders.SOSTATUS = 'CANC' OR Orders.Status = 'CANC')
                 AND INSERTED.QTY > 0)
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 61609
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update on QTY not Allowed After Orders is Cancelled - Update Failed. (ntrPickDetailUpdate)'
         GOTO QUIT
      END
   END
   --(Wan02) - END
END

IF (@n_Continue=1 or @n_Continue=2) and update(Status)
BEGIN
   if EXISTS (SELECT 1
              FROM  DELETED d JOIN StorerConfig s (NOLOCK)
              ON    d.StorerKey = s.StorerKey
              WHERE s.Configkey = 'PICK-TRF'
              AND   s.sValue = '1'
              AND   d.Status = '5') and
      EXISTS (SELECT 1
              FROM  INSERTED i JOIN StorerConfig s (NOLOCK)
              ON    i.StorerKey = s.StorerKey
              WHERE s.Configkey = 'PICK-TRF'
              AND   s.sValue = '1'
              AND   i.Status < '5')
   BEGIN
      SELECT @n_Continue = 3 , @n_err = 61610
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update on Status not Allowed After Pick Confirmed - Update Failed. (ntrPickDetailUpdate)'
      GOTO QUIT
   END

   --(Wan02) - START
   IF NOT EXISTS ( SELECT 1
                  FROM STORERCONFIG WITH (NOLOCK)
                  JOIN ORDERS WITH (NOLOCK) ON (STORERCONFIG.Storerkey = ORDERS.Storerkey)
                                            AND(STORERCONFIG.Facility = ORDERS.Facility OR ISNULL(RTRIM(STORERCONFIG.Facility),'') = '')
                  JOIN INSERTED ON (ORDERS.Orderkey = INSERTED.Orderkey)
                  WHERE STORERCONFIG.Configkey = 'ValidateSOStatus_SP'
                  AND   STORERCONFIG.SValue = 'ispVSOST01' )
   BEGIN
      -- james01
      IF EXISTS (SELECT 1 FROM INSERTED
                 JOIN Orders WITH (NOLOCK) ON INSERTED.OrderKey = Orders.OrderKey
                 WHERE (Orders.SOSTATUS = 'CANC' OR Orders.Status = 'CANC')
                 AND INSERTED.Status <> '4')
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 61611
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update on Status not Allowed After Orders is Cancelled - Update Failed. (ntrPickDetailUpdate)'
         GOTO QUIT
      END
   END
   --(Wan02) - END

   -- Added By Shong on 22nd Nov 2006
   -- If BackendShip Turn ON
   -- Not allow to update Status to 9 if the ShipFlag <> 'Y'
   -- To Prevent user do Mass Ship FROM Front End
   -- Might not accurate if bulk update pickdetail more then 1 storer, don't think it will happen in frontend
   -- reason not check is due to performance issues

   SELECT TOP 1 @c_StorerKey = StorerKey    FROM   INSERTED

   IF NOT EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_StorerKey
                 AND Configkey = 'REALTIMESHIP' AND sValue = 1)
   BEGIN
      IF EXISTS(SELECT 1 FROM INSERTED WHERE Status = '9' and ShipFlag <> 'Y' and StorerKey = @c_StorerKey)
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 61612
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SHIP not Allowed without MBOL - Update Failed. (ntrPickDetailUpdate)'
         GOTO QUIT
      END
   END
   --SET ROWCOUNT 0
END

--(Wan05) - START
IF (@n_Continue=1 or @n_Continue=2) and (Update(Status) OR Update(Qty) OR Update(Lot) OR Update(ID))
BEGIN
   --Allow to update if update from ntrpackserialnodelete trigger. direct update not allow if serialno is picked
  SET @n_Cnt = 0
  SELECT @n_Cnt = SUM(  CASE WHEN d.[Status] <> i.[Status] THEN 1                                  --(Wan06) 
                        WHEN d.qty <> i.qty AND i.[Status] = '5' THEN 1                            --(Wan06) 
                        WHEN d.Lot <> i.Lot AND i.[Status] = '5' AND sc.Authority ='1' THEN 1      --(Wan06) 
                        WHEN d.ID  <> i.ID  AND i.ID <> sn.ID AND i.[Status] = '5' AND             --(Wan06)    
                             sc.Authority ='1' THEN 1                                              --(Wan06) 
                        ELSE 0                                                                     --(Wan06) 
                        END )                                                                      --(Wan06)
               FROM INSERTED i   
               JOIN DELETED  d ON d.Pickdetailkey = i.pickdetailkey
               JOIN PickSerialNo psn WITH (NOLOCK) ON psn.PickDetailKey = i.PickDetailKey
               JOIN SerialNo sn WITH (NOLOCK) ON  sn.SerialNo = psn.SerialNo
               JOIN ORDERS o (NOLOCK) ON o.Orderkey = i.Orderkey
               OUTER APPLY dbo.fnc_SelectGetRight(o.Facility, o.Storerkey, '', 'ASNFizUpdLotToSerialNo') AS sc
               WHERE d.[Status] = '5' AND i.[Status] <= '5'                                        
               AND   psn.SerialNo > ''
               GROUP BY d.PickDetailKey, o.Facility, o.Storerkey, sc.Authority
               HAVING COUNT(1) = SUM(d.Qty)
   IF @n_Cnt > 0
   BEGIN
      SET @n_continue = 3
      SET @n_err   = 61622
      SET @c_errmsg= 'NSQL'+CONVERT(char(6), @n_err)+': SerialNo is picked'
                   + '. Disallow to change Lot/ID/Qty/Status. (ntrPickdetailUpdate)'
   END
   SET @n_Cnt = 0
END
--(Wan05) - END

/* #INCLUDE <TRPDU1.SQL> */
IF @n_Continue = 1 or @n_Continue = 2
BEGIN
   DECLARE @c_AllowOverAllocations NVARCHAR(1)

   SELECT TOP 1 @c_pckdtl_loc = LOC,
          @c_StorerKey = StorerKey
   FROM  INSERTED

   SELECT TOP 1 @c_facility = FACILITY
   FROM  LOC (NOLOCK)
   WHERE LOC = @c_pckdtl_loc

   SELECT @b_success = 0
   Execute nspGetRight @c_facility, -- facility
         @c_StorerKey,  -- StorerKey
         null, -- Sku
         'ALLOWOVERALLOCATIONS', -- Configkey
         @b_success     output,
         @c_AllowOverAllocations output,
         @n_err         output,
         @c_errmsg      output

   IF @b_success <> 1
   BEGIN
     SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailUpdate' + rtrim(@c_errmsg)
   END
END

IF @n_Continue = 1 or @n_Continue = 2
BEGIN
   DECLARE @c_catchweight NVARCHAR(1)

   SELECT @c_catchweight = IsNull(NSQLValue, '0')
   FROM NSQLCONFIG (NOLOCK)
   WHERE Configkey = 'CATCHWEIGHT'
END

IF @b_debug = 1
BEGIN
   SELECT 'Reject changes if the line item is shipped (Status = ''9'')'
   SELECT 'Reject changes if the sourcetype is not ''0'' or ''1'''
END
IF @n_Continue = 1 or @n_Continue = 2
BEGIN
   IF EXISTS (SELECT 1 FROM INSERTED where updatesource NOT IN ('0','1') )
   BEGIN
      SELECT @n_Continue = 3 , @n_err = 61613
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update source is invalid. (ntrPickDetailUpdate)'
      GOTO QUIT
   END
END
-- customized for HK, once pickdetail is Pick in Progress ('3') should not be DELETED. Coz interface has been done
IF @n_Continue=1 or @n_Continue=2
BEGIN
   SELECT @b_success = 0
   Execute nspGetRight null,  -- facility
             @c_StorerKey,    -- StorerKey
             null,            -- Sku
             'OWITF',      -- Configkey
             @b_success    output,
             @c_authority  output,
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailUpdate' + rtrim(@c_errmsg)
      GOTO QUIT
   END
   ELSE IF @c_authority = '1'
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED, DELETED
                 WHERE INSERTED.PickDetailKey = DELETED.PickDetailKey
                 AND DELETED.Status  > '2'
                 AND INSERTED.Status < '3')
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 61614
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Picking in process, Changes to items not allowed. (ntrPickDetailUpdate)'
         GOTO QUIT
      END
   END
END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF UPDATE (Qty) OR UPDATE (OrderKey) OR UPDATE (OrderLineNumber)
   BEGIN
      DECLARE @c_sPickDetailKey            NVARCHAR(20),
              @c_sOrderKey                 NVARCHAR(10),
              @c_sOrderLineNumber          NVARCHAR(5),
              @c_sLot                      NVARCHAR(10),
              @c_sPreAllocatePickDetailKey NVARCHAR(10)

      DECLARE @n_sPreAllocatePickDetailQty int,
              @n_sPickDetailQty            int,
              @n_sQtyToReduce              int

      SELECT @c_sPickDetailKey = SPACE(20)
      WHILE (1=1)
      BEGIN

         SELECT TOP 1 @c_sPickDetailKey = INSERTED.PickDetailKey ,
                @n_sPickDetailQty = INSERTED.QTY - DELETED.QTY,
                @c_sOrderKey = INSERTED.ORDERKEY ,
                @c_sOrderLineNumber = INSERTED.OrderLineNumber ,
                @c_sLot = INSERTED.LOT
         FROM  INSERTED, DELETED
         WHERE INSERTED.PickDetailKey = DELETED.PickDetailKey
         AND INSERTED.PickDetailKey > @c_sPickDetailKey
         AND INSERTED.QTY - DELETED.QTY > 0
         ORDER BY INSERTED.PickDetailKey

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         SELECT @c_sPreAllocatePickDetailKey = SPACE(10)

         WHILE (1=1)
         BEGIN
            SELECT TOP 1 @c_sPreAllocatePickDetailKey = PreAllocatePickDetailKey ,
                   @n_sPreAllocatePickDetailQty = qty
            FROM PreAllocatePickDetail (NOLOCK)
            WHERE PreAllocatePickDetailKey > @c_sPreAllocatePickDetailKey
            AND ORDERKEY = @c_sOrderKey
            AND OrderLineNumber = @c_sOrderLineNumber
            AND LOT = @c_sLot
            AND QTY > 0
            ORDER BY PreAllocatePickDetailKey

            IF @@ROWCOUNT = 0
            BEGIN
               --SET ROWCOUNT 0
               BREAK
            END
            --SET ROWCOUNT 0
            IF @n_sPickDetailQty > @n_sPreAllocatePickDetailQty
            BEGIN
               SELECT @n_sQtyToReduce = @n_sPickDetailQty - @n_sPreAllocatePickDetailQty
               SELECT @n_sPickDetailQty = @n_sPickDetailQty - @n_sQtyToReduce
            END
            ELSE
            BEGIN
               SELECT @n_sQtyToReduce = @n_sPickDetailQty
               SELECT @n_sPickDetailQty = @n_sPickDetailQty - @n_sQtyToReduce
            END

            UPDATE PreAllocatePickDetail  
            SET QTY = QTY - @n_sQtyToReduce,
                  EditDate = GETDATE(),   --tlting
                  EditWho = SUSER_SNAME()
            WHERE PreAllocatePickDetailKey = @c_sPreAllocatePickDetailKey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
           SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61615
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Trigger On PickDetail Could Not Update PreAllocatePickDetail. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
            IF @n_sPickDetailQty <=0
            BEGIN
               BREAK
            END
         END -- 2nd While Loop
         --SET ROWCOUNT 0
      END -- 1st While Loop
      --SET ROWCOUNT 0
   END -- IF UPDATE (Qty) OR UPDATE (OrderKey) OR UPDATE (OrderLineNumber)
END -- IF @n_continue = 1 or @n_continue = 2

-- SWT02 Channel Management 
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
              @c_InsertedLOT    NVARCHAR(10),
              @c_DeletedLOT     NVARCHAR(10),
              @c_cSKU           NVARCHAR(20),
              @n_InsertedQty    INT,
              @n_DeletedQty     INT,
              @c_InsertedStatus NVARCHAR(10),
              @c_DeletedStatus  NVARCHAR(10),
              @c_cPickDetailKey NVARCHAR(10), 
              @n_DeletedChn_ID  BIGINT 
      
      IF ( UPDATE(LOT) OR UPDATE(STATUS) OR UPDATE(Qty) )  
      BEGIN  
         DECLARE CUR_CHANNEL_MGMT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT INSERTED.PickDetailKey,  
                INSERTED.Storerkey,   
                INSERTED.Sku,   
                LOC.Facility,   
                ISNULL(OD.Channel,''),   
                INSERTED.Lot,   
                DELETED.LOT,   
                ISNULL(DELETED.Channel_ID,0),   
                INSERTED.Qty,   
                DELETED.Qty,  
                INSERTED.Status,   
                DELETED.Status   
         FROM INSERTED   
         JOIN DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey     
         JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = INSERTED.Loc 
         CROSS APPLY fnc_SelectGetRight (LOC.Facility, INSERTED.Storerkey, '', 'ChannelInventoryMgmt') SC--(Wan03) 
         --JOIN StorerConfig AS sc WITH(NOLOCK) ON INSERTED.Storerkey = SC.StorerKey                     --(Wan03) 
         --          AND SC.ConfigKey = 'ChannelInventoryMgmt' AND SC.sValue = '1'                       --(Wan03) 
         JOIN ORDERDETAIL AS OD WITH(NOLOCK)  
                ON  OD.OrderKey = INSERTED.OrderKey AND OD.OrderLineNumber = INSERTED.OrderLineNumber  
         WHERE ( INSERTED.Qty <> DELETED.Qty OR   
               ( INSERTED.Status <= '9' AND DELETED.Status IN ('0','1','2','3','4','5','6','7','8') ) )  --INC0683213 
         AND SC.Authority = '1'                                                                          --(Wan03) 
   
               
         OPEN CUR_CHANNEL_MGMT   
        
         FETCH NEXT FROM CUR_CHANNEL_MGMT INTO @c_cPickDetailKey, @c_cStorerKey, @c_cSKU, @c_cFacility, @c_Channel, @c_InsertedLOT, @c_DeletedLOT,   
            @n_Channel_ID, @n_InsertedQty, @n_DeletedQty, @c_InsertedStatus, @c_DeletedStatus 
      
         WHILE @@FETCH_STATUS = 0 
         BEGIN
            IF ISNULL(RTRIM(@c_Channel),'') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63125   
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                     + ': Order Detail Channel Cannot be BLANK. (ntrPickDetailUpdate)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
               BREAK                
            END
            IF ISNULL(@n_Channel_ID,0) = 0 
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63126   
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                     + ': Channel ID Cannot be BLANK. (ntrPickDetailUpdate)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
               BREAK       
      
            END
            IF @c_InsertedLOT = @c_DeletedLOT 
            BEGIN
               IF ISNULL(@n_Channel_ID,0) > 0 
               BEGIN
                  IF (@c_InsertedStatus = @c_DeletedStatus) OR (@c_InsertedStatus < '9')  --INC0683213 
                  BEGIN
                     UPDATE ChannelInv  
                        SET QtyAllocated = QtyAllocated - @n_DeletedQty + @n_InsertedQty , 
                              EditDate = GETDATE(),
                              EditWho = SUSER_SNAME()
                     WHERE Channel_ID = @n_Channel_ID                      
                  END -- IF @c_InsertedStatus = @c_DeletedStatus 
                  ELSE 
                  BEGIN
                     IF @c_InsertedStatus = '9' AND @c_DeletedStatus IN ('0','1','2','3','4','5','6','7','8') 
                     BEGIN
                        UPDATE ChannelInv  
                           SET QtyAllocated = QtyAllocated - @n_DeletedQty, 
                                 EditDate = GETDATE(),
                                 EditWho = SUSER_SNAME()
                        WHERE Channel_ID = @n_Channel_ID                                                                         
                     END                     
                  END -- IF @c_InsertedStatus <> @c_DeletedStatus                   
               END -- IF ISNULL(@n_Channel_ID,0) > 0           
            END -- IF @c_InsertedLOT = @c_DeletedLOT 
            ELSE 
            BEGIN
               SET @n_DeletedChn_ID = 0
                
               EXEC isp_ChannelGetID 
                   @c_StorerKey   = @c_cStorerKey
                  ,@c_Sku         = @c_cSKU
                  ,@c_Facility    = @c_cFacility
                  ,@c_Channel     = @c_Channel
                  ,@c_LOT         = @c_DeletedLOT
                  ,@n_Channel_ID  = @n_DeletedChn_ID OUTPUT

                IF @n_DeletedChn_ID > 0 
                BEGIN
                  UPDATE ChannelInv  
                     SET QtyAllocated = QtyAllocated - @n_DeletedQty, 
                         EditDate = GETDATE(),
                         EditWho = SUSER_SNAME()
                  WHERE Channel_ID = @n_DeletedChn_ID                      
                END                                
                IF ISNULL(@n_Channel_ID,0) > 0 
                BEGIN
                  UPDATE ChannelInv  
                     SET QtyAllocated = QtyAllocated + @n_InsertedQty , 
                         EditDate = GETDATE(),
                         EditWho = SUSER_SNAME()
                  WHERE Channel_ID = @n_Channel_ID                   
                END  
            END -- IF @c_InsertedLOT <> @c_DeletedLOT 
         
            FETCH NEXT FROM CUR_CHANNEL_MGMT INTO @c_cPickDetailKey, @c_cStorerKey, @c_cSKU, @c_cFacility, @c_Channel, @c_InsertedLOT, @c_DeletedLOT,   
               @n_Channel_ID, @n_InsertedQty, @n_DeletedQty, @c_InsertedStatus, @c_DeletedStatus  
         END -- While 
         CLOSE CUR_CHANNEL_MGMT
         DEALLOCATE CUR_CHANNEL_MGMT
      END -- NOT UPDATE(LOT) AND ( UPDATE(STATUS) OR UPDATE(Qty) )         
   END   
END 

---- Process LOT Table Update
IF ( @n_continue = 1 or @n_continue = 2 ) AND 
   ( UPDATE(STORERKEY) OR UPDATE(SKU) OR UPDATE(LOT) OR UPDATE(STATUS) OR UPDATE(QTY) )
BEGIN
   -- tlting01

   Declare @tLOT TABLE   (
      LOT          NVARCHAR(10) NOT NULL,
      QtyAllocated int,
      QtyPicked    int,
      QtyShipped   int
      PRIMARY KEY CLUSTERED (LOT)
      )

   INSERT INTO @tLOT  ( LOT, QtyAllocated, QtyPicked, QtyShipped )
   SELECT LOT,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty ELSE 0 END) AS QtyShipped
   FROM INSERTED
   GROUP BY LOT

   UPDATE tLOT
      SET QtyAllocated = tLOT.QtyAllocated + DEL_PD.QtyAllocated,
          QtyPicked    = tLOT.QtyPicked + DEL_PD.QtyPicked,
          QtyShipped   = tLOT.QtyShipped + DEL_PD.QtyShipped
   FROM  @tLOT tLOT
   JOIN (SELECT LOT,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty * -1 ELSE 0 END) AS QtyShipped
         FROM DELETED
         GROUP BY LOT) AS DEL_PD ON DEL_PD.LOT = tLOT.LOT

   INSERT INTO @tLOT  ( LOT, QtyAllocated, QtyPicked, QtyShipped )
   SELECT DELETED.LOT,
          SUM (CASE WHEN DELETED.Status IN ('0','1','2','3','4') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN DELETED.Status IN ('5','6','7','8') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty * -1 ELSE 0 END) AS QtyShipped
   FROM DELETED
   LEFT OUTER JOIN @tLOT LOT ON LOT.LOT = DELETED.LOT
   WHERE LOT.LOT IS NULL
   GROUP BY DELETED.LOT


   UPDATE LOT  
   SET  Lot.QtyAllocated = (Lot.QtyAllocated + tL.QtyAllocated),
        Lot.QtyPicked    = (Lot.QtyPicked + tL.QtyPicked),
        -- LOT.Qty = (LOT.Qty - tl.QtyShipped)
        EditDate = GETDATE(),   --tlting
        EditWho = SUSER_SNAME()
   FROM LOT
   JOIN @tLOT tL ON tL.LOT = LOT.LOT
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61616
     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update trigger On LOT Failed. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
     GOTO QUIT
   END
END -- IF UPDATE LOT

---- Process LOTxLOCxID Table Update
IF ( @n_continue = 1 or @n_continue = 2 ) AND 
( UPDATE(STORERKEY) OR UPDATE(SKU) OR UPDATE(LOT) OR UPDATE(LOC) OR UPDATE(ID) OR UPDATE(STATUS) OR UPDATE(QTY) )
BEGIN
   -- tlting01
   DECLARE @tLOTxLOCxID     TABLE  (
      LOT          NVARCHAR(10) NOT NULL,
      LOC          NVARCHAR(10) NOT NULL,
      ID           NVARCHAR(18) NOT NULL,
      QtyAllocated int DEFAULT (0),
      QtyPicked    int DEFAULT (0),
      QtyShipped   int DEFAULT (0)
      PRIMARY KEY CLUSTERED (LOT, LOC, ID)
      )
   INSERT INTO @tLOTxLOCxID  ( LOT, LOC, ID, QtyAllocated, QtyPicked, QtyShipped )
   SELECT LOT, LOC, ID,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty ELSE 0 END) AS QtyShipped
   FROM INSERTED
   GROUP BY LOT, LOC, ID

   UPDATE tLLI
      SET tLLI.QtyAllocated = tLLI.QtyAllocated + DEL_PD.QtyAllocated,
          tLLI.QtyPicked    = tLLI.QtyPicked + DEL_PD.QtyPicked,
          tLLI.QtyShipped   = tLLI.QtyShipped + DEL_PD.QtyShipped
   FROM  @tLOTxLOCxID tLLI
   JOIN (SELECT LOT, LOC, ID,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty * -1 ELSE 0 END) AS QtyShipped
         FROM DELETED
         GROUP BY LOT, LOC, ID) AS DEL_PD ON DEL_PD.LOT = tLLI.LOT AND DEL_PD.LOC = tLLI.LOC
                               AND DEL_PD.ID = tLLI.ID

   INSERT INTO @tLOTxLOCxID  ( LOT, LOC, ID, QtyAllocated, QtyPicked, QtyShipped )
   SELECT DELETED.LOT, DELETED.LOC, DELETED.ID,
          SUM (CASE WHEN DELETED.Status IN ('0','1','2','3','4') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN DELETED.Status IN ('5','6','7','8') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN DELETED.Status = '9' THEN DELETED.Qty * -1 ELSE 0 END) AS QtyShipped
   FROM DELETED
   LEFT OUTER JOIN @tLOTxLOCxID LLI ON LLI.LOT = DELETED.LOT AND LLI.LOC = DELETED.LOC AND LLI.ID = DELETED.ID
   WHERE LLI.LOT IS NULL
   GROUP BY DELETED.LOT, DELETED.LOC, DELETED.ID

   UPDATE LOTxLOCxID  
   SET  QtyAllocated = (LOTxLOCxID.QtyAllocated + tLLI.QtyAllocated),
        QtyPicked    = (LOTxLOCxID.QtyPicked + tLLI.QtyPicked),
        QtyExpected  = CASE WHEN SL.LocationType NOT IN ('CASE','PICK') AND               -- (SHONG01)
                                 LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK') THEN 0  -- (TLTING01) (NJOW01)
                            WHEN (( LOTxLOCxID.QtyAllocated +  tLLI.QtyAllocated) +
                                  ( LOTxLOCxID.QtyPicked  + tLLI.QtyPicked )) > (LOTxLOCxID.Qty - tLLI.QtyShipped)
                            THEN (( LOTxLOCxID.QtyAllocated +  tLLI.QtyAllocated) +
                                  ( LOTxLOCxID.QtyPicked  + tLLI.QtyPicked ))  - (LOTxLOCxID.Qty - tLLI.QtyShipped)
                            ELSE 0
                       END,
        /*
        Qty = (LOTxLOCxID.Qty - tLLI.QtyShipped)
        */
         EditDate = GETDATE(),   --tlting
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
   IF @n_err <> 0
   BEGIN
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61617
     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update trigger On LOTxLOCxID Failed. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
     GOTO QUIT
   END
END -- IF UPDATE LOTXLOCXID

--- Process SKUxLOC Table Update
IF ( @n_continue = 1 or @n_continue = 2 ) AND 
( UPDATE(STORERKEY) OR UPDATE(SKU) OR UPDATE(LOC) OR UPDATE(STATUS) OR UPDATE(QTY) )
BEGIN
   -- tlting01
  DECLARE @tSKUxLOC Table    (
      StorerKey    NVARCHAR(15) NOT NULL,
      SKU          NVARCHAR(20) NOT NULL,
      LOC          NVARCHAR(10) NOT NULL,
      QtyAllocated int DEFAULT (0),
      QtyPicked    int DEFAULT (0),
      QtyShipped   int DEFAULT (0)
      PRIMARY KEY CLUSTERED (StorerKey, SKU, LOC)
      )

   INSERT INTO @tSKUxLOC ( StorerKey, SKU, LOC, QtyAllocated, QtyPicked, QtyShipped )
   SELECT StorerKey, SKU, LOC,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty ELSE 0 END) AS QtyShipped
   FROM INSERTED
   GROUP BY StorerKey, SKU, LOC

   UPDATE tSL         SET tSL.QtyAllocated = tSL.QtyAllocated + DEL_PD.QtyAllocated,
          tSL.QtyPicked    = tSL.QtyPicked + DEL_PD.QtyPicked ,
          tSL.QtyShipped   = tSL.QtyShipped + DEL_PD.QtyShipped
   FROM  @tSKUxLOC tSL
   JOIN (SELECT StorerKey, SKU, LOC,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty * -1 ELSE 0 END) AS QtyShipped
         FROM DELETED
         GROUP BY StorerKey, SKU, LOC) AS DEL_PD ON DEL_PD.StorerKey = tSL.StorerKey AND
                                          DEL_PD.SKU = tSL.SKU AND
                                          DEL_PD.LOC = tSL.LOC

   INSERT INTO @tSKUxLOC  ( StorerKey, SKU, LOC, QtyAllocated, QtyPicked, QtyShipped )
   SELECT DELETED.StorerKey, DELETED.SKU, DELETED.LOC,
          SUM (CASE WHEN DELETED.Status IN ('0','1','2','3','4') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN DELETED.Status IN ('5','6','7','8') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN DELETED.Status = '9' THEN DELETED.Qty * -1 ELSE 0 END) AS QtyShipped
   FROM DELETED
   LEFT OUTER JOIN @tSKUxLOC tSL ON tSL.StorerKey = DELETED.StorerKey AND tSL.SKU = DELETED.SKU
                                AND tSL.LOC =  DELETED.LOC
   WHERE tSL.SKU IS NULL
   GROUP BY DELETED.StorerKey, DELETED.SKU, DELETED.LOC

   UPDATE SKUxLOC  
   SET  QtyAllocated = (SKUxLOC.QtyAllocated + tSL.QtyAllocated),
        QtyPicked    = (SKUxLOC.QtyPicked + tSL.QtyPicked),
        QtyExpected  = CASE WHEN SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                 tSL.QtyAllocated + tSL.QtyPicked > (SKUxLOC.Qty - QtyShipped)
                            THEN ( SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                   tSL.QtyAllocated + tSL.QtyPicked ) - (SKUxLOC.Qty - QtyShipped)
                            ELSE 0
                       END,
   /*     QtyExpected  = CASE WHEN @c_AllowOverAllocations <> '1' THEN 0
                            WHEN SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                 tSL.QtyAllocated + tSL.QtyPicked > SKUxLOC.Qty
                            THEN ( SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked +
                                   tSL.QtyAllocated + tSL.QtyPicked ) - SKUxLOC.Qty
                            ELSE 0
                       END
         ,
         Qty    = (SKUxLOC.Qty - tSL.QtyShipped)
         */
         EditDate = GETDATE(),   --tlting
         EditWho = SUSER_SNAME()
   FROM SKUxLOC
   JOIN @tSKUxLOC tSL ON tSL.StorerKey = SKUxLOC.StorerKey AND
                     tSL.SKU = SKUxLOC.SKU AND
                     tSL.LOC = SKUxLOC.LOC
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61618
     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update trigger On SKUxLOC Failed. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
     GOTO QUIT
   END
END -- IF UPDATE...

--- Proccess OrderDetail Update
IF ( @n_continue = 1 or @n_continue = 2 ) AND 
( UPDATE(ORDERKEY) OR UPDATE(OrderLineNumber) OR UPDATE(QTY) OR UPDATE(STATUS) )
BEGIN
 -- tlting01
 Declare @tOrderDetail TABLE  (
      OrderKey NVARCHAR(10),
      OrderLineNumber NVARCHAR(5),
      QtyAllocated    int,
      QtyPicked       int,
      QtyShipped      int
      PRIMARY KEY CLUSTERED (OrderKey, OrderLineNumber) )

   INSERT INTO @tOrderDetail   (OrderKey, OrderLineNumber, QtyAllocated, QtyPicked, QtyShipped )
   SELECT OrderKey, OrderLineNumber,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty ELSE 0 END) AS QtyShipped
   FROM INSERTED
   GROUP BY OrderKey, OrderLineNumber

   UPDATE tOrdDet
      SET tOrdDet.QtyAllocated = tOrdDet.QtyAllocated + DEL_PD.QtyAllocated,
          tOrdDet.QtyPicked    = tOrdDet.QtyPicked + DEL_PD.QtyPicked,
         tOrdDet.QtyShipped   = tOrdDet.QtyShipped + DEL_PD.QtyShipped
   FROM  @tOrderDetail tOrdDet
   JOIN (SELECT OrderKey, OrderLineNumber,
          SUM (CASE WHEN Status IN ('0','1','2','3','4') THEN Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN Status IN ('5','6','7','8') THEN Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN Status = '9' THEN Qty * -1 ELSE 0 END) AS QtyShipped
         FROM DELETED
         GROUP BY OrderKey, OrderLineNumber) AS DEL_PD ON DEL_PD.OrderKey = tOrdDet.OrderKey AND
                                                          DEL_PD.OrderLineNumber = tOrdDet.OrderLineNumber

   INSERT INTO @tOrderDetail  (OrderKey, OrderLineNumber, QtyAllocated, QtyPicked, QtyShipped )
   SELECT DELETED.OrderKey, DELETED.OrderLineNumber,
          SUM (CASE WHEN DELETED.Status IN ('0','1','2','3','4') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyAllocated,
          SUM (CASE WHEN DELETED.Status IN ('5','6','7','8') THEN DELETED.Qty * -1 ELSE 0 END) AS QtyPicked,
          SUM (CASE WHEN DELETED.Status = '9' THEN DELETED.Qty * -1 ELSE 0 END) AS QtyShipped
   FROM DELETED
   LEFT OUTER JOIN @tOrderDetail tOrdDet ON tOrdDet.OrderKey = DELETED.OrderKey
                                        AND tOrdDet.OrderLineNumber = DELETED.OrderLineNumber
   WHERE tOrdDet.OrderKey IS NULL
   GROUP BY DELETED.OrderKey, DELETED.OrderLineNumber

   -- (SWT01) Performance Tuning 
   --UPDATE OrderDetail WITH (RowLock)
   --SET  OrderDetail.QtyAllocated = (OrderDetail.QtyAllocated + tOrdDet.QtyAllocated),
   --     OrderDetail.QtyPicked    = (OrderDetail.QtyPicked + tOrdDet.QtyPicked),
   --     OrderDetail.ShippedQty   = (OrderDetail.ShippedQty + tOrdDet.QtyShipped),
   --     OrderDetail.OpenQty      = (OrderDetail.OpenQty - tOrdDet.QtyShipped),
   --     OrderDetail.EditDate     = GETDATE(),   --tlting
   --     OrderDetail.EditWho      = SUSER_SNAME()
   --FROM OrderDetail
   --JOIN #tOrderDetail AS tOrdDet ON (OrderDetail.OrderKey = tOrdDet.OrderKey AND OrderDetail.OrderLineNumber = tOrdDet.OrderLineNumber)   
   IF EXISTS(SELECT 1 FROM @tOrderDetail WHERE QtyShipped > 0) 
   BEGIN
      UPDATE OrderDetail  
      SET  OrderDetail.QtyAllocated = (OrderDetail.QtyAllocated + tOrdDet.QtyAllocated),
           OrderDetail.QtyPicked    = (OrderDetail.QtyPicked + tOrdDet.QtyPicked),
           OrderDetail.ShippedQty   = (OrderDetail.ShippedQty + tOrdDet.QtyShipped),
           OrderDetail.OpenQty      = (OrderDetail.OpenQty - tOrdDet.QtyShipped),
           OrderDetail.EditDate     = GETDATE(),   --tlting
           OrderDetail.EditWho      = SUSER_SNAME()
      FROM OrderDetail
      JOIN @tOrderDetail AS tOrdDet ON (OrderDetail.OrderKey = tOrdDet.OrderKey AND OrderDetail.OrderLineNumber = tOrdDet.OrderLineNumber)      
   END
   ELSE 
   BEGIN
      UPDATE OrderDetail  
      SET  OrderDetail.QtyAllocated = (OrderDetail.QtyAllocated + tOrdDet.QtyAllocated),
           OrderDetail.QtyPicked    = (OrderDetail.QtyPicked + tOrdDet.QtyPicked),
           OrderDetail.EditDate     = GETDATE(),   --tlting
           OrderDetail.EditWho      = SUSER_SNAME()
      FROM OrderDetail
      JOIN @tOrderDetail AS tOrdDet ON (OrderDetail.OrderKey = tOrdDet.OrderKey AND OrderDetail.OrderLineNumber = tOrdDet.OrderLineNumber)      
   END

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61619
     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update trigger On PickDetail Failed. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
     GOTO QUIT
   END
END -- UPDATE ORDERDETAIL

--(Wan04) - START
IF @n_Continue IN ( 1 ,2 ) AND UPDATE(STATUS) AND  -- UPDATE PACKTASKDETAIL
   EXISTS (SELECT 1 FROM INSERTED INS JOIN DELETED DEL ON INS.PickdetailKey = DEL.PickDetailKey 
           WHERE INS.[STATUS] <> DEL.[STATUS] 
           AND INS.[STATUS] = '3'
           )
BEGIN
   
   DECLARE @tPickOrd TABLE (Orderkey   NVARCHAR(10) NOT NULL DEFAULT(''))
   
   DECLARE @tFullPickOrd TABLE (Orderkey   NVARCHAR(10) NOT NULL DEFAULT(''))
   
   INSERT INTO @tPickOrd (Orderkey)
   SELECT INS.Orderkey 
   FROM INSERTED INS JOIN DELETED DEL ON INS.PickdetailKey = DEL.PickDetailKey 
   JOIN LOC L WITH (NOLOCK) ON INS.Loc = L.Loc
   CROSS APPLY fnc_SelectGetRight (L.Facility, INS.Storerkey, '', 'EPACK4PickedOrder') SC
   WHERE INS.[STATUS] <> DEL.[STATUS]
   AND INS.[STATUS] = '3'   
   AND SC.Authority = '1'
   GROUP BY INS.Orderkey 
     
   IF EXISTS (SELECT 1 
              FROM @tPickOrd pck
              JOIN PACKTASKDETAIL AS p WITH (NOLOCK) ON pck.Orderkey = p.Orderkey
              WHERE p.[Status] = 'P')
   BEGIN
      INSERT INTO @tFullPickOrd ( Orderkey )
      SELECT pd.Orderkey
      FROM @tPICKORD pck
      JOIN PICKDETAIL AS pd WITH (NOLOCK) ON pd.OrderKey = pck.Orderkey
      GROUP BY pd.OrderKey
      HAVING MIN(pd.[Status]) BETWEEN '3' AND '5'
      AND MAX(pd.[Status]) < '9' 
      AND MAX(pd.ShipFlag) NOT IN ('Y')

      IF EXISTS (  SELECT 1 FROM @tFullPickOrd fpck JOIN PACKTASKDETAIL AS p WITH (NOLOCK) ON fpck.Orderkey = p.Orderkey
                   WHERE  p.[Status] = 'P'
      )
      BEGIN
         ;WITH PTD ( RowRef )
          AS ( SELECT RowRef FROM @tFullPickOrd fpck JOIN PACKTASKDETAIL AS p WITH (NOLOCK) ON fpck.Orderkey = p.Orderkey
               WHERE  p.[Status] = 'P'
             )
                 
         UPDATE p
            SET [Status] = '0'
            , Editwho  = SUSER_SNAME()
            , Editdate = GETDATE()
            , Trafficcop = NULL
         FROM PACKTASKDETAIL AS p 
         JOIN PTD ON PTD.RowRef = p.RowRef
         WHERE p.[Status] = 'P'
               
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err=61621   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                              + ': Update Failed On PACKTASKDETAIL. (ntrPickDetailUpdate) ( SQLSvr MESSAGE='
                              + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END
   END
END 
--(Wan04) - END

IF @b_debug=1
BEGIN
    SELECT 'Should We Update Inventory Here??'
END

IF @n_continue=1 OR @n_continue=2
BEGIN
    DECLARE @c_uPickDetailKey    NVARCHAR(18)
           ,@c_uOrderKey         NVARCHAR(10)
           ,@c_uOrderLineNumber  NVARCHAR(5)
           ,@c_uLot              NVARCHAR(10)
           ,@c_uStorerKey        NVARCHAR(15)
           ,@c_uSku              NVARCHAR(20)
           ,@n_uQty              INT
           ,@c_uToloc            NVARCHAR(10)
           ,@c_uToid             NVARCHAR(18)
           ,@d_uEffectiveDate    DATETIME
           ,@c_uUom              NVARCHAR(10)
           ,@c_uPackkey          NVARCHAR(10)
           ,@n_uChannel_ID       BIGINT -- SWT02 
           ,@c_uChannel          NVARCHAR(20) -- SWT02 

    DECLARE @n_Pallet            INT
           ,@n_CaseCnt           INT
           ,@n_InnerPack         INT
           ,@f_OtherUnit1        FLOAT
           ,@f_OtherUnit2        FLOAT
           ,@f_NetWgt            FLOAT
           ,@f_GrossWgt          FLOAT
           ,@f_Tare              FLOAT
           ,@c_Ioflag            NVARCHAR(1)
           ,@c_PrevStorerKey     NVARCHAR(15)
           ,@c_PrevSKU          NVARCHAR(20)

    SELECT @c_uPickDetailKey = master.dbo.fnc_GetCharASCII(14)
          ,@c_PrevStorerKey = master.dbo.fnc_GetCharASCII(14)
          ,@c_PrevSKU = master.dbo.fnc_GetCharASCII(14)

    WHILE (1=1)
    BEGIN

        SELECT TOP 1 @c_uPickDetailKey = PickDetailKey
              ,@c_uOrderKey = OrderKey
              ,@c_uOrderLineNumber = OrderLineNumber
              ,@c_ulot = lot
              ,@c_uStorerKey = StorerKey
              ,@c_usku = sku
              ,@c_uuom = uom
              ,@c_uPackKey = PackKey
              ,@n_uqty = qty
              ,@c_utoloc = loc
              ,@c_utoid = id
              ,@d_uEffectiveDate = EffectiveDate
              ,@n_uChannel_ID = Channel_ID -- SWT02 
        FROM   INSERTED
        WHERE  PickDetailKey > @c_uPickDetailKey
               AND STATUS = '9'
               AND updatesource = '0'
        ORDER BY PickDetailKey
        IF @@ROWCOUNT=0
        BEGIN
           BREAK
        END
                
        SELECT @c_uChannel = Channel -- SWT02 
        FROM ORDERDETAIL AS o WITH (NOLOCK)
        WHERE o.OrderKey = @c_uOrderKey
        AND o.OrderLineNumber = @c_uOrderLineNumber 

        IF @n_continue=1 OR @n_continue=2
        BEGIN
            SELECT @n_pallet = 0
                  ,@n_CaseCnt = 0
                  ,@n_InnerPack = 0
                  ,@f_OtherUnit1 = 0.0
                  ,@f_OtherUnit2 = 0.0
                  ,@f_NetWgt = 0.0
                  ,@f_GrossWgt = 0.0
                  ,@f_tare = 0.0

            SELECT @c_uuom =  dbo.fnc_RTRIM(@c_uuom)
            IF @c_uuom='1'
                SELECT @n_pallet = 1

            IF @c_uuom='2'
                SELECT @n_CaseCnt = 1

            IF @c_uuom='3'
                SELECT @n_InnerPack = 1

            IF @c_uuom='4'
                SELECT @f_OtherUnit1 = 1.0

            IF @c_uuom='5'
                SELECT @f_OtherUnit2 = 1.0

            IF @c_catchweight='1'
            BEGIN
                IF @c_PrevStorerKey<>@c_uStorerKey
                   OR @c_PrevSKU<>@c_usku
                BEGIN
                    SELECT @c_ioflag = ISNULL(IOFlag ,'N')
                          ,@f_tare = ISNULL(TareWeight ,0)
                    FROM   SKU WITH (NOLOCK)
                    WHERE  Sku = @c_usku
                           AND StorerKey = @c_uStorerKey

                    SELECT @c_PrevStorerKey = @c_uStorerKey
                          ,@c_PrevSKU = @c_usku
                END

                IF @c_ioflag IN ('O' ,'B')
                BEGIN
                    SELECT @f_NetWgt = ISNULL(SUM(Wgt) ,0)
                    FROM   LOTxIDDETAIL WITH (NOLOCK)
                    WHERE  PickDetailKey = @c_uPickDetailKey
                           AND IOFlag = 'O'

                    IF @f_NetWgt>0
                    BEGIN
                        SELECT @f_GrossWgt = @f_NetWgt+@f_tare*@n_uqty
                    END
                END
            END

            /*SOS 131697*/
            /*CS01 start*/
            SELECT @c_Lottable01 = Lottable01
                  ,@c_Lottable02 = Lottable02
                  ,@c_Lottable03 = Lottable03
                  ,@d_Lottable04 = Lottable04
                  ,@d_Lottable05 = Lottable05
                  ,@c_Lottable06 = Lottable06
                  ,@c_Lottable07 = Lottable07
                  ,@c_Lottable08 = Lottable08
                  ,@c_Lottable09 = Lottable09
                  ,@c_Lottable10 = Lottable10
                  ,@c_Lottable11 = Lottable11
                  ,@c_Lottable12 = Lottable12
                  ,@d_Lottable13 = Lottable13
                  ,@d_Lottable14 = Lottable14
                  ,@d_Lottable15 = Lottable15
            FROM   LOTATTRIBUTE WITH (NOLOCK)
            WHERE  LOT = @c_ulot
            
            SELECT @c_uChannel = ci.Channel 
            FROM ChannelInv AS ci WITH(NOLOCK)
     WHERE ci.Channel_ID = @n_uChannel_ID

            SELECT @b_success = 0
            EXECUTE nspItrnAddWithdrawal 
               @n_ItrnSysId     =   NULL,
               @c_StorerKey     =   @c_uStorerKey,
               @c_Sku           =   @c_usku,
               @c_Lot           =   @c_ulot,
               @c_ToLoc         =   @c_utoloc,
               @c_ToID          =   @c_utoid,
               @c_Status        =   '',
               @c_Lottable01    =   @c_Lottable01,
               @c_Lottable02    =   @c_Lottable02,
               @c_Lottable03    =   @c_Lottable03,
               @d_Lottable04    =   @d_Lottable04,
               @d_Lottable05    =   @d_Lottable05,
               @c_Lottable06    =   @c_Lottable06,
               @c_Lottable07    =   @c_Lottable07,
               @c_Lottable08    =   @c_Lottable08,
               @c_Lottable09    =   @c_Lottable09,
               @c_Lottable10    =   @c_Lottable10,
               @c_Lottable11    =   @c_Lottable11,
               @c_Lottable12    =   @c_Lottable12,
               @d_Lottable13    =   @d_Lottable13,
               @d_Lottable14    =   @d_Lottable14,
               @d_Lottable15    =   @d_Lottable15,
               @c_Channel       =   @c_uChannel, 
               @n_Channel_ID    =   @n_uChannel_ID, 
               @n_casecnt       =   @n_CaseCnt,
               @n_innerpack     =   @n_InnerPack,
               @n_qty           =   @n_uqty,
               @n_pallet        =   @n_pallet,
               @f_cube          =   0,
               @f_grosswgt      =   @f_GrossWgt,
               @f_netwgt        =   @f_NetWgt,
               @f_otherunit1    =   @f_OtherUnit1,
               @f_otherunit2    =   @f_OtherUnit2,
               @c_SourceKey     =   @c_uPickDetailKey,
               @c_SourceType    =   'ntrPickDetailUpdate',
               @c_PackKey       =   @c_uPackkey,
               @c_UOM           =   @c_uuom,
               @b_UOMCalc       =   0,
               @d_EffectiveDate =   @d_uEffectiveDate,
               @c_itrnkey       =   '',
               @b_Success       =   @b_success OUTPUT,  
               @n_err           =   @n_err     OUTPUT,
               @c_errmsg        =   @c_errmsg  OUTPUT
               
            /*Cs01 End*/
            IF @b_success<>1
            BEGIN
                SELECT @n_continue = 3
            END
        END-- IF @n_continue =1 or @n_continue = 2
    END -- WHILE
    --SET ROWCOUNT 0
END -- IF @n_continue = 1 or @n_continue=2

-- MC01-S
IF ( @n_continue = 1 or @n_continue = 2 ) AND 
( UPDATE(QTY) OR UPDATE(LOT) OR UPDATE(LOC) OR UPDATE(ID) )
BEGIN
   IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
             WHERE StorerKey = @c_StorerKey AND ConfigKey = 'WAVEUPDLOG' AND sValue = '1')
   BEGIN

      INSERT INTO PickDetail_Log (OrderKey ,OrderLineNumber ,WaveKey ,StorerKey
                                 ,B_SKU ,B_LOT ,B_LOC ,B_ID ,B_QTY
                                 ,A_SKU ,A_LOT ,A_LOC ,A_ID ,A_QTY
                                 ,Status ,PickDetailKey)
      SELECT DELETED.OrderKey ,DELETED.OrderLineNumber ,WaveDetail.Wavekey ,DELETED.Storerkey
            ,DELETED.Sku      ,DELETED.Lot             ,DELETED.Loc        ,DELETED.ID         ,DELETED.Qty
            ,INSERTED.Sku     ,INSERTED.Lot            ,INSERTED.Loc       ,INSERTED.ID        ,INSERTED.Qty
            ,'0'              ,DELETED.PickDetailKey
      FROM  INSERTED
      JOIN  DELETED ON INSERTED.PickDetailKey = DELETED.PickDetailKey
      JOIN  WaveDetail WITH (NOLOCK) ON ( WaveDetail.Orderkey = DELETED.Orderkey )
      WHERE EXISTS ( SELECT 1 FROM Transmitlog3 WITH (NOLOCK)
                     WHERE Tablename = 'WAVERESLOG'
                     AND Key1 = WaveDetail.Wavekey
                     AND Key3 = DELETED.Storerkey
                     AND TransmitFlag > '0' )

   END -- IF EXISTS(StorerConfig - 'WAVEUPDLOG')
END
-- MC01-E

--NJOW02 -S
IF (@n_Continue=1 or @n_Continue=2)
   AND UPDATE(Status)
   AND EXISTS(SELECT 1 FROM INSERTED
              JOIN DELETED ON INSERTED.Pickdetailkey = DELETED.Pickdetailkey
              WHERE INSERTED.Status='5' AND DELETED.Status <> INSERTED.Status)
BEGIN
    SELECT @b_success = 0
   Execute nspGetRight @c_Facility,  -- facility
             @c_StorerKey,    -- StorerKey
             null,            -- Sku
             'IDToDropID',      -- Configkey
             @b_success    output,
             @c_authority  output,
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailUpdate' + rtrim(@c_errmsg)
      GOTO QUIT
   END
   ELSE IF @c_authority = '1'
   BEGIN
        UPDATE PICKDETAIL  
        SET PICKDETAIL.DropID = PICKDETAIL.ID,
           PICKDETAIL.TrafficCop = NULL
        FROM PICKDETAIL
        JOIN INSERTED ON PICKDETAIL.Pickdetailkey = INSERTED.Pickdetailkey
        JOIN ORDERS (NOLOCK) ON INSERTED.Orderkey = ORDERS.Orderkey
        JOIN CODELKUP CL (NOLOCK) ON ORDERS.Storerkey = CL.Storerkey AND ORDERS.Type = CL.Code
                                  AND CL.Listname = 'IDTODROPID'
   END
END
--NJOW02 -E

--NJOW03 -S
IF (@n_Continue=1 or @n_Continue=2)
   AND UPDATE(Qty)
   AND EXISTS(SELECT 1 FROM INSERTED
              JOIN DELETED ON INSERTED.Pickdetailkey = DELETED.Pickdetailkey
              WHERE INSERTED.Status='4' AND DELETED.Qty > INSERTED.Qty)
BEGIN

   DECLARE @n_ShortQty INT

   SELECT @b_success = 0
   Execute nspGetRight @c_Facility,  -- facility
            @c_StorerKey,    -- StorerKey
            null,            -- Sku
            'AutoMoveShortPick_SP',      -- Configkey
            @b_success    output,
            @c_authority  output,
            @n_err        output,
            @c_errmsg     output

   IF @b_success <> 1
   BEGIN
      SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailUpdate' + rtrim(@c_errmsg)
      GOTO QUIT
   END
   ELSE IF LEN(ISNULL(RTRIM(@c_authority),'')) > 1
   BEGIN

        SET @c_uPickDetailKey = ''
        WHILE (1=1) AND (@n_Continue=1 or @n_Continue=2)
        BEGIN

         SELECT TOP 1 @c_uPickDetailKey = INSERTED.PickDetailKey,
                @n_ShortQty = DELETED.Qty - INSERTED.Qty
         FROM INSERTED
         JOIN DELETED ON INSERTED.Pickdetailkey = DELETED.Pickdetailkey
         WHERE INSERTED.PickDetailKey > @c_uPickDetailKey
         AND INSERTED.Status='4' AND DELETED.Qty > INSERTED.Qty
         ORDER BY INSERTED.PickDetailKey

         IF @@ROWCOUNT = 0
         BEGIN
             BREAK
         END

         SELECT @b_Success = 0

         EXECUTE dbo.isp_AutoMoveShortPick_Wrapper
                 @c_uPickDetailKey
               , @n_ShortQty
               , @b_Success OUTPUT
               , @n_Err     OUTPUT
               , @c_ErrMsg  OUTPUT

         IF @b_Success <> 1
         BEGIN
            SELECT @n_Continue = 3, @c_errmsg = 'ntrPickDetailUpdate ' + rtrim(@c_errmsg)
         END
      END
   END
END
--NJOW03 -E

-- tlting02
IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   IF @c_AllowOverAllocations = "0"
   BEGIN
      IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK), INSERTED --NJOW02
                WHERE INSERTED.Lot = LOTxLOCxID.Lot
                AND INSERTED.Loc = LOTxLOCxID.Loc
                AND INSERTED.Id = LOTxLOCxID.Id
                AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED) > LOTxLOCxID.QTY)
      BEGIN
         SELECT @n_Continue = 3 , @n_err = 61620
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": An Attempt Was Made by OverAllocate is Turn OFF. (ntrPickDetailUpdate)"
      END
   END
END

IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
BEGIN
   UPDATE PICKDETAIL  
   SET EditDate = GETDATE(), EditWho=SUSER_SNAME(),
       TrafficCop = NULL                            -- tlting01
   FROM PICKDETAIL,INSERTED
   WHERE PICKDETAIL.PickDetailKey=INSERTED.PickDetailKey
   AND INSERTED.[status] = '9'                     -- tlting01
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61620
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On PickDetail. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
   END
END

   /* #INCLUDE <TRPDU2.SQL> */

QUIT:

IF @n_continue=3
BEGIN
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT = 1
   BEGIN
      -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
      -- Instead we commit AND raise an error back to parent, let the parent decide

      -- Commit until the level we BEGIN with
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPickDetailUpdate'
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

GO