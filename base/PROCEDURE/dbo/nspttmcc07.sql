SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: nspTTMCC07                                         */    
/* Copyright: IDS                                                       */    
/*                                                                      */    
/* Purpose: Only allow 1 user to do cycle count in 1 Loc.Floor          */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 2023-06-07   James         WMS-22670. Created bt CN LIT              */    
/************************************************************************/    
    
CREATE   PROC [dbo].[nspTTMCC07]    
   @c_userid       NVARCHAR(18)    
,  @c_AreaKey01    NVARCHAR(10)    
,  @c_AreaKey02    NVARCHAR(10)    
,  @c_AreaKey03    NVARCHAR(10)    
,  @c_AreaKey04    NVARCHAR(10)    
,  @c_AreaKey05    NVARCHAR(10)    
,  @c_lastloc      NVARCHAR(10)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_debug int    
   SELECT @b_debug = 0    
   DECLARE        @n_continue int        ,    
   @n_starttcnt int        , -- Holds the current transaction count    
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations    
   @n_err2 int             , -- For Additional Error Detection    
   @b_Success int          ,    
   @n_err int              ,    
   @c_errmsg NVARCHAR(250)    
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0    
   DECLARE @c_executestmt NVARCHAR(255)    
   DECLARE @c_LastLocAisle          NVARCHAR( 10)    
   DECLARE @c_TaskDetailKey         NVARCHAR( 10)    
   DECLARE @c_TaskDetailKey2LOCK    NVARCHAR( 10)    
   DECLARE @c_LocAisle              NVARCHAR( 10)    
    
   /* #INCLUDE <SPTMCC01_1.SQL> */    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      SET @c_LastLocAisle = ''    

      -- Get last locaisle user previously assigned task    
      SELECT TOP 1 @c_LastLocAisle = LOC.Floor  ------Modify 2023-05-16   
      FROM dbo.TASKDETAIL TD WITH (NOLOCK)    
      JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.FROMLOC = LOC.LOC    
      WHERE  TD.Tasktype = 'CC'    
            AND TD.Status = '9'    
            AND TD.UserKey = @c_UserID    
            AND NOT EXISTS(    
                     SELECT 1    
                     FROM   TaskManagerSkipTasks(NOLOCK)    
                     WHERE  TaskManagerSkipTasks.Taskdetailkey = TD.TaskDetailkey)    
      ORDER BY TD.EditDate DESC    
    
      IF ISNULL( @c_LastLocAisle, '') <> ''    
      BEGIN    
         -- Check if locaisle is valid within the area    
         IF NOT EXISTS ( SELECT 1 FROM dbo.AreaDetail AD WITH (NOLOCK)    
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON AD.PutAwayZone = LOC.PutAwayZone    
                         WHERE AD.AreaKey = @c_AreaKey01    
                         AND   LOC.Floor = @c_LastLocAisle)
         BEGIN    
            SET @c_LastLocAisle = ''    
         END    
    
         -- Check if last locaisle retrieved still has task to assign    
         IF NOT EXISTS (    
            SELECT TaskDetailKey    
            FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)    
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)    
            JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.Code = Loc.PickZone AND C.ListName='NKCNTM'    
            JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) 
               ON ( AreaDetail.AreaKey = C.Short AND AreaDetail.PutAwayZone = C.Long)
            WHERE TaskDetail.Status = '0'    
            AND   TaskDetail.TaskType = 'CC'    
            AND   TaskDetail.UserKey = ''    
            AND   AreaDetail.AreaKey = @c_AreaKey01    
            AND   NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD2 WITH (NOLOCK)    
                               JOIN dbo.Loc Loc2 WITH (NOLOCK) ON (TD2.FromLoc = Loc2.Loc)    
                               WHERE TD2.TaskType = 'CC'    
                               AND   TD2.Status = '3'    
                               AND   Loc.Floor = Loc2.Floor)
                               AND   Loc.Floor =  @c_LastLocAisle)
         BEGIN    
            SET @c_LastLocAisle = ''    
         END    
      END    
    
      IF ISNULL( RTRIM(@c_LastLocAisle), '') = ''    
      BEGIN    
         SELECT TOP 1 @c_TaskDetailKey = TaskDetailKey    
         FROM TaskDetail TaskDetail WITH (NOLOCK)    
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)    
         JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.Code = Loc.PickZone AND C.ListName='NKCNTM'    
         JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) 
            ON ( AreaDetail.AreaKey = C.Short AND AreaDetail.PutAwayZone = C.Long)
         WHERE TaskDetail.Status = '0'    
         AND   TaskDetail.TaskType = 'CC'    
         AND   TaskDetail.UserKey = ''    
         AND   AreaDetail.AreaKey = @c_AreaKey01    
         AND   NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD2 WITH (NOLOCK)    
                            JOIN dbo.Loc Loc2 WITH (NOLOCK) ON (TD2.FromLoc = Loc2.Loc)    
                            WHERE TD2.TaskType = 'CC'    
                            AND   TD2.Status = '3'    
                            AND   TD2.UserKey <> @c_userid    
                            AND   Loc.Floor = Loc2.Floor)
         ORDER BY [Priority],TaskDetailKey    
    
      END    
      ELSE    
      BEGIN    
         SELECT TOP 1 @c_TaskDetailKey = TaskDetailKey    
         FROM TaskDetail TaskDetail WITH (NOLOCK)    
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)    
         JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.Code = Loc.PickZone AND C.ListName='NKCNTM'    
         JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) 
            ON ( AreaDetail.AreaKey = C.Short AND AreaDetail.PutAwayZone = C.Long)    
         WHERE TaskDetail.Status = '0'    
         AND   TaskDetail.TaskType = 'CC'    
         AND   TaskDetail.UserKey = ''    
         AND   AreaDetail.AreaKey = @c_AreaKey01    
         AND   Loc.Floor = @c_LastLocAisle
         AND   NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD2 WITH (NOLOCK)    
                            JOIN dbo.Loc Loc2 WITH (NOLOCK) ON (TD2.FromLoc = Loc2.Loc)    
                            WHERE TD2.TaskType = 'CC'    
                            AND   TD2.Status = '3'    
                            AND   TD2.UserKey <> @c_userid    
                            AND   Loc.Floor = Loc2.Floor)
         ORDER BY [Priority],TaskDetailKey    
      END    
    
    
      IF ISNULL( @c_TaskDetailKey, '') <> ''    
      BEGIN    
         SELECT TOP 1 @c_LocAisle = LOC.Floor
         FROM dbo.TaskDetail TD WITH (NOLOCK)    
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)    
         WHERE TD.TaskDetailKey = @c_TaskDetailKey    
         ORDER BY 1    
    
         DECLARE CUR_UPDLOCAISLE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
         SELECT DISTINCT TD.TaskDetailKey    
         FROM dbo.TaskDetail TD WITH (NOLOCK)    
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)    
         WHERE LOC.Floor = @c_LocAisle
         AND   TD.Status = '0'    
         AND   TD.UserKey = ''    
         AND   TD.TaskDetailKey <> @c_TaskDetailKey  
         AND TD.TASKTYPE = 'CC'
         ORDER BY 1    
    
         OPEN CUR_UPDLOCAISLE    
         FETCH NEXT FROM CUR_UPDLOCAISLE INTO @c_TaskDetailKey2LOCK    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET    
               [Status] = '3',    
               UserKey = @c_userid,    
               EditDate = GETDATE(),    
               EditWho  = sUSER_sNAME(),    
               TrafficCop = NULL    
            WHERE TaskDetailKey = @c_TaskDetailKey2LOCK    
    
            SELECT @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Lock CC Task Failed. (nspTTMCC05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
               BREAK    
            END    
    
            FETCH NEXT FROM CUR_UPDLOCAISLE INTO @c_TaskDetailKey2LOCK    
         END    
         CLOSE CUR_UPDLOCAISLE    
         DEALLOCATE CUR_UPDLOCAISLE    
      END    
    
      DECLARE CURSOR_CCTASKCANDIDATES    
      CURSOR FOR    
      SELECT TaskDetailKey        
      FROM TaskDetail WITH (NOLOCK)
      WHERE TASKDETAILKEY = @c_TaskDetailKey        
        
      SELECT @n_err = @@ERROR        
      IF @n_err <> 0        
      BEGIN        
         SELECT @n_continue = 3        
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Of CrossDock Tasks Pick Code Failed. (nspTTMCC05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '        
      END        
   END        
        
   /* #INCLUDE <SPTMCC01_2.SQL> */        
   IF @n_continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_success = 0    
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
      execute nsp_logerror @n_err, @c_errmsg, 'nspTTMCC07'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
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