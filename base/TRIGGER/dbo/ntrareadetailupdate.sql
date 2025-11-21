SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/    
/* Trigger: ntrAreaDetailUpdate                                                        */    
/* Creation Date:                                                                      */    
/* Copyright: IDS                                                                      */    
/* Written by:                                                                         */    
/*                                                                                     */    
/* Purpose:                                                                            */    
/*                                                                                     */    
/* Input Parameters:                                                                   */    
/*                                                                                     */    
/* Output Parameters:                                                                  */    
/*                                                                                     */    
/* Return Status:                                                                      */    
/*                                                                                     */    
/* Usage:                                                                              */    
/*                                                                                     */    
/* Local Variables:                                                                    */    
/*                                                                                     */    
/* Called By: When records updated                                                     */    
/*                                                                                     */    
/* PVCS Version: 1.1                                                                   */    
/*                                                                                     */    
/* Version: 5.4                                                                        */    
/*                                                                                     */    
/* Data Modifications:                                                                 */    
/*                                                                                     */    
/* Updates:                                                                            */    
/* Date         Author        Ver   Purposes                                           */    
/* 28-Feb-2011  Leong         1.1   SOS# 207014 - Update EditDate & EditWho            */    
/* 28-Oct-2013  TLTING        1.2   Review Editdate column update                      */    
/* 2022-05-17   kelvinongcy	1.3	WMS-19673 prevent bulk update or delete (kocy01)	*/   
/***************************************************************************************/    
    
CREATE   TRIGGER [dbo].[ntrAreaDetailUpdate]    
ON [dbo].[AreaDetail]    
FOR UPDATE    
AS    
BEGIN    
   IF @@ROWCOUNT = 0    
   BEGIN    
      RETURN    
   END    
  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Success   int,       -- Populated by calls to stored procedures - was the proc successful?    
           @n_err       int,       -- Error number returned by stored procedure or this trigger    
           @c_errmsg    NVARCHAR(250), -- Error message returned by stored procedure or this trigger    
           @n_continue  int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing    
           @n_starttcnt int,       -- Holds the current transaction count    
           @n_cnt       int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.    
    
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT    
   
   IF (SELECT COUNT(*) FROM DELETED WITH (NOLOCK)) = (SELECT COUNT(*) FROM DELETED WITH (NOLOCK) WHERE DELETED.ArchiveCop = '9')    
   BEGIN    
      SELECT @n_continue = 4    
   END    
    
   --SOS# 207014 (Start)    
   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)    
   BEGIN    
      UPDATE AreaDetail WITH (ROWLOCK)    
      SET EditWho = SUSER_NAME(),    
          EditDate = GETDATE()    
      FROM AreaDetail   
      JOIN INSERTED ON AreaDetail.AreaKey = INSERTED.AreaKey    
      AND AreaDetail.PutawayZone = INSERTED.PutawayZone    
    
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
      IF @n_err <> 0    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=86402    
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On AreaDetail. (ntrAreaDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '    
      END    
    
   END    
   --SOS# 207014 (End)    
    
   IF NOT UPDATE(AreaKey)    
   BEGIN    
      SELECT @n_continue = 4    
   END    
    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      IF EXISTS(SELECT * FROM PutawayStrategyDetail WITH (NOLOCK), DELETED WITH (NOLOCK)    
                WHERE PutawayStrategyDetail.AreaTypeExclude01 = DELETED.AreaKey    
                OR PutawayStrategyDetail.AreaTypeExclude02 = DELETED.AreaKey    
                OR PutawayStrategyDetail.AreaTypeExclude03 = DELETED.AreaKey)    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 86400    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On AreaDetail Failed As Putaway Strategy Details Still Reference Area. (ntrAreaDetailUpdate)"    
      END    
   END    
    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      IF EXISTS(SELECT * FROM TaskManagerUserDetail WITH (NOLOCK) , DELETED WITH (NOLOCK)   
                WHERE TaskManagerUserDetail.AreaKey = DELETED.AreaKey)    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 86401    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On AreaDetail Failed As Task manager User Details Still Reference Area. (ntrAreaDetailUpdate)"    
      END    
   END    
    
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01    
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())    
   BEGIN          
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=86403   -- Should Be Set To The SQL Err message but I don't know how to do so.    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table AreaDetail. Batch Update not allow! (ntrAreaDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "    
   END    
    
    
   IF @n_continue=3  -- Error Occured - Process And Return    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrAreaDetailUpdate"    
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