SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrAppPrinterUpdate                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 07-04-2020  Chermaine  Review Editdate column update                 */
/************************************************************************/
CREATE TRIGGER [API].[ntrAppPrinterUpdate] ON [API].[AppPrinter] 
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
	
   DECLARE @n_continue int
         , @b_success  int       -- Populated by calls to stored procedures - was the proc successful?
		   , @n_err      int       -- Error number returned by stored procedure or this trigger  
		   , @c_errmsg   NVARCHAR(250) -- Error message returned by stored procedure or this trigger 

	

	IF NOT UPDATE(EditDate)
	BEGIN
	 	UPDATE API.AppPrinter
	 	SET EditDate = GETDATE(),
	 	    EditWho = SUSER_SNAME()
	 	FROM API.AppPrinter (NOLOCK),	INSERTED
 	  WHERE AppPrinter.Workstation = INSERTED.Workstation
 	  AND AppPrinter.PrinterType = INSERTED.PrinterType
 	  
	END
   /* Return Statement */  
END

--ALTER TABLE [API].[AppPrinter]  ENABLE TRIGGER [ntrAppPrinterUpdate]

GO