SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger:  ntrOTMLogDelete                                                           */
/* Creation Date:                                                                      */
/* Copyright: IDS                                                                      */
/* Written by:                                                                         */
/*                                                                                     */
/* Purpose:  Trigger point upon any Delete on the OTMLog                               */
/*                                                                                     */
/* Return Status:  None                                                                */
/*                                                                                     */
/* Usage:                                                                              */
/*                                                                                     */
/* Local Variables:                                                                    */
/*                                                                                     */
/* Called By: When records Deleted                                                     */
/*                                                                                     */
/* PVCS Version: 1.0                                                                   */
/*                                                                                     */
/* Version: 5.4                                                                        */
/*                                                                                     */
/* Data Modifications:                                                                 */
/*                                                                                     */
/* Updates:                                                                            */
/* Date         Author    		Ver.  Purposes                                           */
/* 2022-05-17   kelvinongcy	1.1	WMS-19673 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/
 
CREATE   TRIGGER [dbo].[ntrOTMLogDelete]
 ON [dbo].[OTMLOG]
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

   DECLARE @b_Success         int,       -- Populated by calls to stored procedures - was the proc successful?
           @n_err             int,       -- Error number returned by stored procedure or this trigger
           @c_errmsg          NVARCHAR(250), -- Error message returned by stored procedure or this trigger
           @n_continue        int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
           @n_starttcnt       int,       -- Holds the current transaction count
           @n_cnt             int,        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
           @c_authority       NVARCHAR(1)  -- KHLim02
           
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
  

   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )    --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table OTMLog. Batch Delete not allow! (ntrOTMLogDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END


      /* #INCLUDE <TRTHD2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrOTMLogDelete"
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