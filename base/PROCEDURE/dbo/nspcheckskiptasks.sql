SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: nspCheckSkipTasks                                  */      
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
/* Date         Ver.  Author     Purposes                               */      
/* 28-09-2009   1.1   Vicky      RDT Compatible Error Message (Vicky01) */      
/* 22-07-2010   1.2   Vicky      Bug Fix (Vicky02)                      */      
/* 02-09-2010   1.3   ChewKP     Reduce checking to 1 mins (ChewKP01)   */    
/* 06-10-2010   1.4   Shong      Use System Config for interval intead  */  
/*                               of hardcoding (Shong01)                */  
/* 04-12-2014   1.5   TLTING     Performance Tune                       */  
/* 23-10-2015   1.6   James      Add skip task for TM CC (james01)      */
/* 04-07-2016   1.7   TLTING02   Performance Tune                       */  
/************************************************************************/      
      
CREATE  PROC    [dbo].[nspCheckSkipTasks]      
               @c_userid       NVARCHAR(18)      
,              @c_taskdetailkey NVARCHAR(10)      
,              @c_tasktype     NVARCHAR(10)      
,              @c_caseid       NVARCHAR(10)      
,              @c_lot          NVARCHAR(10)      
,              @c_FromLoc      NVARCHAR(10)      
,              @c_FromID       NVARCHAR(18)      
,              @c_ToLoc        NVARCHAR(10)      
,              @c_ToId         NVARCHAR(18)      
,              @b_skipthetask  int        OUTPUT      
,              @b_Success      int        OUTPUT      
,              @n_err          int        OUTPUT      
,              @c_errmsg       NVARCHAR(250)  OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_continue   int,      
            @n_starttcnt  int, -- Holds the current transaction count      
            @c_preprocess NVARCHAR(250), -- preprocess      
            @c_pstprocess NVARCHAR(250), -- post process      
            @n_cnt        int,      
            @n_err2       int        -- For Additional Error Detection      
      
   SELECT @n_starttcnt = @@TRANCOUNT,       
          @n_continue = 1,       
          @b_success = 0,      
          @n_err = 0,      
          @c_errmsg = '',       
          @n_err2 = 0      
   /* #INCLUDE <SPCST1.SQL> */      
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN      
      DECLARE @d_cdate datetime   
      DECLARE @c_STTaskDetailKey NVARCHAR(10) 
      DECLARE @c_STuserid        NVARCHAR(18)          
        
      -- (Shong01) Start  
      DECLARE @nSkipTimeInterval INT  
        
      SET @nSkipTimeInterval = 0   
      SELECT @nSkipTimeInterval = ISNULL(CASE WHEN ISNUMERIC(n.NSQLValue) = 1 THEN n.NSQLValue ELSE 0 END,0)   
      FROM   NSQLCONFIG n WITH (NOLOCK)   
      WHERE  n.ConfigKey = 'TMSkipTime'   
        
      SELECT @d_cdate = getdate()      
        
      IF @nSkipTimeInterval > 0   
      BEGIN  
         SET @nSkipTimeInterval = @nSkipTimeInterval * -1  
         --SELECT @d_cdate = dateadd(hh,-1, @d_cdate) -- (ChewKP01)      
         SELECT @d_cdate = dateadd(mi, @nSkipTimeInterval, @d_cdate) -- (Shong01)             
      END  
      -- (Shong01) End  
      
      
      IF EXISTS ( SELECT 1 FROM TASKMANAGERSKIPTASKS WITH (NOLOCK)     
                  WHERE adddate <= @d_cdate  )
      BEGIN  
         -- tlting02 performance tune
         DECLARE Cursor_Taskitems  CURSOR LOCAL FAST_FORWARD READ_ONLY   
         FOR  
         SELECT TaskDetailKey, userid
            FROM TASKMANAGERSKIPTASKS WITH (NOLOCK)     
            WHERE adddate <= @d_cdate  

         OPEN Cursor_Taskitems 
	         FETCH NEXT FROM Cursor_Taskitems INTO @c_STTaskDetailKey, @c_STuserid 
	         WHILE @@FETCH_STATUS = 0 AND (@n_continue = 1 or @n_continue = 2 )
	         BEGIN               
         
               DELETE TASKMANAGERSKIPTASKS with (rowlock) 
               WHERE TaskDetailKey = @c_STTaskDetailKey
               AND  userid = @c_STuserid      
         
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT      
               IF @n_err <> 0      
               BEGIN      
                  SELECT @n_continue = 3      
                  SELECT @n_err = 67778--85501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Occurred While Attempting To Update TaskManagerSkipTasks. (nspCheckTaskManagerSkipTasks)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
               END   
		      FETCH NEXT FROM Cursor_Taskitems INTO @c_STTaskDetailKey, @c_STuserid
	      END
	      CLOSE Cursor_Taskitems 
	      DEALLOCATE Cursor_Taskitems                    
      END
   END      
      
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN      
      IF @c_tasktype = 'PK'      
      BEGIN      
         IF EXISTS(SELECT 1 FROM TASKMANAGERSKIPTASKS WITH (NOLOCK)      
                   WHERE userid = @c_userid      
                   AND tasktype = 'PK'      
                   -- AND caseid = @c_caseid      
                   AND taskdetailkey = @c_taskdetailkey) -- (Vicky02)      
         BEGIN      
            SELECT @b_skipthetask = 1      
         END      
      END      
      
      IF @c_tasktype = 'RP'      
      BEGIN      
         IF EXISTS(SELECT 1 FROM TASKMANAGERSKIPTASKS WITH (NOLOCK)      
        WHERE userid = @c_userid      
                   AND tasktype = 'RP'      
                   AND lot = @c_lot      
                   AND fromloc = @c_fromloc      
                   AND fromid = @c_fromid      
                   AND toloc = @c_toloc      
                   and toid = @c_toid)      
         BEGIN      
            SELECT @b_skipthetask = 1      
         END      
      END      
      
      IF @c_tasktype <> 'PK' and @c_tasktype <> 'RP'      
      BEGIN      
         IF EXISTS(SELECT 1 FROM TASKMANAGERSKIPTASKS WITH (NOLOCK)      
                   WHERE taskdetailkey = @c_taskdetailkey      
                   AND userid = @c_userid)      
         BEGIN      
            SELECT @b_skipthetask = 1      
         END      
      END      

      -- (james02)
      IF @c_tasktype LIKE 'CC%'      
      BEGIN      
         IF EXISTS(SELECT 1 FROM TASKMANAGERSKIPTASKS WITH (NOLOCK)      
                   WHERE userid = @c_userid      
                   AND tasktype LIKE 'CC%'       
                   AND taskdetailkey = @c_taskdetailkey)       
         BEGIN      
            SELECT @b_skipthetask = 1      
         END      
      END      
   END      
      
   /* #INCLUDE <SPCST2.SQL> */      
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
         execute nsp_logerror @n_err, @c_errmsg, 'nspCheckSkipTasks'      
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