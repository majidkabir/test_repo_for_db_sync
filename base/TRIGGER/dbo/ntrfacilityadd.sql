SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Trigger: ntrFacilityAdd                                                       */
/* Creation Date: 08-May-2023                                                    */
/* Copyright: MAERSK                                                             */
/* Written by: WLChooi                                                           */
/*                                                                               */
/* Purpose: WMS-22471 - Trigger for inserting Facility table                     */
/*                                                                               */
/* Return Status:                                                                */
/*                                                                               */
/* Usage:                                                                        */
/*                                                                               */
/* Called By: When records Added                                                 */
/*                                                                               */
/* PVCS Version: 1.0                                                             */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Modifications:                                                                */
/* Date         Author    Ver  Purposes                                          */
/* 08-May-2023  WLChooi   1.0  DevOps Combine Script                             */
/*********************************************************************************/
  
CREATE   TRIGGER [dbo].[ntrFacilityAdd]  
ON  [dbo].[FACILITY]   
FOR INSERT  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_Success int          -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err int              -- Error number returned by stored procedure or this trigger  
         , @c_errmsg NVARCHAR(250)     -- Error message returned by stored procedure or this trigger  
         , @n_continue int                   
         , @n_starttcnt int        -- Holds the current transaction count  
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE TRIM(SiteID) = '')
   BEGIN      
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67410   -- Should Be Set To The SQL Err message but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": INSERT Failed On Table Facility. Not allow INSERT blank SiteID! (ntrFacilityAdd)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrFacilityAdd'  
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