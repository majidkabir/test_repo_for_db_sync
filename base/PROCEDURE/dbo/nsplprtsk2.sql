SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspLPRTSK2                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Loadplan Task Release Strategy for IDSUK Diana Project      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* Version: 3.3                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 24-Jun-2010  Shong    1.0  Creation                                  */
/* 23-Jul-2010  Vicky    1.1  Filter Order Type when checking StoreToLoc*/
/*                            (Vicky01)                                 */
/* 27-Jul-2010  Shong    1.2  Select PickDetail with TaskDetailKey = '' */
/*                            (Shong01)                                 */
/* 29-Jul-2010  Vicky    1.3  Do not insert Areakey to TaskDetail coz   */
/*                            1 PAZone can be in >1 Area  (Vicky02)     */
/* 04-Aug-2010  Shong    1.4  Check the PTS Location not Setup for PEICE*/
/*                            Pick (Shong02)                            */
/* 16-Aug-2010  ChewKP   1.5  Do not create DRP task where there is     */
/*                            un-processed task in TaskDetail from the  */
/*                            same zone (ChewKP01)                      */
/* 04-Sep-2010  Shong    1.6  Default QtyReplen to Zero if value =      */
/*                            Negative (Shong03)                        */
/* 04-Sep-2010  ChewKP   1.7  DRP Task Priority (ChewKP02)              */
/* 08-Sep-2010  ChewKP   1.8  Fix Error when Release Task only for      */
/*                            PickDetial.Status = 0 (ChewKP03)          */
/* 09-Sep-2010  ChewKP   1.9  Filter by LOC.LocationType = PICK for PPA */
/*                            Location (ChewKP04)                       */
/* 10-Sep-2010  ChewKP   2.0  Bug Fixes (ChewKP05)                      */
/* 12-Sep-2010  ChewKP   2.1  Fix Issues: LocationType = 'PICK' shall   */
/*                            not generate Task as Case Pick (ChewKP06) */
/* 13-Sep-2010  Shong    2.2  LOC.LocationType Should exclude from      */
/*                            suggest replen from location (Shong04)    */
/* 27-Sep-2010  James    2.3  Take out filter by putawayzone when calc  */
/*                            DRP task (james01)                        */
/* 03-Oct-2010  Shong    2.4  Include SystemQty when Insert Task        */
/*                            (Shong05)                                 */
/* 14-Oct-2010  Shong    2.5  Group Carton by PTS Station (Shong06)     */
/* 25-Oct-2010  TLTING   2.6  Replace Variable table to #Temp           */
/* 26-Oct-2010  SHONG    2.7  Replen Priority Should Getting from ToLoc */
/*                            Not FromLoc (SHONG07)                     */
/* 18-Jan-2011  James    2.8  Include storegroup feature (SHONG08)      */
/* 03-Mac-2011  AQSKC    2.9  SOS#205637 Split Task Types for PK from   */
/*                            PPA for STORE orders (Kc01)               */
/* 19-May-2011  Audrey        SOS# 215663 - Apply Storer ConfigKey      */
/*                                          'PickDet_InsertLog' to log  */
/*                                          data before release task.   */
/* 13-Jun-2011  Leong    3.0  SOS# 218370 - Prevent Over Replenishment  */
/* 15-Jun-2011  James    3.0  SOS# 218262 - Stamp 'C&C Orders' (james02)*/
/* 02-Aug-2011  Shong    3.1  SOS# 222218 - To track replen task not    */
/*                                          generated using a temp table*/
/*                                          Temp_ReplenTrace            */
/* 10-Aug-2011  Leong    3.1  SOS# 223156 - Track Qty before DRP task   */
/* 11-Oct-2011  NJOW01   3.2  227534-filter store to loc blocked status */
/*                            exclude storetolocdetail.status = '9'     */
/* 14-DEC-2011  YTWan    3.3  SOS#231895-Add Route to StatusMsg.(Wan01) */
/* 16-Feb-2012  NJOW02   3.4  234484-Update orderkey to taskdetail if   */
/*                            SPK task type for Store pick in PPA       */
/* 24-Feb-2012  NJOW03   3.5  237046-Remove double and change to multi  */
/*                            if an order more than a single unit       */
/* 22-Mar-2012  NJOW04   3.6  238854-Gender split task routing          */
/* 12-Apr-2012  NJOW05   3.7  240693-Increate storegroup to varchar(20) */
/* 05-Jun-2014  NJOW06   3.8  313177-Change pickmethod logic            */
/* 28-Oct-2012  NJOW07   3.9  314930 - Move process flag checking       */
/*                            to wrapper and move raiseerror to control */
/*                            by wrapper                                */
/************************************************************************/

CREATE PROC [dbo].[nspLPRTSK2]
   @c_LoadKey     NVARCHAR(10),
   @n_err         INT OUTPUT,
   @c_ErrMsg      NVARCHAR(250) OUTPUT,
   @c_Storerkey   NVARCHAR(15) = ''
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_continue       INT
           ,@c_PickDetailKey  NVARCHAR(10)
           ,@c_TaskDetailKey  NVARCHAR(10)
           ,@c_PickLoc        NVARCHAR(10)
           ,@b_Success        INT
           ,@n_ShipTo         INT
           ,@c_PickMethod     NVARCHAR(10)
           ,@c_RefTaskKey     NVARCHAR(10)

    DECLARE @n_cnt            INT

    DECLARE @c_SKU            NVARCHAR(20)
           ,@c_ID             NVARCHAR(18)
           ,@c_FromLoc        NVARCHAR(10)
           ,@c_ToLoc          NVARCHAR(10)
           ,@c_PnDLocation    NVARCHAR(10)
           ,@n_InWaitingList  INT
           ,@n_SKUCnt         INT
           ,@n_PickQty        INT
           ,@c_Status         NVARCHAR(10)
           --,@c_StorerKey      NVARCHAR(15)
           ,@n_PalletQty      INT
           ,@n_StartTranCnt   INT
           ,@c_LaneType       NVARCHAR(20)
           ,@c_Priority       NVARCHAR(10)
           ,@c_OrderType      NVARCHAR(10)
           ,@c_OrderKey       NVARCHAR(10)
           ,@c_ConsigneeKey   NVARCHAR(15)
           ,@c_LOT            NVARCHAR(10)
           ,@c_AreaKey        NVARCHAR(10)
           ,@n_ReplenQty      INT
           ,@c_Facility       NVARCHAR(10)
           ,@n_Qty            INT
           ,@n_TotalPick      INT
           ,@c_Putawayzone    NVARCHAR(10)
           ,@c_ReplenPriority NVARCHAR(10)
           --,@c_ProcessFlag    NCHAR(1) --NJOW07
           ,@c_authority      NCHAR(1)           --(Kc01)
           ,@c_TaskType       NVARCHAR(5)        --(Kc01)
           ,@c_Route          NVARCHAR(10)       --(Wan01)
           ,@c_Userdefine01   NVARCHAR(20) --NJOW06


   DECLARE  @d_StartTime    datetime,
            @d_EndTime      datetime,
            @d_Step1        datetime,
            @d_Step2        datetime,
            @d_Step3        datetime,
            @d_Step4        datetime,
            @d_Step5        datetime,
            @d_SubStartTime datetime,
            @d_SubEndTime   datetime,
            @d_SubStep1     datetime,
            @d_SubStep2     datetime,
            @d_SubStep3     datetime,
            @d_SubStep4     datetime,
            @d_SubStep5     datetime,
            @c_col1         NVARCHAR(20),
            @c_col2         NVARCHAR(20),
            @c_col3         NVARCHAR(20),
            @c_col4         NVARCHAR(20),
            @c_col5         NVARCHAR(20),
            @c_myTraceName  NVARCHAR(80),
            @b_mydebug        int

   DECLARE @c_CurrPutawayZone NVARCHAR(10),
           @c_PrevSKU         NVARCHAR(20),
           @n_CursorDeclared  INT

   DECLARE @n_SGANo        INT,
           @c_NextStoreGrp NVARCHAR(20)  --NJOW05

   SET @b_mydebug = 9
   SET @c_myTraceName = 'nspLPRTSK2'
   SET @d_StartTime = GETDATE()

   SET @c_Route = ''                            --(Wan01)
   SELECT @n_continue = 1
          ,@n_err = 0
          ,@c_ErrMsg = ''
          --,@c_ProcessFlag = 'N' --NJOW07

    SET @n_StartTranCnt = @@TRANCOUNT

    WHILE @@TRANCOUNT > 0
      COMMIT TRAN

    IF @n_continue=1 OR @n_continue=2
    BEGIN
    	  /* --NJOW07
        IF EXISTS(SELECT 1 FROM   LoadPlan with (NOLOCK)
                  WHERE  LoadKey = @c_LoadKey
                    AND  ProcessFlag = 'L'
                 )
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81001 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': This Load is Currently Being Processed!'+' ( '+
                   ' SQLSvr MESSAGE='+@c_ErrMsg+
                   ' ) '
            GOTO QUIT_SP
        END
        ELSE
        */
        IF NOT EXISTS(
               SELECT 1
               FROM   PickDetail p WITH (NOLOCK)
                      JOIN LoadPlanDetail lpd WITH (NOLOCK)
                           ON  lpd.OrderKey = p.OrderKey
                      JOIN ORDERS o WITH (NOLOCK)
                           ON  o.OrderKey = p.OrderKey
                      JOIN LoadPlan lp WITH (NOLOCK)
                           ON  lp.LoadKey = lpd.LoadKey
               WHERE  lpd.LoadKey = @c_LoadKey
                      AND p.STATUS = '0'
                      AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' ) -- (Shong01)
                      )
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81002 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': No task to release'+' ( '+' SQLSvr MESSAGE='+
                   @c_ErrMsg+' ) '

            --SET @c_ProcessFlag = 'Y' --NJOW07

            GOTO QUIT_SP
        END

        BEGIN TRAN

        /* --NJOW07
        UPDATE LoadPlan WITH (ROWLOCK)
        SET    PROCESSFLAG = 'L'
        WHERE  LoadKey = @c_LoadKey
        */

        SELECT @n_err = @@ERROR
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81003 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Update of LoadPlan Failed (nspLPRTSK2)'+' ( '
                  +' SQLSvr MESSAGE='+@c_ErrMsg
                  +' ) '

            ROLLBACK TRAN
            GOTO QUIT_SP
        END
        ELSE
        BEGIN
           WHILE @@TRANCOUNT > 0
              COMMIT TRAN
        END

      IF @b_mydebug = 9
      BEGIN
         select @c_col3 = MIN(TYPE),
                @c_col5 = MIN(STORERKEY)
           from orders (nolock)
         where LOADkey = @c_LoadKey;

         SET @d_EndTime = GETDATE()

         INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], TotalTime, Step1,
                  Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         VALUES
         (RTRIM(@c_myTraceName),@d_StartTime, @d_EndTime
         ,CONVERT(NVARCHAR(12),@d_EndTime - @d_StartTime ,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep1,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep2,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep3,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep4,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep5,114)
         ,'START' -- col1
         ,@c_LoadKey
         ,@c_col3
         ,@c_col4
         ,@c_col5)
      END

       -- Declare temp table to store the from LOT, LOC and ID, Qty for Bulk Pick
       --tlting
       CREATE TABLE #BulkPick  (
          RowRef        BIGINT IDENTITY(1,1)  Primary Key,
          PickDetailKey NVARCHAR(10),
          StorerKey     NVARCHAR(15),
          SKU           NVARCHAR(20),
          LOT           NVARCHAR(10),
          LOC           NVARCHAR(10),
          ID            NVARCHAR(18),
          Qty           INT,
          ConsigneeKey  NVARCHAR(15),
          StoreLoc      NVARCHAR(10),
          Done          NCHAR(1)
          )

       DECLARE @c_MissingStoreLoc NVARCHAR(215)

      -- SOS# 215663 (Start)
      IF EXISTS ( SELECT 1 FROM StorerConfig SC WITH (NOLOCK)
                  JOIN Orders O WITH (NOLOCK)
                  ON SC.StorerKey = O.StorerKey
                WHERE SC.ConfigKey = 'PickDet_InsertLog'
                  AND ISNULL(RTRIM(SC.SValue),'') = '1'
                  AND O.LoadKey = @c_LoadKey )
      BEGIN
         INSERT INTO PickDet_Log
            ( PickDetailKey, OrderKey  , OrderLineNumber
            , Storerkey    , Sku    , Lot
            , Loc          , ID        , UOM
            , Qty          , STATUS    , DropID
            , PackKey      , WaveKey   , AddDate
            , AddWho       , PickSlipNo, TaskDetailKey
            , CaseId       , EditDate  , EditWho )
         SELECT P.PickDetailKey, P.OrderKey  , P.OrderLineNumber
              , P.StorerKey    , P.Sku       , P.Lot
              , P.Loc          , P.Id        , P.UOM
              , P.Qty          , P.Status    , P.DropId
              , P.PackKey      , 'nspLPRTSK2', P.AddDate
              , P.AddWho       , P.PickSlipNo, P.TaskDetailKey
              , P.CaseID       , P.EditDate  , P.EditWho
         FROM Orders O WITH (NOLOCK)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = O.OrderKey
         JOIN PickDetail P WITH (NOLOCK) ON O.OrderKey = P.OrderKey
         WHERE LPD.LoadKey = @c_LoadKey
         AND ISNULL(RTRIM(P.TaskDetailKey), '') = ''
         AND ISNULL(RTRIM(O.UserDefine01), '') = ''
      END
      -- SOS# 215663 (End)

      INSERT INTO #BulkPick   ( PickDetailKey, StorerKey, SKU, LOT, LOC, ID, Qty, ConsigneeKey, StoreLoc, Done )
      SELECT p.PickDetailKey, p.StorerKey, p.SKU, p.LOT, p.LOC, p.ID, p.Qty, O.ConsigneeKey,
      ISNULL(StoreLOC.LOC, ''), 'N'
      FROM  Orders O WITH (NOLOCK)
      JOIN  LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = O.OrderKey
      JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
      JOIN SKUxLOC sl WITH (NOLOCK) ON sl.LOC = p.LOC AND sl.StorerKey = p.Storerkey AND sl.Sku = p.Sku
      AND sl.LocationType NOT IN ('PICK','CASE')
      --JOIN LOC WITH (NOLOCK) ON LOC.LOC = p.LOC AND LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR')      -- (ChewKP06)
      JOIN LOC WITH (NOLOCK) ON LOC.LOC = p.LOC AND LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','PICK') -- (ChewKP06)
      LEFT OUTER JOIN ( SELECT stld.ConsigneeKey, MAX(stld.LOC) AS LOC
                        FROM StoreToLocDetail stld WITH (NOLOCK)
                        WHERE stld.Status <> '9' --NJOW01
                        GROUP BY stld.ConsigneeKey) AS StoreLoc ON O.ConsigneeKey = StoreLOC.ConsigneeKey
      WHERE lpd.LoadKey = @c_LoadKey
      AND (p.TaskDetailKey IS NULL OR p.TaskDetailKey = '')
      AND (ISNULL(RTRIM(o.UserDefine01), '') = '') -- (Vicky01)

      IF EXISTS(SELECT 1 FROM #BulkPick WHERE StoreLoc = '')
      BEGIN
         DECLARE CUR_MissingStoreLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT ConsigneeKey
         FROM #BulkPick WHERE StoreLoc = ''

         OPEN CUR_MissingStoreLoc

         FETCH NEXT FROM CUR_MissingStoreLoc INTO @c_ConsigneeKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF ISNULL(@c_MissingStoreLoc, '') = ''
               SET @c_MissingStoreLoc = @c_ConsigneeKey
            ELSE
               SET @c_MissingStoreLoc = @c_MissingStoreLoc + ', ' + @c_ConsigneeKey

            FETCH NEXT FROM CUR_MissingStoreLoc INTO @c_ConsigneeKey
         END
         --CLOSE CUR_MissingStoreLoc          -- (ChewKP05)
         --DEALLOCATE CUR_MissingStoreLoc     -- (ChewKP05)

         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
               ,@n_err = 81004 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg = 'The following Stores NOT yet assign Store Location: ' + @c_MissingStoreLoc +
                ' (nspLPRTSK2)'
         CLOSE CUR_MissingStoreLoc
         DEALLOCATE CUR_MissingStoreLoc
         GOTO QUIT_SP
       END
    END

    IF @n_continue=1 OR @n_continue=2
    BEGIN
       SET @c_Status = '0'

       SELECT @c_Priority = Priority
       FROM   Loadplan WITH (NOLOCK)
       WHERE  LoadKey = @c_LoadKey

     -- tlting
     CREATE TABLE  #Orders (
          RowRef    BIGINT IDENTITY(1,1) Primary Key,
          OrderKey  NVARCHAR(10)
         ,OrderType NVARCHAR(10)
         ,SKUCount  INT
         ,TotalPick INT
         ,Userdefine01 NVARCHAR(20) NULL --NJOW06
         )

       INSERT INTO #Orders  ( OrderKey, OrderType, SKUCount, TotalPick, 
                            Userdefine01 ) --NJOW06
         SELECT o.OrderKey
              ,CASE WHEN (o.UserDefine01 <> '' AND o.UserDefine01 IS NOT NULL) THEN 'ECOM'
                     ELSE 'STORE'
                END AS OrderType
               ,COUNT( DISTINCT SKU ) AS SKUCount
               ,SUM(p.Qty) AS TotalPick
               ,o.Userdefine01 --NJOW06  
         FROM   PickDetail p WITH (NOLOCK)
                JOIN LoadPlanDetail lpd WITH (NOLOCK) ON  lpd.OrderKey = p.OrderKey
         JOIN ORDERS o WITH (NOLOCK) ON  o.OrderKey = p.OrderKey
                JOIN LoadPlan lp WITH (NOLOCK) ON  lp.LoadKey = lpd.LoadKey
         WHERE  lpd.LoadKey = @c_LoadKey
                AND p.STATUS = '0'
                AND (p.TaskDetailKey IS NULL OR p.TaskDetailKey = '')
         GROUP BY o.OrderKey
                 ,CASE WHEN (o.UserDefine01 <> '' AND o.UserDefine01 IS NOT NULL) THEN 'ECOM'
                    ELSE 'STORE'
                  END
                 ,o.Userdefine01 --NJOW06
                 
       --NJOW06          
       UPDATE #Orders 
       SET Userdefine01 = CASE WHEN TotalPick = 1 AND Userdefine01 LIKE 'MULTIS%' THEN 
                                  REPLACE(Userdefine01, 'MULTIS', 'SINGLES') ELSE Userdefine01 END                                              

       -- Shong02 (Start)
       -- Check the PTS Location not Setup for PEICE
       DECLARE CUR_MissingStoreLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT OD.ConsigneeKey
       FROM  #Orders O
       JOIN ORDERS OD ON OD.OrderKey = O.OrderKey
       JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
       JOIN SKUxLOC sl WITH (NOLOCK) ON sl.LOC = p.LOC AND sl.StorerKey = p.Storerkey AND sl.Sku = p.Sku
               AND sl.LocationType = 'PICK'
       WHERE (o.OrderType = 'STORE')

       OPEN CUR_MissingStoreLoc

       FETCH NEXT FROM CUR_MissingStoreLoc INTO @c_ConsigneeKey
       WHILE @@FETCH_STATUS <> -1
       BEGIN
          IF NOT EXISTS(
             SELECT stld.ConsigneeKey
             FROM  StoreToLocDetail stld WITH (NOLOCK)
             WHERE ConsigneeKey = @c_ConsigneeKey
             AND stld.Status <> '9') --NJOW01
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                   ,@n_err = 81005 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_ErrMsg = 'The following Stores NOT yet assign Store Location: ' + @c_ConsigneeKey +
                   ' (nspLPRTSK2)'
             CLOSE CUR_MissingStoreLoc
             DEALLOCATE CUR_MissingStoreLoc
             GOTO QUIT_SP
          END

          FETCH NEXT FROM CUR_MissingStoreLoc INTO @c_ConsigneeKey
       END
       CLOSE CUR_MissingStoreLoc
       DEALLOCATE CUR_MissingStoreLoc
       -- Shong02 (End)

       SELECT @c_PickDetailKey = ''
       SELECT @c_PickLoc = ''

       WHILE @@TRANCOUNT > 0
         COMMIT TRAN

       --------------------------------------------------
       -- ECOM Single, Group Task by SKU, ID & Location
       ---------------------------------------------------
       DECLARE C_SinglePickTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT p.StorerKey, p.SKU, p.LOC, p.ID, SUM(p.Qty), o.OrderType,
                  o.Userdefine01 --NJOW06
           FROM  #Orders O
           JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
           JOIN LOC Loc WITH (NOLOCK) ON LOC.Loc = p.loc   -- (ChewKP04)
           --WHERE (O.SKUCount = 1 AND O.TotalPick = 1)
           WHERE o.Userdefine01 LIKE 'SINGLES%' --NJOW06
           AND (o.OrderType = 'ECOM')
           AND p.Status = '0' -- (ChewKP03)
           AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' )  -- (ChewKP03)
           AND LOC.LocationType = 'PICK' -- (CheWKP04)           
           GROUP BY p.StorerKey, p.SKU, p.LOC, p.ID, o.OrderType,
                    o.Userdefine01 --NJOW06

       OPEN C_SinglePickTask

       FETCH NEXT FROM C_SinglePickTask INTO @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty, @c_OrderType,
                                             @c_Userdefine01 --NJOW06

       WHILE (@@FETCH_STATUS<>-1)
       BEGIN
          IF @c_OrderType = 'ECOM'
             --SET @c_PickMethod = 'SINGLES'
             SET @c_PickMethod = @c_Userdefine01 --NJOW06

          SET @c_ToLoc = ''
          SELECT @c_ToLoc = ISNULL(SHORT,'')
          FROM   CODELKUP c WITH (NOLOCK)
          WHERE  c.LISTNAME = 'WCSROUTE'
          AND    c.Code = @c_PickMethod

          -- Insert into taskdetail Main
          EXECUTE nspg_getkey
          'TaskDetailKey',
          10,
          @c_TaskDetailKey OUTPUT,
          @b_Success OUTPUT,
          @n_err OUTPUT,
          @c_ErrMsg OUTPUT
          IF NOT @b_Success=1
          BEGIN
              SELECT @n_continue = 3
              SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                    ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                     ': Unable to Get TaskDetailKey (nspLPRTSK2)'
                +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                    +' ) '
              CLOSE C_SinglePickTask
              DEALLOCATE C_SinglePickTask
              GOTO QUIT_SP
          END
          ELSE
          BEGIN
              SET @c_AreaKey=''
              SELECT @c_AreaKey = ISNULL(ad.AreaKey,'')
              FROM AreaDetail ad WITH (NOLOCK)
              JOIN LOC l WITH (NOLOCK) ON l.PutawayZone = ad.PutawayZone
              WHERE l.Loc = @c_FromLoc

              BEGIN TRAN

              INSERT TASKDETAIL
                (
                  TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
                  UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
                  SourceKey, Caseid, Priority, SourcePriority, OrderKey,
                  OrderLineNumber, PickDetailKey, PickMethod, STATUS,
                  LoadKey, AreaKey, SystemQty
                )
              VALUES
                (
                  @c_TaskDetailKey, 'PK', @c_Storerkey, @c_SKU, '' -- Lot,
                  , '' -- UOM,
                  , 0  -- UOMQty,
                  , @n_PickQty
                  , @c_FromLoc -- FromLoc
                  , @c_ID    -- FromID
                  , @c_ToLoc -- ToLoc
                  , @c_ID    -- ToID
                  , 'nspLPRTSK2'
                  , @c_LoadKey, '' -- Caseid
                  , @c_Priority -- Priority
                  , '9'
                  , '' -- Orderkey,
                  , '' -- OrderLineNumber
                  , '' -- PickDetailKey
                  , @c_PickMethod
                  , @c_Status
                  , @c_LoadKey
                  , '' --(Vicky02)
                  , @n_PickQty -- (Shong05)
                )

              SELECT @n_err = @@ERROR
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81007 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                  CLOSE C_SinglePickTask
                  DEALLOCATE C_SinglePickTask

                  GOTO QUIT_SP
              END
              -- Update the Pickdetail TaskDetailKey
              DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY
              FOR
                 SELECT p.PickDetailKey
                 FROM  #Orders O
                 JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
                 --WHERE O.SKUCount = 1
                 WHERE p.STATUS = '0'
                   AND (p.TaskDetailKey IS NULL OR p.TaskDetailKey = '') -- (Shong01)
                   AND p.LOC = @c_FromLoc
                   AND p.ID = @c_ID
                   AND p.Storerkey = @c_StorerKey
                   AND p.Sku = @c_SKU
                   AND o.OrderType = @c_OrderType
                   --AND o.TotalPick = 1  -- (ChewKP04)
                   AND o.Userdefine01 = @c_Userdefine01 --NJOW06

              OPEN CUR_PICKDETAILKEY
              FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey

              WHILE @@FETCH_STATUS<>-1
              BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET    TaskDetailKey = @c_TaskDetailKey
                        ,TrafficCop = NULL
                  WHERE  PickDetailKey = @c_PickDetailKey

                 IF @n_err<>0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                           ,@n_err = 81008 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                            ': Update of Pickdetail Failed (nspLPRTSK2)'+' ( '
                           +' SQLSvr MESSAGE='+@c_ErrMsg
                           +' ) '
                     GOTO QUIT_SP
                 END

                 -- (james02)
                 IF @c_OrderType = 'ECOM'
                 BEGIN
                    UPDATE TD WITH (ROWLOCK) SET
                       TD.ListKey = 'C&C EComm',
                       TD.TrafficCop = NULL
                    FROM TaskDetail TD
                    JOIN PickDetail PD ON TD.TaskDetailKey = PD.TaskDetailKey
                    JOIN Orders O ON PD.OrderKey = O.OrderKey
                    WHERE PD.PickDetailKey = @c_PickDetailKey
                       AND O.Incoterm = 'CC'
                       AND ISNULL(TD.ListKey, '') = ''    -- prevent update many times

                    IF @n_err<>0
                    BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                              ,@n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                               ': Update of TaskDetail.ListKey Failed (nspLPRTSK2)'+' ( '
                              +' SQLSvr MESSAGE='+@c_ErrMsg
                              +' ) '
                        GOTO QUIT_SP
                    END
                 END

                 FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey

              END
              CLOSE CUR_PICKDETAILKEY
              DEALLOCATE CUR_PICKDETAILKEY
           END-- Insert into taskdetail Main

           WHILE @@TRANCOUNT > 0
              COMMIT TRAN

           FETCH NEXT FROM C_SinglePickTask INTO @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty, @c_OrderType,
                                                 @c_Userdefine01 --NJOW06
        END -- WHILE 1=1
        CLOSE C_SinglePickTask
        DEALLOCATE C_SinglePickTask

       WHILE @@TRANCOUNT > 0
         COMMIT TRAN

       -------------------------------------------------
       -- Doubles and Multis Pick Task - By Orders
       -------------------------------------------------
       DECLARE C_MultiPickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT p.OrderKey, p.StorerKey, p.SKU, p.LOC, p.ID, SUM(P.Qty), O.SKUCount, O.TotalPick,
                  o.Userdefine01 --NJOW06
           FROM  #Orders O
           JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
           JOIN LOC Loc WITH (NOLOCK) ON LOC.Loc = p.loc   -- (ChewKP04)
           --WHERE ( O.SKUCount > 1 OR (O.SKUCount = 1 AND O.TotalPick > 1) )
           WHERE o.Userdefine01 LIKE 'MULTIS%'  --NJOW06
           AND   o.OrderType = 'ECOM'
           AND p.Status = '0' -- (ChewKP03)
           AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' )  -- (ChewKP03)
           AND LOC.LocationType = 'PICK' -- (CheWKP04)
           GROUP BY p.OrderKey, p.StorerKey, p.SKU, p.LOC, p.ID, O.SKUCount, O.TotalPick,
                    o.Userdefine01 --NJOW06
           ORDER BY p.OrderKey, p.LOC, p.StorerKey, p.SKU

       OPEN C_MultiPickTask

       FETCH NEXT FROM C_MultiPickTask INTO @c_OrderKey, @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty,
                                            @n_SKUCnt, @n_TotalPick,
                                            @c_Userdefine01 --NJOW06

       WHILE (@@FETCH_STATUS<>-1)
       BEGIN
          --SET @c_PickMethod = CASE WHEN @n_SKUCnt = 2 AND @n_TotalPick = 2 THEN 'DOUBLES'
          --                         WHEN @n_SKUCnt = 1 AND @n_TotalPick = 2 THEN 'DOUBLES'
          --                    ELSE 'MULTIS' END
          --SET @c_PickMethod = 'MULTIS'  --NJOW03
          SET @c_PickMethod = @c_Userdefine01 --NJOW06
          
          SET @c_ToLoc = ''
          SELECT @c_ToLoc = ISNULL(SHORT,'')
          FROM   CODELKUP c WITH (NOLOCK)
          WHERE  c.LISTNAME = 'WCSROUTE'
          AND    c.Code = @c_PickMethod

          -- Insert into taskdetail Main
          EXECUTE nspg_getkey
          'TaskDetailKey',
          10,
          @c_TaskDetailKey OUTPUT,
          @b_Success OUTPUT,
          @n_err OUTPUT,
          @c_ErrMsg OUTPUT
          IF NOT @b_Success=1
          BEGIN
              SELECT @n_continue = 3
              SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                    ,@n_err = 81010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                     ': Unable to Get TaskDetailKey (nspLPRTSK2)'
                    +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                    +' ) '
              CLOSE C_MultiPickTask
              DEALLOCATE C_MultiPickTask
              GOTO QUIT_SP
          END
          ELSE
          BEGIN
              SET @c_AreaKey=''

              SELECT @c_AreaKey = ISNULL(ad.AreaKey,'')
              FROM AreaDetail ad WITH (NOLOCK)
              JOIN LOC l WITH (NOLOCK) ON l.PutawayZone = ad.PutawayZone
              WHERE l.Loc = @c_FromLoc

              BEGIN TRAN

              INSERT TASKDETAIL
                (
                  TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
                  UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
                  SourceKey, Caseid, Priority, SourcePriority, OrderKey,
                  OrderLineNumber, PickDetailKey, PickMethod, STATUS,
                  LoadKey, AreaKey, SystemQty
                )
              VALUES
                (
                  @c_TaskDetailKey, 'PK',
                  @c_Storerkey,
                  @c_SKU, '' -- Lot,
                  , '' -- UOM,
                  , 0  -- UOMQty,
                  , @n_PickQty
                  , @c_FromLoc -- FromLoc
                  , @c_ID -- FromID
                  , @c_ToLoc -- ToLoc
                  , @c_ID -- ToID
                  , 'nspLPRTSK2'
                  , @c_LoadKey, '' -- Caseid
                  , @c_Priority -- Priority
                  , '9'
                  , @c_OrderKey -- Orderkey,
                  , '' -- OrderLineNumber
                  , '' -- PickDetailKey
                  , @c_PickMethod
                  , @c_Status
                  , @c_LoadKey
                  , '' --(Vicky02)
                  , @n_PickQty -- (Shong05)
                )

              SELECT @n_err = @@ERROR, @n_cnt=@@ROWCOUNT
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                  CLOSE C_MultiPickTask
                  DEALLOCATE C_MultiPickTask
                  GOTO QUIT_SP
              END

              DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT PickDetailKey
              FROM PICKDETAIL p WITH (NOLOCK)
              WHERE  OrderKey  = @c_OrderKey
              AND    StorerKey = @c_StorerKey
              AND    SKU = @c_SKU
              AND    LOC = @c_FromLoc
              AND    ID  = @c_ID

              OPEN  CUR_UPDATE_PICKDETAIL
              FETCH NEXT FROM CUR_UPDATE_PICKDETAIL INTO @c_PickDetailKey
              WHILE @@FETCH_STATUS <> -1
              BEGIN
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET    TaskDetailKey = @c_TaskDetailKey
                       ,TrafficCop = NULL
                 WHERE PickDetailKey = @c_PickDetailKey

                 SELECT @n_err = @@ERROR, @n_cnt=@@ROWCOUNT
                 IF @n_err<>0 OR @n_cnt = 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                           ,@n_err = 81012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                           ': Update Pick Detail Failed (nspLPRTSK2)'
                           +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                           +' ) '
                     CLOSE CUR_UPDATE_PICKDETAIL
                     DEALLOCATE CUR_UPDATE_PICKDETAIL

                     CLOSE C_MultiPickTask
                     DEALLOCATE C_MultiPickTask

                     GOTO QUIT_SP
                 END

                 -- (james02)
                 IF @c_OrderType = 'ECOM'
                 BEGIN
                    UPDATE TD WITH (ROWLOCK) SET
                       TD.ListKey = 'C&C EComm',
                       TD.TrafficCop = NULL
                    FROM TaskDetail TD
                    JOIN PickDetail PD ON TD.TaskDetailKey = PD.TaskDetailKey
                    JOIN Orders O ON PD.OrderKey = O.OrderKey
                    WHERE PD.PickDetailKey = @c_PickDetailKey
                       AND O.Incoterm = 'CC'
                       AND ISNULL(TD.ListKey, '') = ''    -- prevent update many times

                    IF @n_err<>0
                    BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                              ,@n_err = 81013 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                               ': Update of TaskDetail.ListKey Failed (nspLPRTSK2)'+' ( '
                              +' SQLSvr MESSAGE='+@c_ErrMsg
                              +' ) '
                        GOTO QUIT_SP
                    END
                 END

                 FETCH NEXT FROM CUR_UPDATE_PICKDETAIL INTO @c_PickDetailKey
              END
              CLOSE CUR_UPDATE_PICKDETAIL
              DEALLOCATE CUR_UPDATE_PICKDETAIL

              IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK)
                        WHERE  OrderKey  = @c_OrderKey
                        AND    StorerKey = @c_StorerKey
                        AND    SKU = @c_SKU
                        AND    LOC = @c_FromLoc
                        AND    ID  = @c_ID
                        AND    TaskDetailKey = '')
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81014 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Update Pick Detail Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                  CLOSE C_MultiPickTask
                  DEALLOCATE C_MultiPickTask

                  GOTO QUIT_SP
              END

           END-- Insert into taskdetail Main

           WHILE @@TRANCOUNT > 0
              COMMIT TRAN

            FETCH NEXT FROM C_MultiPickTask INTO @c_OrderKey, @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty,
                            @n_SKUCnt, @n_TotalPick,
                            @c_Userdefine01 --NJOW06
        END -- WHILE 1=1
        CLOSE C_MultiPickTask
        DEALLOCATE C_MultiPickTask
        
       --NJOW06 Start
       BEGIN TRAN
       UPDATE ORDERS WITH (ROWLOCK)
          SET ORDERS.Userdefine01 = O.Userdefine01, 
              ORDERS.TrafficCop = NULL,
              EditWho = SUSER_SNAME(),
              EditDate = GetDate()
       FROM ORDERS 
       JOIN #Orders O ON ORDERS.Orderkey = O.Orderkey
       WHERE ORDERS.Userdefine01 <> O.Userdefine01 
       
       IF @n_err<>0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                 ,@n_err = 81023 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                  ': Update of Orders.Userdefine01 Failed (nspLPRTSK2)'+' ( '
                 +' SQLSvr MESSAGE='+@c_ErrMsg
                 +' ) '
           GOTO QUIT_SP
       END
       --NJOW06 End

       WHILE @@TRANCOUNT > 0
         COMMIT TRAN

       -------------------------------------------------
       -- Piece Pick for Store Order
       -- Group by From loc, ID, SKU and Store
       -------------------------------------------------
       -- Load Balancing
       DECLARE @c_PPAZone NVARCHAR(10),
               @c_PTSZone NVARCHAR(10)

       DECLARE @c_PPAArea       NVARCHAR(10),
               @c_PTSStoreGroup NVARCHAR(20), --NJOW05
               @n_PTSZoneNo     INT

       /*  --NJOW04 Remark 
       IF OBJECT_ID('tempdb..#PTS_Zone') IS NOT NULL
          DROP TABLE #PTS_Zone

       CREATE TABLE #PTS_Zone (
           SeqNo           INT IDENTITY(1,1),
           ConsigneeKey    NVARCHAR(15),
           PPAArea         NVARCHAR(10),
           PTSStoreGroup   NVARCHAR(20))

       INSERT INTO #PTS_Zone (ConsigneeKey, PPAArea, PTSStoreGroup)
       SELECT DISTINCT OD.ConsigneeKey, AD.AreaKey, ''
       FROM  #Orders O
       JOIN ORDERS OD ON OD.OrderKey = O.OrderKey
       JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
       JOIN LOC Loc WITH (NOLOCK) ON LOC.Loc = p.loc   -- (ChewKP04)
       JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = Loc.PutawayZone
       WHERE (o.OrderType = 'STORE')
              AND p.Status = '0' -- (ChewKP03)
              AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' )  -- (ChewKP03)
              AND LOC.LocationType = 'PICK' -- (CheWKP04)

       SET @n_PTSZoneNo = 0
       WHILE 1=1
       BEGIN
          SELECT TOP 1
             @n_PTSZoneNo  = SeqNo,
             @c_PPAArea    = PPAArea,
             @c_ConsigneeKey = ConsigneeKey
          FROM   #PTS_Zone
          WHERE  SeqNo > @n_PTSZoneNo
          AND    PTSStoreGroup = ''
          IF @@ROWCOUNT=0
             BREAK

          SELECT TOP 1 @c_NextStoreGrp = StoreGroup
          FROM   StoreToLocDetail stld WITH (NOLOCK)
          WHERE  StoreGroup > @c_NextStoreGrp
          AND    stld.Status <> '9' --NJOW01
          ORDER BY StoreGroup
          IF @@ROWCOUNT=0
          BEGIN
             SET @c_NextStoreGrp = ''

             SELECT TOP 1 @c_NextStoreGrp = StoreGroup
             FROM   StoreToLocDetail stld WITH (NOLOCK)
             WHERE  StoreGroup > @c_NextStoreGrp
             AND stld.Status <> '9' --NJOW01
             ORDER BY StoreGroup
          END
          IF ISNULL(RTRIM(@c_NextStoreGrp),'') <> ''
          BEGIN
            UPDATE #PTS_Zone
            SET PTSStoreGroup = @c_NextStoreGrp
            WHERE SeqNo = @n_PTSZoneNo
          END
       END
       */
       
       --NJOW04 Start
	     DECLARE @c_TableName NVARCHAR(30)
	        		,@c_ColumnName NVARCHAR(30)
	        		,@c_TableColumnName NVARCHAR(100)
	        		,@c_ColumnType NVARCHAR(10)
	        	  ,@c_SQLDYN NVARCHAR(2000)

       IF OBJECT_ID('tempdb..#PTS_StoreGroup') IS NOT NULL
          DROP TABLE #PTS_StoreGroup

       CREATE TABLE #PTS_StoreGroup (
           SourceField   NVARCHAR(30) NULL,
           PTSStoreGroup   NVARCHAR(20) NULL)  --NJOW05

       SELECT @c_TableColumnName = description 
       FROM CODELKUP (NOLOCK)
       WHERE Listname = 'SOURCEFLD'
       AND Code = 'SOURCE'
       
       IF ISNULL(@c_TableColumnName,'') = ''
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                ,@n_err = 81024 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                 ': Source Field Not Setup. (nspLPRTSK2)'
                +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                +' ) '
          GOTO QUIT_SP
       END
       
       SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)
       SET @c_ColumnName = SUBSTRING(@c_TableColumnName, 
                           CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))

       --IF ISNULL(RTRIM(@c_TableName), '') NOT IN('ORDERS','SKU') 
       IF ISNULL(RTRIM(@c_TableName), '') NOT IN('SKU') 
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                ,@n_err = 81025 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                --'Source Field Only Allow Refer To Orders Or Sku Table. Invalid Table: '+RTRIM(@c_TableColumnName)+ '.(nspLPRTSK2)'
                'Source Field Only Allow Refer To Sku Table. Invalid Table: '+RTRIM(@c_TableColumnName)+ '.(nspLPRTSK2)'
                +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                +' ) '
          GOTO QUIT_SP
       END 
       
       SET @c_ColumnType = ''
       SELECT @c_ColumnType = DATA_TYPE 
       FROM   INFORMATION_SCHEMA.COLUMNS 
       WHERE  TABLE_NAME = @c_TableName
       AND    COLUMN_NAME = @c_ColumnName
     
       IF ISNULL(RTRIM(@c_ColumnType), '') = '' 
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                ,@n_err = 81026 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                'Invalid Source Field Name: '+RTRIM(@c_TableColumnName)+ '.(nspLPRTSK2)'
                +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                +' ) '
          GOTO QUIT_SP
       END
       
       IF @c_TableName = 'SKU'
       BEGIN
       	  SET @c_SQLDYN = 'INSERT INTO #PTS_StoreGroup ' +
       	                  'SELECT DISTINCT p.Sku AS SourceField, CL.Description AS PTSStoreGroup ' +
       	                  'FROM  #Orders O ' +
                          'JOIN ORDERS OD (NOLOCK) ON OD.OrderKey = O.OrderKey ' +
                          'JOIN PICKDETAIL p (NOLOCK) ON O.OrderKey = p.OrderKey ' +
                          'JOIN LOC (NOLOCK) ON LOC.Loc = p.loc ' +
                          'JOIN SKU (NOLOCK) ON p.Storerkey = SKU.Storerkey AND p.Sku = SKU.Sku ' + 
                          'JOIN CODELKUP CL ON ' + RTRIM(@c_TableColumnName) + '= CL.Code AND CL.Listname = ''PTSGROUP'' ' +
                          'WHERE o.OrderType = ''STORE'' ' +
                          'AND p.Status = ''0'' ' +
                          'AND ISNULL(p.TaskDetailKey,'''')='''' ' +
                          'AND LOC.LocationType = ''PICK'' ' 
           EXEC (@c_SQLDYN)       
       END
       
       /*
       IF @c_TableName = 'ORDERS'
       BEGIN
       	  SET @c_SQLDYN = 'INSERT INTO #PTS_StoreGroup ' +
       	                  'SELECT DISTINCT O.Orderkey AS SourceField, CL.Description AS PTSStoreGroup ' +
       	                  'FROM  #Orders O ' +
                          'JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = O.OrderKey ' +
                          'JOIN PICKDETAIL p (NOLOCK) ON O.OrderKey = p.OrderKey ' +
                          'JOIN LOC (NOLOCK) ON LOC.Loc = p.loc ' +
                          'JOIN CODELKUP CL ON ' + RTRIM(@c_TableColumnName) + '= CL.Code AND CL.Listname = ''PTSGROUP'' ' +
                          'WHERE o.OrderType = ''STORE'' ' +
                          'AND p.Status = ''0'' ' +
                          'AND ISNULL(p.TaskDetailKey,'''')='''' ' +
                          'AND LOC.LocationType = ''PICK'' ' 
          EXEC (@c_SQLDYN)       
       END
       */
       
       --NJOW04 End
                   
       DECLARE C_PiecePickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT p.StorerKey, p.SKU, p.LOC, p.ID, SUM(p.Qty), OD.ConsigneeKey
               ,  ISNULL(RTRIM(OD.Route),'')                                                     --(Wan01)
               ,  MAX(OD.Orderkey)   --NJOW02
           FROM  #Orders O
           JOIN ORDERS OD ON OD.OrderKey = O.OrderKey
           JOIN PICKDETAIL p WITH (NOLOCK) ON O.OrderKey = p.OrderKey
           JOIN LOC Loc WITH (NOLOCK) ON LOC.Loc = p.loc   -- (ChewKP04)
           WHERE (o.OrderType = 'STORE')
                  AND p.Status = '0' -- (ChewKP03)
                  AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' )  -- (ChewKP03)
                  AND LOC.LocationType = 'PICK' -- (CheWKP04)
           GROUP BY p.StorerKey, p.SKU, OD.ConsigneeKey, p.LOC, p.ID
                 ,  ISNULL(RTRIM(OD.Route),'')                                                     --(Wan01)

       OPEN C_PiecePickTask

       FETCH NEXT FROM C_PiecePickTask INTO @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty, @c_ConsigneeKey
                                          , @c_Route                                               --(Wan01)
                                          , @c_Orderkey  --NJOW02

       WHILE (@@FETCH_STATUS<>-1)
       BEGIN

          SET @c_PickMethod = 'PIECE'

          SELECT TOP 1
               @c_PPAArea = ad.AreaKey
          FROM LOC l WITH (NOLOCK)
          JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = l.PutawayZone
          WHERE l.LOC = @c_FromLoc

          SET @c_ToLoc   = ''
          SET @c_PTSStoreGroup = ''

          /* NJOW04 Remark
          SELECT @c_PTSStoreGroup = ISNULL(PTSStoreGroup,'')
          FROM  #PTS_Zone PZ
          WHERE PZ.ConsigneeKey = @c_ConsigneeKey
          AND   PZ.PPAArea = @c_PPAArea
          */
          
          --NJOW04 
          IF @c_TableName = 'SKU'
          BEGIN
          	 SELECT TOP 1 @c_PTSStoreGroup = PTSStoreGroup
          	 FROM #PTS_StoreGroup
          	 WHERE SourceField = @c_Sku
          END
          
          /*
          IF @c_TableName = 'ORDERS'
          BEGIN
          	 SELECT TOP 1 @c_PTSStoreGroup = PTSStoreGroup
          	 FROM #PTS_StoreGroup
          	 WHERE SourceField = @c_Orderkey
          END
          */
          --NJOW04 End

          --SELECT @c_ConsigneeKey '@c_ConsigneeKey',  @c_PPAArea '@c_PPAArea', @c_PTSStoreGroup '@c_PTSStoreGroup'

          IF ISNULL(RTRIM(@c_PTSStoreGroup),'') <> ''
          BEGIN
             SET @c_ToLoc = ''
             SELECT TOP 1
                     @c_ToLoc = ISNULL(stld.LOC,'')
             FROM   StoreToLocDetail stld WITH (NOLOCK)
           WHERE  stld.ConsigneeKey = @c_ConsigneeKey
             AND    stld.StoreGroup = @c_PTSStoreGroup
             AND    stld.Status <> '9' --NJOW01
          END

          IF ISNULL(RTRIM(@c_ToLoc),'') = ''
          BEGIN
             SELECT TOP 1
                     @c_ToLoc = ISNULL(stld.LOC,'')
             FROM   StoreToLocDetail stld WITH (NOLOCK)
             WHERE  stld.ConsigneeKey = @c_ConsigneeKey
             AND    stld.Status <> '9' --NJOW01
          END

          -- Insert into taskdetail Main
         EXECUTE nspg_getkey
          'TaskDetailKey',
          10,
          @c_TaskDetailKey OUTPUT,
          @b_Success OUTPUT,
          @n_err OUTPUT,
          @c_ErrMsg OUTPUT
          IF NOT @b_Success=1
          BEGIN
              SELECT @n_continue = 3
              SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                    ,@n_err = 81015 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                     ': Unable to Get TaskDetailKey (nspLPRTSK2)'
                    +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                    +' ) '
              CLOSE C_PiecePickTask
              DEALLOCATE C_PiecePickTask

              GOTO QUIT_SP

          END
          ELSE
          BEGIN
              SET @c_AreaKey=''
              SELECT @c_AreaKey = ISNULL(ad.AreaKey,'')
              FROM AreaDetail ad WITH (NOLOCK)
              JOIN LOC l WITH (NOLOCK) ON l.PutawayZone = ad.PutawayZone
              WHERE l.Loc = @c_FromLoc

               --(Kc01) - Start
               SET @b_success = 0

               EXECUTE nspGetRight null,     -- facility
                  @c_StorerKey,              -- Storerkey
                  null,                      -- Sku
                  'SplitPickTaskByStore',    -- Configkey
                  @b_success    output,
                  @c_authority  output,
                  @n_err        output,
                  @c_errmsg     output

               IF @c_authority = '1' AND @b_success = 1
               BEGIN
                  SET @c_TaskType = 'SPK'
               END
               ELSE
               BEGIN
                  SET @c_TaskType = 'PK'
                  SET @c_Orderkey = '' --NJOW02
               END
               --(Kc01) - End

              BEGIN TRAN
              INSERT TASKDETAIL
                (
                  TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
                  UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
                  SourceKey, Caseid, Priority, SourcePriority, OrderKey,
                  OrderLineNumber, PickDetailKey, PickMethod, STATUS,
                  LoadKey, AreaKey, Message01, SystemQty, StatusMsg                                --(Wan01)  
                )
              VALUES
                (
                  @c_TaskDetailKey, @c_TaskType, @c_Storerkey, @c_SKU, '' -- Lot,              --(Kc01)
                  , '' -- UOM,
                  , 0  -- UOMQty,
                  , @n_PickQty
                  , @c_FromLoc -- FromLoc
                  , @c_ID    -- FromID
                  , @c_ToLoc -- ToLoc
                  , @c_ID    -- ToID
                  , 'nspLPRTSK2'
                  , @c_LoadKey, '' -- Caseid
                  , @c_Priority    -- Priority
                  , '9'
                  , @c_Orderkey -- Orderkey,  --NJOW02
                  , '' -- OrderLineNumber
                  , '' -- PickDetailKey
                  , @c_PickMethod
                  , @c_Status
                  , @c_LoadKey
                  , '' --(Vicky02)
                  --, @c_AreaKey
                  , @c_ConsigneeKey
                  , @n_PickQty -- (Shong05)
                  , @c_Route                                                                       --(Wan01)
                )

              SELECT @n_err = @@ERROR
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81016 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                  CLOSE C_PiecePickTask
                  DEALLOCATE C_PiecePickTask

                  GOTO QUIT_SP
              END
              -- Update the Pickdetail TaskDetailKey

              DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                 SELECT p.PickDetailKey
                 FROM  #Orders O
                 JOIN ORDERS OD  WITH (NOLOCK, INDEX(PKOrders)) ON OD.OrderKey = O.OrderKey
                 JOIN PICKDETAIL p WITH (NOLOCK, INDEX(PICKDETAIL10)) ON O.OrderKey = p.OrderKey
                 WHERE p.STATUS = '0'
                   AND (p.TaskDetailKey IS NULL OR p.TaskDetailKey = '') -- (Shong01)
                   AND p.Storerkey = @c_StorerKey
                   AND p.Sku = @c_SKU
                   AND p.LOC = @c_FromLoc
                   AND p.ID = @c_ID
                   AND (o.OrderType = 'STORE')
                   AND OD.ConsigneeKey = @c_ConsigneeKey
                   AND OD.LoadKey = @c_LoadKey
                 --  ORDER BY p.PickDetailKey
                 -- commented out 5/11/2010 MCF  performance
              OPEN CUR_PICKDETAILKEY
              FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey

              WHILE @@FETCH_STATUS<>-1
              BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET    TaskDetailKey = @c_TaskDetailKey
                        ,TrafficCop = NULL
                  WHERE  PickDetailKey = @c_PickDetailKey
                 IF @@ERROR<>0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                           ,@n_err = 81017 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                            ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                           +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                           +' ) '
                     CLOSE CUR_PICKDETAILKEY
                     DEALLOCATE CUR_PICKDETAILKEY
                     CLOSE C_PiecePickTask
                     DEALLOCATE C_PiecePickTask

                     GOTO QUIT_SP
                 END

                  FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey
              END
              CLOSE CUR_PICKDETAILKEY
              DEALLOCATE CUR_PICKDETAILKEY
           END-- Insert into taskdetail Main

           WHILE @@TRANCOUNT > 0
              COMMIT TRAN

           FETCH NEXT FROM C_PiecePickTask INTO @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty, @c_ConsigneeKey
                                              , @c_Route                                           --(Wan01)
                                              , @c_Orderkey --NJOW02

        END -- WHILE 1=1
        CLOSE C_PiecePickTask
        DEALLOCATE C_PiecePickTask

       IF OBJECT_ID('tempdb..#ORDERs') IS NOT NULL
         DROP TABLE #ORDERs

       WHILE @@TRANCOUNT > 0
         COMMIT TRAN

       BEGIN TRAN

       -------------------------------------------------
       -- Store Bulk Pick - Group By Location
       -- Generate Replenishment Task Only
       -------------------------------------------------
       -- Split Store Load Balancing
       /* NJOW04 Remark
       IF OBJECT_ID('tempdb..#StoreGrpAssign') IS NOT NULL
         DROP TABLE #StoreGrpAssign

       CREATE TABLE #StoreGrpAssign (
          SeqNo      INT IDENTITY(1,1),
          SKU        NVARCHAR(20),
          StoreGroup NVARCHAR(10),)

       INSERT INTO #StoreGrpAssign (SKU, StoreGroup)
       SELECT DISTINCT bp.SKU, ''
       FROM #BulkPick bp
       ORDER BY bp.SKU

       SET @n_SGANo = 0
       WHILE 1=1
       BEGIN
          SELECT TOP 1
             @n_SGANo = SeqNo,
             @c_SKU   = SKU
          FROM   #StoreGrpAssign
          WHERE  SeqNo > @n_SGANo
          AND   StoreGroup = ''
          IF @@ROWCOUNT=0
             BREAK

          SELECT TOP 1 @c_NextStoreGrp = StoreGroup
          FROM   StoreToLocDetail stld WITH (NOLOCK)
          WHERE  StoreGroup > @c_NextStoreGrp
          AND    stld.Status <> '9' --NJOW01
          ORDER BY StoreGroup
          IF @@ROWCOUNT=0
          BEGIN
             SET @c_NextStoreGrp = ''

             SELECT TOP 1 @c_NextStoreGrp = StoreGroup
             FROM   StoreToLocDetail stld WITH (NOLOCK)
             WHERE  StoreGroup > @c_NextStoreGrp
             AND    stld.Status <> '9' --NJOW01
             ORDER BY StoreGroup
          END
          IF ISNULL(RTRIM(@c_NextStoreGrp),'') <> ''
          BEGIN
            UPDATE #StoreGrpAssign
            SET StoreGroup = @c_NextStoreGrp
            WHERE SeqNo = @n_SGANo
          END
       END
       */
       
       --NJOW04 Start
       IF OBJECT_ID('tempdb..#PTS_StoreGroup') IS NOT NULL
          DELETE #PTS_StoreGroup
       
       IF @c_TableName = 'SKU'
       BEGIN
       	  SET @c_SQLDYN = 'INSERT INTO #PTS_StoreGroup ' +
       	                  'SELECT DISTINCT bp.Sku AS SourceField, CL.Description AS PTSStoreGroup ' +
       	                  'FROM #BulkPick bp ' +
                          'JOIN SKU (NOLOCK) ON bp.Storerkey = SKU.Storerkey AND bp.Sku = SKU.Sku ' + 
                          'JOIN CODELKUP CL ON ' + RTRIM(@c_TableColumnName) + '= CL.Code AND CL.Listname = ''PTSGROUP'' ' 

          EXEC (@c_SQLDYN)       
       END
       --NJOW04 End

       DECLARE CUR_SplitStoreLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT SKU, ConsigneeKey
       FROM   #BulkPick
       ORDER BY SKU, ConsigneeKey

       OPEN CUR_SplitStoreLoc

       FETCH NEXT FROM CUR_SplitStoreLoc INTO @c_SKU, @c_ConsigneeKey
       WHILE @@FETCH_STATUS <> -1
       BEGIN

          SET @c_PnDLocation = ''

          /* NJOW04 Remark
          SELECT TOP 1
               @c_PnDLocation = Stld.LOC
          FROM StoreToLocDetail stld WITH (NOLOCK)
          JOIN #StoreGrpAssign SGA ON SGA.SKU = @c_SKU
          WHERE stld.ConsigneeKey = @c_ConsigneeKey
          AND   stld.StoreGroup = SGA.StoreGroup
          AND   stld.Status <> '9' --NJOW01
          */
          
          --NJOW04 
          IF @c_TableName = 'SKU'
          BEGIN
          	 SELECT TOP 1 @c_PTSStoreGroup = PTSStoreGroup
          	 FROM #PTS_StoreGroup
          	 WHERE SourceField = @c_Sku
          END

          IF ISNULL(RTRIM(@c_PTSStoreGroup),'') <> ''
          BEGIN
             SET @c_PnDLocation = ''
             SELECT TOP 1
                     @c_PnDLocation = ISNULL(stld.LOC,'')
             FROM   StoreToLocDetail stld WITH (NOLOCK)
             WHERE  stld.ConsigneeKey = @c_ConsigneeKey
             AND    stld.StoreGroup = @c_PTSStoreGroup
             AND    stld.Status <> '9' --NJOW01
          END

          -- if Location For the Consignee Not Found in StoreGroup, Just get any loc from StoreToLoc
          IF ISNULL(RTRIM(@c_PnDLocation),'') = ''
          BEGIN
             SELECT TOP 1
                  @c_PnDLocation = Stld.LOC
             FROM StoreToLocDetail stld WITH (NOLOCK)
             WHERE stld.ConsigneeKey = @c_ConsigneeKey
             AND stld.Status <> '9' --NJOW01
          END
   --          select @c_CurrPutawayZone '@c_CurrPutawayZone', @c_PnDLocation'@c_PnDLocation',
   --          @c_ConsigneeKey'@c_ConsigneeKey', @c_SKU '@c_SKU'

          IF ISNULL(RTRIM(@c_PnDLocation),'') <> ''
          BEGIN
             UPDATE #BulkPick
               SET StoreLoc = @c_PnDLocation
             WHERE ConsigneeKey = @c_ConsigneeKey
             AND   SKU = @c_SKU
          END

          FETCH NEXT FROM CUR_SplitStoreLoc INTO @c_SKU, @c_ConsigneeKey
       END
       CLOSE CUR_SplitStoreLoc
       DEALLOCATE CUR_SplitStoreLoc

       -- Step 1: Consolidate Pick Task By SKU & LOC
       DECLARE C_BulkPickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT StorerKey, SKU, LOC, ID, SUM(Qty)
             FROM #BulkPick
           WHERE StoreLoc IS NOT NULL
           GROUP BY StorerKey, sku, loc, ID
           ORDER BY StorerKey, sku, loc, ID

       OPEN C_BulkPickTask

       FETCH NEXT FROM C_BulkPickTask INTO @c_StorerKey, @c_SKU, @c_FromLoc, @c_id, @n_PickQty

       WHILE (@@FETCH_STATUS<>-1)
       BEGIN
          -- Insert into taskdetail Main
          EXECUTE nspg_getkey
          'TaskDetailKey',
          10,
          @c_TaskDetailKey OUTPUT,
          @b_Success OUTPUT,
          @n_err OUTPUT,
          @c_ErrMsg OUTPUT
          IF NOT @b_Success=1
          BEGIN
              SELECT @n_continue = 3
              SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                    ,@n_err = 81018 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                     ': Unable to Get TaskDetailKey (nspLPRTSK2)'
                    +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                    +' ) '
              CLOSE C_BulkPickTask
              DEALLOCATE C_BulkPickTask
              GOTO QUIT_SP

          END
          ELSE
          BEGIN
             SET @c_AreaKey=''

             SELECT @c_AreaKey = ISNULL(ad.AreaKey,'')
             FROM AreaDetail ad WITH (NOLOCK)
             JOIN LOC l WITH (NOLOCK) ON l.PutawayZone = ad.PutawayZone
             WHERE l.Loc = @c_FromLoc

             SET @c_ToLoc = ''
             SELECT @c_ToLoc = ISNULL(SHORT,'')
             FROM   CODELKUP c WITH (NOLOCK)
             WHERE  c.LISTNAME = 'WCSROUTE'
             AND    c.Code = 'CASE'




             BEGIN TRAN

              INSERT TASKDETAIL
                (
                  TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
                  UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
                  SourceKey, Caseid, Priority, SourcePriority, OrderKey,
                  OrderLineNumber, PickDetailKey, PickMethod, STATUS,
                  LoadKey, AreaKey, SystemQty
                )
              VALUES
                (
                  @c_TaskDetailKey, 'DPK', @c_Storerkey, @c_SKU
                  , '' -- Lot,
                  , '' -- UOM,
                  , 0  -- UOMQty,
                  , @n_PickQty
                  , @c_FromLoc -- FromLoc
                  , @c_ID      -- FromID
                  , @c_ToLoc   -- ToLoc
                  , ''         -- ToID
                  , 'nspLPRTSK2'
                  , @c_LoadKey
                  , ''             -- Caseid
                  , @c_Priority    -- Priority
                  , '9'
                  , '' -- Orderkey,
                  , '' -- OrderLineNumber
                  , '' -- PickDetailKey
                  , 'CASE' -- PickMethod
                  , @c_Status
                  , @c_LoadKey
                  , '' --(Vicky02)
                  , @n_PickQty
                )

              SELECT @n_err = @@ERROR
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81019 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                 CLOSE C_BulkPickTask
                 DEALLOCATE C_BulkPickTask

                 GOTO QUIT_SP
              END
           END

           -- Step 2: Swap the Bulk Picking with Store Location
           DECLARE C_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT BP.PickDetailKey, BP.LOT, BP.StoreLoc, BP.Qty
           FROM #BulkPick BP
           JOIN LOC WITH (NOLOCK) ON LOC.LOC = BP.StoreLoc -- (Shong06)
           WHERE BP.StoreLoc IS NOT NULL
           AND   BP.StorerKey = @c_StorerKey
           AND   BP.SKU = @c_SKU
           AND   BP.LOC = @c_FromLoc
           AND   BP.ID  = @c_ID
           ORDER BY LOC.PutAwayZone, BP.StoreLoc, BP.ConsigneeKey -- (Shong06)

           OPEN C_PickDetail

           FETCH NEXT FROM C_PickDetail INTO @c_PickDetailKey, @c_LOT, @c_ToLoc, @n_Qty

           WHILE @@FETCH_STATUS <> -1
           BEGIN
              -- TO ID Should be BLANK, The Put To Store Location Must Set to LoseID
              IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_LOT AND LOC = @c_ToLoc AND ID = '')
              BEGIN
                 INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey, Sku, Qty,
                             PendingMoveIN)
                 VALUES ( @c_LOT, @c_ToLoc, '', @c_StorerKey, @c_SKU, 0, 0)
                SELECT @n_err = @@ERROR
                 IF @n_err<>0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                           ,@n_err = 81020 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                            ': Insert Into LOTxLOCxID Failed (nspLPRTSK2)'
                           +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                           +' ) '
               CLOSE C_PickDetail
                     DEALLOCATE C_PickDetail
                     GOTO QUIT_SP
                 END
              END
              IF NOT EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                            WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU AND LOC = @c_ToLoc)
              BEGIN
                 INSERT INTO SKUxLOC (StorerKey, Sku, LOC, Qty)
                 VALUES ( @c_StorerKey, @c_SKU, @c_ToLoc, 0)
                 SELECT @n_err = @@ERROR
                 IF @n_err<>0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                           ,@n_err = 81021 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                            ': Insert Into SKUxLOC Failed (nspLPRTSK2)'
                          +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                           +' ) '
                     CLOSE C_PickDetail
                     DEALLOCATE C_PickDetail

                     GOTO QUIT_SP
                 END
              END

              UPDATE PICKDETAIL WITH (ROWLOCK)
              SET    TaskDetailKey = @c_TaskDetailKey
                    ,Loc = @c_ToLoc
                    ,ToLOC = @c_FromLoc
                    ,ID = ''
              WHERE  PickDetailKey = @c_PickDetailKey
              SELECT @n_err = @@ERROR
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81022 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Update Pick Detail Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                  CLOSE C_PickDetail
                  DEALLOCATE C_PickDetail

                  GOTO QUIT_SP
              END

              UPDATE LOTxLOCxID with (RowLock)
               SET QtyReplen = ISNULL(QtyReplen,0) + @n_Qty
              WHERE Lot = @c_LOT
              AND   LOC = @c_FromLoc
              AND   ID  = @c_ID

              SELECT @n_err = @@ERROR
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81023 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Update LOTxLOCxID Failed (nspLPRTSK2)'
                        +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
                  CLOSE C_PickDetail
                  DEALLOCATE C_PickDetail

                  GOTO QUIT_SP
              END

              FETCH NEXT FROM C_PickDetail INTO @c_PickDetailKey, @c_LOT, @c_ToLoc, @n_Qty
           END
           CLOSE C_PickDetail
           DEALLOCATE C_PickDetail

           WHILE @@TRANCOUNT > 0
              COMMIT TRAN

           FETCH NEXT FROM C_BulkPickTask INTO @c_StorerKey, @c_SKU, @c_FromLoc, @c_ID, @n_PickQty
        END -- WHILE 1=1
        CLOSE C_BulkPickTask
        DEALLOCATE C_BulkPickTask
       -- End Store Bulk Pick

       WHILE @@TRANCOUNT > 0
         COMMIT TRAN

       IF OBJECT_ID('tempdb..#BulkPick') IS NOT NULL
         DROP TABLE #BulkPick

       -------------------------------------------------
       -- Scan Pick Location For Replenishment Task
       -- Generate Force Replenishment Task
       -------------------------------------------------

      -- SOS# 223156 (Start)
      INSERT INTO [dbo].[Temp_ReplenTrace]
                  ( [LoadKey]
                  , [AddDate]
                  , [StorerKey]
                  , [SKU]
                  , [LOC]
                  , [Qty]
                  , [PATaskQty]
                  , [QtyAllocated]
                  , [QtyPicked]
                  , [QtyLocationLimit]
                  , [QtyLocationMinimum]
                  , [LocationType]
                  , [AddWho]
                  , [AlertStatus] )
      SELECT @c_LoadKey, GETDATE(), SL.StorerKey, SL.SKU, SL.LOC
           , SL.Qty, ISNULL(PA_TASK.Qty, 0), SL.QtyAllocated, SL.QtyPicked
           , SL.QtyLocationLimit, SL.QtyLocationMinimum, SL.LocationType
           , SUSER_SNAME(), '5'
      FROM   SKUxLOC SL WITH (NOLOCK)
      JOIN   LOC WITH (NOLOCK) ON LOC.Loc = SL.Loc
      JOIN   ( SELECT DISTINCT StorerKey, SKU, FromLoc AS LOC
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  LoadKey = @c_LoadKey
               AND    STATUS < '9'
               AND    TaskDetail.TaskType in ('PK', 'SPK') ) AS PickLOC
               ON PickLOC.StorerKey = SL.StorerKey
               AND PickLOC.Sku = SL.Sku
               AND PickLOC.Loc = SL.Loc
      LEFT OUTER JOIN
             ( SELECT StorerKey, SKU, ToLoc AS LOC, SUM(Qty) AS Qty
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  STATUS < '9'
               AND    TaskDetail.TaskType IN ('PA','DRP')
               GROUP BY StorerKey, SKU, ToLoc) AS PA_TASK
               ON PA_TASK.StorerKey = SL.StorerKey
               AND PA_TASK.Sku = SL.Sku
               AND PA_TASK.LOC = SL.LOC
      --WHERE (SL.Qty  + ISNULL(PA_TASK.Qty, 0)) - (SL.QtyAllocated + SL.QtyPicked) < SL.QtyLocationMinimum
      --AND  SL.LocationType IN ('PICK', 'CASE')
      -- SOS# 223156 (End)

       DECLARE Cursor_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT sl.StorerKey, sl.SKU, sl.LOC,
              sl.QtyLocationLimit - ((sl.Qty  + ISNULL(PA_TASK.Qty, 0)) - (sl.QtyAllocated + sl.QtyPicked)),
              LOC.Facility, ReplenishmentPriority -- (SHONG07)
       FROM   SKUxLOC sl WITH (NOLOCK)
       JOIN   LOC WITH (NOLOCK) ON LOC.Loc = sl.Loc
       JOIN   (SELECT DISTINCT StorerKey, SKU, FromLoc AS LOC
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  LoadKey = @c_LoadKey
               AND    STATUS < '9'
               AND    TaskDetail.TaskType in ('PK', 'SPK') ) AS PickLOC               --(Kc01)
               ON PickLOC.StorerKey = sl.StorerKey
                  AND PickLOC.Sku = sl.Sku
                  AND PickLOC.Loc = sl.Loc
       LEFT OUTER JOIN
              (SELECT StorerKey, SKU, ToLoc AS LOC, SUM(Qty) AS Qty
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  STATUS < '9'
               AND    TaskDetail.TaskType IN ('PA','DRP')
               GROUP BY StorerKey, SKU, ToLoc) AS PA_TASK
               ON PA_TASK.StorerKey = sl.StorerKey
                  AND PA_TASK.Sku = sl.Sku
                  AND PA_TASK.LOC = sl.LOC
       WHERE (sl.Qty  + ISNULL(PA_TASK.Qty, 0)) - (sl.QtyAllocated + sl.QtyPicked) < sl.QtyLocationMinimum
       AND  sl.LocationType IN ('PICK', 'CASE')


       OPEN Cursor_Replenishment

       FETCH NEXT FROM Cursor_Replenishment INTO @c_StorerKey, @c_SKU, @c_ToLOC, @n_ReplenQty, @c_Facility, @c_ReplenPriority
       WHILE @@FETCH_STATUS <> -1
       BEGIN
           -- (ChewKP01) Start
           -- Get Putawayzone
          SET @c_Putawayzone = ''

          SELECT @c_Putawayzone = Putawayzone FROM LOC WITH (NOLOCK)
          WHERE LOC = @c_ToLOC

            -- (james01)
--          IF NOT EXISTS ( SELECT 1 FROM TaskDetail TD WITH (NOLOCK)
--                          INNER JOIN LOC LOC WITH (NOLOCK) ON (LOC.LOC = TD.ToLOC )
--                          WHERE TD.Status IN ( '0','3')
--                            AND TD.TaskType = 'DRP'
--                            AND Putawayzone = @c_Putawayzone
--                           )
            BEGIN
                -- Find Available Qty FROM Bulk
                DECLARE CUR_AvailableQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT lli.LOT, lli.LOC, lli.Id,
                       (lli.Qty - lli.QtyAllocated - lli.QtyPicked - CASE WHEN lli.QtyReplen > 0 THEN lli.QtyReplen ELSE 0 END) -- (Shong03)
                FROM   LOTxLOCxID lli WITH (NOLOCK)
                JOIN   SKUxLOC sl WITH (NOLOCK) ON sl.StorerKey = lli.StorerKey AND sl.Sku = lli.Sku AND sl.Loc = lli.Loc
                JOIN   LOC WITH (NOLOCK) ON LOC.Loc = lli.Loc
                JOIN   ID WITH (NOLOCK) ON ID.ID = lli.Id AND ID.[Status] = 'OK'
                JOIN   LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.[Status] = 'OK'
                WHERE  lli.StorerKey = @c_StorerKey
                AND    lli.Sku = @c_SKU
                AND    sl.LocationType NOT IN ('PICK', 'CASE')
                AND    LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','PICK') -- (Shong04)
                AND    LOC.[Status] = 'OK'
                AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
                AND    (lli.Qty - lli.QtyAllocated - lli.QtyPicked - CASE WHEN lli.QtyReplen > 0 THEN lli.QtyReplen ELSE 0 END) > 0 --(Shong03)

                OPEN CUR_AvailableQty

                FETCH NEXT FROM CUR_AvailableQty INTO @c_LOT, @c_FromLoc, @c_ID, @n_Qty
                WHILE @@FETCH_STATUS <> -1
                BEGIN
                   IF @n_Qty > @n_ReplenQty
                      SET @n_Qty = @n_ReplenQty

                   -- Insert Replen Task here
                   EXECUTE nspg_getkey
                   'TaskDetailKey',
                   10,
                   @c_TaskDetailKey OUTPUT,
                   @b_Success OUTPUT,
                   @n_err OUTPUT,
                   @c_ErrMsg OUTPUT
                   IF NOT @b_Success=1
                   BEGIN
                    SELECT @n_continue = 3
                       SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                             ,@n_err = 81024 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                       SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                              ': Unable to Get TaskDetailKey (nspLPRTSK2)'
                             +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                             +' ) '
                      CLOSE CUR_AvailableQty
                      DEALLOCATE CUR_AvailableQty
                      GOTO QUIT_SP
                   END
                   ELSE
                   BEGIN
                      SET @c_AreaKey=''

                      SELECT @c_AreaKey = ISNULL(ad.AreaKey,'')
                      FROM AreaDetail ad WITH (NOLOCK)
                      JOIN LOC l WITH (NOLOCK) ON l.PutawayZone = ad.PutawayZone
                      WHERE l.Loc = @c_FromLoc

                      BEGIN TRAN

                       INSERT TASKDETAIL
                         (
                           TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
                           UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
                           SourceKey, Caseid, Priority, SourcePriority, OrderKey,
                           OrderLineNumber, PickDetailKey, PickMethod, STATUS,
                           LoadKey, AreaKey, SystemQty
                            )
                          VALUES
                            (
                              @c_TaskDetailKey, 'DRP'
                              , @c_Storerkey
                              , @c_SKU
                              , @c_LOT -- Lot,
                              , ''     -- UOM,
                              , 0      -- UOMQty,
                              , @n_Qty
                              , @c_FromLoc -- FromLoc
                              , @c_ID      -- FromID
                              , @c_ToLoc   -- ToLoc
                              , ''         -- ToID
                              , 'nspLPRTSK2'
                              , @c_LoadKey
                          , ''             -- Caseid
                              , @c_ReplenPriority    -- Priority
                              , '9'
                              , '' -- Orderkey,
                              , '' -- OrderLineNumber
                              , '' -- PickDetailKey
                              , 'CASE' -- PickMethod
                              , @c_Status
                              , @c_LoadKey
                              , '' --(Vicky02)
                              , @n_Qty -- (Shong05)
                          )

                       SELECT @n_err = @@ERROR
                       IF @n_err<>0
                       BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                                 ,@n_err = 81025 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                                  ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                                 +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                                 +' ) '

                          CLOSE CUR_AvailableQty
                          DEALLOCATE CUR_AvailableQty
                          GOTO QUIT_SP
                      END
                   END

                 UPDATE LOTxLOCxID WITH (ROWLOCK)
                 SET QtyReplen = QtyReplen + @n_Qty
                 WHERE LOT = @c_Lot
                 AND   LOC = @c_FromLoc
                 AND   ID  = @c_ID

                 SELECT @n_err = @@ERROR
                 IF @n_err<>0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                           ,@n_err = 81026 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                            ': Insert Into TaskDetail Failed (nspLPRTSK2)'
                           +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                           +' ) '

                    CLOSE CUR_AvailableQty
                    DEALLOCATE CUR_AvailableQty
                    GOTO QUIT_SP
                 END

                 SET @n_ReplenQty = @n_ReplenQty - @n_Qty

                   IF @n_ReplenQty <= 0 -- SOS# 218370
                      BREAK

                   FETCH NEXT FROM CUR_AvailableQty INTO @c_LOT, @c_FromLoc, @c_ID, @n_Qty
                END
                CLOSE CUR_AvailableQty
                DEALLOCATE CUR_AvailableQty
            END -- (ChewKP01) End

           WHILE @@TRANCOUNT > 0
              COMMIT TRAN

          FETCH NEXT FROM Cursor_Replenishment INTO @c_StorerKey, @c_SKU, @c_ToLOC, @n_ReplenQty, @c_Facility, @c_ReplenPriority
       END
       CLOSE Cursor_Replenishment
       DEALLOCATE Cursor_Replenishment

       -- Added by SHong on 02-Aug-2011
       -- To track replen task not ganerated Issues
       INSERT INTO [dbo].[Temp_ReplenTrace]
           ([LoadKey]
           ,[AddDate]
           ,[StorerKey]
           ,[SKU]
           ,[LOC]
           ,[Qty]
           ,[PATaskQty]
           ,[QtyAllocated]
           ,[QtyPicked]
           ,[AddWho])
       SELECT @c_LoadKey, GetDate(), sl.StorerKey, sl.SKU, sl.LOC,
       sl.Qty, ISNULL(PA_TASK.Qty, 0) AS PATaskQty, sl.QtyAllocated, sl.QtyPicked, sUser_sName()
       FROM   SKUxLOC sl WITH (NOLOCK)
       JOIN   LOC WITH (NOLOCK) ON LOC.Loc = sl.Loc
       JOIN   (SELECT DISTINCT StorerKey, SKU, FromLoc AS LOC
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  LoadKey = @c_LoadKey
               AND    STATUS < '9'
               AND    TaskDetail.TaskType in ('PK', 'SPK') ) AS PickLOC
               ON PickLOC.StorerKey = sl.StorerKey
                  AND PickLOC.Sku = sl.Sku
                  AND PickLOC.Loc = sl.Loc
       LEFT OUTER JOIN
              (SELECT StorerKey, SKU, ToLoc AS LOC, SUM(Qty) AS Qty
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  STATUS < '9'
               AND    TaskDetail.TaskType IN ('PA','DRP')
               GROUP BY StorerKey, SKU, ToLoc) AS PA_TASK
               ON PA_TASK.StorerKey = sl.StorerKey
                  AND PA_TASK.Sku = sl.Sku
                  AND PA_TASK.LOC = sl.LOC
       WHERE (sl.Qty  + ISNULL(PA_TASK.Qty, 0)) - (sl.QtyAllocated + sl.QtyPicked) < sl.QtyLocationMinimum
       AND  sl.LocationType IN ('PICK', 'CASE')
    END

    Quit_SP:
    IF @n_continue=3
    BEGIN
        IF @@TRANCOUNT>@n_StartTranCnt
            ROLLBACK TRAN

        /*  --NJOW07	
        EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'nspLPRTSK2'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

        BEGIN TRAN  
         
        UPDATE LoadPlan WITH (ROWLOCK)
        SET    PROCESSFLAG = @c_ProcessFlag
        WHERE  LoadKey = @c_LoadKey        

        SELECT @n_err = @@ERROR
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81027 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Update of LoadPlan Failed (nspLPRTSK2)'+' ( '
                  +' SQLSvr MESSAGE='+@c_ErrMsg
                  +' ) '
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@n_StartTranCnt
                  COMMIT TRAN
        END
        */
    END
    ELSE
    BEGIN
       WHILE @@TRANCOUNT > 0
         COMMIT TRAN

       WHILE @@TRANCOUNT < @n_StartTranCnt
       BEGIN TRAN

      IF @b_mydebug = 9
      BEGIN
         select @c_col3 = MIN(TYPE),
                @c_col5 = MIN(STORERKEY)
           from orders (nolock)
         where LOADkey = @c_LoadKey;

         SET @d_EndTime = GETDATE()

         INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], TotalTime, Step1,
                  Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         VALUES
         (RTRIM(@c_myTraceName),@d_StartTime, @d_EndTime
         ,CONVERT(NVARCHAR(12),@d_EndTime - @d_StartTime ,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep1,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep2,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep3,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep4,114)
         ,CONVERT(NVARCHAR(12),@d_SubStep5,114)
         ,'END' -- Col1
         ,@c_LoadKey
         ,@c_col3
         ,@c_col4
         ,@c_col5)
      END
        /* --NJOW07
        UPDATE LoadPlan WITH (ROWLOCK)
        SET    PROCESSFLAG = 'Y'
        WHERE  LoadKey = @c_LoadKey        

        SELECT @n_err = @@ERROR
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81028 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Update of LoadPlan Failed (nspLPRTSK2)'+' ( '
                  +' SQLSvr MESSAGE='+@c_ErrMsg
                  +' ) '
        END
        ELSE
        BEGIN
        */
            WHILE @@TRANCOUNT>@n_StartTranCnt
                  COMMIT TRAN
        --END        
    END
END

GO