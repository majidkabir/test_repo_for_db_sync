SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/  
/* Store Procedure:  ntrrdtPTLPieceLogDelete                                     */  
/* Copyright: LF Logistics                                                       */  
/*                                                                               */  
/* Purpose:  VFCDC Debugging Script                                              */  
/*                                                                               */  
/* Modification log:                                                             */  
/* Date         Author     Ver   Purposes                                        */  
/* 15-Apr-2022  yeekung    1.0   Created                                         */  
/* 31-05-2022   kocy       1.1   restructure dellog table for DM sync            */ 
/*********************************************************************************/  
CREATE   TRIGGER [RDT].[ntrrdtPTLPieceLogDelete]  
ON  [RDT].[rdtPTLPieceLog]  
FOR DELETE  
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
  
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
  
   DECLARE  
      @b_Success            int           -- Populated by calls to stored procedures - was the proc successful?  
     ,@n_err                int           -- Error number returned by stored procedure or this trigger  
     ,@n_err2               int           -- For Additional Error Detection  
     ,@c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
     ,@n_continue           int  
     ,@n_starttcnt          int           -- Holds the current transaction count  
     ,@c_preprocess         NVARCHAR(250) -- preprocess  
     ,@c_pstprocess         NVARCHAR(250) -- post process  
     ,@profiler             NVARCHAR(80)  
     ,@n_cnt                int
     ,@c_authority       NVARCHAR(1)  -- KHLim02
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   /* #INCLUDE <TRTHD1.SQL> */      
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
               ,@c_errmsg = 'ntrrdtPTLPieceLogDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO rdt.rdtPTLPieceLog_DELLOG ( RowRefSource )
         SELECT RowRef FROM DELETED WITH (NOLOCK)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table rdtPTLPieceLog Failed. (ntrrdtPTLPieceLogDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN 
      INSERT INTO rdt.rdtPTLPieceLog_Log (
      [Station],[IPAddress],[Position],[LOC],[Method],[CartonID],[OrderKey],[LoadKey],[WaveKey],[PickSlipNo],
      [BatchKey],[ConsigneeKey],[ShipTo],[StorerKey],[MaxTask],[UserDefine01],[UserDefine02],[UserDefine03],[SourceKey],[SourceType],
      [AddWho],[AddDate],[EditWho],[EditDate],[SKU],[DropID])
      SELECT 
      [Station],[IPAddress],[Position],[LOC],[Method],[CartonID],[OrderKey],[LoadKey],[WaveKey],[PickSlipNo],
      [BatchKey],[ConsigneeKey],[ShipTo],[StorerKey],[MaxTask],[UserDefine01],[UserDefine02],[UserDefine03],[SourceKey],[SourceType],
      [AddWho],[AddDate],[EditWho],[EditDate],[SKU],[DropID]
      FROM DELETED WITH (NOLOCK)

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table RDT.rdtPTLPieceLog Failed. (ntrrdtPTLPieceLogDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
      END      
   END
   
QUIT:  
 
   /* #INCLUDE <TRRDA2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
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
         IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
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
         execute nsp_logerror @n_err, @c_errmsg, "ntrrdtPTLPieceLogDelete"  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL 2012 (Jay01)  
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
END

GO