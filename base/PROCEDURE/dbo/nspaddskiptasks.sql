SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspAddSkipTasks                                    */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
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
/* 03-09-2010  ChewKP         Remove UserKey, Reasonkey when insert into*/    
/*                            TaskManagerSkipTask table (ChewKP01)      */    
/* 04-09-2010   ChewKP        Insert same DropID Task into SkipTask for */    
/*          the same zone                               (ChewKP02)      */    
/* 09-09-2010   ChewKP        Bug Fixes (CheWKP03)                      */    
/* 10-12-2010   James         Add (NOLOCK) (james01)                    */    
/* 27-05-2014   ChewKP        Extend ChildID > 20 Char (ChewKP03)       */ 
/* 23-08-2014   ChewKP        Only Skip Task with Same Zone (ChewKP04)  */ 
/* 04-12-2014   TLTING        Performance Tune                          */   
/************************************************************************/    
CREATE PROC    [dbo].[nspAddSkipTasks]    
 @c_ptcid        NVARCHAR(10)    
 ,              @c_userid       NVARCHAR(18)    
 ,              @c_taskdetailkey NVARCHAR(10)    
 ,              @c_tasktype     NVARCHAR(10)    
 ,              @c_caseid       NVARCHAR(20)  -- (ChewKP03)  
 ,              @c_lot          NVARCHAR(10)    
 ,              @c_FromLoc      NVARCHAR(10)    
 ,              @c_FromID       NVARCHAR(18)    
 ,              @c_ToLoc        NVARCHAR(10)    
 ,              @c_ToId         NVARCHAR(18)    
 ,              @b_Success      int        OUTPUT    
 ,              @n_err          int        OUTPUT    
 ,              @c_errmsg       NVARCHAR(250)  OUTPUT    
 AS    
 BEGIN    
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE        @n_continue int        ,    
   @n_starttcnt int        , -- Holds the current transaction count    
   @c_preprocess NVARCHAR(250) , -- preprocess    
   @c_pstprocess NVARCHAR(250) , -- post process    
   @n_cnt int              ,    
   @n_err2 int,              -- For Additional Error Detection    
   --@c_FromLoc NVARCHAR(10),   -- (ChewKP02)    
   @c_DropID  NVARCHAR(18),    -- (ChewKP02)    
   @c_RTaskDetailkey NVARCHAR(10), -- (ChewKP02)    
   @c_Putawayzone NVARCHAR(10),  -- (ChewKP02)    
   @c_Reasonkey NVARCHAR(10),    -- (ChewKP02)    
   @c_AreaKey   NVARCHAR(10)    -- (ChewKP04) 
       
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0    
   /* #INCLUDE <SPAST1.SQL> */    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      IF @c_tasktype = "PK"    
      BEGIN    
         SET @c_AreaKey = ''
         
         SELECT @c_AreaKey = AreaKey 
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @c_taskdetailkey
         
         INSERT TaskManagerSkipTasks (userid,taskdetailkey,tasktype,lot,fromloc,toloc,fromid,toid,caseid)    
         SELECT @c_userid,taskdetailkey,"PK",lot,fromloc,toloc,fromid,toid, caseid    
         FROM TASKDETAIL WITH (NOLOCK) -- (james01)   
         WHERE taskdetailkey = @c_taskdetailkey    
    
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=85601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Add To TaskManagerSkipTasks. (nspAddSkipTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
         END    
    
         -- Start (ChewKP02)    
         INSERT INTO TaskManagerSkipTasks (userid,taskdetailkey,tasktype,lot,fromloc,toloc,fromid,toid,caseid)    
         SELECT @c_userid,taskdetailkey,"PK",lot,fromloc,toloc,fromid,toid, caseid    
         FROM TASKDETAIL WITH (NOLOCK)     
         WHERE UserKey = @c_userid    
               AND Status = '3'    
               AND AreaKey = CASE WHEN @c_AreaKey = '' THEN AreaKey ELSE @c_AreaKey END -- (ChewKP04)
             
    
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=85601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Add To TaskManagerSkipTasks. (nspAddSkipTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
         END    
         -- End (ChewKP02)    
      END    
   END    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      IF @c_tasktype = "RP"    
      BEGIN    
         INSERT TaskManagerSkipTasks (userid,taskdetailkey,tasktype,lot,fromloc,toloc,fromid,toid,caseid)    
         SELECT @c_userid,"","RP",lot,fromloc,toloc,id,id,""    
         FROM REPLENISHMENT_LOCK WITH (NOLOCK) -- (ChewKP03)    
         WHERE ptcid = @c_ptcid    
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=85601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Add To TaskManagerSkipTasks. (nspAddSkipTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
         END    
      END    
   END    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      IF @c_tasktype <> "PK" and @c_tasktype <> "RP"    
      BEGIN    
         INSERT TaskManagerSkipTasks (userid,taskdetailkey,tasktype,lot,fromloc,toloc,fromid,toid,caseid)    
         SELECT @c_userid,taskdetailkey,@c_tasktype,lot,fromloc,toloc,fromid,toid,caseid    
         FROM TASKDETAIL WITH (NOLOCK) -- (ChewKP03)    
         WHERE taskdetailkey = @c_taskdetailkey    
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=85601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Add To TaskManagerSkipTasks. (nspAddSkipTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
         END    
      END    
   END    
       
   IF @n_continue = 1 or @n_continue = 2 -- (ChewKP01) / (ChewKP02)    
   BEGIN    
      SELECT @c_FromLOC = FROMLOC,   
             @c_DropID = DropID,   
             @c_Reasonkey = Reasonkey   
      FROM TaskDetail WITH (NOLOCK)    
      WHERE TaskDetailkey = @c_taskdetailkey    
        
     --SET Reasonkey = '' , Userkey = '' , --,  TrafficCop = NULL -- (ChewKP03)    

      -- tlting
      IF EXISTS ( SELECT 1 FROM TaskDetail WITH (NOLOCK)
                  WHERE Taskdetailkey = @c_taskdetailkey 
                  AND ( Reasonkey <> '' OR Userkey <> '' OR Status <> '0' ) ) 
      BEGIN          
         UPDATE TaskDetail WITH (ROWLOCK)    
             SET Reasonkey = '' , Userkey = '' , Status = '0', Trafficcop = NULL, EditDate = GETDATE()  --,  TrafficCop = NULL -- (ChewKP03)      
         WHERE Taskdetailkey = @c_taskdetailkey    
       
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
          IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=85601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Update TaskDetail. (nspAddSkipTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
            END    
       END
            
    DECLARE curDropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
    SELECT TaskDetailkey      
         FROM dbo.TaskDetail TD WITH (NOLOCK)     
         --INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Putawayzone = @c_Putawayzone -- (ChewKP03)    
         --WHERE DropID = @c_DropID    
         WHERE Userkey = @c_userID     
         AND Status = '3'    
    
    OPEN curDropID    
    FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey    
    WHILE @@FETCH_STATUS <> -1    
    BEGIN  
      --SET Reasonkey = '' , Userkey = '' , --,  TrafficCop = NULL -- (ChewKP03)             
       UPDATE TaskDetail WITH (ROWLOCK)    
          SET Reasonkey = '' , Userkey = '' , Status = '0',   
              Trafficcop = NULL, EditDate = GETDATE()  --,  TrafficCop = NULL -- (ChewKP03)      
       WHERE Taskdetailkey = @c_RTaskDetailkey    
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=85601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Update TaskDetail. (nspAddSkipTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
       END    
             
       FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey    
    END    
    CLOSE curDropID    
    DEALLOCATE curDropID      
 END    
       
   /* #INCLUDE <SPAST2.SQL> */    
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
      execute nsp_logerror @n_err, @c_errmsg, "nspAddSkipTasks"    
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