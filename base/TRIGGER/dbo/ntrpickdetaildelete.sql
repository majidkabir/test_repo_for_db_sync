SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrPickDetailDelete                                            */
/* Creation Date:                                                          */
/* Copyright: Maersk Logistics                                             */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records delete from PickDetail                          */
/*                                                                         */
/* PVCS Version: 1.24                                                      */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author     Ver.  Purposes                                  */
/* 17-Mar-2009  TLTING     1.1   Change user_name() to SUSER_SNAME()       */
/* 10-JUN-2009  NJOW       1.2   'SA' LOCKDOWN. The checking has been      */
/*                               shift to front-end (PB)                   */
/* 26-Mar-2010  Vicky      1.3   Comment out the update of                 */
/*                               QtyPickInProcess (Vicky01)                */
/* 08-Nov-2010  James      1.4   Cancel TM task when delete pickdetail     */
/*                               (james01)                                 */
/* 09-Nov-2010  ChewKP     1.5   Insert Delete PickDetail to PickDet_Log   */
/*                               By StorerConfig = 'PickDET_InsertLog'     */
/*                               SOS#195929 (ChewKP01)                     */
/* 22-Dec-2010  Shong      1.6   Performance Tuning                        */
/*  9-Jun-2011  KHLim01    1.7   Insert Delete log                         */
/* 14-Jul-2011  KHLim02    1.8   GetRight for Delete log                   */
/* 02-Dec-2011  MCTang     1.9   Add WAVEUPDLOG for WCS-WAVE Status Change */
/*                               Export(MC01)                              */
/*  8-Mar-2011  KHLim03    1.10  Delete log for backend shipped records    */
/* 22-May-2012  TLTING01   1.10  DM data integrity issue - insert DELLOG   */
/*                               if status < '9'                           */
/* 11-JUN-2012  YTWan      1.11  SOS#246450:Delete short pick at MBOL&CBOL */
/*                               and auto packconfirm improvement(Wan01)   */
/* 25-Feb-2014  Chee       1.12  Add StorerConfig - UCC to revert          */
/*                               UCC.Status when unallocate (Chee01)       */
/* 02-Mar-2015  Shong      1.13  Prevent PickDetail delete if Packdetail   */
/*                               Exists (Shong01)                          */
/*                               Revise Update TaskDetail When Deletion    */
/* 23-Apr-2015  TLTING02   1.14  Deadlock tune, Taskdetail delete          */
/* 20-APR-2015  YTWan      1.15  SOS#337957 - ANF - CR on unallocation     */
/*                               logic (for handling shared UCC in multiple*/
/*                               orders). (Wan02)                          */
/* 29-Apr-2015  NJOW02     1.16  315021-Call pickdetail delete custom sp   */
/* 15-Dec-2015  NJOW03     1.17  357827-Allow Un-Allocation for            */
/*                               IDS_Supervisor When PICK-TRF='1'          */
/* 19-Aep-2017  TLTING02   1.18  deadlock tune                             */
/* 06-Feb-2018  SHONG04    1.19  Added Channel Management Logic            */
/* 04-SEP-2019  Wan03      1.20  WMS-10156 - NIKE - PH Allocation Strategy */
/*                               Enhancement                               */
/* 23-JUL-2019  Wan04      1.20  ChannelInventoryMgmt use fnc_SelectGetRight*/
/* 01-Dec-2021  TLTING03   1.21  Perfromance tune                          */
/* 14-MAR-2023  JH01       1.22  change @c_username length to nvarchar(30) */
/* 24-FEB-2023  NJOW04     1.23  WMS-21757 Unallocation extended validation*/
/* 24-FEB-2023  NJOW04     1.23  DEVOPS Combine Script                     */
/* 03-JAN-2024  NJOW05     1.24  WMS-22471 Allow configure                 */
/*                               PickDetailTrigger_SP run after inv update */
/* 02-DEC-2024  Wan05      1.25  UWP-23317 - [FCR-618 819] Unpick SerialNo */
/***************************************************************************/
CREATE   TRIGGER [dbo].[ntrPickDetailDelete]
ON [dbo].[PICKDETAIL]
FOR  DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success          INT -- Populated by calls to stored procedures - was the proc successful?
         ,@n_err              INT -- Error number returned by stored procedure or this trigger
         ,@n_err2             INT -- For Additional Error Detection
         ,@c_errmsg           NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         ,@n_continue         INT
         ,@n_starttcnt        INT -- Holds the current transaction count
         ,@c_preprocess       NVARCHAR(250) -- preprocess
         ,@c_pstprocess       NVARCHAR(250) -- post process
         ,@n_cnt              INT
         ,@n_PickDetailSysId  INT
         ,@c_authority        NVARCHAR(1)
         ,@c_Facility         NVARCHAR(5)
         ,@c_Storerkey        NVARCHAR(15)
         ,@c_Taskdetailkey    NVARCHAR(10)

   SELECT @n_continue = 1
         ,@n_starttcnt = @@TRANCOUNT

   DECLARE @c_AllowOverAllocations  NVARCHAR(1) -- Flag to see if overallocations are allowed.
   DECLARE @c_CatchWeight           NVARCHAR(1) -- Flag to see if catch weight processing is allowed.

   --(Wan02) - START
   DECLARE @c_UnAllocUCCPickCode    NVARCHAR(10)
         , @c_UnAllocStorerkey      NVARCHAR(15)
         , @c_SQL                   NVARCHAR(MAX)
         , @c_SQLParm               NVARCHAR(MAX)
   --(Wan02) - END

   --NJOW03
   DECLARE @c_username   NVARCHAR(30)  --(JH01)
          ,@c_Flag       NVARCHAR(10)
          ,@c_UnAllocateValidationRules NVARCHAR(30) --NJOW04
          ,@c_Pickdetailkey NVARCHAR(10) --NJOW04
          ,@c_UnAllocateValidationType NVARCHAR(10)='' --NJOW04

   DECLARE @n_PickSerialNoKey       BIGINT = 0                                --(Wan05)
         , @cur_PSNDEL              CURSOR                                    --(Wan05)

   -- TLTING01
   IF EXISTS ( SELECT 1 FROM DELETED WHERE [STATUS] < '9')
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
                  ,@c_errmsg = 'ntrPICKDETAILDelete' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE
         IF @c_authority = '1'         --    End   (KHLim02)
         BEGIN
            INSERT INTO dbo.PICKDETAIL_DELLOG ( PickDetailKey )
            SELECT PickDetailKey  FROM DELETED
            WHERE [STATUS] < '9'

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PICKDETAIL Failed. (ntrPICKDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
      -- End (KHLim01)
   END

   IF (SELECT COUNT(*) FROM   DELETED) =
      (SELECT COUNT(*) FROM   DELETED WHERE  DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   --NJOW02
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      --NJOW05
      IF EXISTS (SELECT 1 FROM DELETED d
               JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
               JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
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
      END

      IF EXISTS (SELECT 1 FROM DELETED d
               JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
               JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
               WHERE  s.configkey = 'PickDetailTrigger_SP'
               AND s.option3 <> 'POSTDELETE')  --NJOW05
      BEGIN
         /* --NJOW05 Move up
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
         */

         EXECUTE dbo.isp_PickDetailTrigger_Wrapper
                  'DELETE' --@c_Action
               , @b_Success  OUTPUT
               , @n_Err      OUTPUT
               , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrPICKDETAILDelete' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END

   /* #INCLUDE <TRPDD1.SQL> */
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT TOP 1
            @c_Facility = FACILITY
      FROM   LOC(NOLOCK)
      JOIN   DELETED ON LOC.LOC = DELETED.LOC

      SELECT TOP 1
            @c_Storerkey = Storerkey
      FROM   DELETED

      SELECT @b_success = 0
      EXECUTE nspGetRight @c_Facility, -- facility
         @c_Storerkey, -- Storerkey
         NULL, -- Sku
         'ALLOWOVERALLOCATIONS', -- Configkey
         @b_success OUTPUT,
         @c_AllowOverAllocations OUTPUT,
         @n_err OUTPUT,
         @c_errmsg OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3 ,@c_errmsg = 'ntrPickDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END

      -- SELECT @c_AllowOverAllocations = NSQLValue
      -- FROM NSQLCONFIG (NOLOCK)
      -- WHERE CONFIGKEY = 'ALLOWOVERALLOCATIONS'

      SELECT @c_CatchWeight = NSQLValue
      FROM   NSQLCONFIG(NOLOCK)
      WHERE  CONFIGKEY = 'CATCHWEIGHT'

      IF @c_AllowOverAllocations IS NULL
      BEGIN
         SELECT @c_AllowOverAllocations = '0'
      END
      IF @c_CatchWeight IS NULL
      BEGIN
         SELECT @c_CatchWeight = '0'
      END
   END

   --NJOW04 S
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SET @c_UnAllocateValidationRules = ''
      SET @c_UnAllocateValidationType = ''

      SELECT TOP 1 @c_UnAllocateValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_StorerKey
      AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
      AND SC.Configkey = 'UnAllocateExtendedValidation'
      ORDER BY SC.Facility DESC

      IF ISNULL(@c_UnAllocateValidationRules,'') <> ''
      BEGIN
         SET @c_UnAllocateValidationType = 'CODELKUP'
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_UnAllocateValidationRules = SC.sValue
         FROM STORERCONFIG SC (NOLOCK)
         JOIN dbo.sysobjects SY ON SY.Name = SC.sValue AND SY.Type = 'P'
         WHERE SC.StorerKey = @c_StorerKey
         AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
         AND SC.Configkey = 'UnAllocateExtendedValidation'
         ORDER BY SC.Facility DESC

         IF ISNULL(@c_UnAllocateValidationRules,'') <> ''
            SET @c_UnAllocateValidationType = 'STOREDPROC'
      END

      IF ISNULL(@c_UnAllocateValidationType,'') <> ''
      BEGIN
         IF OBJECT_ID('tempdb..#DELETEDPICK') IS NOT NULL
            DROP TABLE #DELETEDPICK

         SELECT *
         INTO #DELETEDPICK
         FROM DELETED

         DECLARE CUR_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Pickdetailkey
            FROM DELETED
            WHERE Storerkey = @c_Storerkey
            ORDER BY Pickdetailkey

         OPEN CUR_PICKDET

         FETCH NEXT FROM CUR_PICKDET INTO @c_Pickdetailkey

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN
            IF @c_UnAllocateValidationType = 'CODELKUP'
            BEGIN
               EXEC isp_UnAllocate_ExtendedValidation
                  @c_Pickdetailkey = @c_Pickdetailkey,
                  @c_Orderkey = '',
                  @c_UnAllocateValidationRules=@c_UnAllocateValidationRules,
                  @b_Success=@b_Success OUTPUT,
                  @c_ErrMsg=@c_ErrMsg OUTPUT

               IF @b_Success <> 1
               BEGIN
                  IF OBJECT_ID('tempdb..#DELETEDPICK') IS NOT NULL
                     DROP TABLE #DELETEDPICK

                  SELECT @n_continue = 3
                        ,@c_errmsg =  RTRIM(@c_errmsg) + ' (ntrPICKDETAILDelete)'
               END
            END
            ELSE
            BEGIN
               SET @c_SQL = 'EXEC ' + @c_UnAllocateValidationRules + ' @c_Pickdetailkey, @c_Orderkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
               EXEC sp_executesql @c_SQL,
                  N'@c_Pickdetailkey NVARCHAR(10), @c_OrderKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',
                  @c_Pickdetailkey,
                  '',
                  @b_Success OUTPUT,
                  @n_err OUTPUT,
                  @c_ErrMsg OUTPUT

               IF @b_Success <> 1
               BEGIN
                  IF OBJECT_ID('tempdb..#DELETEDPICK') IS NOT NULL
                     DROP TABLE #DELETEDPICK

                  SELECT @n_continue = 3
                        ,@c_errmsg =  RTRIM(@c_errmsg) + ' (ntrPICKDETAILDelete)'
               END
            END
            FETCH NEXT FROM CUR_PICKDET INTO @c_Pickdetailkey
         END
         CLOSE CUR_PICKDET
         DEALLOCATE CUR_PICKDET

         IF OBJECT_ID('tempdb..#DELETEDPICK') IS NOT NULL
            DROP TABLE #DELETEDPICK
      END
   END
   --NJOW04 E

   -- SOS 14880: prevent delete of pick confirmed detail if PICK-TRF is on
   IF (@n_continue=1 OR @n_continue=2)
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d
                     JOIN storerconfig s(NOLOCK) ON  d.storerkey = s.storerkey
            WHERE  s.configkey = 'PICK-TRF'
            AND    s.svalue = '1'
            AND    d.status = '5'
         )
      BEGIN
         --NJOW03 Start
         SET ANSI_NULLS ON
         SET ANSI_WARNINGS ON

         SET @c_username = SUSER_SNAME()
         SET @c_flag = 'N'

         EXEC isp_CheckSupervisorRole
               @c_username
            , @c_Flag        OUTPUT
            , @b_Success     OUTPUT
            , @n_Err         OUTPUT
            , @c_ErrMsg      OUTPUT

         SET ANSI_NULLS OFF
         SET ANSI_WARNINGS OFF
         --NJOW03 End

         IF ISNULL(@c_Flag,'N') <> 'Y'  --NJOW03
         BEGIN
            SELECT @n_continue = 3
                  ,@n_err = 63201
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete Not Allowed on Pick Confirmed Record - Delete Failed. (ntrPickDetailDelete)'
         END
      END
   END

   -- (Shong01)
   IF (@n_continue=1 OR @n_continue=2)
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d
                  JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
            WHERE  s.configkey = 'DisallowDeleteIfPacked01'
            AND    s.svalue = '1'
            AND    d.status BETWEEN '5' AND '8')
      BEGIN
         -- Checking the Store Orders (UK JackWill)
         IF EXISTS(SELECT 1 FROM DELETED D
                  JOIN ORDERS AS SO WITH (NOLOCK) ON D.OrderKey = SO.OrderKey
                  JOIN PackDetail AS pd WITH (NOLOCK)
                     ON  D.StorerKey = PD.StorerKey
                     AND D.SKU = PD.SKU
                     AND D.PickSlipNo = PD.PickSlipNo
                     AND D.AltSKU = PD.DropID
                     AND (D.DropID IS NOT NULL AND D.DropID <> '')
                  WHERE SO.TYPE LIKE 'STORE%')

         BEGIN
            SELECT @n_continue = 3
                  ,@n_err = 63217
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete Not Allowed on Pack Confirmed Record - Delete Failed. (ntrPickDetailDelete)'

         END
         -- Checking the ECOM Orders (UK JackWill)
         IF EXISTS(SELECT 1 FROM DELETED D
                  JOIN ORDERS AS SO WITH (NOLOCK) ON D.OrderKey = SO.OrderKey
                  JOIN PackDetail AS pd WITH (NOLOCK)
                     ON  D.StorerKey = PD.StorerKey
                     AND D.SKU = PD.SKU
                     AND D.PickSlipNo = PD.PickSlipNo
                     AND D.Dropid = PD.DropID
                     AND (D.DropID IS NOT NULL AND D.DropID <> '')
                  WHERE SO.TYPE LIKE 'ECOMM%')
         BEGIN
            SELECT @n_continue = 3
                  ,@n_err = 63217
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete Not Allowed on Pack Confirmed Record - Delete Failed. (ntrPickDetailDelete)'
         END
      END
   END

   IF @n_continue=1
   OR @n_continue=2 --Added by vicky 29 July 2002 to control the unallocation of pickdetail
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspGetRight NULL, -- facility
      NULL, -- Storerkey
      NULL, -- Sku
      'OWITF', -- Configkey
      @b_success OUTPUT,
      @c_authority OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrPickDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE
      IF @c_authority = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM   DELETED WHERE  STATUS IN ('3' ,'4'))
         BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 63201
               SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Item(s) Are InProcess - Delete Failed. (ntrPickDetailDelete)'
         END
         --END --commented by Vicky 11 Dec 2002 because other country need to delete pickdetail even status is > 2
         -- customized for HK, once pickdetail is Pick in Progress ('3') should not be DELETED. Coz interface has been done
         IF @n_continue=1
         OR @n_continue=2
         BEGIN
               IF EXISTS (SELECT 1 FROM   DELETED WHERE  STATUS > '2') -- not in ('0','1','2','3','4','5','6,','7','8'))
               BEGIN
                  SELECT @n_continue = 3
                        ,@n_err = 63301
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ': Deletion of Allocated Order lines are not allowed. (ntrPickDetailDelete)'
               END
         END
      END
   END-- END OWITF configkey

   IF @n_continue=1
   OR @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM   DELETED WHERE  STATUS = '9')
      BEGIN
         SELECT @n_continue = 3
               ,@n_err = 63202
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Item(s) Are Shipped - Delete Failed. (ntrPickDetailDelete)'
      END
   END
   -- Add by June for IDSV5 1.JUL.02, Extract from IDSMY *** Start
   IF @n_continue=1
   OR @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED WHERE  ShipFlag = 'Y')
      BEGIN
         SELECT @n_continue = 3
               ,@n_err = 63202
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Item(s) Are Shipped - Delete Failed. (ntrPickDetailDelete)'
      END
   END

   -- TBL UCC un-allocate
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM   DELETED d
                  JOIN StorerConfig s(NOLOCK) ON  d.StorerKey = s.StorerKey
                  WHERE  s.ConfigKey IN ('UCCTracking', 'UCC') -- Chee01
                  AND    s.SValue = '1')
      BEGIN
         --(Wan02) - START
         IF EXISTS(  SELECT 1
                     FROM DELETED D
                     JOIN STORERCONFIG S1 WITH (NOLOCK) ON (D.StorerKey = S1.StorerKey AND S1.ConfigKey IN ('UCCTracking', 'UCC')
                                                         AND S1.SVAlue = '1')
                     JOIN STORERCONFIG S2 WITH (NOLOCK) ON (D.StorerKey = S2.StorerKey AND S2.ConfigKey = 'UnAllocUCCPickCode')
                     WHERE S2.SValue <> '' AND S2.SValue IS NOT NULL
                     AND NOT EXISTS (SELECT 1 FROM sys.objects O WHERE NAME = S2.SValue
                                       AND O.TYPE = 'P')
                     )
         BEGIN
            SET @n_Continue= 3
            SET @n_Err     = 63218
            SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid UnallocUCCPickCode (ntrPickDetailDelete)'
         END

         IF ( @n_continue = 1  OR @n_continue=2 )
         BEGIN
            SELECT D.PickDetailKey
               , D.CaseID
               , D.PickHeaderKey
               , D.OrderKey
               , D.OrderLineNumber
               , D.Lot
               , D.Storerkey
               , D.Sku
               , D.AltSku
               , D.UOM
               , D.UOMQty
               , D.Qty
               , D.QtyMoved
               , D.Status
               , D.DropID
               , D.Loc
               , D.ID
               , D.PackKey
               , D.UpdateSource
               , D.CartonGroup
               , D.CartonType
               , D.ToLoc
               , D.DoReplenish
               , D.ReplenishZone
               , D.DoCartonize
               , D.PickMethod
               , D.WaveKey
               , D.EffectiveDate
               , D.TrafficCop
               , D.ArchiveCop
               , D.OptimizeCop
               , D.ShipFlag
               , D.PickSlipNo
               , D.TaskDetailKey
               , D.TaskManagerReasonKey
               , D.Notes
--                  , D.MoveRefKey
            INTO #D_PICKDETAIL
            FROM DELETED D
            JOIN STORERCONFIG S1 WITH (NOLOCK) ON (D.StorerKey = S1.StorerKey AND S1.ConfigKey IN ('UCCTracking', 'UCC')
                                                AND S1.SVAlue = '1')
            JOIN STORERCONFIG S2 WITH (NOLOCK) ON (D.StorerKey = S2.StorerKey AND S2.ConfigKey = 'UnAllocUCCPickCode')
            WHERE S2.SValue <> '' AND S2.SValue IS NOT NULL
            AND EXISTS (SELECT 1 FROM sys.objects O WHERE NAME = S2.SValue
                        AND O.TYPE = 'P')

            DECLARE CUR_UNALLOCSP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT D.Storerkey
                  , S2.SValue
            FROM DELETED D
            JOIN STORERCONFIG S1 WITH (NOLOCK) ON (D.StorerKey = S1.StorerKey AND S1.ConfigKey IN ('UCCTracking', 'UCC')
                                                AND S1.SVAlue = '1')
            JOIN STORERCONFIG S2 WITH (NOLOCK) ON (D.StorerKey = S2.StorerKey AND S2.ConfigKey = 'UnAllocUCCPickCode')
            WHERE S2.SValue <> '' AND S2.SValue IS NOT NULL
            AND EXISTS (SELECT 1 FROM sys.objects O WITH (NOLOCK) WHERE NAME = S2.SValue
                        AND O.TYPE = 'P')

            OPEN CUR_UNALLOCSP

            FETCH NEXT FROM CUR_UNALLOCSP INTO  @c_UnAllocStorerkey
                                             ,  @c_UnAllocUCCPickCode

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @c_SQL = ''
               SET @c_SQL = N'EXECUTE ' + @c_UnallocUCCPickCode
                           +  '  @c_Storerkey = @c_UnAllocStorerkey '
                           +  ', @b_Success   = @b_Success     OUTPUT '
                           +  ', @n_Err       = @n_Err         OUTPUT '
                           +  ', @c_ErrMsg    = @c_ErrMsg      OUTPUT '

               SET @c_SQLParm = ''
               SET @c_SQLParm =  N'@c_UnAllocStorerkey NVARCHAR(15)'
                              +  ',@b_Success INT OUTPUT'
                              +  ',@n_Err     INT OUTPUT'
                              +  ',@c_ErrMsg  NVARCHAR(250) OUTPUT'

               EXEC sp_ExecuteSQL  @c_SQL
                                 , @c_SQLParm
                                 , @c_UnAllocStorerkey
                                 , @b_Success   OUTPUT
                                 , @n_Err       OUTPUT
                                 , @c_ErrMsg    OUTPUT

               IF @@ERROR <> 0 OR @b_Success <> 1
               BEGIN
                  SET @n_Continue= 3
                  SET @n_Err     = 63219
                  SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_UnallocUCCPickCode +
                                    CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ntrPickDetailDelete)'
               END
               FETCH NEXT FROM CUR_UNALLOCSP INTO  @c_UnAllocStorerkey
                                                ,  @c_UnAllocUCCPickCode
            END
         END


         -- Call Standard Unallocate UCC If No customize Unallocate Pick Code being Setup
         IF ( @n_continue = 1  OR @n_continue=2 )
         BEGIN
         --(Wan02) - END
            UPDATE U with (ROWLOCK)
            SET STATUS = '1'
                  ,PickdetailKey = ''
                  ,OrderKey = ''
                  ,OrderLineNumber = ''
                  ,WaveKey = ''
            FROM   DELETED d
                     JOIN UCC U ON  D.PickDetailKey = U.PickDetailKey
                     -- (Wan02) - START
                     LEFT JOIN StorerConfig s2(NOLOCK) ON  d.StorerKey = s2.StorerKey AND s2.ConfigKey = 'UnAllocUCCPickCode'
                     -- (Wan02) - END
            WHERE  U.Status > '2' AND U.Status < '6' -- Chee01
            AND    (RTRIM(s2.SVALUE) = '' OR s2.SVALUE IS NULL)         -- (Wan02)
            AND    U.Storerkey = @c_Storerkey   --tlting03

            SELECT @n_err = @@ERROR
                  ,@n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ': Update on UCC Failed. (ntrPickDetailDelete)' + ' ( ' +
                        ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                        + ' ) '
            END
         END --(Wan02)
      END
   END

   -- SHONG04 Channel Management
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT TOP 1 @c_StorerKey = StorerKey
      FROM DELETED

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
         SELECT DELETED.PickDetailKey,
               DELETED.Storerkey,
               DELETED.Sku,
               LOC.Facility,
               ISNULL(OD.Channel,''),
               DELETED.Lot,
               ISNULL(DELETED.Channel_ID,0),
               DELETED.Qty
         FROM DELETED WITH (NOLOCK)
         JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = DELETED.Loc
         CROSS APPLY fnc_SelectGetRight (LOC.Facility, DELETED.Storerkey, '', 'ChannelInventoryMgmt') SC --(Wan04)
         --JOIN StorerConfig AS sc WITH(NOLOCK) ON DELETED.Storerkey = SC.StorerKey                      --(Wan04)
         --          AND SC.ConfigKey = 'ChannelInventoryMgmt' AND SC.sValue = '1'                       --(Wan04)
         JOIN ORDERDETAIL AS OD WITH(NOLOCK)
               ON  OD.OrderKey = DELETED.OrderKey AND OD.OrderLineNumber = DELETED.OrderLineNumber
         WHERE SC.Authority = '1'                                                                        --(Wan04)

         OPEN CUR_CHANNEL_MGMT

         FETCH NEXT FROM CUR_CHANNEL_MGMT INTO @c_cPickDetailKey, @c_cStorerKey, @c_cSKU, @c_cFacility, @c_Channel, @c_cLOT, @n_Channel_ID, @n_cQty

         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF ISNULL(RTRIM(@c_Channel),'') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63125
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                     + ': Order Detail Channel Cannot be BLANK. (ntrPickDetailDelete)'
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
                        AND ci.QtyAllocated < @n_cQty)
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63126
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        + ': Update Channel Inventory Failed, Channel Qty less than Qty Allocated. (ntrPickDetailDelete)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               END
               ELSE
               BEGIN
                  UPDATE ChannelInv WITH (ROWLOCK)
                     SET QtyAllocated = QtyAllocated - @n_cQty,
                        EditDate = GETDATE(),
                        EditWho = SUSER_SNAME()
                  WHERE Channel_ID = @n_Channel_ID

               END
            END

            FETCH NEXT FROM CUR_CHANNEL_MGMT INTO @c_cPickDetailKey, @c_cStorerKey, @c_cSKU, @c_cFacility, @c_Channel, @c_cLOT, @n_Channel_ID, @n_cQty
         END -- While

      END
   END

   --(Wan05) - START
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SET @cur_PSNDEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT psn.PickSerialNoKey
      FROM DELETED d
      JOIN dbo.PickSerialNo psn (NOLOCK) ON psn.Pickdetailkey = d.PickdetailKey
      WHERE psn.SerialNo > ''

      OPEN @cur_PSNDEL

      FETCH NEXT FROM @cur_PSNDEL INTO @n_PickSerialNoKey

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
      BEGIN
         DELETE PickSerialNo WITH (ROWLOCK)
         WHERE PickSerialNoKey = @n_PickSerialNoKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
         END

         FETCH NEXT FROM @cur_PSNDEL INTO @n_PickSerialNoKey
      END
      CLOSE @cur_PSNDEL
      DEALLOCATE @cur_PSNDEL
   END
   --(Wan05) - END

   -- Add by June for IDSV5 1.JUL.02, Extract from IDSMY *** End
   IF @n_continue=1 OR @n_continue=2
   BEGIN

      CREATE TABLE #DEL_LOT
         (LOT           NVARCHAR(10) NOT NULL
         ,QtyAllocated  INT NOT NULL
         ,QtyPicked     INT NOT NULL
         ,PRIMARY KEY (LOT)
         ,UNIQUE (LOT) )

      INSERT INTO #DEL_LOT (QtyAllocated, QtyPicked, LOT)
      SELECT ISNULL(SUM(CASE WHEN DELETED.Status IN ('0' ,'1' ,'2' ,'3' ,'4') THEN DELETED.Qty ELSE 0 END),0) AS QtyAllocated
      ,ISNULL(SUM(CASE WHEN DELETED.Status IN ('5' ,'6' ,'7' ,'8') THEN DELETED.Qty ELSE 0 END),0) AS QtyPicked
      ,DELETED.LOT
      FROM   DELETED
      GROUP BY DELETED.LOT

      UPDATE LOT WITH (ROWLOCK)
         SET QtyPicked    = (LOT.QtyPicked - DEL_LOT.QtyPicked),
               QtyAllocated = (LOT.QtyAllocated - DEL_LOT.QtyAllocated)
      FROM LOT
      JOIN #DEL_LOT AS DEL_LOT ON DEL_LOT.LOT = LOT.LOT

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 63203 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Delete trigger On PickDetail Failed. (ntrPickDetailDelete)'
                  + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                  + ' ) '
      END

      IF @n_continue=1 OR @n_continue=2
      BEGIN
         CREATE TABLE #DEL_LOTxLOCxID
            (LOT           NVARCHAR(10) NOT NULL
            ,LOC           NVARCHAR(10) NOT NULL
            ,ID            NVARCHAR(18) NOT NULL
            ,QtyAllocated  INT NOT NULL
            ,QtyPicked     INT NOT NULL
            ,PRIMARY KEY (LOT, LOC, ID)
            ,UNIQUE (LOT, LOC, ID) )

         INSERT INTO #DEL_LOTxLOCxID(QtyAllocated, QtyPicked, LOT, LOC, ID)
         SELECT ISNULL(SUM(CASE WHEN DELETED.Status IN ('0' ,'1' ,'2' ,'3' ,'4') THEN DELETED.Qty ELSE 0 END),0) AS QtyAllocated
                  ,ISNULL(SUM(CASE WHEN DELETED.Status IN ('5' ,'6' ,'7' ,'8') THEN DELETED.Qty ELSE 0 END),0) AS QtyPicked
                  ,DELETED.LOT
                  ,DELETED.LOC
                  ,DELETED.ID
         FROM   DELETED
         GROUP BY DELETED.LOT, DELETED.LOC, DELETED.ID

         UPDATE LOTxLOCxID WITH (ROWLOCK)
         SET QtyPicked = (LOTxLOCxID.QtyPicked - DEL_LLI.QtyPicked),
               QtyAllocated = (LOTxLOCxID.QtyAllocated - DEL_LLI.QtyAllocated),
               QtyExpected = CASE
                              WHEN (((LOTxLOCxID.QtyAllocated - DEL_LLI.QtyAllocated) + (LOTxLOCxID.QtyPicked - DEL_LLI.QtyPicked)) - LOTxLOCxID.Qty) >= 0
                              AND @c_AllowOverAllocations = '1'
                              THEN (((LOTxLOCxID.QtyPicked - DEL_LLI.QtyPicked) + (LOTxLOCxID.QtyAllocated - DEL_LLI.QtyAllocated)) - LOTxLOCxID.Qty)
                              ELSE 0
                           END
         FROM LOTxLOCxID
         JOIN #DEL_LOTxLOCxID AS DEL_LLI ON
                     LOTxLOCxID.lot = DEL_LLI.LOT AND
                     LOTxLOCxID.loc = DEL_LLI.LOC AND
                     LOTxLOCxID.id  = DEL_LLI.ID

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                     ,@n_err = 63208 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete trigger On PickDetail Failed. (ntrPickDetailDelete)'
                     + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                     + ' ) '
         END
      END

      IF @n_continue=1 OR @n_continue=2
      BEGIN
         CREATE TABLE #DEL_SKUxLOC
            (StorerKey     NVARCHAR(15) NOT NULL
            ,SKU           NVARCHAR(20) NOT NULL
            ,LOC           NVARCHAR(10) NOT NULL
            ,QtyAllocated  INT NOT NULL
            ,QtyPicked     INT NOT NULL
            ,PRIMARY KEY (StorerKey, SKU, LOC)
            ,UNIQUE (StorerKey, SKU, LOC) )

            INSERT INTO #DEL_SKUxLOC(QtyAllocated, QtyPicked, StorerKey, SKU, LOC)
            SELECT ISNULL(SUM(CASE WHEN DELETED.Status IN ('0' ,'1' ,'2' ,'3' ,'4') THEN DELETED.Qty ELSE 0 END),0) AS QtyAllocated
                  ,ISNULL(SUM(CASE WHEN DELETED.Status IN ('5' ,'6' ,'7' ,'8') THEN DELETED.Qty ELSE 0 END),0) AS QtyPicked
                  ,DELETED.StorerKey
                  ,DELETED.SKU
                  ,DELETED.LOC
            FROM   DELETED
            GROUP BY DELETED.StorerKey, DELETED.SKU, DELETED.LOC

         UPDATE SKUxLOC WITH (ROWLOCK)
         SET QtyPicked    = SKUxLOC.QtyPicked - DEL_SKUxLOC.QtyPicked,
               QtyAllocated = SKUxLOC.QtyAllocated - DEL_SKUxLOC.QtyAllocated,
               QtyExpected  = CASE
                                 WHEN (((SKUxLOC.QtyAllocated - DEL_SKUxLOC.QtyAllocated) +
                                          (SKUxLOC.QtyPicked - DEL_SKUxLOC.QtyPicked)) - SKUxLOC.Qty) >= 0
                                       AND @c_AllowOverAllocations = '1'
                                 THEN (((SKUxLOC.QtyAllocated - DEL_SKUxLOC.QtyAllocated) + (SKUxLOC.QtyPicked - DEL_SKUxLOC.QtyPicked))
                                          - SKUxLOC.Qty)
                                 ELSE 0
                              END
         FROM SKUxLOC
         JOIN #DEL_SKUxLOC AS DEL_SKUxLOC ON
                  DEL_SKUxLOC.StorerKey = SKUxLOC.StorerKey AND
                  DEL_SKUxLOC.SKU = SKUxLOC.SKU AND
                  DEL_SKUxLOC.LOC = SKUxLOC.LOC

         SELECT @n_err = @@ERROR
               ,@n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                     ,@n_err = 63208 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete trigger On PickDetail Failed. (ntrPickDetailDelete)'
                     + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                     + ' ) '
         END
      END

      --NJOW05 just after update inventory
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF EXISTS (SELECT 1 FROM DELETED d
                     JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
                     JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
                     WHERE  s.configkey = 'PickDetailTrigger_SP'
                     AND s.option3 = 'POSTDELETE')
         BEGIN
            EXECUTE dbo.isp_PickDetailTrigger_Wrapper
                     'DELETE' --@c_Action
                     , @b_Success  OUTPUT
                     , @n_Err      OUTPUT
                     , @c_ErrMsg   OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
                     ,@c_errmsg = 'ntrPICKDETAILDelete' + dbo.fnc_RTrim(@c_errmsg)
            END

            IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
               DROP TABLE #INSERTED

            IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
               DROP TABLE #DELETED
         END
      END

      IF @n_continue=1 OR @n_continue=2
      BEGIN
         CREATE TABLE #DEL_ORD
            (OrderKey           NVARCHAR(10) NOT NULL
            ,OrderLineNumber    NVARCHAR(5) NOT NULL
            ,QtyAllocated  INT NOT NULL
            ,QtyPicked     INT NOT NULL
            ,PRIMARY KEY (OrderKey, OrderLineNumber)
            ,UNIQUE (OrderKey, OrderLineNumber) )

         INSERT INTO #DEL_ORD(QtyAllocated, QtyPicked, OrderKey, OrderLineNumber)
         SELECT ISNULL(SUM(CASE WHEN DELETED.Status IN ('0' ,'1' ,'2' ,'3' ,'4') THEN DELETED.Qty ELSE 0 END),0) AS QtyAllocated
               ,ISNULL(SUM(CASE WHEN DELETED.Status IN ('5' ,'6' ,'7' ,'8') THEN DELETED.Qty ELSE 0 END),0) AS QtyPicked
               ,DELETED.OrderKey
               ,DELETED.OrderLineNumber
         FROM   DELETED
         GROUP BY DELETED.OrderKey, DELETED.OrderLineNumber

         UPDATE OrderDetail WITH (ROWLOCK)
            SET    QtyPicked = OrderDetail.QtyPicked - DEL_OD.QtyPicked,
                     QtyAllocated = OrderDetail.QtyAllocated - DEL_OD.QtyAllocated
         FROM OrderDetail
         JOIN #DEL_ORD AS DEL_OD ON
                  OrderDetail.OrderKey = DEL_OD.OrderKey AND
                  OrderDetail.OrderLineNumber = DEL_OD.OrderLineNumber

         SELECT @n_err = @@ERROR
               ,@n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                     ,@n_err = 63206 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete trigger On PickDetail Failed. (ntrPickDetailDelete)'
                     + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                     + ' ) '
         END
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Shong01)
      DECLARE @n_PickDetQty    INT,
               @n_TaskStatus    NVARCHAR(1),
               @c_TaskStatus    NVARCHAR(10),
               @n_TaskQty       INT,
               @c_DelPickDetKey NVARCHAR(10)
      --(Wan01) - START
      DECLARE @c_DelPickCommTaskQtysUpd   NVARCHAR(10) = ''
            , @c_FacilityD                NVARCHAR(15) = ''
            , @c_StorerkeyDLast           NVARCHAR(15) = ''
            , @c_StorerkeyD               NVARCHAR(15) = ''
            , @c_SkuD                     NVARCHAR(20) = ''
            , @c_FromLoc                  NVARCHAR(10) = ''
            , @n_Qty                      INT          = 0
            , @n_SystemQty                INT          = 0
            , @b_Case                     BIT          = 0

      --(james01)
      DECLARE CUR_DELETE_TASK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT DELETED.TaskDetailKey, DELETED.Qty, DELETED.PickDetailKey
            , DELETED.Storerkey, DELETED.Sku, LOC.Facility                                                  --(Wan03)
      FROM   DELETED
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = DELETED.Loc                                                       --(Wan03)
      ORDER BY DELETED.Storerkey

      OPEN CUR_DELETE_TASK
      FETCH NEXT FROM CUR_DELETE_TASK INTO @c_TaskDetailKey, @n_PickDetQty, @c_DelPickDetKey
                                       ,  @c_StorerkeyD, @c_SkuD, @c_FacilityD                              --(Wan03)
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_TaskStatus = ''
         SET @n_TaskQty = 0

         SELECT @c_TaskStatus = Status,
               @n_TaskQty = Qty
               , @c_FromLoc  = FromLoc                                                                     --(Wan03)
         FROM TASKDETAIL WITH (NOLOCK)
         WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey

         IF ( @c_TaskStatus <> '9' AND @c_TaskStatus <> '')
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM PICKDETAIL(NOLOCK)
                           WHERE  TaskDetailKey = @c_TaskDetailKey
                           AND    PickDetailKey <> @c_DelPickDetKey)
            BEGIN
               --         UPDATE TASKDETAIL WITH (ROWLOCK) SET
               --            STATUS = 'X', TRAFFICCOP = NULL
               --         WHERE TaskDetailKey = @c_TaskDetailKey

               DELETE TASKDETAIL with (ROWLOCK)
               WHERE  TaskDetailKey = @c_TaskDetailKey
               AND    [Status] <> '9'

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                        ,@n_err = 63214
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                           ': Delete trigger On PickDetail Failed. (ntrPickDetailDelete)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                           + ' ) '
               END
            END
            ELSE
            BEGIN
               --(Wan03) - START
               IF @c_StorerkeyD <> @c_StorerkeyDLast
               BEGIN
                  SELECT @c_DelPickCommTaskQtysUpd = SC.Authority
                  FROM fnc_SelectGetRight (@c_FacilityD, @c_StorerkeyD, '', 'DelPickCommTaskQtysUpd') SC

                  SET @c_StorerkeyDLast = @c_StorerkeyD
               END

               IF @c_DelPickCommTaskQtysUpd = '1'
               BEGIN
                  SET @b_Case = 0
                  SET @n_SystemQty = @n_PickDetQty
                  SET @n_Qty = @n_PickDetQty

                  IF EXISTS ( SELECT 1
                              FROM LOC WITH (NOLOCK)
                              JOIN UCC WITH (NOLOCK) ON LOC.Loc = UCC.Loc
                              WHERE LOC.Loc = @c_FromLOC
                              AND LOC.LoseUCC = '0'
                              )
                  BEGIN
                     SET @b_Case = 1
                  END

                  IF @b_Case = 0
                  BEGIN
                     IF EXISTS ( SELECT 1
                                 FROM SKU S WITH (NOLOCK)
                                 JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
                                 WHERE S.Storerkey = @c_StorerkeyD
                                 AND S.Sku = @c_SkuD
                                 GROUP BY P.Packkey, P.CaseCnt
                                 HAVING @n_TaskQty % CONVERT(INT, P.CaseCnt) = 0
                                 )
                     BEGIN
                        SET @b_Case = 1
                     END
                  END

                  IF @b_Case = 1
                  BEGIN
                     SET @n_Qty = 0
                  END

                  UPDATE TASKDETAIL with (ROWLOCK)
                     SET Qty        = Qty - @n_Qty
                        , SystemQty  = SystemQty - @n_SystemQty
                        , EditWho    = sUser_sName()
                        , EditDate   = GetDate()
                        , TrafficCop = NULL
                  WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey
                  AND TASKDETAIL.Status <> '9'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63214
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TaskDetail Failed. (ntrPickDetailDelete)' +
                           ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

               END
               ELSE
               BEGIN
                  UPDATE TASKDETAIL with (ROWLOCK)
                     SET Qty = Qty - @n_PickDetQty,
                        EditWho    = sUser_sName(),
                        EditDate   = GetDate(),
                        TrafficCop = NULL
                  WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey
                  AND TASKDETAIL.Status <> '9'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63214
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TaskDetail Failed. (ntrPickDetailDelete)' +
                           ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
               --(Wan03) - END
            END
         END

         FETCH NEXT FROM CUR_DELETE_TASK INTO @c_TaskDetailKey, @n_PickDetQty, @c_DelPickDetKey
                                             , @c_StorerkeyD, @c_SkuD,  @c_FacilityD                             --(Wan03)
      END
      CLOSE CUR_DELETE_TASK
      DEALLOCATE CUR_DELETE_TASK
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      -- tlting02
      IF EXISTS ( SELECT 1 FROM TASKDETAIL (NOLOCK),  DELETED
      WHERE  TASKDETAIL.PickDetailKey = DELETED.PickDetailKey
      AND    TASKDETAIL.TaskType = 'PK'
      AND    TASKDETAIL.Status <> '9'    )
      BEGIN
         DELETE TASKDETAIL with (ROWLOCK)
         FROM   DELETED
         WHERE  TASKDETAIL.PickDetailKey = DELETED.PickDetailKey
         AND    TASKDETAIL.TaskType = 'PK'
         AND    TASKDETAIL.Status <> '9'
         SELECT @n_err = @@ERROR
               ,@n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 63214
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                     ': Delete trigger On PickDetail Failed. (ntrPickDetailDelete)'
                     + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                     + ' ) '
         END
      END
   END

   IF (@c_CatchWeight = '1')
   AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      DELETE LOTxIDDETAIL with (ROWLOCK)
      FROM   DELETED
      WHERE  LOTxIDDETAIL.PickDetailKey = DELETED.PickDetailKey
      SELECT @n_err = @@ERROR
            ,@n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 63215
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Delete LOTxIDDETAIL Failed. (ntrPickDetailDelete)' + ' ( '
                  + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                  + ' ) '
      END
   END

   IF (@n_continue=1 OR @n_continue=2) -- (ChewKP01)
   BEGIN
      IF EXISTS (
            SELECT 1
            FROM   DELETED d
                     JOIN storerconfig s(NOLOCK)
                        ON  d.storerkey = s.storerkey
            WHERE  s.configkey = 'PickDet_InsertLog'
            AND    s.svalue = '1'
         )
      BEGIN
         INSERT INTO PickDet_LOG
            (
               PickDetailKey     ,OrderKey    ,OrderLineNumber
            ,Storerkey         ,Sku         ,Lot
            ,Loc               ,ID          ,UOM
            ,Qty               ,STATUS      ,DropID
            ,PackKey           ,WaveKey     ,AddDate
            ,AddWho            ,PickSlipNo  ,TaskDetailKey
            ,CaseID
            )
         SELECT PickDetailKey  ,OrderKey    ,OrderLineNumber
               ,Storerkey      ,Sku         ,Lot
               ,Loc            ,ID          ,UOM
               ,Qty            ,STATUS      ,DropID
               ,PackKey        ,WaveKey     ,AddDate
               ,AddWho         ,PickSlipNo  ,TaskDetailKey
               ,CaseID
         FROM   DELETED

         SELECT @n_err = @@ERROR
               ,@n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
                  ,@n_err = 63216
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Insert into PickDet_Log Failed - Insert Failed. (ntrPickDetailDelete)'
         END
      END
   END

   -- MC01-S
   IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
             WHERE StorerKey = @c_StorerKey AND ConfigKey = 'WAVEUPDLOG' AND sValue = '1')
   BEGIN

      INSERT INTO PickDetail_Log (OrderKey ,OrderLineNumber ,WaveKey ,StorerKey
                                 ,B_SKU ,B_LOT ,B_LOC ,B_ID ,B_QTY
                                 ,A_SKU ,A_LOT ,A_LOC ,A_ID ,A_QTY
                                 ,Status ,PickDetailKey)
      SELECT DELETED.OrderKey ,DELETED.OrderLineNumber ,WaveDetail.Wavekey ,DELETED.Storerkey
            ,DELETED.Sku      ,DELETED.Lot             ,DELETED.Loc        ,DELETED.ID         ,DELETED.Qty
            ,''               ,''                      ,''                 ,''                 ,0
            ,'0'              ,DELETED.PickDetailKey
      FROM  DELETED
      JOIN  WaveDetail WITH (NOLOCK) ON ( WaveDetail.Orderkey = DELETED.Orderkey )
      WHERE EXISTS ( SELECT 1 FROM Transmitlog3 WITH (NOLOCK)
                     WHERE Tablename = 'WAVERESLOG'
                     AND Key1 = WaveDetail.Wavekey
                     AND Key3 = DELETED.Storerkey
                     AND TransmitFlag > '0' )

   END -- IF EXISTS(StorerConfig - 'WAVEUPDLOG')
   -- MC01-E

    /* #INCLUDE <TRPDD2.SQL> */

    -- Added By SHONG
    -- 25th Jul 2002
    -- To refresh the Order Header Status
    --IF @n_continue=1 OR @n_continue=2
    --BEGIN
    --    UPDATE ORDERS with (ROWLOCK)
    --    SET    EditWho = SUSER_SNAME()
    --    FROM   ORDERS
    --          ,DELETED
    --    WHERE  DELETED.OrderKey = ORDERS.OrderKey
    --    SELECT @n_err = @@ERROR
    --          ,@n_cnt = @@ROWCOUNT
    --    IF @n_err <> 0
    --    BEGIN
    --        SELECT @n_continue = 3
    --        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
    --              ,@n_err = 63210 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
    --        SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
    --               ': Delete trigger On ORDERS Failed. (ntrPickDetailDelete)' +
    --               ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
    --               + ' ) '
    --    END
    --END

   IF @n_continue=1
   OR @n_continue=2
   BEGIN
      DELETE RefKeyLookup with (ROWLOCK)
      FROM   RefKeyLookup
            ,DELETED
      WHERE  RefKeyLookup.Pickdetailkey = DELETED.Pickdetailkey

      SELECT @n_err = @@ERROR
            ,@n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 63212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Delete trigger On RefKeyLookup Failed. (ntrPickDetailDelete)'
                  + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                  + ' ) '

      END
   END
   --(Wan01) -- START
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED WHERE STATUS = '4')
      BEGIN
         INSERT INTO dbo.ShortPickLog
           (
             MBOLKey, DeleteWho, DeleteDate, PickDetailKey, CaseID, PickHeaderKey,
             OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku, UOM, UOMQty, Qty,
             QtyMoved, STATUS, DropID, Loc, ID, PackKey, UpdateSource, CartonGroup,
             CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
             WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag,
             PickSlipNo, TaskDetailKey, TaskManagerReasonKey, AddDate, AddWho, EditDate,
             EditWho
           )
         SELECT MBOLDETAIL.MBOLKey, SUSER_NAME(), GETDATE(), DELETED.PickDetailKey,
                DELETED.CaseID, DELETED.PickHeaderKey, DELETED.OrderKey,
                DELETED.OrderLineNumber, DELETED.Lot, DELETED.Storerkey, DELETED.Sku,
                DELETED.AltSku, DELETED.UOM, DELETED.UOMQty, DELETED.Qty, DELETED.QtyMoved,
                DELETED.Status, DELETED.DropID, DELETED.Loc, DELETED.ID, DELETED.PackKey,
                DELETED.UpdateSource, DELETED.CartonGroup, DELETED.CartonType, DELETED.ToLoc,
                DELETED.DoReplenish, DELETED.ReplenishZone, DELETED.DoCartonize, DELETED.PickMethod,
                DELETED.WaveKey, DELETED.EffectiveDate, DELETED.TrafficCop, DELETED.ArchiveCop,
                DELETED.OptimizeCop, DELETED.ShipFlag, DELETED.PickSlipNo, DELETED.TaskDetailKey,
                DELETED.TaskManagerReasonKey, DELETED.AddDate, DELETED.AddWho, DELETED.EditDate,
                DELETED.EditWho
         FROM   DELETED
         LEFT JOIN MBOLDETAIL WITH (NOLOCK)
               ON  (DELETED.Orderkey = MBOLDETAIL.Orderkey)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63209   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT Record On to SHORTPICKLOG Table Failed. (ntrPICKDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   --(Wan01) -- END

   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1
      AND @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPickDetailDelete'
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