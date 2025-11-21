SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetActionKey                                    */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Getting the Action Code from XML message that pass from RDT */
/*          server.                                                     */
/* Input Parameters: XML Message passing from RDT Server.               */
/*                                                                      */
/* Output Parameters: Action code: Yes/No                               */
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

CREATE PROC [RDT].[rdtGetActionKey] (
   @cInMessage NVARCHAR(max),
   @cActionKey NVARCHAR(3) OUTPUT ,
   @InMobile  int
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @iDoc int

   -- Create an internal representation of the XML document.
   EXEC sp_xml_preparedocument @iDoc OUTPUT, @cInMessage

   DECLARE @XML_Row Table(Respond NVARCHAR(10))

   DECLARE @ColName  NVARCHAR(20),
           @ColValue NVARCHAR(60),
           @cSQL     NVARCHAR(max)

   -- Execute a SELECT statement that uses the OPENXML rowset provider.
   INSERT INTO @XML_Row
   SELECT  * FROM  OPENXML (@iDoc, '/fromRDT/input',2)
             WITH (Respond NVARCHAR(10) '../@type')

   SELECT @ColName = '', @cSQL = ''

   IF EXISTS(SELECT 1 FROM   @XML_Row WHERE  Respond = 'NO')
      SELECT @cActionKey = 'NO'
   ELSE
      SELECT @cActionKey = 'YES'

   -- Delete the XML document.
   EXEC sp_xml_removedocument @iDoc

   /*
   IF SUBSTRING(@cInMessage,54,2) = 'NO'
      SELECT @cActionKey = 'NO'
   ELSE
      SELECT @cActionKey = 'YES'
   */

   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET INPUTKEY = CASE @cActionKey WHEN 'YES' THEN 1 ELSE 0 END
   WHERE  mobile = @InMobile

GO