SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Trigger: ntrContainerDetailAdd                                          */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:                                                                */  
/*                                                                         */  
/* Input Parameters: NONE                                                  */  
/*                                                                         */  
/* Output Parameters: NONE                                                 */  
/*                                                                         */  
/* Return Status: NONE                                                     */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: When records added                                           */  
/*                                                                         */  
/* PVCS Version: 1.2                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author    Ver.  Purposes                                   */  
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()        */  
/* 05-Nov-2009  Vicky     1.2   System assign ContainerLineNumber to       */   
/*                              prevent same ContainerLineNumber           */
/*                              being assigned concurrently                */  
/*                              (Vicky01)                                  */  
/* 30-Mar-2020  kocy      1.3   Skip when data move from Archive (kocy01)  */
/* 13-Jan-2021  Shong     1.4   Comment the update for AddWho... Schema    */
/*                              Default already have this. Redundancy      */
/***************************************************************************/  
CREATE TRIGGER [dbo].[ntrContainerDetailAdd]
 ON  [dbo].[CONTAINERDETAIL]
 FOR INSERT
 AS
 BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF
 	
 DECLARE @b_debug int
 SELECT @b_debug = 0
 DECLARE
 @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2 int              -- For Additional Error Detection
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue int                 
 ,         @n_starttcnt int                -- Holds the current transaction count
 ,         @c_preprocess NVARCHAR(250)         -- preprocess
 ,         @c_pstprocess NVARCHAR(250)         -- post process
 ,         @n_cnt int               

 DECLARE @cLineNo NVARCHAR(5),     -- (Vicky01)
         @cMax_LineNo NVARCHAR(5)  -- (Vicky01)

 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRCONDA1.SQL> */     
 
 -- kocy01(s)
 IF @n_continue=1 or @n_continue=2  
 BEGIN
    IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = "9")
    BEGIN
       SELECT @n_continue = 4
    END
 END
 --kocy01(e)

 IF @n_continue=1 or @n_continue=2
 BEGIN
     IF EXISTS (SELECT 1 FROM CONTAINER WITH (NOLOCK)
                JOIN INSERTED ON (CONTAINER.ContainerKey = INSERTED.ContainerKey)
                WHERE CONTAINER.Status = '9')
     BEGIN
         SELECT @n_continue = 3
         SELECT @n_err=68200
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': CONTAINER.Status = ''SHIPPED''. UPDATE rejected. (ntrContainerDetailAdd)'
     END
 END

 -- (Vicky01) - Start  
 IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE ContainerLineNumber = '0')  
 BEGIN  
     SELECT @cMax_LineNo = MAX(CONTAINERDETAIL.ContainerLineNumber)  
     FROM CONTAINERDETAIL WITH (NOLOCK)  
     JOIN INSERTED WITH (NOLOCK) ON (CONTAINERDETAIL.ContainerKey = INSERTED.ContainerKey)

     SELECT @cLineNo = RIGHT( '00000' + CAST( CAST( IsNULL( @cMax_LineNo, '0') AS INT) + 1 AS NVARCHAR( 5)), 5)  

     UPDATE CONTAINERDETAIL WITH (ROWLOCK)
        SET ContainerLineNumber = @cLineNo -- (Vicky01)
     FROM INSERTED 
     WHERE CONTAINERDETAIL.ContainerKey = INSERTED.ContainerKey
     AND CONTAINERDETAIL.ContainerLineNumber = '0'
 END  
 -- (Vicky01) - End  
 
 --IF @n_continue=1 or @n_continue=2
 --BEGIN
 --    UPDATE CONTAINERDETAIL WITH (ROWLOCK)
 --       SET TrafficCop = NULL,
 --           AddDate = GETDATE(),
 --           AddWho = SUSER_SNAME(),
 --           EditDate = GETDATE(),
 --           EditWho = SUSER_SNAME()
 --    FROM CONTAINERDETAIL
 --    JOIN INSERTED ON (CONTAINERDETAIL.ContainerKey = INSERTED.ContainerKey AND
 --                      CONTAINERDETAIL.ContainerLineNumber = INSERTED.ContainerLineNumber)

 --   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 --   IF @n_err <> 0
 --   BEGIN
 --       SELECT @n_continue = 3
 --       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68202   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 --       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table CONTAINERDETAIL. (ntrContainerDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
 --   END
 --END
 
  /* #INCLUDE <TRCONDA2.SQL> */
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
          'ntrContainerDetailAdd'
     
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
END -- Procedure 


GO