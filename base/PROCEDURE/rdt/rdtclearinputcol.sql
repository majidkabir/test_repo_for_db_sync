SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtClearInputCol                                   */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Set all the input column value to blank                     */
/*                                                                      */
/* Input Parameters: Mobile#                                            */
/*                                                                      */
/* Output Parameters: Error Number and Error Message                    */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Called By: rdtHandle                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/*                                                                      */
/************************************************************************/

CREATE PROC [RDT].[rdtClearInputCol] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   
   BEGIN TRAN

   UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
   SET I_Field01='',
       I_Field02='',
       I_Field03='',
       I_Field04='',
       I_Field05='',
       I_Field06='',
       I_Field07='',
       I_Field08='',
       I_Field09='',
       I_Field10='',
       I_Field11='',
       I_Field12='',
       I_Field13='',
       I_Field14='',
       I_Field15=''
   WHERE Mobile = @nMobile
   
   IF @@ERROR <> 0
   BEGIN
      SELECT  @nErrNo = @@ERROR,
              @cErrMsg = 'Update RDTMOBREC Failed'
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      COMMIT TRAN
   END

GO