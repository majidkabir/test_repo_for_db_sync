SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrrdtQCInquiryLogUpdate                                    */
/* Creation Date:   23 Sept 2010                                        */
/* Copyright: IDS                                                       */
/* Written by:  TLTING                                                  */
/*                                                                      */
/* Purpose:  RDT.rdtQCInquiryLog Update Transaction                     */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 28-Oct-2013  TLTING     Review Editdate column update                */
/************************************************************************/

CREATE TRIGGER [RDT].[ntrrdtQCInquiryLogUpdate]
ON  RDT.rdtQCInquiryLog
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

   IF NOT UPDATE(EditDate)
   BEGIN
      UPDATE rdtQCInquiryLog WITH (ROWLOCK) 
         SET EditDate = GetDate(), EditWho = suser_sname()
      FROM rdtQCInquiryLog 
      JOIN INSERTED ON INSERTED.QCInquiryLogKey = rdtQCInquiryLog.QCInquiryLogKey 
	END 
END

GO