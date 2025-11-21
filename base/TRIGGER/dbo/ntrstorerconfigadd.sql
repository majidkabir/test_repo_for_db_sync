SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: ntrStorerConfigAdd                                          */  
/* Creation Date: 2021-11-26                                            */  
/* Copyright: LFL                                                       */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose:  Insert StorerConfig                                        */  
/*                                                                      */  
/* Return Status:                                                       */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: When records Inserted                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Modifications:                                                       */  
/* Date         Author  Ver   Purposes                                  */
/* 26-Nov-2021  Wan01   1.0   Created.                                  */
/* 26-Nov-2021  Wan01   1.0   WMS-18410 - [RG] Logitech Tote ID Packing */
/*                            Change Request                            */
/* 26-Nov-2021  Wan01   1.0   DevOps Conbine Script                     */
/************************************************************************/  
CREATE TRIGGER ntrStorerConfigAdd ON STORERCONFIG 
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug        int = 0   
 
   DECLARE @b_Success      int = 1        -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err          int = 0        -- Error number returned by stored procedure or this trigger    
         , @n_err2         int = 0        -- For Additional Error Detection    
         , @c_errmsg       NVARCHAR(250) = '' -- Error message returned by stored procedure or this trigger    
         , @n_continue     int = 1                     
         , @n_starttcnt    int = @@TRANCOUNT  -- Holds the current transaction count    

   IF @n_continue=1 OR @n_continue=2 
   BEGIN
      IF EXISTS ( SELECT 1 FROM INSERTED 
                  WHERE INSERTED.Configkey = 'AdvancePackGenCartonNo'
                  AND INSERTED.SValue IN ('1')
                  AND INSERTED.Facility = ''
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) 
                              WHERE ph.Storerkey = INSERTED.Storerkey
                              AND ph.[Status] < '9' ) 
                  UNION  
                  SELECT 1 FROM INSERTED 
                  WHERE INSERTED.Configkey = 'AdvancePackGenCartonNo'
                  AND INSERTED.SValue IN ('1')
                  AND INSERTED.Facility <> ''
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) 
                              JOIN dbo.ORDERS AS o WITH (NOLOCK) ON ph.OrderKey = o.OrderKey AND ph.OrderKey <> ''
                              WHERE ph.Storerkey = INSERTED.Storerkey
                              AND o.Facility = INSERTED.Facility
                              AND ph.[Status] < '9')
                  UNION  
                  SELECT 1 FROM INSERTED 
                  WHERE INSERTED.Configkey = 'AdvancePackGenCartonNo'
                  AND INSERTED.SValue IN ('1')
                  AND INSERTED.Facility <> ''
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) 
                              JOIN dbo.LoadPlan AS lp WITH (NOLOCK) ON ph.Loadkey = lp.LoadKey AND ph.OrderKey = ''
                              WHERE ph.Storerkey = INSERTED.Storerkey
                              AND lp.Facility = INSERTED.Facility
                              AND ph.[Status] < '9')   )
      BEGIN
         SET @n_continue = 3
         SET @n_err=62501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to change ''AdvancePackGenCartonNo'' setting. Pack Not confirm found. (ntrStorerConfigAdd).'
      END
   END

   /* #INCLUDE <TRRDA2.SQL> */    
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
      execute nsp_logerror @n_err, @c_errmsg, "ntrStorerConfigAdd"    
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