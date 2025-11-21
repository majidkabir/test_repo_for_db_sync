SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrPutawayZoneUpdate                                                 		*/
/* Creation Date:                                                                		*/
/* Copyright: IDS                                                                		*/
/* Written by:                                                                   		*/
/*                                                                               		*/
/* Purpose: Trigger point upon any Update on the PutawayZone                       		*/
/*                                                                               		*/
/* Usage:                                                                        		*/
/*                                                                               		*/
/* Local Variables:                                                              		*/
/*                                                                               		*/
/* Called By: When records updated                                               		*/
/*                                                                               		*/
/* PVCS Version: 1.1                                                             		*/
/*                                                                               		*/
/* Version: 5.4                                                                  		*/
/*                                                                               		*/
/* Data Modifications:                                                           		*/
/*                                                                               		*/
/* Updates:                                                                      		*/
/* Date         Author   		Ver  	Purposes                                          	*/
/* 17-Mar-2009  TLTING     			Change user_name() to SUSER_SNAME()                */
/* 22-May-2012  TLTING01 		1.1  	DM Integrity issue - Update editdate B4 ArchiveCop */
/* 28-Oct-2013  TLTING   		1.2  	Review Editdate column update                      */
/* 04-Mar-2022  TLTING   		1.3   WMS-19029 prevent bulk update or delete           	*/
/* 2022-04-12   kelvinongcy	1.4	amend way for control user run batch (kocy01)		*/  
/***************************************************************************************/

CREATE   TRIGGER [dbo].[ntrPutawayZoneUpdate]
 ON [dbo].[PutawayZone]
 FOR UPDATE
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

   DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
   @n_err              int,       -- Error number returned by stored procedure or this trigger
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
   @n_starttcnt        int,       -- Holds the current transaction count
   @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
 
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
 
   IF (select count(1) from DELETED WIT (NOLOCK)) = (select count(1) from DELETED WITH (NOLOCK) where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
 
   IF ( @n_continue=1 OR @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE PUTAWAYZONE WITH (ROWLOCK)
      SET EditDate = GetDate(),
          EditWho  = Suser_Sname(),
          TrafficCop = NULL
    FROM PUTAWAYZONE , INSERTED
    WHERE PUTAWAYZONE.PutawayZone = INSERTED.PutawayZone
   END 

    IF NOT UPDATE(PutawayZone)
    BEGIN
      SELECT @n_continue = 4
    END

   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=86310   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table PutawayZone. Batch Update not allow! (ntrPutawayZoneUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

      /* #INCLUDE <TRPZU1.SQL> */     
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS( SELECT 1 FROM SKU (NOLOCK), Deleted WITH (NOLOCK)
                 WHERE SKU.PutawayZone = Deleted.PutawayZone)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 86300
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PutawayZone Failed As Commodities Still Reference Zone. (ntrPutawayZoneUpdate)"
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS( SELECT 1 FROM LOC (NOLOCK), Deleted WITH (NOLOCK)
                 WHERE LOC.PutawayZone = Deleted.PutawayZone)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 86301
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PutawayZone Failed As Locations Still Reference Zone. (ntrPutawayZoneUpdate)"
      END
   END
 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS( SELECT 1 FROM PutawayStrategyDetail (NOLOCK), Deleted WITH (NOLOCK)
                 WHERE PutawayStrategyDetail.Zone = Deleted.PutawayZone)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 86302
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PutawayZone Failed As Putaway Strategy Details Still Reference Zone. (ntrPutawayZoneUpdate)"
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS( SELECT 1 FROM PAZoneEquipmentExcludeDetail (NOLOCK), Deleted WITH (NOLOCK)
                 WHERE PAZoneEquipmentExcludeDetail.PutawayZone = Deleted.PutawayZone)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 86303
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PutawayZone Failed As PAZone Equipment Exclude Details Still Reference Zone. (ntrPutawayZoneUpdate)"
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS( SELECT 1 FROM AreaDetail (NOLOCK), Deleted WITH (NOLOCK)
                 WHERE AreaDetail.PutawayZone = Deleted.PutawayZone)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 86304
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Trigger On PutawayZone Failed As Area Details Still Reference Zone. (ntrPutawayZoneUpdate)"
      END
   END
      
      /* #INCLUDE <TRPZU2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPutawayZoneUpdate"
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
 
 END  -- Main

GO