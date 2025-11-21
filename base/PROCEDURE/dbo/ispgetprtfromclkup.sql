SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispGetPrtFromClkUp                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT only can print to 2 printers based on user login. If 1  */
/*          module require > 2 printing then need to use CODELKUP to    */
/*          lookup for printer. This only can use if 3rd printing is for*/
/*          bartender. This use the label printer upon login to get the */
/*          printer name from CODELKUP.                                 */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 28-May-2014 1.0  James       Created                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetPrtFromClkUp] (
   @nMobile         INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cReportType     NVARCHAR( 10), 
   @cPrinter        NVARCHAR( 50) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPrinterName   NVARCHAR( 10) 

   SET @cPrinterName = ''
   -- Retrieve printer name
   SELECT @cPrinterName = Short 
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'PRINTNAME'
   AND   Code = @cPrinter
   AND   StorerKey = @cStorerKey

   SET @cPrinter = @cPrinterName
   
QUIT:
END -- End Procedure


GO