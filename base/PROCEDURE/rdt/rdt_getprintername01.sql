SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_GetPrinterName01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT only can print to 2 printers based on user login. If 1  */
/*          module require > 2 printing then need to use CODELKUP to    */
/*          lookup for printer. Use code2 as report type to print       */
/*          different type of report                                    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 17-Dec-2015 1.0  James       SOS353558 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_GetPrinterName01] (
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

   /* Required field
   ListName
   Code = Printer name from login
   Short = Actual printer name
   StorerKey
   code2 = Report type
   */

   SET @cPrinterName = ''

   -- Retrieve printer name
   SELECT @cPrinterName = Short 
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'PRINTNAME'
   AND   Code = @cPrinter
   AND   StorerKey = @cStorerKey
   AND   code2 = @cReportType

   SET @cPrinter = @cPrinterName
   
QUIT:
END -- End Procedure

GO