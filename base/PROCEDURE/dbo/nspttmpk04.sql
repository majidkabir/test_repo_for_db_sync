SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMPK04                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Strategy for PTL Cart Picking                               */
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
/* Date         Author  Ver.  Purposes                                  */
/* 24-Jan-2014  James   1.0   SOS296464 - Created                       */
/* 11-Jun-2014  Chee    1.1   Bug Fix - Close CURSOR_PKTASKCANDIDATES   */
/*                            before create (Chee01)                    */
/* 10-Oct-2014  James   1.2   Add (NOLOCK) (james01)                    */
/* 11-Dec-2014  Shong   1.3   Bug Fixing                                */
/* 22-May-2015  James   1.4   Revamp error msg (james02)                */
/* 22-Sep-2016  Ung     1.5   Performance tuning                        */
/* 24-Sep-2018  James   1.6   WMS7751-Remove OD.loadkey (james03)       */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMPK04]
               @c_UserID           NVARCHAR(18)
,              @c_AreaKey01        NVARCHAR(10)
,              @c_AreaKey02        NVARCHAR(10)
,              @c_AreaKey03        NVARCHAR(10)
,              @c_AreaKey04        NVARCHAR(10)
,              @c_AreaKey05        NVARCHAR(10)
,              @c_LastLoc          NVARCHAR(10)
AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT
   SELECT @b_debug = 0
   DECLARE @n_continue   INT
        ,@n_starttcnt  INT -- Holds the current transaction count
        ,@n_cnt        INT -- Holds @@ROWCOUNT after certain operations
        ,@n_err2       INT -- For Additional Error Detection
        ,@b_Success    INT
        ,@n_err        INT
        ,@c_errmsg     NVARCHAR(250)

   SELECT @n_starttcnt = @@TRANCOUNT
       ,@n_continue = 1
       ,@b_success = 0
       ,@n_err = 0
       ,@c_errmsg = ''
       ,@n_err2 = 0

   DECLARE @c_executestmt     NVARCHAR(255)
   DECLARE @c_LastCaseID      NVARCHAR(10)
        ,@c_LastWaveKey     NVARCHAR(10)
        ,@c_LastOrderKey    NVARCHAR(10)
        ,@c_LastRoute       NVARCHAR(10)
        ,@c_LastStop     NVARCHAR(10)
        ,@c_LogicalLoc      NVARCHAR(10)
        ,@c_lot             NVARCHAR(10)
        ,@c_UOM             NVARCHAR(10)


   DECLARE @b_gotarow         INT
        ,@b_RowCheckPass    INT
        ,@b_EvaluationType  INT
        ,@b_DoEval01_only   INT

   SELECT @b_gotarow = 0
       ,@b_RowCheckPass = 0
       ,@b_DoEval01_only = 0

   DECLARE @c_TaskDetailkey              NVARCHAR(10)
        ,@c_CaseID                     NVARCHAR(10)
        ,@c_OrderKey                   NVARCHAR(10)
        ,@c_OrderLineNumber            NVARCHAR(5)
        ,@c_WaveKey                    NVARCHAR(10)
        ,@c_StorerKey                  NVARCHAR(15)
        ,@c_sku                        NVARCHAR(20)
        ,@c_loc                        NVARCHAR(10)
        ,@c_id                         NVARCHAR(18)
        ,@c_UserKeyOverride            NVARCHAR(18)
        ,@c_route             NVARCHAR(10)
        ,@c_stop  NVARCHAR(10)
        ,@c_door                      NVARCHAR(10)
        ,@c_Message01                  NVARCHAR(20)
        ,@c_Message02                  NVARCHAR(20)
        ,@c_Message03                  NVARCHAR(20)
        ,@c_PickMethod                 NVARCHAR(10)
        ,@c_NextOrderKey               NVARCHAR(10)
        ,@c_TaskType                   NVARCHAR(10)
        ,@c_PutawayZone                NVARCHAR(10) -- (Shong01)

   DECLARE @c_PalletPickDispatchMethod   NVARCHAR(10)
        ,@c_CasePickDispatchMethod     NVARCHAR(10)
        ,@c_PiecePickDispatchMethod    NVARCHAR(10)

   DECLARE @n_temptable_recordcount      INT
        ,@n_temptable_qty              INT
        ,@c_LocType                    NVARCHAR(10)
        ,@c_uomtext                    NVARCHAR(10)
        ,@c_tempTaskDetailkey          NVARCHAR(10)
        ,@c_CaseIDtodelete             NVARCHAR(10)
        ,@n_countCaseIDtodelete        INT
        ,@b_SkipTheTask                INT

   DECLARE @b_Cursor_Eval01_Open         INT
        ,@b_Cursor_Eval02_Open         INT
        ,@b_Cursor_Eval03_Open         INT
        ,@b_Cursor_Eval04_Open         INT
        ,@b_Cursor_Eval05_Open         INT
        ,@b_Cursor_Eval06_Open         INT
        ,@b_Cursor_Eval07_Open         INT
        ,@b_Cursor_EvalBatchPick_Open  INT
        ,@b_TempTableCreated           INT

   DECLARE @c_LastLoadKey                NVARCHAR(10)
        ,@c_LoadKey                    NVARCHAR(10)
        ,@c_SourceType                 NVARCHAR(15)
        ,@c_DropID                     NVARCHAR(18) -- (Vicky01)
        ,@c_PrevToteFullFlag           NVARCHAR(1)  -- (Vicky01)
        ,@c_Consigneekey               NVARCHAR(20) -- (ChewKP02)

   DECLARE @nConsignee_Cnt INT, @cDeviceID NVARCHAR( 20), @cConsigneeKey NVARCHAR( 15), @cDeviceProfileKey NVARCHAR( 10), @cLoadKey NVARCHAR( 10)

   SELECT @b_Cursor_Eval01_Open = 0
       ,@b_Cursor_Eval02_Open = 0
       ,@b_Cursor_Eval03_Open = 0
       ,@b_Cursor_Eval04_Open = 0
       ,@b_Cursor_Eval05_Open = 0
       ,@b_Cursor_Eval06_Open = 0
       ,@b_Cursor_Eval07_Open = 0
       ,@b_Cursor_EvalBatchPick_Open = 0
       ,@b_TempTableCreated = 0
   /* #INCLUDE <SPTMPK01_1.SQL> */

   BEGIN TRAN

   IF @b_debug = '9'
   BEGIN
      INSERT dbo.TraceInfo (TraceName, TimeIn, TotalTime, Step1, Step2, Col1, Col2, Col3, Col4, Col5)
      VALUES ('nspTTMPK04', GETDATE(), '1', @c_UserID, @c_LastLoc, @c_AreaKey01, @c_AreaKey02, @c_AreaKey03, @c_AreaKey04, @c_AreaKey05)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @cDeviceID = DeviceID FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE UserName = @c_UserID

      IF ISNULL( @cDeviceID, '') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 54551 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                ': NO DEVICE ID. (nspTTMPK04)'+' ( '+
                ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '
      END

      CREATE TABLE #t_cartconsignee(
         DeviceID       NVARCHAR(20),
         ConsigneeKey   NVARCHAR(15),
         LoadKey        NVARCHAR(10) )
   END

    DECLARE @c_Priority NVARCHAR(10)
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        SELECT TOP 1 @c_LastLoadKey = TA.LoadKey
        FROM   TASKDETAIL TA WITH (NOLOCK)
        WHERE  TA.Tasktype = 'SPK'
               AND TA.Status = '9'
               AND ta.UserKey = @c_UserID
               AND NOT EXISTS(
                       SELECT 1
                       FROM   TaskManagerSkipTasks(NOLOCK)
                       WHERE  TaskManagerSkipTasks.Taskdetailkey = TA.TaskDetailkey
                   )
        ORDER BY
               TA.EditDate DESC

       IF @b_debug=1
       BEGIN
  SELECT 'Loadkey' = @c_LastLoadKey
       END
    END

    STARTPROCESSING:

    IF @n_continue=1 OR @n_continue=2
    BEGIN
        IF @b_debug=1
        BEGIN
            SELECT 'start processing'
        END

        UPDATE TaskDetail WITH (ROWLOCK)
        SET    STATUS = '0'
              ,USERKEY = ''
              ,REASONKEY = ''
              ,EditDate = GetDate()     -- (SHONG02)
              ,EditWho  = sUSER_sNAME()
              ,TrafficCop = NULL
        WHERE  USERKEY = @c_UserID
               AND STATUS = '3' -- (Vicky02)

        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT

        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 54552 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Update to TaskDetail table failed. (nspTTMPK04)'+' ( '+
                   ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '
        END

        IF @b_debug=1
        BEGIN
            SELECT 'Records where the userkey is equal to '
                   ,@c_UserID,' status is in process '

            SELECT *
            FROM   TaskDetail WITH (NOLOCK)
            WHERE  USERKEY = @c_UserID
                   AND STATUS='3' -- (Vicky01)
        END
    END

    WHILE (1=1)
          AND (@n_continue=1 OR @n_continue=2)
    BEGIN
        IF @b_debug=1
        BEGIN
            SELECT 'Start Evaluating'
        END


        IF (@n_continue=1 OR @n_continue=2)
        BEGIN
            --IF ISNULL(RTRIM(@c_LastLoadKey) ,'')<>''
            BEGIN
                IF @b_debug=1
                BEGIN
                    SELECT 'DECLARE Cursor_Eval01'
                END
                DECLARECURSOR_EVAL01:

                SELECT @b_Cursor_Eval01_Open = 0

               SET @nConsignee_Cnt = 0
               SELECT @nConsignee_Cnt = COUNT( DISTINCT DROPID)
               FROM dbo.DeviceProfilelog DL WITH (NOLOCK)
               JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
               WHERE D.DeviceID = @cDeviceID
               AND   D.Status < '9'
               AND   DL.Status < '9'
               AND   D.DeviceType = 'CART'
               AND   ISNULL( DL.ConsigneeKey, '') = ''

               DECLARE @ct_consigneekey NVARCHAR( 10), @ct_loadkey NVARCHAR(10)

               DECLARE CUR_LOOP CURSOR  LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT CONSIGNEEKEY, USERDEFINE02
               FROM dbo.DeviceProfilelog DL WITH (NOLOCK)
               JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
               WHERE D.DeviceID = @cDeviceID
               AND   D.Status < '9'
               AND   DL.Status < '9'
               AND   D.DeviceType = 'CART'
               AND   ISNULL( DL.ConsigneeKey, '') <> ''
               OPEN CUR_LOOP
               FETCH NEXT FROM CUR_LOOP INTO @ct_consigneekey, @ct_loadkey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  INSERT INTO #t_cartconsignee (DeviceID, ConsigneeKey, LoadKey) VALUES (@cDeviceID, @ct_consigneekey, @ct_loadkey)
                  FETCH NEXT FROM CUR_LOOP INTO @ct_consigneekey, @ct_loadkey
               END
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP


               IF ISNULL(RTRIM(@c_AreaKey01) ,'')<>''
               BEGIN
                  SELECT TOP 1 @c_loc = TaskDetail.FromLoc
                              ,@c_WaveKey = WaveKey
                              ,@c_StorerKey = StorerKey
                  FROM   TaskDetail WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON  TaskDetail.FromLoc = Loc.Loc
                  JOIN AREADETAIL WITH (NOLOCK) ON  AreaDetail.Putawayzone = Loc.PutAwayZone
                  WHERE  AreaDetail.AreaKey = @c_AreaKey01
                         AND TaskDetail.TASKTYPE = 'SPK'
                         AND TaskDetail.USERKEY = ''
                         AND TaskDetail.STATUS = '0'
                         AND ISNULL( TaskDetail.Message03, '') <> ''
                         AND EXISTS(SELECT 1 FROM TaskManagerUserDetail tmu WITH (NOLOCK)
                                    WHERE PermissionType = TaskDetail.TASKTYPE
                                      AND tmu.UserKey = @c_UserID
                                      AND tmu.AreaKey = @c_AreaKey01
                                      AND tmu.Permission = '1')
                         AND EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) -- Added By Shong on 11/12/2014
                                    WHERE PD.TaskDetailKey = TaskDetail.TaskDetailKey
                                     AND  PD.[Status] = '0')
                  ORDER BY
                         TaskDetail.Priority
                        ,CASE
                              WHEN TaskDetail.LOADKEY=@c_LastLoadKey THEN
                                   ''
                              ELSE TaskDetail.LoadKey
                         END -- Last LoadKey always come 1st
                        ,LOC.LogicalLocation
                        ,LOC.LOC


                  WHILE @nConsignee_Cnt > 0
                  BEGIN
                     SELECT TOP 1 @cConsigneeKey = OD.Userdefine02, @cLoadKey = O.LoadKey
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                     JOIN dbo. Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
                     WHERE PD.LOC = @c_loc
                     AND   PD.StorerKey = @c_StorerKey
                     AND   PD.Status = '0'
                     AND   O.UserDefine09 = @c_WaveKey
                     AND NOT EXISTS (SELECT 1 FROM #t_cartconsignee T WITH (NOLOCK) WHERE OD.Userdefine02 = T.ConsigneeKey AND O.LoadKey = T.LoadKey)
                     GROUP BY OD.Userdefine02, O.LoadKey
                     ORDER BY 2

                     IF EXISTS (SELECT 1 FROM dbo.DEVICEPROFILELOG DL WITH (NOLOCK)
                                JOIN dbo.DEVICEPROFILE D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
                                 WHERE D.DeviceID = @cDeviceID
                                 AND   D.Status < '9'
                                 AND   DL.Status < '9'
                                 AND   D.DeviceType = 'CART'
                                 AND   ISNULL( DL.ConsigneeKey, '') = @cConsigneeKey
                                 AND   ISNULL( DL.USERDEFINE02, '') = @cLoadKey)
                     BEGIN
                        INSERT INTO #t_cartconsignee (DeviceID, ConsigneeKey, LoadKey) VALUES (@cDeviceID, @cConsigneeKey, @cLoadKey)
                     END
                     ELSE
                     BEGIN
                        IF EXISTS (SELECT 1 FROM dbo.DEVICEPROFILELOG DL WITH (NOLOCK)
                                       JOIN dbo.DEVICEPROFILE D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
                                       WHERE D.DeviceID = @cDeviceID
                                       AND   D.Status < '9'
                                       AND   DL.Status < '9'
                                       AND   D.DeviceType = 'CART'
                                       AND   ISNULL( DL.ConsigneeKey, '') = ''
                                       AND   ISNULL( DL.USERDEFINE02, '') = '')
                        BEGIN
                           INSERT INTO #t_cartconsignee (DeviceID, ConsigneeKey, LoadKey) VALUES (@cDeviceID, @cConsigneeKey, @cLoadKey)
                        END
                        ELSE
                        BEGIN
                           IF EXISTS (SELECT 1 FROM dbo.DEVICEPROFILELOG DL WITH (NOLOCK)
                                          JOIN dbo.DEVICEPROFILE D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
                                          WHERE D.DeviceID = @cDeviceID
                                          AND   D.Status < '9'
                         AND   DL.Status < '9'
                                          AND   D.DeviceType = 'CART'
                                          AND   ISNULL( DL.ConsigneeKey, '') = @cConsigneeKey
                                          AND   ISNULL( DL.USERDEFINE02, '') = '')
                           BEGIN
                              INSERT INTO #t_cartconsignee (DeviceID, ConsigneeKey, LoadKey) VALUES (@cDeviceID, @cConsigneeKey, @cLoadKey)
                           END
                        END
                     END
                     SET @nConsignee_Cnt = @nConsignee_Cnt - 1
                  END

                  DECLARE Cursor_Eval01 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT TD.TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON  (TD.FromLoc = LOC.Loc)
                  JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON (AD.Putawayzone = LOC.PutAwayZone)
                  JOIN #t_cartconsignee t WITH (NOLOCK) ON (TD.Message03 = t.ConsigneeKey AND TD.LoadKey = t.LoadKey)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)
                  -- JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                  -- JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey AND t.LoadKey = O.LoadKey)
                  WHERE  AD.AreaKey = @c_AreaKey01
                         AND TD.TASKTYPE = 'SPK'
                         AND TD.USERKEY = ''
                         AND TD.STATUS = '0'
                         AND ISNULL( TD.Message03, '') <> ''
                         AND PD.Status = '0'
                         AND EXISTS(SELECT 1 FROM TaskManagerUserDetail tmu WITH (NOLOCK)
                                    WHERE PermissionType = TD.TASKTYPE
                                      AND tmu.UserKey = @c_UserID
                                      AND tmu.AreaKey = @c_AreaKey01
                                      AND tmu.Permission = '1')
                  ORDER BY
                         TD.Priority
                        ,CASE
                              WHEN TD.LOADKEY=@c_LastLoadKey THEN
                                   ''
                              ELSE TD.LoadKey
                         END -- Last LoadKey always come 1st
                        ,LOC.LogicalLocation
                        ,LOC.LOC
                END
                ELSE
                BEGIN
                    DECLARE Cursor_Eval01  CURSOR LOCAL FAST_FORWARD READ_ONLY
                    FOR
                        SELECT TaskDetailkey
                        FROM   TaskDetail WITH (NOLOCK)
                               JOIN LOC WITH (NOLOCK) ON  TaskDetail.FromLoc = Loc.Loc
                        JOIN AREADETAIL WITH (NOLOCK) ON  AreaDetail.Putawayzone = Loc.PutAwayZone
                        WHERE  TaskDetail.TASKTYPE = 'SPK'
                               AND TaskDetail.USERKEY = ''
                               AND TaskDetail.STATUS = '0'
                               AND EXISTS(SELECT 1 FROM TaskManagerUserDetail tmu WITH (NOLOCK)
                                          WHERE PermissionType = TaskDetail.TASKTYPE
                                            AND tmu.UserKey = @c_UserID
                                            AND tmu.Permission = '1')
                        ORDER BY
                               TaskDetail.Priority
                              ,CASE
                                    WHEN TaskDetail.LOADKEY=@c_LastLoadKey THEN
                       ''
                                    ELSE TaskDetail.LoadKey
                               END -- Last LoadKey always come 1st
                              ,LOC.LogicalLocation
                              ,LOC.LOC
                END
                SELECT @n_err = @@ERROR
          ,@n_cnt = @@ROWCOUNT

                IF @n_err=16915
                BEGIN
                    CLOSE Cursor_Eval01
                    DEALLOCATE Cursor_Eval01
                    GOTO DECLARECURSOR_EVAL01
                END

                OPEN Cursor_Eval01
                SELECT @n_err = @@ERROR
                      ,@n_cnt = @@ROWCOUNT

                IF @n_err=16905
                BEGIN
                    CLOSE Cursor_Eval01
                    DEALLOCATE Cursor_Eval01
                    GOTO DECLARECURSOR_EVAL01
                END

                IF @n_err<>0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                          ,@n_err = 54553 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                           ': Could not Open Cursor_Eval02. (nspTTMPK04)'+' ( '
                          +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)
                          +' ) '
                END
                ELSE
                BEGIN
                    SELECT @b_Cursor_Eval01_Open = 1
                END
                IF @n_continue=1 OR @n_continue=2
                BEGIN
                    WHILE (1=1)
                    BEGIN
                        FETCH NEXT FROM Cursor_Eval01 INTO @c_TaskDetailkey
                        IF @@FETCH_STATUS<>0
                        BEGIN
                            BREAK
                        END

                        SELECT @c_TaskDetailkey = TaskDetailkey
                              ,@c_CaseID = CaseID
                              ,@c_OrderKey = OrderKey
                              ,@c_OrderLineNumber = OrderLineNumber
                              ,@c_WaveKey = WaveKey
                              ,@c_StorerKey = StorerKey
                              ,@c_sku = SKU
                              ,@c_loc = FromLoc
                              ,@c_LogicalLoc = LogicalFromLoc
                              ,@c_id = FromID
                              ,@c_lot = lot
                              ,@c_uom = uom
                              ,@c_UserKeyOverride = UserKeyOverride
                              ,@c_PickMethod = PickMethod
                              ,@c_LoadKey = TaskDetail.LoadKey
                              ,@c_TaskType = TaskDetail.TaskType
                              ,@c_DropID = ISNULL(RTRIM(TaskDetail.DropID), '') -- (Vicky01)
                              ,@c_PrevToteFullFlag = CASE WHEN ISNULL(RTRIM(Message03), '') = 'PREVFULL' THEN 'Y' ELSE 'N' END
                              ,@c_Consigneekey = TaskDetail.Message03 --(ChewKP02)
                        FROM   TaskDetail WITH (NOLOCK)
                        WHERE  TaskDetailKEY = @c_TaskDetailkey

                        SELECT @b_EvaluationType = 1
                        SELECT @b_RowCheckPass = 0
                        GOTO CHECKROW
                        EVALUATIONTYPERETURN_01:
                        IF @b_RowCheckPass=1
                        BEGIN
                            SELECT @b_gotarow = 1
                            GOTO DISPATCH
                        END
                    END -- WHILE (1=1)
                END
            END
        END

        BREAK
        CHECKROW:
        SET ROWCOUNT 0
        IF @b_debug=1
        BEGIN
            SELECT 'evaluationtype' ,@b_EvaluationType
                  ,'TaskDetailkey=' ,@c_TaskDetailkey
                  ,'CaseID=' ,@c_CaseID
   ,'OrderKey=' ,@c_OrderKey
                  ,'OrderLineNumber=' ,@c_OrderLineNumber
                  ,'WaveKey=' ,@c_WaveKey
                  ,'storer=' ,@c_StorerKey
             ,'sku=' ,@c_sku
                  ,'loc=' ,@c_loc
                  ,'logicalloc=' ,@c_LogicalLoc
                  ,'id=' ,@c_id
                  ,'lot=' ,@c_lot
                  ,'uom=' ,@c_uom
                  ,'UserKeyOverride=' ,@c_UserKeyOverride
        END

        IF @b_RowCheckPass=0
        BEGIN
            IF @b_debug=1
            BEGIN
                SELECT 'Row candidate check #1 - area authorization...'
            END

            IF ISNULL(RTRIM(@c_AreaKey01) ,'')=''
            BEGIN
                IF NOT EXISTS(
                       SELECT 1
                       FROM  TaskManagerUserDetail WITH (NOLOCK)
                       JOIN  AreaDetail WITH (NOLOCK) ON TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
                       JOIN  Loc WITH (NOLOCK) ON AreaDetail.Putawayzone = Loc.PutAwayZone
                       WHERE  TaskManagerUserDetail.UserKey = @c_UserID
                              AND TaskManagerUserDetail.PermissionType = @c_TaskType
                              AND TaskManagerUserDetail.Permission = '1'
                              AND Loc.Loc = @c_loc
                   )
                BEGIN
                    GOTO EVALUATIONDONE
                END
            END
            ELSE
            BEGIN
                IF NOT EXISTS(
                       SELECT 1
                       FROM   AreaDetail WITH (NOLOCK)
                              JOIN Loc WITH (NOLOCK) ON  AreaDetail.Putawayzone = Loc.PutAwayZone
                       WHERE  AreaDetail.AreaKey = @c_AreaKey01
                              AND Loc.Loc = @c_loc
                   )
                BEGIN
                    GOTO EVALUATIONDONE
                END
            END
        END

        IF @b_RowCheckPass=0
        BEGIN
            IF @b_debug=1
            BEGIN
                SELECT
                       'Row candidate check #2 - Make sure record is not assigned to another user'

                SELECT @c_UserKeyOverride
                      ,@c_UserID
            END

            IF NOT (@c_UserKeyOverride='' OR @c_UserKeyOverride=@c_UserID)
            BEGIN
                GOTO EVALUATIONDONE
            END
        END

        IF @b_RowCheckPass=0
        BEGIN
            SELECT @b_success = 0
                  ,@b_SkipTheTask = 0

            EXECUTE nspCheckSkipTasks
            @c_UserID
            , @c_TaskDetailkey
            , @c_TaskType
            , @c_TaskDetailkey -- 'BatchPick' --@c_CaseID
            , ''
            , ''
            , ''
            , ''
            , ''
            , @b_SkipTheTask OUTPUT
            , @b_Success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            IF @b_success<>1
            BEGIN
                SELECT @n_continue = 3
            END

            IF @b_SkipTheTask=1
            BEGIN
                GOTO EVALUATIONDONE
            END
        END

        IF @b_RowCheckPass=0
        BEGIN
            SELECT @b_success = 0
            EXECUTE nspCheckEquipmentProfile
              @c_UserID=@c_UserID
            , @c_TaskDetailkey=''
            , @c_StorerKey=@c_StorerKey
            , @c_sku=@c_sku
            , @c_lot=@c_lot
            , @c_FromLoc=@c_loc
            , @c_FromID=@c_id
            , @c_toLoc=@c_loc
            , @c_toID=@c_id
            , @n_qty=0
            , @b_Success=@b_success OUTPUT
            , @n_err=@n_err OUTPUT
            , @c_errmsg=@c_errmsg OUTPUT
            IF @b_success=0
            BEGIN
                GOTO EVALUATIONDONE
            END
        END

        SELECT @b_RowCheckPass = 1
        IF @b_debug=1
        BEGIN
            SELECT 'Row check passed'
     END
        EVALUATIONDONE:

        IF @b_EvaluationType=1
        BEGIN
            GOTO EVALUATIONTYPERETURN_01
        END

      DISPATCH:

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN/*
         SET @nConsignee_Cnt = 0
         SELECT @nConsignee_Cnt = COUNT( DISTINCT DROPID)
         FROM dbo.DeviceProfilelog DL WITH (NOLOCK)
         JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         WHERE D.DeviceID = @cDeviceID
         AND   D.Status < '9'
         AND   D.DeviceType = 'CART'

         WHILE @nConsignee_Cnt > 0
         BEGIN
            INSERT INTO #t_cartconsignee (DeviceID, ConsigneeKey)
            SELECT DISTINCT TOP 1 @cDeviceID AS DeviceID, O.ConsigneeKey
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo. Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            WHERE PD.LOC = @c_loc
            AND   PD.StorerKey = @c_StorerKey
            AND   PD.Status = '0'
            AND   O.UserDefine09 = @c_WaveKey
            AND NOT EXISTS (SELECT 1 FROM #t_cartconsignee T WITH (NOLOCK) WHERE O.ConsigneeKey = T.ConsigneeKey)
            ORDER BY 2

            SET @nConsignee_Cnt = @nConsignee_Cnt - 1
         END
*/
         -- Lock the task for the consignee within same area
         UPDATE TD WITH (ROWLOCK)
         SET  TD.STATUS = '3'
             ,TD.UserKey = @c_UserID
             ,TD.ReasonKey = ''
             ,TD.EditDate = GetDate()
             ,TD.EditWho  = sUSER_sNAME()
             ,TD.TrafficCop = NULL
         FROM dbo.TaskDetail TD
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (TD.FROMLOC = LOC.LOC)
         JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON (LOC.PutawayZone = AD.PutawayZone)
         JOIN #t_cartconsignee t WITH (NOLOCK) ON (TD.Message03 = t.ConsigneeKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)
         JOIN dbo.OrderDetail OD WITH (NOLOCK)  ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey AND t.LoadKey = O.LoadKey)
         WHERE TD.Storerkey = @c_StorerKey
            AND TD.TaskType = 'SPK'
            AND TD.UserKey = ''
            AND TD.Status = '0'
            AND TD.WaveKey = @c_WaveKey
            AND TD.FromLOC = @c_loc
            AND TD.SKU = @c_sku
            AND AD.AreaKey = @c_AreaKey01

         SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT
         IF @n_err<>0
         BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 54554 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': UPDATE TaskDetail Failed. (nspTTMPK03)'+' ( '
                 + ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '
         END
/*
         -- Lock the cart
         UPDATE DL WITH (ROWLOCK) SET
            DL.Status = '1'
         FROM dbo.DeviceProfilelog DL
         JOIN dbo.DeviceProfile D ON DL.DeviceProfileKey = D.DeviceProfileKey
         WHERE D.DeviceID = @cDeviceID
         AND   D.Status = '0'
         AND   D.DeviceType = 'CART'
         AND   ISNULL( DL.ConsigneeKey, '') = ''

         SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT
         IF @n_err<>0
         BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 81206 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': UPDATE DeviceProfile Failed. (nspTTMPK03)'+' ( '
                 + ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '
         END

         -- Lock the cart
         UPDATE DeviceProfile WITH (ROWLOCK) SET
            [Status] = '1'
         WHERE DeviceID = @cDeviceID
         AND   [Status] = '0'
         AND   DeviceType = 'CART'


         SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT
         IF @n_err<>0
         BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 81207 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': UPDATE DeviceProfile Failed. (nspTTMPK03)'+' ( '
                 + ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '
         END  */
      END

      -- Close cursor  (Chee01)
      IF CURSOR_STATUS( 'global', 'CURSOR_PKTASKCANDIDATES') IN (0, 1) -- 0=empty, 1=record
         CLOSE CURSOR_PKTASKCANDIDATES
      IF CURSOR_STATUS( 'global', 'CURSOR_PKTASKCANDIDATES') IN (-1)   -- -1=cursor is closed
         DEALLOCATE CURSOR_PKTASKCANDIDATES

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         DECLARE CURSOR_PKTASKCANDIDATES
         CURSOR FOR
         SELECT @c_taskdetailkey,@c_caseid,@c_loadkey,@c_orderlinenumber,
               @c_wavekey, @c_storerkey,@c_sku,@c_lot,@c_loc,@c_id,'' as '@c_packkey',
               @c_uomtext, @n_temptable_qty, @c_message01, @c_message02, @c_message03

         GOTO DONE
      END
      ELSE
         GOTO NOTHINGTOSEND

        DISPATCHCHECK:

        DISPATCHEXECUTE:
     END  -- WHILE (1=1) AND (@n_continue=1 OR @n_continue=2)
     SET ROWCOUNT 0
     NOTHINGTOSEND:

     IF @b_debug=1
     BEGIN
         SELECT 'Nothing to send...'
     END

      -- Close cursor  (Chee01)
      IF CURSOR_STATUS( 'global', 'CURSOR_PKTASKCANDIDATES') IN (0, 1) -- 0=empty, 1=record
         CLOSE CURSOR_PKTASKCANDIDATES
      IF CURSOR_STATUS( 'global', 'CURSOR_PKTASKCANDIDATES') IN (-1)   -- -1=cursor is closed
         DEALLOCATE CURSOR_PKTASKCANDIDATES

     DECLARE CURSOR_PKTASKCANDIDATES  CURSOR
     FOR
         SELECT '' ,'' ,'' ,'' ,'' ,'' ,'' ,''
               ,'' ,'' ,'' ,'' , 0 ,'' ,'' ,''
     DONE:

     IF @b_debug=1
     BEGIN
         SELECT 'DONE'
     END

     IF @b_Cursor_Eval01_Open=1
     BEGIN
         CLOSE Cursor_Eval01
         DEALLOCATE Cursor_Eval01
     END

     IF @b_Cursor_Eval02_Open=1
     BEGIN
         CLOSE Cursor_Eval02
         DEALLOCATE Cursor_Eval02
     END

     IF @b_Cursor_Eval03_Open=1
     BEGIN
         CLOSE Cursor_Eval03
         DEALLOCATE Cursor_Eval03
     END

     IF @b_Cursor_Eval04_Open=1
     BEGIN
         CLOSE Cursor_Eval04
         DEALLOCATE Cursor_Eval04
     END

     IF @b_Cursor_Eval05_Open=1
     BEGIN
         CLOSE Cursor_Eval05
         DEALLOCATE Cursor_Eval05
     END

     IF @b_Cursor_Eval06_Open=1
     BEGIN
         CLOSE Cursor_Eval06
         DEALLOCATE Cursor_Eval06
     END

     IF @b_Cursor_Eval07_Open=1
     BEGIN
         CLOSE Cursor_Eval07
         DEALLOCATE Cursor_Eval07
     END

     IF @b_TempTableCreated=1
     BEGIN
         DROP TABLE #TEMP_DISPATCHCaseID
     END

   /* #INCLUDE <SPTMMV01_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
        IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMPK04'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
     END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END

GO