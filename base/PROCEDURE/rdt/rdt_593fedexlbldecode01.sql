SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593FedexLBLDecode01                                   */
/*                                                                            */
/* Customer: Granite                                                          */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-02-07 1.0  NLT03      FCR-727 Create                                  */
/* 2025-02-05 1.1  Dennis     FCR-2630 Fixbug                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593FedexLBLDecode01] (
   @nMobile          INT,     
   @nFunc            INT,     
   @cLangCode        NVARCHAR( 3),     
   @cStorerKey       NVARCHAR( 15),     
   @cByRef1          NVARCHAR( 20),     
   @cByRef2          NVARCHAR( 20),     
   @cByRef3          NVARCHAR( 20),     
   @cByRef4          NVARCHAR( 20),     
   @cByRef5          NVARCHAR( 20),     
   @cByRef6          NVARCHAR( 20),     
   @cByRef7          NVARCHAR( 20),     
   @cByRef8          NVARCHAR( 20),     
   @cByRef9          NVARCHAR( 20),     
   @cByRef10         NVARCHAR( 20),     
   @cPrintTemplate   NVARCHAR( MAX),     
   @cPrintData       NVARCHAR( MAX) OUTPUT,    
   @nErrNo           INT            OUTPUT,    
   @cErrMsg          NVARCHAR( 20)  OUTPUT    
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelNo    NVARCHAR(20)    
   DECLARE @c_OutputString NVARCHAR(MAX)
   DECLARE @c_InputString  NVARCHAR(MAX)
 

   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cPrintTemplate = ''
   SET @cLabelNo = @cByRef1

   SELECT @c_InputString = PrintData
   FROM dbo.CartonTrack CT WITH (NOLOCK)
   WHERE CT.CarrierRef1 = @cLabelNo
   AND EXISTS(SELECT 1 FROM DBO.CODELKUP CDLP (NOLOCK) WHERE CDLP.LISTNAME='wscourier' AND CDLP.code='ECL-1' AND CDLP.Short = CT.CarrierName)

   EXEC master.dbo.isp_BASe64Decode 'UTF-8', @c_InputString, @c_OutputString OUTPUT,@cErrMsg OUTPUT
   IF @cErrMSG <> ''
   BEGIN
      SET @cErrMSG = 'Print Data Error'
      SET @nErrNo = 9999
   END
   SET @cPrintData = @c_OutputString

Fail:
   RETURN
Quit:

GO