SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTMTM05_LV                                       */
/* Creation Date:                                                       */
/* Copyright: Maersk                                                    */
/* Customer:  Grainte LEVIS                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Ver.   Author     Purposes                              */
/* 2025-03-03   1.0.0  Dennis     UWP-30476 Custom Logic,base on nspTMT01*/
/************************************************************************/
CREATE    PROC    [RDT].[nspTMTM05_LV]
               @c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(18)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(5)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_ttm              NVARCHAR(5)
,              @c_AreaKey01        NVARCHAR(10)    OUTPUT -- (james04)
,              @c_AreaKey02        NVARCHAR(10)
,              @c_AreaKey03        NVARCHAR(10)
,              @c_AreaKey04        NVARCHAR(10)
,              @c_AreaKey05        NVARCHAR(10)
,              @c_LastLOC          NVARCHAR(10)
,              @c_LastTaskType     NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          INT        OUTPUT
,              @n_err              INT        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
,              @c_TaskDetailKey    NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @c_TTMTaskType      NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @c_RefKey01         NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @c_RefKey02         NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @c_RefKey03         NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @c_RefKey04         NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @c_RefKey05         NVARCHAR(20)   OUTPUT -- (Vicky01)
,              @n_Mobile           INT = 0               -- (james04)
,              @n_Func             INT = 0               -- (james04)
,              @c_StorerKey        NVARCHAR( 15) = ''    -- (james04)

AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_debug INT
    SELECT @b_debug = 0

    IF @c_ptcid = '1'
    BEGIN
       SET @b_debug = 1
    END
    
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   /***********************************************************************************************
                                             Standard
   ***********************************************************************************************/
    DECLARE @n_continue       INT
           ,@n_starttcnt      INT -- Holds the current transaction count
           ,@n_cnt            INT -- Holds @@ROWCOUNT after certain operations
           ,@n_err2           INT -- For Additional Error Detection

    DECLARE @c_retrec         NVARCHAR(2) -- Return Record '01' = Success, '09' = Failure

    DECLARE @n_cqty           INT
           ,@n_returnrecs     INT
           ,@c_LastAisle      NVARCHAR(10)

    DECLARE @c_MinPriority    NVARCHAR(10)
           ,@c_OtherPriority  NVARCHAR(10)
           ,@c_OtherTaskType  NVARCHAR(10)
           ,@c_NextTaskType   NVARCHAR(10)
           ,@c_DefaultAreaKey NVARCHAR(10)
           ,@c_UserName       NVARCHAR(18)


    SELECT @n_starttcnt = @@TRANCOUNT
          ,@n_continue = 1
          ,@b_success = 0
          ,@n_err = 0
          ,@c_errmsg = ''
          ,@n_err2 = 0

    SELECT @c_retrec = '01'
    SELECT @n_returnrecs = 1

    DECLARE @c_Strategykey               NVARCHAR(10)
           ,@c_ttmStrategykey            NVARCHAR(10)
           ,@c_InterLeaveTasks           NVARCHAR(10)

    DECLARE @c_CurrentLineNumber         NVARCHAR(5)
            --@c_TTMTaskType       NVARCHAR(10),
           ,@c_ttmpickcode        NVARCHAR(10)
           ,@c_ttmoverride               NVARCHAR(10)

    DECLARE @c_TaskTypeoverride          NVARCHAR(10)
           ,@n_TablePasses               INT
           ,@c_MaxTTMStrategyLineNumber  NVARCHAR(5)

    SELECT @c_CurrentLineNumber = SPACE(5)
          ,@c_TaskTypeoverride = ''
          ,@n_TablePasses = 0

    DECLARE @c_la   NVARCHAR(10)
           ,@nCnt   INT
           ,@nCnt1  INT
           ,@nCnt2  INT

    DECLARE @c_ContinueTask   NVARCHAR( 1)

    -- (james06)
    SET @c_ContinueTask = rdt.RDTGetConfig( @n_Func, 'ContinueALLTaskWithinAisle', @c_StorerKey)

    SET @nCnt = 0
    SET @nCnt1 = 0
    SET @nCnt2 = 0


    -- (Vicky01) - Start
    DECLARE @c_fromloc  NVARCHAR(10)
           ,@c_toid     NVARCHAR(18) -- (Vicky02)

    SET @c_fromloc = ''
    SET @c_RefKey01 = ''
    SET @c_RefKey02 = ''
    SET @c_RefKey03 = ''
    SET @c_RefKey04 = ''
    SET @c_RefKey05 = ''
    SET @c_TaskDetailKey = ''
    SET @c_toid = '' -- (Vicky02)
                     -- (Vicky01) - End

    /* #INCLUDE <SPTMTM01_1.SQL> */
    IF @n_continue=1 OR @n_continue=2
    BEGIN
        SELECT @c_taskid = CONVERT(NVARCHAR(18) ,CONVERT(INT ,(RAND()*2147483647)))
    END

    IF @n_continue=1 OR @n_continue=2
    BEGIN
        SELECT @n_continue = @n_continue -- Dummy line so that BEGIN/END statement doesnt bomb in SQL SERVER.
    END

    IF @n_continue=1 OR @n_continue=2
    BEGIN
        IF ISNULL(RTRIM(@c_AreaKey02) ,'')<>''
        BEGIN
            SELECT @c_TaskTypeoverride = 'PK'
        END
    END

    IF @n_continue=1 OR @n_continue=2
    BEGIN
        IF SUBSTRING(@c_LastTaskType ,1 ,1)='T'
        BEGIN
            -- RF pass TPK and after this statement @c_LastTaskType = 'PK'
            SELECT @c_LastTaskType = SUBSTRING(@c_LastTaskType ,2 ,2)
        END
    END


    IF @n_continue=1 OR @n_continue=2
    BEGIN
        SELECT @c_Strategykey = TaskManagerUser.Strategykey
        FROM   TaskManagerUser WITH (NOLOCK)
        WHERE  TaskManagerUser.UserKey = @c_userid

        IF ISNULL(RTRIM(@c_Strategykey) ,'')=''
           OR NOT EXISTS (
                  SELECT 1
                  FROM   Strategy WITH (NOLOCK)
                  WHERE  Strategykey = @c_Strategykey
              )
        BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63056 --78601
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Bad Strategy Key (nspTMTM01)'
        END


        IF @n_continue=1 OR @n_continue=2
        BEGIN
            SELECT @c_ttmStrategykey = ttmStrategykey
            FROM   Strategy WITH (NOLOCK)
            WHERE  Strategykey = @c_Strategykey

            IF ISNULL(RTRIM(@c_ttmStrategykey) ,'')=''
               OR NOT EXISTS (
                      SELECT 1
                      FROM   TTMStrategy WITH (NOLOCK)
                      WHERE  TTMStrategykey = @c_ttmStrategykey
                  )
               OR NOT EXISTS (
                      SELECT 1
                      FROM   TTMStrategyDetail WITH (NOLOCK)
                      WHERE  TTMStrategykey = @c_ttmStrategykey
                  )
            BEGIN
                SELECT @n_continue = 3
                SELECT @n_err = 63057--78602
                SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                       ': Bad TTMStrategy Key (nspTMTM01)'
            END
        END

        IF @n_continue=1 OR @n_continue=2
        BEGIN
            SELECT @c_InterLeaveTasks = interleavetasks
            FROM   TTMStrategy WITH (NOLOCK)
            WHERE  TTMStrategykey = @c_ttmStrategykey

            IF ISNULL(RTRIM(@c_InterLeaveTasks) ,'')=''
            BEGIN
                SELECT @c_InterLeaveTasks = '0'
            END
        END
    END

    -- Shong02
    IF @n_continue=1 OR @n_continue=2
    BEGIN
         -- Added By SHONG on 8-Jun-2012
        IF EXISTS(SELECT 1 FROM TASKDETAIL WITH (NOLOCK) WHERE  UserKey = @c_userid
                  AND STATUS = '3')
        BEGIN
            UPDATE TD
            SET    STATUS = '0'
                 ,UserKey = ''
                 ,Reasonkey = ''
                 ,EditDate = GetDate()     -- (SHONG08)
                 ,EditWho  = sUSER_sNAME()
                 ,TrafficCop = NULL
                 ,DropId = '' -- SOS# 248996
                 ,ToLoc = IIF(LOC.LocationCategory IN ('PND', 'PND_IN', 'PND_OUT'), TD.FinalLoc, TD.ToLoc)
                 ,TransitLoc = IIF(LOC.LocationCategory IN ('PND', 'PND_IN', 'PND_OUT'), '', TD.TransitLoc)
                 ,FinalLoc = IIF(LOC.LocationCategory IN ('PND', 'PND_IN', 'PND_OUT'), '', TD.FinalLoc)
            FROM TASKDETAIL TD WITH (ROWLOCK)
            INNER JOIN dbo.LOC LOC WITH(NOLOCK) ON TD.ToLoc = LOC.Loc
            WHERE TD.UserKey = @c_userid
               AND TD.STATUS = '3'

           SELECT @n_err = @@ERROR
                 ,@n_cnt = @@ROWCOUNT

			   --NICK
   DECLARE @NICKMSG NVARCHAR(200)
   SET @NICKMSG = CONCAT_WS(',', 'nspTMTM05_LV', 'Reset TaskDetail' )
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)

           IF @n_err<>0
           BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63058
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                      ': Update TASKDETAIL Failed. (nspTMTM01)'+' ( '+
                      ' SQLSvr MESSAGE='
                     +ISNULL(RTRIM(@c_errmsg) ,'')+' ) '
           END
           ELSE
           BEGIN
              -- Added by SHONG on 26th Oct 2013, Release locking 1st
               WHILE @@TRANCOUNT > 0
                  COMMIT TRAN

               WHILE @@TRANCOUNT < @n_starttcnt
                  BEGIN TRAN
           END
        END
    END

    DECLARE @t_ProcessTaskType TABLE (TaskType NVARCHAR(10), NoOfTry INT)

    -- (james01)
    IF @n_continue=1 OR @n_continue=2
    BEGIN
        Create TABLE #Aisle_InUsed ( Rowref INT identity(1,1) Primary Key,
               LocAIsle NVARCHAR(10) ,UserKey NVARCHAR(18))
        IF EXISTS (
               SELECT 1
               FROM   TaskManagerUser TMU WITH (NOLOCK)
                      INNER JOIN EquipmentProfile EP WITH (NOLOCK)
                           ON  (TMU.EquipmentProfileKey=EP.EquipmentProfileKey)
               WHERE  TMU.Userkey = @c_userid
                      AND TMU.EquipmentProfileKey = 'VNA'
           )
        BEGIN
            INSERT INTO #Aisle_InUsed
              (
                LocAisle, UserKey
              )
            SELECT L.LocAisle
                  ,TD.UserKey
            FROM   TaskDetail TD WITH (NOLOCK)
            JOIN LOC L WITH (NOLOCK) ON  (TD.FromLOC=L.Loc)
            JOIN TaskManagerUser TMU WITH (NOLOCK) ON  (TD.UserKey=TMU.UserKey)
            JOIN EquipmentProfile EP WITH (NOLOCK) ON  (TMU.EquipmentProfileKey=EP.EquipmentProfileKey)
            WHERE  TMU.EquipmentProfileKey = 'VNA'
             AND TD.UserKey<>@c_userid
             AND TD.Status = '3'
            ORDER BY L.LocAisle
        END
    END

    IF @b_debug=1
    BEGIN
        SELECT 'Strategykey = ',@c_Strategykey,'TTMStrategyKey = ',@c_TTMStrategyKey
    END

    IF @n_continue=1 OR @n_continue=2
    BEGIN
        IF (@c_InterLeaveTasks='1' AND ISNULL(RTRIM(@c_LastTaskType) ,'')<>'') OR ( @c_ContinueTask = '1')
        BEGIN
            BEGIN
                SELECT @c_CurrentLineNumber = TTMStrategyLineNumber
                FROM   TTMStrategyDetail WITH (NOLOCK)
                WHERE  TTMStrategyKEY = @c_ttmStrategykey
                       AND TaskType = @c_LastTaskType

                SELECT @c_MaxTTMStrategyLineNumber = MAX(TTMStrategyLineNumber)
                FROM   TTMStrategyDetail WITH (NOLOCK)
                WHERE  TTMStrategyKEY = @c_ttmStrategykey

                IF @c_CurrentLineNumber=@c_MaxTTMStrategyLineNumber
                BEGIN
                    SELECT @c_CurrentLineNumber = ''
                END
            END

            IF @b_debug=1
            BEGIN
                SELECT 'Interleaving Starts At:'
                      ,CONVERT(NVARCHAR(30) ,GETDATE() ,109)
                      ,' Line Number='
                      ,@c_CurrentLineNumber
                      ,'Task Type='
                      ,@c_TTMTaskType
                      ,'Pick Code = '
                      ,@c_ttmpickcode
                      ,'Override='
                      ,@c_ttmoverride
                      ,'Last TaskType ='
                      ,@c_LastTaskType

            END
        END -- IF @c_InterLeaveTasks='1' AND ISNULL(RTRIM(@c_LastTaskType) ,'')<>''


        WHILE (1=1)
        BEGIN
            SET @nCnt = 0
            SET @nCnt1 = 0
            SET @nCnt2 = 0

            IF @c_InterLeaveTasks='1'
            BEGIN
                IF @n_TablePasses=0 AND @c_CurrentLineNumber=@c_MaxTTMStrategyLineNumber
                BEGIN
                    SELECT @c_CurrentLineNumber = ''
                          ,@n_TablePasses = 1
                END
            END

            SET @n_continue = 1
            SET ROWCOUNT 1


            IF @c_InterLeaveTasks='1' --AND ISNULL(RTRIM(@c_LastLOC),'') <> ''
            BEGIN
                IF @b_debug=1
                BEGIN
                    SELECT 'LastLoc',@c_LastLOC,'Last TaskType =',@c_LastTaskType
                END

                ---- Start TITAN Logic Here
                IF ISNULL(RTRIM(@c_LastLOC) ,'')<>''
                BEGIN
                    -- Get Last Aisle he is working now
                    -- (Vicky03) - Start
                    SELECT @c_LastAisle = ISNULL(LOCAisle ,'')
                    FROM   LOC WITH (NOLOCK)
                    WHERE  LOC.Loc = @c_LastLOC
                    -- (Vicky03) - End

                    IF @b_debug=1
                    BEGIN
                        SELECT @c_LastAisle '@c_LastAisle',
                               @c_userid '@c_userid',
                               @c_AreaKey01 '@c_AreaKey01',
                               @c_LastTaskType '@c_LastTaskType'

                    END

                    IF @c_LastTaskType<>'NMV' -- (Vicky04)
                    BEGIN
                        -- Get the 1st Priority
                        SELECT TOP 1
                               @c_MinPriority = td.Priority
                              ,@c_NextTaskType = td.TaskType
                              ,@nCnt1 = 1
                        FROM   TaskDetail td WITH (NOLOCK)
                        JOIN LOC l WITH (NOLOCK) ON  l.LOC = td.FromLoc
                        JOIN PutawayZone pz WITH (NOLOCK) ON  pz.PutawayZone = L.PutawayZone
                        JOIN AreaDetail ad WITH (NOLOCK) ON  ad.PutawayZone = pz.PutawayZone
                        JOIN TaskManagerUserDetail tmud WITH (NOLOCK)
                              ON  tmud.AreaKey = ad.AreaKey
                                  AND tmud.Permission = '1'
                                  AND tmud.PermissionType = td.TaskType
                                  AND tmud.UserKey = @c_userid
                        WHERE  l.LocAisle = @c_LastAisle
                        AND ad.AreaKey = CASE
                                            WHEN ISNULL(RTRIM(@c_AreaKey01) ,'') =''
                                            THEN ad.AreaKey
                                            ELSE @c_AreaKey01
                                          END
                        AND td.status = '0' -- (james01)
                        AND td.userkey = '' -- (ChewKP02)
                        AND td.TaskType<>'NMV' -- (Vicky04)
                        ORDER BY
                               td.Priority
                              ,L.LocAisle
                              ,CASE
                                    WHEN td.TaskType=@c_LastTaskType THEN '2'
                                    ELSE '1'
                               END

                        -- (Vicky03) - Start
                        IF @nCnt1=0
                        BEGIN
                            SELECT TOP 1
                                   @c_MinPriority = td.Priority
                                  ,@c_NextTaskType = td.TaskType
                                  ,@nCnt1 = 1
                            FROM   TaskDetail td WITH (NOLOCK)
                                   JOIN LOC l WITH (NOLOCK)
                                        ON  l.LOC = td.ToLoc
                                   JOIN PutawayZone pz WITH (NOLOCK)
                                        ON  pz.PutawayZone = L.PutawayZone
                                   JOIN AreaDetail ad WITH (NOLOCK)
                                        ON  ad.PutawayZone = pz.PutawayZone
                                   JOIN TaskManagerUserDetail tmud WITH (NOLOCK)
                                        ON  tmud.AreaKey = ad.AreaKey
                                            AND tmud.Permission = '1'
                                            AND tmud.PermissionType = td.TaskType
                                           AND tmud.UserKey = @c_userid
                            WHERE  l.LocAisle = @c_LastAisle
                                   AND ad.AreaKey = CASE
                                                           WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')
                                                               ='' THEN ad.AreaKey
                                                           ELSE @c_AreaKey01
                                                      END
                                   AND td.status = '0' -- (james01)
                                   AND td.userkey = '' -- (ChewKP02)
                                   AND td.TaskType<>'NMV' -- (Vicky04)
                            ORDER BY
                                   td.Priority
                                  ,L.LocAisle
                                  ,CASE
                                        WHEN td.TaskType=@c_LastTaskType THEN
                                             '2'
                                        ELSE '1'
                                   END
                        END-- (Vicky03) - End
                    END-- (Vicky04) - Start
                    ELSE
                    IF @c_LastTaskType='NMV'
                    BEGIN
                        SELECT TOP 1
                               @c_MinPriority = td.Priority
                              ,@c_NextTaskType = td.TaskType
                              ,@nCnt1 = 1
                        FROM   TaskDetail td WITH (NOLOCK)
                               JOIN LOC l WITH (NOLOCK)
                                    ON  l.LOC = td.FromLoc
                               JOIN AreaDetail ad WITH (NOLOCK)
                                    ON  (ad.AreaKey=td.AreaKey)
                               JOIN TaskManagerUserDetail tmud WITH (NOLOCK)
                                    ON  tmud.AreaKey = ad.AreaKey
                                        AND tmud.Permission = '1'
                                        AND tmud.PermissionType = td.TaskType
                               WHERE  l.LocAisle = @c_LastAisle
                               AND ad.AreaKey = CASE
                                                       WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')
                                                           ='' THEN ad.AreaKey
                                                       ELSE @c_AreaKey01
                                                  END
                               --                      AND   td.status NOT IN ('3','S','R','9')  -- (james01)
                               AND td.status = '0' -- (james01)
                               AND td.userkey = '' -- (ChewKP02)
                               AND tmud.UserKey = @c_userid
                               AND td.TaskType = 'NMV'
                        ORDER BY
                               td.Priority
                              ,L.LocAisle
                              ,CASE
                                    WHEN td.TaskType=@c_LastTaskType THEN '2'
                                    ELSE '1'
                               END
                    END
                    -- (Vicky04) - End

                    IF ISNULL(RTRIM(@c_MinPriority) ,'')=''
                    BEGIN
                        SET @c_MinPriority = '9'
                    END

                    IF ISNULL(RTRIM(@c_NextTaskType) ,'')=''
                    BEGIN
                        SET @c_NextTaskType = ''
                    END

                    IF ISNULL(RTRIM(@c_LastAisle) ,'')=''
                    BEGIN
                        SET @c_LastAisle = ''
                    END

                    IF ISNULL((@nCnt1) ,0)=0
                    BEGIN
                        SELECT @nCnt1 = 0
                    END

                    IF @b_debug=1
                    BEGIN
 SELECT '@c_MinPriority'
                              ,@c_MinPriority
                              ,'@c_NextTaskType'
                              ,@c_NextTaskType
                              ,'Last TaskType ='
                              ,@c_LastTaskType
                    END

                   IF @c_LastTaskType<>'NMV' -- (Vicky04)
                   BEGIN
                        SELECT TOP 1
                               @c_OtherPriority = td.Priority
                              ,@c_OtherTaskType = td.TaskType
                              ,@c_la = L.LocAisle
                              ,@nCnt = 1
                        FROM   TaskDetail td WITH (NOLOCK)
                               JOIN LOC L WITH (NOLOCK)
                                    ON  L.LOC = td.FromLoc
                               JOIN PutawayZone pz WITH (NOLOCK)
                                    ON  pz.PutawayZone = L.PutawayZone
                               JOIN AreaDetail ad WITH (NOLOCK)
                                    ON  ad.PutawayZone = pz.PutawayZone
                               JOIN TaskManagerUserDetail tmud WITH (NOLOCK)
                                    ON  tmud.AreaKey = ad.AreaKey
                                        AND tmud.Permission = '1'
                                        AND tmud.PermissionType = td.TaskType
                        WHERE  ad.AreaKey = CASE
                                                   WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')
                                                       ='' THEN ad.AreaKey
                                                   ELSE @c_AreaKey01
                                              END
                               AND td.status = '0'
                               AND td.userkey = '' -- (ChewKP02)
                               AND L.LocAisle<>@c_LastAisle
                               AND tmud.UserKey = @c_userid
                               AND td.TaskType<>'NMV'
                               AND NOT EXISTS (
                                       SELECT 1
                                       FROM   #Aisle_InUsed AIU -- (james01)
                                       WHERE  AIU.LocAisle = L.LocAisle
                                   )
                        ORDER BY
                               td.Priority
                              ,L.LocAisle
                              ,CASE
                                    WHEN td.TaskType=@c_LastTaskType THEN '2'
                                    ELSE '1'
                               END

                        -- (Vicky03) - Start
                        IF @nCnt=0
                        BEGIN
                            SELECT TOP 1
                                   @c_OtherPriority = td.Priority
                                  ,@c_OtherTaskType = td.TaskType
                                  ,@c_la = L.LocAisle
                                  ,@nCnt = 1
                            FROM   TaskDetail td WITH (NOLOCK)
                                   JOIN LOC L WITH (NOLOCK)
                                        ON  L.LOC = td.ToLoc
                                   JOIN PutawayZone pz WITH (NOLOCK)
                                        ON  pz.PutawayZone = L.PutawayZone
                                   JOIN AreaDetail ad WITH (NOLOCK)
                                        ON  ad.PutawayZone = pz.PutawayZone
                                   JOIN TaskManagerUserDetail tmud WITH (NOLOCK)
                                        ON  tmud.AreaKey = ad.AreaKey
                                            AND tmud.Permission = '1'
                                            AND tmud.PermissionType = td.TaskType
                            WHERE  ad.AreaKey = CASE
                                                       WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')
   ='' THEN ad.AreaKey
                                                       ELSE @c_AreaKey01
                                                  END
                                   AND td.status = '0'
                                   AND td.userkey = '' -- (ChewKP02)
                                   AND L.LocAisle<>@c_LastAisle
                                   AND tmud.UserKey = @c_userid
                                   AND td.TaskType<>'NMV'
                                   AND -- (Vicky04)
                                       NOT EXISTS (
                                           SELECT 1
                                       FROM   #Aisle_InUsed AIU -- (james01)
                                           WHERE  AIU.LocAisle = L.LocAisle
                                       )
                            ORDER BY
                                   td.Priority
                                  ,L.LocAisle
                                  ,CASE
                                        WHEN td.TaskType=@c_LastTaskType THEN
                                             '2'
                                        ELSE '1'
                                   END
                        END-- (Vicky03) - End
                    END-- (Vicky04) - Start
                    ELSE
                    IF @c_LastTaskType='NMV'
                    BEGIN
                        SELECT TOP 1
                               @c_OtherPriority = td.Priority
                              ,@c_OtherTaskType = td.TaskType
                              ,@c_la = L.LocAisle
                              ,@nCnt = 1
                        FROM   TaskDetail td WITH (NOLOCK)
                               JOIN LOC L WITH (NOLOCK)
                                    ON  L.LOC = td.FromLoc
                               JOIN AreaDetail ad WITH (NOLOCK)
                                    ON  (ad.AreaKey=td.AreaKey)
                               JOIN TaskManagerUserDetail tmud WITH (NOLOCK)
                                    ON  tmud.AreaKey = ad.AreaKey
                                        AND tmud.Permission = '1'
                                        AND tmud.PermissionType = td.TaskType
                        WHERE  ad.AreaKey = CASE
                                                   WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')
                                                       ='' THEN ad.AreaKey
                                                   ELSE @c_AreaKey01
                                              END
                               AND td.status = '0'
                               AND td.userkey = '' -- (ChewKP02)
                               AND L.LocAisle<>@c_LastAisle
                               AND tmud.UserKey = @c_userid
                               AND td.TaskType = 'NMV'
                        ORDER BY
                               td.Priority
                              ,L.LocAisle
                              ,CASE
                                    WHEN td.TaskType=@c_LastTaskType THEN '2'
                                    ELSE '1'
                               END
                 END
                    -- (Vicky04) - End

                 IF @b_debug = 1
                 BEGIN
                    SELECT @c_OtherPriority '@c_OtherPriority',
                           @c_OtherTaskType '@c_OtherTaskType',
                           @nCnt '@nCnt',
                           @c_LastAisle '@c_LastAisle'

                 END

                    IF ISNULL(RTRIM(@c_OtherPriority) ,'')=''
                    BEGIN
                        SET @c_OtherPriority = '9'
                    END

                    IF ISNULL(RTRIM(@c_OtherTaskType) ,'')=''
                    BEGIN
                        SET @c_OtherTaskType = ''
   END

                    IF ISNULL(RTRIM(@c_LastAisle) ,'')=''
                    BEGIN
                        SET @c_LastAisle = ''
                    END

                    IF ISNULL((@nCnt) ,0)=0
                    BEGIN
                        SELECT @nCnt = 0
                    END


                    IF @nCnt=0 AND @nCnt1=0
                    BEGIN
                        SET ROWCOUNT 0
                        BREAK
                    END

                    ---- End TITAN Logic Here
                    IF @nCnt>0
                    BEGIN
                        IF (@c_OtherPriority<@c_MinPriority)
                           OR (@nCnt1=0 AND @nCnt>0)
                        BEGIN
                           SET @c_NextTaskType = @c_OtherTaskType

                           IF @b_debug=1
                           BEGIN
                              SELECT '@c_NextTaskType',@c_NextTaskType
                           END
                        END

                        SELECT @c_CurrentLineNumber = TTMStrategyLineNumber
                              ,@c_TTMTaskType = TaskType
                              ,@c_ttmpickcode = TTMPickCode
                              ,@c_ttmoverride = TTMOverride
                              ,@nCnt2 = 1
                        FROM   TTMStrategyDetail WITH (NOLOCK)
                        WHERE  TTMStrategykey = @c_TTMStrategyKey
                               AND TaskType = @c_NextTaskType

                        --IF @@ROWCOUNT=0
                        IF @nCnt2=0
                        BEGIN
                            SET ROWCOUNT 0
                            BREAK
                        END
                    END-- rowcount
                    ELSE
                    BEGIN
                        SELECT TOP 1
                               @c_CurrentLineNumber = TTMStrategyLineNumber
                              ,@c_TTMTaskType = TaskType
                              ,@c_ttmpickcode = TTMPickCode
                              ,@c_ttmoverride = TTMOverride
                              ,@nCnt2 = 1
                        FROM   TTMStrategyDetail WITH (NOLOCK)
                        WHERE  TTMStrategykey = @c_TTMStrategyKey
                        AND   TTMStrategyLineNumber > @c_CurrentLineNumber
                        ORDER BY TTMStrategyLineNumber
--                        AND   EXISTS(SELECT 1
--                                     FROM   TaskManagerUserDetail WITH (NOLOCK)
--                                     WHERE  USERKEY = @c_userid
--                                     AND PERMISSIONTYPE = TTMStrategyDetail.TaskType
--                                     AND PERMISSION = '1')
--                        ORDER BY CASE WHEN TTMStrategyLineNumber = @c_CurrentLineNumber THEN 9
--                                      WHEN TTMStrategyLineNumber < @c_CurrentLineNumber THEN 8
--                                      ELSE 1
--                                 END,
--                                 TTMStrategyLineNumber

                        IF @nCnt2=0
                        BEGIN
                            SET ROWCOUNT 0
                            BREAK
                        END
                    END
                END-- last loc <> ''
                ELSE
                BEGIN
                    SELECT TOP 1
                           @c_CurrentLineNumber = TTMStrategyLineNumber
                          ,@c_TTMTaskType = TaskType
                          ,@c_ttmpickcode = TTMPickCode
                          ,@c_ttmoverride = TTMOverride
                          ,@nCnt2 = 1
                    FROM   TTMStrategyDetail WITH (NOLOCK)
                    WHERE  TTMStrategykey = @c_TTMStrategyKey
                    AND    TTMStrategyLineNumber>@c_CurrentLineNumber
--                    AND   EXISTS(SELECT 1
--                                 FROM   TaskManagerUserDetail WITH (NOLOCK)
--                                 WHERE  USERKEY = @c_userid
--                                 AND PERMISSIONTYPE = TTMStrategyDetail.TaskType
--                                 AND PERMISSION = '1')
                    ORDER BY TTMStrategyLineNumber
--                    ORDER BY CASE WHEN TTMStrategyLineNumber = @c_CurrentLineNumber THEN 9
--                                  WHEN TTMStrategyLineNumber < @c_CurrentLineNumber THEN 8
--                                  ELSE 1
--                             END,
--                             TTMStrategyLineNumber

                    IF @nCnt2=0
                    BEGIN
                        SET ROWCOUNT 0
                        BREAK
                    END
                END

--               INSERT INTO TRACEINFO (TraceName, TimeIn, Step1, Step2, Step3,
--                           Step4, Step5, Col1, Col2, Col3, Col4, Col5)
--               VALUES('nspTMTM01-InterLeave', GETDATE(), @c_LastTaskType, @c_LastLOC, @c_LastAisle,
--                     @c_NextTaskType,  @c_TTMTaskType,  @c_CurrentLineNumber,  @c_ttmpickcode,
--                     @c_ttmoverride, SUSER_SNAME(), @c_AreaKey01)


            END-- interleave = 1
            ELSE
            BEGIN
               -- (james06)
               IF @c_ContinueTask = 1 AND ISNULL( @c_LastTaskType, '') <> ''
               BEGIN
                  SELECT TOP 1
                         @c_CurrentLineNumber = TTMStrategyLineNumber
                        ,@c_TTMTaskType = TaskType
                        ,@c_ttmpickcode = TTMPickCode
                        ,@c_ttmoverride = TTMOverride
                        ,@nCnt2 = 1
                  FROM   TTMStrategyDetail WITH (NOLOCK)
                  WHERE  TTMStrategykey = @c_TTMStrategyKey
                  AND    TaskType = @c_LastTaskType
                  AND    EXISTS(SELECT 1
                                FROM   TaskManagerUserDetail WITH (NOLOCK)
                                WHERE  USERKEY = @c_userid
                                AND PERMISSIONTYPE = TTMStrategyDetail.TaskType
                                AND PERMISSION = '1')
                  ORDER BY TTMStrategyLineNumber

                  IF @nCnt2=0
                  BEGIN
                     SELECT TOP 1
                            @c_CurrentLineNumber = TTMStrategyLineNumber
                           ,@c_TTMTaskType = TaskType
                           ,@c_ttmpickcode = TTMPickCode
                           ,@c_ttmoverride = TTMOverride
                           ,@nCnt2 = 1
                     FROM   TTMStrategyDetail WITH (NOLOCK)
                     WHERE  TTMStrategykey = @c_TTMStrategyKey
                     AND    TTMStrategyLineNumber>@c_CurrentLineNumber
                     AND    EXISTS(SELECT 1
                                   FROM   TaskManagerUserDetail WITH (NOLOCK)
                                   WHERE  USERKEY = @c_userid
                                   AND PERMISSIONTYPE = TTMStrategyDetail.TaskType
                                   AND PERMISSION = '1')
                     ORDER BY TTMStrategyLineNumber

                     IF @nCnt2=0
                     BEGIN
                        SET ROWCOUNT 0
                        BREAK
                     END
                  END
                  
               END
               ELSE
               BEGIN
                  SELECT TOP 1
                         @c_CurrentLineNumber = TTMStrategyLineNumber
                        ,@c_TTMTaskType = TaskType
                        ,@c_ttmpickcode = TTMPickCode
                        ,@c_ttmoverride = TTMOverride
                        ,@nCnt2 = 1
                  FROM   TTMStrategyDetail WITH (NOLOCK)
                  WHERE  TTMStrategykey = @c_TTMStrategyKey
                  AND    TTMStrategyLineNumber>@c_CurrentLineNumber
                  AND    EXISTS(SELECT 1
                                FROM   TaskManagerUserDetail WITH (NOLOCK)
                                WHERE  USERKEY = @c_userid
                                AND PERMISSIONTYPE = TTMStrategyDetail.TaskType
                                AND PERMISSION = '1')
                  ORDER BY TTMStrategyLineNumber

                  IF @nCnt2=0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END
               END
            END
            --DROP TABLE #Aisle_InUsed

            -- SHONG05
            -- For Vocollect Logic, not able to do interleaving now...
            IF @c_LastTaskType IN ('VNPK','VRPL')
            BEGIN
               SELECT @c_CurrentLineNumber = TTMStrategyLineNumber
                      ,@c_TTMTaskType = TaskType
                      ,@c_TTMPickCode = TTMPickCode
                      ,@c_TTMOverride = TTMOverride
                      ,@nCnt2 = 1
                FROM   TTMStrategyDetail WITH (NOLOCK)
                WHERE  TTMStrategyKey = @c_TTMStrategyKey
                   AND TaskType = @c_LastTaskType
                ORDER BY TTMStrategyLineNumber
            END

            SET ROWCOUNT 0


            IF @b_debug=1
            BEGIN
                SELECT 'VV Start At:'
                      ,CONVERT(NVARCHAR(30) ,GETDATE() ,109)
                      ,' Line Number='
                      ,@c_CurrentLineNumber
                      ,'Task Type='
                      ,@c_TTMTaskType
                      ,'Pick Code = '
                      ,@c_ttmpickcode
                      ,'Override='
                      ,@c_ttmoverride
            END

            IF NOT EXISTS(SELECT 1 FROM @t_ProcessTaskType WHERE TaskType = @c_TTMTaskType)
            BEGIN
               INSERT INTO @t_ProcessTaskType VALUES (@c_TTMTaskType, 1)
            END
            ELSE
            BEGIN
               UPDATE @t_ProcessTaskType
               SET NoOfTry = NoOfTry + 1
               WHERE TaskType = @c_TTMTaskType
            END

            IF @c_TTMTaskType='GM'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='GM')
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'GM'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TGM'
                EXECUTE nspTTMEvaluateGMTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (KHLim01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType='MV'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='MV')
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'MV'
            AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TMV'
                EXECUTE nspTTMEvaluateMVTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT

                SELECT @n_err = @@ERROR
                      ,@n_cnt = @@ROWCOUNT -- Note: Need this here to trap error message for use later!
                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END


            IF @c_TTMTaskType='PA'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='PA')
               AND OBJECT_ID('nspTTMEvaluatePATasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'PA'
                              AND PERMISSION = '1'
                   )
            BEGIN

                SELECT @b_success = 0
                SELECT @c_appflag = 'TPA'
                EXECUTE nspTTMEvaluatePATasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
      , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Vicky01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Vicky01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Vicky01)
                 --, @c_CaseID=@c_CaseID OUTPUT -- (ChewKP02)
                 --, @c_ToteID=@c_ToteID  -- (ChewKP02)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)
                --SET @c_RefKey03 = @c_CaseID -- (ChewKP02)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                    IF @n_err = 63061
                       BREAK;
                END
            END

            --(ung02)
            IF @c_TTMTaskType IN ('PAF', 'PA1')
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride IN ('PAF', 'PA1'))
               AND OBJECT_ID('nspTTMEvaluatePAFTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE IN ('PAF', 'PA1')
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TPA'
                EXECUTE nspTTMEvaluatePAFTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid
                , @c_fromloc=@c_fromloc OUTPUT
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT

                SET @c_RefKey01 = @c_fromloc

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            --(ung01)
            IF @c_TTMTaskType='PAT'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='PAT')
               AND OBJECT_ID('nspTTMEvaluatePATTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'PAT'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TPA'
                EXECUTE nspTTMEvaluatePATTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid
                , @c_fromloc=@c_fromloc OUTPUT
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT

                SET @c_RefKey01 = @c_fromloc

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType='XD'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='XD')
               AND OBJECT_ID('nspTTMEvaluateXDTasks') IS NOT NULL
               AND EXISTS (
                     SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'XD'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TXD'
                EXECUTE nspTTMEvaluateXDTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType='CO'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='CO')
               AND OBJECT_ID('nspTTMEvaluateCOTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'CO'
                    AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TCO'
                EXECUTE nspTTMEvaluateCOTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType='RP'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='RP')
               AND OBJECT_ID('nspTTMEvaluateRPTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'RP'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TRP'
                EXECUTE nspTTMEvaluateRPTasks
                @c_senddelimiter=@c_senddelimiter
                --, @c_ptcid=@c_ptcid         (ChewKP04)
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (ChewKP04)
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP04)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP04)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType='PK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='PK')
               AND OBJECT_ID('nspTTMEvaluatePKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'PK'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'TPK'
               EXECUTE nspTTMEvaluatePKTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType='CC'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='CC')
               AND OBJECT_ID('nspTTMEvaluateCCTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'CC'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TCC'
                EXECUTE nspTTMEvaluateCCTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid = @c_ptcid                         -- (ChewKP03)
                , @c_FromLoc = @c_FromLoc          OUTPUT     -- (ChewKP03)
                , @c_TaskDetailKey = @c_TaskDetailKey    OUTPUT     -- (ChewKP03)

                SET @c_RefKey01 =  @c_FromLoc -- (ChewKP03)

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END

            -- (ChewKP03)
            IF @c_TTMTaskType='CCSV'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='CCSV')
               AND OBJECT_ID('nspTTMEvaluateCCTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'CCSV'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'TCCSV'
               EXECUTE nspTTMEvaluateCCTasks
                       @c_senddelimiter=@c_senddelimiter
                     , @c_userid=@c_userid
                     , @c_Strategykey=@c_Strategykey
                     , @c_ttmStrategykey=@c_ttmStrategykey
                     , @c_ttmpickcode=@c_ttmpickcode
                     , @c_ttmoverride=@c_ttmoverride
                     , @c_AreaKey01=@c_AreaKey01
                     , @c_AreaKey02=@c_AreaKey02
                     , @c_AreaKey03=@c_AreaKey03
                     , @c_AreaKey04=@c_AreaKey04
                     , @c_AreaKey05=@c_AreaKey05
                     , @c_LastLOC=@c_LastLOC
                     , @c_outstring=@c_outstring OUTPUT
                     , @b_Success=@b_success OUTPUT
                     , @n_err=@n_err OUTPUT
                     , @c_errmsg=@c_errmsg OUTPUT
                     , @c_ptcid = @c_ptcid
                     , @c_FromLoc = @c_FromLoc             OUTPUT
                     , @c_TaskDetailKey = @c_TaskDetailKey OUTPUT

               SET @c_RefKey01 =  @c_FromLoc

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END

            -- (ChewKP03)
            IF @c_TTMTaskType='CCSUP'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='CCSUP')
               AND OBJECT_ID('nspTTMEvaluateCCTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'CCSUP'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'TCCSUP'
               EXECUTE nspTTMEvaluateCCTasks
                       @c_senddelimiter=@c_senddelimiter
                     , @c_userid=@c_userid
                     , @c_Strategykey=@c_Strategykey
                     , @c_ttmStrategykey=@c_ttmStrategykey
                     , @c_ttmpickcode=@c_ttmpickcode
                     , @c_ttmoverride=@c_ttmoverride
                     , @c_AreaKey01=@c_AreaKey01
                     , @c_AreaKey02=@c_AreaKey02
                     , @c_AreaKey03=@c_AreaKey03
                     , @c_AreaKey04=@c_AreaKey04
                     , @c_AreaKey05=@c_AreaKey05
                     , @c_LastLOC=@c_LastLOC
                     , @c_outstring=@c_outstring OUTPUT
                     , @b_Success=@b_success OUTPUT
                     , @n_err=@n_err OUTPUT
                     , @c_errmsg=@c_errmsg OUTPUT
                     , @c_ptcid = @c_ptcid
                     , @c_FromLoc = @c_FromLoc             OUTPUT
                     , @c_TaskDetailKey = @c_TaskDetailKey OUTPUT

               SET @c_RefKey01 =  @c_FromLoc

               IF @b_success<>1
               BEGIN
                  SELECT @n_continue = 3
               END
            END

            IF @c_TTMTaskType='QC'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='QC')
               AND OBJECT_ID('nspTTMEvaluateQCTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'QC'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TQC'
                EXECUTE nspTTMEvaluateQCTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            -- (Vicky02) - Start - TaskType = NMV
            IF @c_TTMTaskType='NMV'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='NMV')
               AND OBJECT_ID('nspTTMEvaluateNMVTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'NMV'
                   AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'NMV'
                EXECUTE nspTTMEvaluateNMVTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid
                , @c_fromloc=@c_fromloc OUTPUT
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT
                , @c_toid=@c_toid OUTPUT

                SET @c_RefKey01 = @c_toid
                SET @c_RefKey02 = @c_fromloc


                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            -- (Vicky02) - End

            -- (ChewKP01) - Start - TaskType = OPK
            IF @c_TTMTaskType='OPK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='OPK')
               AND OBJECT_ID('nspTTMEvaluateOPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'OPK'
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'OPK'
                EXECUTE nspTTMEvaluateOPKTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            -- (ChewKP01) - End

            -- (Shong03) - Start - TaskType = DPK
            IF @c_TTMTaskType='DPK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='DPK')
               AND OBJECT_ID('nspTTMEvaluateDPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'DPK'
                              AND PERMISSION = '1'
                   )
             BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'DPK'
                EXECUTE nspTTMEvaluateDPKTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid
                , @c_fromloc=@c_fromloc OUTPUT
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT

                SET @c_RefKey01 = @c_fromloc

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            -- (Shong03) - End

            -- (KC01) - Start - TaskType = DRP
            IF @c_TTMTaskType='DRP'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='DRP')
               AND OBJECT_ID('nspTTMEvaluateDRPTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'DRP'
                            AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'DRP'
                EXECUTE nspTTMEvaluateDRPTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid
                , @c_fromloc=@c_fromloc OUTPUT
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT

                SET @c_RefKey01 = @c_fromloc

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            -- (KC01) - End

            -- Store PPA Pick
            -- (SHONG04)
            IF @c_TTMTaskType='SPK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='SPK')
               AND OBJECT_ID('nspTTMEvaluateSPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'SPK'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'SPK'
               EXECUTE nspTTMEvaluateSPKTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType IN ('RPF', 'RP1')
               AND @c_TaskTypeoverride IN ('', 'RPF', 'RP1')
               AND OBJECT_ID('nspTTMEvaluateRPFTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE IN ('RPF', 'RP1')
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TRP'
                EXECUTE nspTTMEvaluateRPFTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (ChewKP04)
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP04)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP04)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType IN ('FPK', 'FPK1')
               AND @c_TaskTypeoverride IN ('', 'FPK', 'FPK1')
               AND OBJECT_ID('nspTTMEvaluateFPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE IN ('FPK', 'FPK1')
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TFPK'
                EXECUTE nspTTMEvaluateFPKTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (ChewKP04)
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP04)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP04)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType IN ('FCP', 'FCP1')
               AND @c_TaskTypeoverride IN ('', 'FCP', 'FCP1')
               AND OBJECT_ID('nspTTMEvaluateFCPTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE IN ('FCP', 'FCP1')
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TFPK'
                EXECUTE nspTTMEvaluateFCPTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (ChewKP04)
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP04)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP04)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            
              -- Shong05
            IF @c_TTMTaskType='VNPK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='VNPK')
               AND OBJECT_ID('nspTTMEvaluateVNPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'VNPK'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'VNPK'
               EXECUTE nspTTMEvaluateVNPKTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_TTMStrategyKey=@c_TTMStrategyKey
                , @c_TTMPickCode=@c_TTMPickCode
                , @c_TTMOverride=@c_TTMOverride
                , @c_areakey01=@c_areakey01
                , @c_areakey02=@c_areakey02
                , @c_areakey03=@c_areakey03
                , @c_areakey04=@c_areakey04
                , @c_areakey05=@c_areakey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END -- IF @c_TTMTaskType='VNPK'


            IF @c_TTMTaskType='VRPL'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='VRPL')
               AND OBJECT_ID('nspTTMEvaluateVRPLTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'VRPL'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'VRPL'
               EXECUTE nspTTMEvaluateVRPLTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_TTMStrategyKey=@c_TTMStrategyKey
                , @c_TTMPickCode=@c_TTMPickCode
                , @c_TTMOverride=@c_TTMOverride
                , @c_areakey01=@c_areakey01
                , @c_areakey02=@c_areakey02
                , @c_areakey03=@c_areakey03
                , @c_areakey04=@c_areakey04
                , @c_areakey05=@c_areakey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)
                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            -- (ChewKP05)
            IF @c_TTMTaskType='RPT'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='RPT')
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'RPT'
            AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'RPT'
                EXECUTE nspTTMEvaluateRTTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_areakey01=@c_areakey01
                , @c_areakey02=@c_areakey02
                , @c_areakey03=@c_areakey03
                , @c_areakey04=@c_areakey04
                , @c_areakey05=@c_areakey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Vicky01)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP03)  
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP03)  
  
  
                SET @c_RefKey01 = @c_fromloc -- (ChewKP03)  
  
  
  
                SELECT @n_err = @@ERROR  
                      ,@n_cnt = @@ROWCOUNT -- Note: Need this here to trap error message for use later!  
                IF @b_success<>1  
                BEGIN  
                    SELECT @n_continue = 3  
                END  
            END

            IF @c_TTMTaskType IN ('MVF', 'MV1')
               AND @c_TaskTypeoverride IN ('', 'MVF', 'MV1')
               AND OBJECT_ID('nspTTMEvaluateMVFTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE IN ('MVF', 'MV1')
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TMV'
                EXECUTE nspTTMEvaluateMVFTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (ChewKP04)
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP04)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP04)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            IF @c_TTMTaskType IN ('NMF', 'NM1')
               AND @c_TaskTypeoverride IN ('', 'NMF', 'NM1')
               AND OBJECT_ID('nspTTMEvaluateMVFTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE IN ('NMF', 'NM1')
                              AND PERMISSION = '1'
                   )
            BEGIN
                SELECT @b_success = 0
                SELECT @c_appflag = 'TNMF'
                EXECUTE nspTTMEvaluateNMFTasks
                  @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (ChewKP04)
                , @c_fromloc=@c_fromloc OUTPUT -- (ChewKP04)
                , @c_taskDetailkey=@c_taskDetailkey OUTPUT -- (ChewKP04)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            -- (james03)
            IF @c_TTMTaskType='PPK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='PPK')
               AND OBJECT_ID('nspTTMEvaluatePPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'PPK'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'TPPK'
               EXECUTE nspTTMEvaluatePKTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END

            -- (james05)
            IF @c_TTMTaskType='CPK'
               AND (@c_TaskTypeoverride='' OR @c_TaskTypeoverride='CPK')
               AND OBJECT_ID('nspTTMEvaluateCPKTasks') IS NOT NULL
               AND EXISTS (
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                       WHERE  USERKEY = @c_userid
                              AND PERMISSIONTYPE = 'CPK'
                              AND PERMISSION = '1'
                   )
            BEGIN
               SELECT @b_success = 0
               SELECT @c_appflag = 'TCPK'
               EXECUTE nspTTMEvaluateCPKTasks
                @c_senddelimiter=@c_senddelimiter
                , @c_userid=@c_userid
                , @c_Strategykey=@c_Strategykey
                , @c_ttmStrategykey=@c_ttmStrategykey
                , @c_ttmpickcode=@c_ttmpickcode
                , @c_ttmoverride=@c_ttmoverride
                , @c_AreaKey01=@c_AreaKey01
                , @c_AreaKey02=@c_AreaKey02
                , @c_AreaKey03=@c_AreaKey03
                , @c_AreaKey04=@c_AreaKey04
                , @c_AreaKey05=@c_AreaKey05
                , @c_LastLOC=@c_LastLOC
                , @c_outstring=@c_outstring OUTPUT
                , @b_Success=@b_success OUTPUT
                , @n_err=@n_err OUTPUT
                , @c_errmsg=@c_errmsg OUTPUT
                , @c_ptcid=@c_ptcid -- (Shong01)
                , @c_fromloc=@c_fromloc OUTPUT -- (Shong01)
                , @c_TaskDetailKey=@c_TaskDetailKey OUTPUT -- (Shong01)

                SET @c_RefKey01 = @c_fromloc -- (Vicky01)

                IF @b_success<>1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            
            -- (KC01) - End
            --
            IF @n_continue=1 OR @n_continue=2
            BEGIN
                IF ISNULL(RTRIM(@c_TaskDetailKey) ,'')<>''
                BEGIN
                    BREAK
                END
                ELSE
                BEGIN
                   IF EXISTS(SELECT 1 FROM TaskDetail td WITH (NOLOCK)
                               WHERE td.status = '0'
                               AND td.userkey = ''
                               AND EXISTS (SELECT 1 FROM @t_ProcessTaskType t
                                               WHERE  t.TaskType = td.TaskType
                                               AND   t.NoOfTry > 3))
                   BEGIN
                      BREAK
                   END
               END
            END

        END -- While

        SET ROWCOUNT 0
    END -- @n_continue = 1 or @n_continue = 2

    IF @n_continue=1
       OR @n_continue=2
    BEGIN
       IF EXISTS(
               SELECT 1
               FROM   TASKDETAIL WITH (NOLOCK)
               WHERE  TaskDetailKey = @c_TaskDetailKey
                      AND Userkey<>@c_userid
                      AND STATUS = '3'
           )
       BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63059--78603
            SELECT @c_errmsg = CONVERT(NVARCHAR(5) ,@n_err)+' Task Taken!' -- (james02)
       END
   ELSE
   BEGIN
      -- Added By Shong on 9th Jul 2010
      -- Return Correct Task Type
      SELECT @c_TTMTaskType = Tasktype
      FROM   TASKDETAIL WITH (NOLOCK)
      WHERE  TaskDetailKey = @c_TaskDetailKey

   END
END

    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        IF ISNULL(RTRIM(@c_TaskDetailKey) ,'')=''--ISNULL(RTRIM(@c_outstring), '') = ''
        BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63060--78603
            SELECT @c_errmsg = CONVERT(NVARCHAR(5) ,@n_err)+' No Task!'
        END
    END

   -- (james04)
   IF @c_ptcid = 'RDT'
   BEGIN
      -- Try get default areakey from user setup. if not setup then get from rdt config   
      SELECT @c_DefaultAreaKey = AreaKey
      FROM rdt.RDTUser WITH (NOLOCK)
      WHERE UserName = @c_userid

      IF ISNULL( @c_DefaultAreaKey, '') = ''
      BEGIN
         SET @c_DefaultAreaKey = rdt.RDTGetConfig( @n_Func, 'DefaultAreaKey', @c_StorerKey)
         IF @c_DefaultAreaKey NOT IN ('', '0')
            SET @c_AreaKey01 = @c_DefaultAreaKey
      END
      ELSE
         SET @c_AreaKey01 = @c_DefaultAreaKey
    END
      
    IF @n_continue=3
    BEGIN
        IF @c_retrec='01'
        BEGIN
            SELECT @c_retrec = '09'
                  ,@c_appflag = 'TM'
        END
    END
    ELSE
    BEGIN
        SELECT @c_retrec = '01'
    END

    SELECT @c_outstring = @c_ptcid+@c_senddelimiter
          +RTRIM(@c_userid)+@c_senddelimiter
          +RTRIM(@c_taskid)+@c_senddelimiter
          +RTRIM(@c_databasename)+@c_senddelimiter
          +RTRIM(@c_appflag)+@c_senddelimiter
          +RTRIM(@c_retrec)+@c_senddelimiter
          +RTRIM(@c_server)+@c_senddelimiter
          +RTRIM(@c_errmsg)+@c_senddelimiter
          +RTRIM(@c_outstring)

    IF @c_ptcid<>'RDT'
    BEGIN
        SELECT RTRIM(@c_outstring)
    END

    IF @b_debug=1
    BEGIN
        SELECT 'End At:'
      ,CONVERT(NVARCHAR(30) ,GETDATE() ,109)
    END

    /* #INCLUDE <SPTMTM01_2.SQL> */
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        SELECT @b_success = 0
        DECLARE @n_IsRDT INT
        EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

        IF @n_IsRDT=1
        BEGIN
            -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
            -- Instead we commit and raise an error back to parent, let the parent decide

            -- Commit until the level we begin with
            WHILE @@TRANCOUNT>@n_starttcnt
                  COMMIT TRAN

            -- Convert to RDT message
            DECLARE @cLangCode NVARCHAR(3)
            SELECT @cLangCode = Lang_Code FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')

            -- Raise error with severity = 10, instead of the default severity 16.
            -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
            IF @n_err = 63061
            BEGIN
                SET @c_ErrMsg = CONCAT_WS('-',  @c_TTMTaskType, @c_ErrMsg)
                RETURN
            END
            ELSE 
                RAISERROR (@n_err ,10 ,1) WITH SETERROR

            -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
        END
        ELSE
        BEGIN
            IF @@TRANCOUNT=1
               AND @@TRANCOUNT>@n_starttcnt
            BEGIN
                ROLLBACK TRAN
            END
            ELSE
            BEGIN
                WHILE @@TRANCOUNT>@n_starttcnt
         BEGIN
                    COMMIT TRAN
                END
            END
            EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTMTM01'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            RETURN
        END
    END
    ELSE
    BEGIN
        SELECT @b_success = 1
        WHILE @@TRANCOUNT>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END
        RETURN
    END
END -- End Proc

GO