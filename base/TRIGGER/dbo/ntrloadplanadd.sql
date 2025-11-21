SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrLoadPlanAdd                                                 */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author     Ver   Purposes                                  */
/* 05-Jun-2017  Leong            IN00365955 - Add Log for missing header.  */
/*                               (temp only).                              */
/* 27-Jul-2017  TLTING     1.1   Set Option                                */
/***************************************************************************/

CREATE TRIGGER [dbo].[ntrLoadPlanAdd]
ON [dbo].[LoadPlan]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
        @b_Success     INT           -- Populated by calls to stored procedures - was the proc successful?
      , @n_err         INT           -- Error number returned by stored procedure OR this trigger
      , @n_err2        INT           -- For Additional Error Detection
      , @c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
      , @n_continue    INT
      , @n_starttcnt   INT           -- Holds the current transaction count
      , @c_preprocess  NVARCHAR(250) -- preprocess
      , @c_pstprocess  NVARCHAR(250) -- post process
      , @n_cnt         INT

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

   -- IN00365955 (Start)
   DECLARE @c_LoadKey   NVARCHAR(10)
         , @c_Facility  NVARCHAR(5)
         , @c_FieldName NVARCHAR(30)

   SELECT @c_LoadKey   = LoadKey
        , @c_Facility  = Facility
        , @c_FieldName = 'LPHEADER'
   FROM INSERTED

   EXEC isp_Sku_log
        @cStorerKey = @c_LoadKey
      , @cSKU       = @c_Facility
      , @cFieldName = @c_FieldName
      , @cOldValue  = ''
      , @cNewValue  = 'INSERTED'
   -- IN00365955 (End)

   /* #INCLUDE <TRMBOA1.SQL> */
   -- Added By SHONG
   -- 30th Apr 2003
   -- Do Nothing when ArchiveCop = '9'
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = "9")
      BEGIN
         SELECT @n_continue = 4
      END
   END
   -- END 30th Apr 2003

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT * FROM INSERTED WHERE Status = "9")
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 72602
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Bad LoadPlan.Status. (ntrLoadPlanAdd)"
      END
   END

   /* #INCLUDE <TRMBOHA2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrLoadPlanAdd"
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