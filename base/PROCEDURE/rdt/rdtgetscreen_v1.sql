SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetScreen_V1                                    */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Build the screen format for the Function screen,            */
/*          which setup in rdtScn table.                                */
/*                                                                      */
/* Input Parameters: Mobile No                                          */
/*                   DefaultFromCol - OUT: Get from RDTMOBREC O_Field99 */
/*                                     IN: Get from RDTMOBREC I_Field99 */
/*                                                                      */
/* Output Parameters: NIL                                               */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
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

CREATE PROC [RDT].[rdtGetScreen_V1] (
   @nMobile         INT,
   @cDefaultFromCol NVARCHAR(3) = 'OUT'
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nScreen int

   SELECT @nScreen = Scn
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile

   IF NOT EXISTS(SELECT 1 FROM RDT.RDTXML_Root (NOLOCK) WHERE Mobile = @nMobile)
   BEGIN
        INSERT INTO RDT.RDTXML_Root (mobile) VALUES (@nMobile)
   END
/*
   ELSE
   BEGIN
        UPDATE RDT.RDTXML_Root SET focus = NULL WHERE Mobile = @nMobile
   END
*/

   -- Purge all the XML data from this Mobile number
   IF EXISTS(SELECT 1 FROM RDT.RDTXML_Elm (NOLOCK) WHERE Mobile = @nMobile)
   BEGIN
        DELETE RDT.RDTXML_Elm WITH (ROWLOCK) Where mobile = @nMobile
   END

   IF NOT EXISTS(SELECT 1 FROM RDT.RDTScn (NOLOCK) WHERE Scn = @nScreen)
   BEGIN
      INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
      EXEC RDT.rdtScr2XML_V1 @nMobile, '01', 'Screen Not Setup Yet', @cDefaultFromCol
      
      INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
      EXEC RDT.rdtScr2XML_V1 @nMobile, '02', 'Press Esc to Go Back: %01i3 ', @cDefaultFromCol
      
      GOTO RETURN_SP
   END

   DECLARE @cLine NVARCHAR(125),
           @nLine int,
           @cSQL  nvarchar(1000),
           @y     NVARCHAR(10)

   SELECT @nLine = 1

   WHILE @nLine <= 60
   BEGIN
      SELECT @cSQL =  N'SELECT @cLine = Line' + RIGHT('0' + RTRIM(Cast( @nLine as NVARCHAR(2))),2) +
                   ' FROM RDT.RDTScn (NOLOCK) WHERE Scn = ' + Cast(@nScreen as NVARCHAR(5))
   
      EXEC sp_executesql @cSQL, N'@cLine NVARCHAR(125) output', @cLine output
   
      IF RTRIM(@cLine) IS NOT NULL AND RTRIM(@cLine) <> ''
      BEGIN
          SET @y = RIGHT('0' + RTRIM(Cast( @nLine as NVARCHAR(2))),2)
      
          INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
          EXEC RDT.rdtScr2XML_V1 @nMobile, @y, @cLine, @cDefaultFromCol
      END
   
      SET @nLine = @nLine + 1
   END

RETURN_SP:


GO