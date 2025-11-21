SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nspTTMEvaluatePKTasks                              */  
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
/* 29-01-2010   1.1   James      Add Parameter                          */  
/*                               RDT Compatible Error Message (james01) */  
/* 19-02-2010   1.2   Vicky      Add in SkipTask & EquipmentProfile     */  
/*                               checking (Vicky01)                     */  
/* 09-03-2010   1.3   ChewKP     Avoid same user getting same task      */  
/*                               (ChewKP01)                             */  
/* 10-03-2010   1.4   Shong      Make sure task records updated status  */  
/*                               to 3 (Shong01)                         */     
/* 01-11-2010   1.5   Shong      Separate Piece PPA Pick (SPK) and ECom */
/*                               Pick (PK) (SHONG04)                    */
/************************************************************************/  
  
CREATE PROC    [dbo].[nspTTMEvaluatePKTasks]  
@c_sendDelimiter    NVARCHAR(1)  
,              @c_userid           NVARCHAR(18)  
,              @c_strategykey      NVARCHAR(10)  
,              @c_ttmstrategykey   NVARCHAR(10)  
,              @c_ttmpickcode      NVARCHAR(10)  
,              @c_ttmoverride      NVARCHAR(10)  
,              @c_areakey01        NVARCHAR(10)  
,              @c_areakey02        NVARCHAR(10)  
,              @c_areakey03        NVARCHAR(10)  
,              @c_areakey04        NVARCHAR(10)  
,              @c_areakey05        NVARCHAR(10)  
,              @c_lastloc          NVARCHAR(10)  
,              @c_outstring        NVARCHAR(255)  OUTPUT  
,              @b_Success          INT        OUTPUT  
,              @n_err              INT        OUTPUT  
,              @c_errmsg           NVARCHAR(250)  OUTPUT  
,              @c_ptcid            NVARCHAR(5) -- (james01)  
,              @c_fromloc          NVARCHAR(10)   OUTPUT -- (james01)  
,              @c_TaskDetailKey    NVARCHAR(10)   OUTPUT -- (james01)  
AS  
BEGIN  
    SET NOCOUNT ON   
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @b_debug INT  
    SELECT @b_debug = 0  
    DECLARE @n_continue    INT  
           ,@n_starttcnt   INT -- Holds the current transaction count  
           ,@n_cnt         INT -- Holds @@ROWCOUNT after certain operations  
           ,@n_err2        INT -- For Additional Error Detection  
    DECLARE @c_retrec      NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure  
    DECLARE @n_cqty        INT  
           ,@n_returnrecs  INT  
      
    SELECT @n_starttcnt = @@TRANCOUNT  
          ,@n_continue = 1  
          ,@b_success = 0  
          ,@n_err = 0  
          ,@c_errmsg = ""  
          ,@n_err2 = 0  
      
    SELECT @c_retrec = "01"  
    SELECT @n_returnrecs = 1  
    DECLARE @c_executestmt    NVARCHAR(255)  
           ,@c_AlertMessage     NVARCHAR(255)  
           ,@b_gotarow          INT  
           ,@b_skipthetask      INT -- (Vicky01)  
    
    DECLARE @b_cursor_open      INT  
--           ,@c_TaskDetailKey    NVARCHAR(10)  
      
    DECLARE @c_storerkey        NVARCHAR(15)  
           ,@c_sku              NVARCHAR(20)  
--           ,@c_fromloc          NVARCHAR(10)  
           ,@c_fromid           NVARCHAR(18)  
           ,@c_droploc          NVARCHAR(10)  
           ,@c_dropid           NVARCHAR(18)  
           ,@c_lot              NVARCHAR(10)  
           ,@n_qty              INT  
           ,@c_packkey          NVARCHAR(15)  
           ,@c_uom              NVARCHAR(10)  
           ,@c_message01        NVARCHAR(20)  
           ,@c_message02        NVARCHAR(20)  
           ,@c_message03        NVARCHAR(20)  
           ,@c_caseid           NVARCHAR(10)  
           ,@c_orderkey         NVARCHAR(10)  
           ,@c_orderlinenumber  NVARCHAR(5)  
           ,@c_wavekey          NVARCHAR(10)  
      
    DECLARE @b_recordok         INT -- used when figuring out whether or not enough inventory exists at the source location for a move to occur.  
    SELECT @b_gotarow = 0  
          ,@b_recordok = 0  

    /* #INCLUDE <SPEVMV_1.SQL> */  
    IF @n_continue=1 OR  
       @n_continue=2  
    BEGIN  
        DECLARECURSOR_PKTASKCANDIDATES:  
        SELECT @b_cursor_open = 0  
        SELECT @n_continue = 1 -- Reset just in case the GOTO statements below get executed  
        SELECT @c_executestmt = "execute "+RTRIM(@c_ttmpickcode)   
              +" "  
              +"N'"+RTRIM(@c_userid)+"'"+","  
              +"N'"+RTRIM(@c_areakey01)+"'"+","  
              +"N'"+RTRIM(@c_areakey02)+"'"+","  
              +"N'"+RTRIM(@c_areakey03)+"'"+","  
              +"N'"+RTRIM(@c_areakey04)+"'"+","  
              +"N'"+RTRIM(@c_areakey05)+"'"+","  
              +"N'"+RTRIM(@c_lastloc)+"'"  
          
        IF @b_debug=1  
            SELECT @c_executestmt  
          
        EXECUTE (@c_executestmt)  
        SELECT @n_err = @@ERROR  
        IF @n_err<>0 AND  
           @n_err<>16915 AND  
           @n_err<>16905 -- Error #s 16915 and 16905 handled separately below  
        BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                  ,@n_err = 81101 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+  
                   ": Execute Of Move Tasks Pick Code Failed. (nspTTMEvaluatePKTasks)"   
                  +" ( "+" SQLSvr MESSAGE="+RTRIM(@c_errmsg)   
                  +" ) "  
        END  
          
        IF @n_err=16915  
        BEGIN  
            CLOSE CURSOR_PKTASKCANDIDATES  
            DEALLOCATE CURSOR_PKTASKCANDIDATES  
            GOTO DECLARECURSOR_PKTASKCANDIDATES  
        END  

        OPEN CURSOR_PKTASKCANDIDATES  
        SELECT @n_err = @@ERROR  
              ,@n_cnt = @@ROWCOUNT  
          
        IF @n_err=16905  
        BEGIN  
            CLOSE CURSOR_PKTASKCANDIDATES  
            DEALLOCATE CURSOR_PKTASKCANDIDATES  
            GOTO DECLARECURSOR_PKTASKCANDIDATES  
        END  
          
        IF @n_err=0  
        BEGIN  
            SELECT @b_cursor_open = 1  
        END  
    END  

    IF (@n_continue=1 OR @n_continue=2) AND  
       @b_cursor_open=1  
    BEGIN  
        WHILE (1=1) AND  
              (@n_continue=1 OR @n_continue=2)  
        BEGIN  
            SELECT @b_recordok = 0  
            SET @c_TaskDetailKey = ''  
  
            FETCH NEXT FROM CURSOR_PKTASKCANDIDATES  
            INTO @c_TaskDetailKey,   
                 @c_caseid,   
                 @c_orderkey,   
                 @c_orderlinenumber,  
                 @c_wavekey,   
                 @c_storerkey,   
                 @c_sku,   
                 @c_lot,   
                 @c_fromloc,   
                 @c_fromid,  
                 @c_packkey,   
                 @c_uom,   
                 @n_qty,   
                 @c_message01,   
                 @c_message02,   
                 @c_message03  
            IF @@FETCH_STATUS=-1  
            BEGIN  
                BREAK  
            END  
            ELSE   
            IF ISNULL(RTRIM(@c_TaskDetailKey),'') <> '' -- (Shong01)   
            BEGIN  
                SELECT @b_recordok = 1  
                  
                -- (Vicky01) - Start  
                SELECT @b_success = 0, @b_skipthetask = 0  
                EXECUTE nspCheckSkipTasks  
                  @c_userid  
                , @c_TaskDetailKey  
                , 'PK'  
                , ''  
                , ''  
                , ''  
                , ''  
                , ''  
                , ''  
                , @b_skipthetask OUTPUT  
                , @b_Success OUTPUT  
                , @n_err OUTPUT  
                , @c_errmsg OUTPUT  
  
                IF @b_success <> 1  
                BEGIN  
                   SELECT @n_continue=3  
                END  

                IF @b_skipthetask = 1  
                BEGIN  
                   CONTINUE  
                END  

                SELECT @b_success = 0  
                EXECUTE    nspCheckEquipmentProfile  
                               @c_userid       = @c_userid  
                ,              @c_TaskDetailKey= @c_TaskDetailKey  
                ,              @c_storerkey    = @c_storerkey  
                ,              @c_sku          = @c_sku  
                ,              @c_lot          = @c_lot  
                ,              @c_fromLoc      = @c_fromloc  
                ,              @c_fromID       = @c_fromid  
                ,              @c_toLoc        = ''--@c_toloc  
                ,              @c_toID         = ''--@c_toid  
                ,              @n_qty          = @n_qty  
                ,              @b_Success      = @b_success    OUTPUT  
                ,              @n_err          = @n_err        OUTPUT  
                ,              @c_errmsg       = @c_errmsg     OUTPUT  
                  
                IF @b_success = 0  
                BEGIN  
                   CONTINUE  
                END  
                -- (Vicky01) - End  

                IF NOT EXISTS(
                       SELECT 1
                       FROM   TASKDETAIL WITH (ROWLOCK)
                       WHERE  TaskDetailKey = @c_TaskDetailKey
                              AND STATUS = '3'
                              AND UserKey = @c_userid
                   )
                BEGIN
                    UPDATE TASKDETAIL WITH (ROWLOCK)
                    SET    STATUS = '3'
                          ,UserKey = @c_userid
                          ,Reasonkey = ''
                          ,StartTime = CURRENT_TIMESTAMP
                    WHERE  TaskDetailKey = @c_TaskDetailKey
                           AND STATUS IN ('0') -- (ChewKP01) 
                    
                    IF @@RowCount=0 -- (ChewKP01)
                    BEGIN
                        CONTINUE
                    END
                END 

                -- (Shong01) 
                IF NOT EXISTS(
                       SELECT 1
                       FROM   TASKDETAIL WITH (ROWLOCK)
                       WHERE  TaskDetailKey = @c_TaskDetailKey
                              AND STATUS = '3'
                              AND UserKey = @c_userid
                   )
                BEGIN
                    CONTINUE
                END
                ELSE
                    -- Task assiged Sucessfully, Quit Now!!!
                    BREAK  
            END  
  
              
            IF ISNULL(RTRIM(@c_TaskDetailKey),'') = '' -- The record in the cursor is blank!  
            BEGIN  
                SELECT @b_recordok = 0  
                CONTINUE  
            END  
              
            SELECT @b_gotarow = 1  
            BREAK  
        END -- WHILE (1=1)  
    END  

    IF @b_cursor_open=1  
    BEGIN  
        CLOSE CURSOR_PKTASKCANDIDATES  
        DEALLOCATE CURSOR_PKTASKCANDIDATES  
    END  
      
    IF @n_continue=3  
    BEGIN  
        IF @c_retrec="01"  
        BEGIN  
            SELECT @c_retrec = "09"  
        END  
    END  
    ELSE  
    BEGIN  
        SELECT @c_retrec = "01"  
    END  

--    IF (@n_continue=1 OR @n_continue=2) AND  
--       @b_gotarow=1  
--    BEGIN  
--        --CCLAW  
--        --FBR28d  
--        IF EXISTS (  
--               SELECT 1  
--               FROM   NSQLCONFIG(NOLOCK)  
--               WHERE  NSQLVALUE = '1' AND  
--                      CONFIGKEY = 'PUTAWAYTASK'  
--           )  
--        BEGIN  
--            --Need to return logicaltoloc as toloc for FBR28d.  
--            SELECT @c_droploc = logicaltoloc  
--                  ,@c_dropid = fromid  
--            FROM   TaskDetail(NOLOCK)  
--            WHERE  taskdetailkey = @c_TaskDetailKey  
--        END  
--        ELSE  
--        BEGIN  
--            --Base script didn't set the value of toloc and toid.  
--            SELECT @c_droploc = toloc  
--                  ,@c_dropid = fromid  
--            FROM   TaskDetail(NOLOCK)  
--            WHERE  taskdetailkey = @c_TaskDetailKey  
--        END  
--        SELECT @c_outstring = @c_TaskDetailKey+@c_senddelimiter  
--              +RTrim(@c_storerkey)+@c_senddelimiter  
--              +RTrim(@c_sku)+@c_senddelimiter  
--              +RTrim(@c_fromloc)+@c_senddelimiter  
--              +RTrim(@c_fromid)+@c_senddelimiter  
--              +RTrim(@c_droploc)+@c_senddelimiter  
--              +RTrim(@c_dropid)+@c_senddelimiter  
--              +RTrim(@c_lot)+@c_senddelimiter  
--              +RTrim(CONVERT(CHAR(10) ,@n_qty))+@c_senddelimiter  
--              +RTrim(@c_packkey)+@c_senddelimiter  
--              +RTrim(@c_uom)+@c_senddelimiter  
--              +RTrim(@c_caseid)+@c_senddelimiter  
--              +RTrim(@c_message01)+@c_senddelimiter  
--              +RTrim(@c_message02)+@c_senddelimiter  
--              +RTrim(@c_message03)  
--                
--  
--    END  
--    ELSE  
--    BEGIN  
--        SELECT @c_outstring = ""  
--    END  
    /* #INCLUDE <SPEVMV_2.SQL> */  
 /* #INCLUDE <SPEVPA_2.SQL> */  
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
       execute nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluatePKTasks'  
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