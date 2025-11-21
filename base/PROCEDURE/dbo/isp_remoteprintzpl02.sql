SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_RemotePrintZPL02                                   */
/* Purpose: Print ZPL Label                                                */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2022-10-14 1.0  Ung      WMS-20629 Created (based isp_RemotePrintZPL01) */
/***************************************************************************/

CREATE PROC [dbo].[isp_RemotePrintZPL02] (
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR( 15), 
   @cByRef1     NVARCHAR( 20), 
   @cByRef2     NVARCHAR( 20), 
   @cByRef3     NVARCHAR( 20), 
   @cByRef4     NVARCHAR( 20), 
   @cByRef5     NVARCHAR( 20), 
   @cByRef6     NVARCHAR( 20), 
   @cByRef7     NVARCHAR( 20), 
   @cByRef8     NVARCHAR( 20), 
   @cByRef9     NVARCHAR( 20), 
   @cByRef10    NVARCHAR( 20), 
   @cPrintTemplate NVARCHAR( MAX), 
   @cPrintData  NVARCHAR( MAX) OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT,
   @cCodePage   NVARCHAR( 50)  output
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cFacility   NVARCHAR( 5)
         , @cLabelNo    NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cPrintTemplate = ''

   
   SET @cLabelNo           = @cByRef1
   
   
   
   SELECT @cPrintTemplate = PrintData 
   FROM dbo.CartonTrack WITH (NOLOCK)
   WHERE LabelNo = @cLabelNo
   
   SET @cPrintData = @cPrintTemplate

   /* ZPL contain: ^CI28

      Programming Guide for ZPL II.pdf, page 152/1268
      28 = Unicode (UTF-8 encoding) - Unicode Character Set

      https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers
      65001	utf-8	Unicode (UTF-8)
   */
   SET @cCodePage = '65001' 
   
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN isp_RemotePrintZPL02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO