SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/  
/* Trigger: ntrFacilityUpdate                                              		*/  
/* Creation Date:                                                          		*/  
/* Copyright: IDS                                                          		*/  
/* Written by:                                                             		*/  
/*                                                                         		*/  
/* Purpose:  Update Facility.                                              		*/  
/*                                                                         		*/  
/* Return Status:                                                          		*/  
/*                                                                         		*/  
/* Usage:                                                                  		*/  
/*                                                                         		*/  
/* Called By: When records Updated                                         		*/  
/*                                                                         		*/  
/* PVCS Version: 1.4                                                       		*/  
/*                                                                         		*/  
/* Version: 5.4                                                            		*/  
/*                                                                         		*/  
/* Modifications:                                                          		*/  
/* Date         Author   		Ver  Purposes                                     	*/
/* 28-Oct-2013  TLTING   		1.0  Review Editdate column update                	*/  
/* 26-Jun-2018  NJOW01   		1.1  WMS-5221 disallow update type to PHYSICAL    	*/
/* 04-Mar-2022  TLTING   		1.2  WMS-19029 prevent bulk update or delete      	*/
/* 2022-04-12   kelvinongcy	1.3  amend way for control user run batch (kocy01)	*/  
/* 08-May-2023  WLChooi       1.4  WMS-22471 - not allow update SiteID to blank  */
/*                                 (WL01)                                        */
/* 08-May-2023  WLChooi       1.4  DevOps Combine Script                         */
/*********************************************************************************/  
  
CREATE   TRIGGER [dbo].[ntrFacilityUpdate]  
ON  [dbo].[FACILITY]   
FOR UPDATE  
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
	
   DECLARE @b_Success INT          -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err INT              -- Error number returned by stored procedure or this trigger  
         , @n_err2 INT             -- For Additional Error Detection  
         , @c_errmsg NVARCHAR(250)     -- Error message returned by stored procedure or this trigger  
         , @n_continue int                   
         , @n_starttcnt int        -- Holds the current transaction count  
         , @c_preprocess NVARCHAR(250) -- preprocess  
         , @c_pstprocess NVARCHAR(250) -- post process  
         , @n_cnt int                    
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND UPDATE(Type) --NJOW01
   BEGIN  
   	IF EXISTS (SELECT 1 FROM INSERTED (NOLOCK) WHERE Type = 'PHYSICAL')
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Err message but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))  
                         +': PHYSICAL is not allowed for facility type. (ntrFacilityUpdate)' + ' ( '   
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN  
      UPDATE Facility WITH (ROWLOCK) 
      SET EditDate = GETDATE(),  
          EditWho = SUSER_SNAME()
      FROM Facility, INSERTED
      WHERE Facility.Facility = INSERTED.Facility  
 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Err message but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))  
                         +': Update Failed On Table Facility. (ntrFacilityUpdate)' + ' ( '   
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  

   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67408   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table Facility. Batch Update not allow! (ntrFacilityUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

   --WL01 S
   IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE TRIM(SiteID) = '')
   BEGIN      
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67409   -- Should Be Set To The SQL Err message but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table Facility. Not allow updating SiteID to blank! (ntrFacilityUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END
   --WL01 E

   /* END Added */
  
   /* #INCLUDE <TRPU_2.SQL> */  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrFacilityUpdate'  
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