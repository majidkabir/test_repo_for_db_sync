SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Trigger: ntrPalletDetailAdd                                          */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Input Parameters: NONE                                               */  
/*                                                                      */  
/* Output Parameters: NONE                                              */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: When records added                                        */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 2012-Nov-30  Chew KP   1.1   Auto Gen PalletLinenumber (ChewKP01)    */  
/* 2018-Dec-19  TLTING01  1.2   missing NOLOCK                          */  
/* 31-Mar-2020  kocy      1.3   Skip when data move from Archive (kocy01)*/
/* 12-Jan-2021  Shong     1.4   Performance Tuning, Move the logic to   */ 
/*                              Pre-Add Trigger                         */
/************************************************************************/  
CREATE TRIGGER [dbo].[ntrPalletDetailAdd]  
   ON  [dbo].[PALLETDETAIL]  
 FOR INSERT  
 AS  
 BEGIN  
    SET NOCOUNT ON  
    SET ANSI_NULLS OFF  
    SET QUOTED_IDENTIFIER OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @b_debug INT  
    SELECT @b_debug = 0  
    DECLARE @b_Success        INT -- Populated by calls to stored procedures - was the proc successful?
           ,@n_err            INT -- Error number returned by stored procedure or this trigger
           ,@n_err2           INT -- For Additional Error Detection
           ,@c_errmsg         NVARCHAR(250) -- Error message returned by stored procedure or this trigger
           ,@n_continue       INT
           ,@n_starttcnt      INT -- Holds the current transaction count
           ,@c_preprocess     NVARCHAR(250) -- preprocess
           ,@c_pstprocess     NVARCHAR(250) -- post process
           ,@n_cnt            INT

    DECLARE 
            @c_CaseID       NVARCHAR(20)   
           ,@c_Status       NVARCHAR(10)
        
    SELECT @n_continue = 1
          ,@n_starttcnt = @@TRANCOUNT  
         /* #INCLUDE <TRPALDA1.SQL> */       
      
    -- kocy01(s)
    IF @n_continue=1 OR @n_continue=2
    BEGIN
        IF EXISTS (SELECT 1 FROM   INSERTED WHERE  ArchiveCop = '9' )
        BEGIN
           SELECT @n_continue = 4
        END
    END
    --kocy01(e)
 

 IF @n_continue=1 OR @n_continue=2
 BEGIN     
     DECLARE CUR_CASEMANIFEST_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT CM.CaseId 
          , INS.[Status]
     FROM [dbo].[CASEMANIFEST] AS CM WITH (NOLOCK) 
     JOIN INSERTED AS INS ON CM.CaseId = INS.CaseId 
     WHERE INS.CaseID IS NOT NULL
     AND INS.CaseID > ''
     AND INS.Status = '9' 
     
     OPEN CUR_CASEMANIFEST_UPDATE
     
     FETCH FROM CUR_CASEMANIFEST_UPDATE INTO @c_CaseId, @c_Status
     
     WHILE @@FETCH_STATUS = 0
     BEGIN 
        IF @c_Status = '9'
        BEGIN
           UPDATE dbo.CASEMANIFEST
            SET   ShipStatus = '9'
           WHERE  CaseId = @c_CaseID
     
           SELECT @n_err = @@ERROR
                 ,@n_cnt = @@ROWCOUNT
     
           IF @n_err<>0
           BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250) ,@n_err)
                     ,@n_err = 67601 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                      ': Update Failed On Table CASEMANIFEST. (ntrPalletDetailAdd)'+' ( '+' SQLSvr MESSAGE='+ISNULL(TRIM(@c_errmsg) ,'') 
                     +' ) '
           END           
        END -- IF @c_Status = '9'
        
        FETCH FROM CUR_CASEMANIFEST_UPDATE INTO @c_CaseId, @c_Status
     END
     
     CLOSE CUR_CASEMANIFEST_UPDATE
     DEALLOCATE CUR_CASEMANIFEST_UPDATE
 END
  
 
 /* #INCLUDE <TRPALDA2.SQL> */  
 IF @n_continue=3 -- Error Occured - Process And Return
 BEGIN
     IF @@TRANCOUNT=1
        AND @@TRANCOUNT>=@n_starttcnt
     BEGIN
         ROLLBACK TRAN
     END
     ELSE
     BEGIN
         WHILE @@TRANCOUNT>@n_starttcnt
         BEGIN
             COMMIT TRAN
         END
     END  
     EXECUTE nsp_logerror @n_err,
          @c_errmsg,
          'ntrPalletDetailAdd'
     
     RAISERROR (@c_errmsg ,16 ,1) WITH SETERROR -- SQL2012  
     RETURN
 END
 ELSE
 BEGIN
     WHILE @@TRANCOUNT>@n_starttcnt
     BEGIN
         COMMIT TRAN
     END 
     RETURN
 END  
END  

GO