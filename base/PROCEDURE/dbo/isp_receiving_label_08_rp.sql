SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_Receiving_Label_08_RP                              */
/* Purpose: SKU label                                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2013-09-03 1.0  Ung      SOS273208 Created                              */
/* 2018-01-03 1.1  Ung      WMS-3689 Change format                         */
/* 2018-11-23 1.2  Ung      WMS-7106 Change mapping                        */
/***************************************************************************/

CREATE PROC [dbo].[isp_Receiving_Label_08_RP] (
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
   @cErrMsg     NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptKey NVARCHAR(10)
   DECLARE @cToID       NVARCHAR(18)
   DECLARE @nQTY        INT
   DECLARE @cLottable01 NVARCHAR(18)
   DECLARE @cEditWho    NVARCHAR(18)

   SET @cLottable01 = ''
   SET @cEditWho = ''

   SET @cReceiptKey  = @cByRef1
   SET @cToID        = @cByRef2

   -- Get ReceiptDetail info
   SELECT TOP 1
      @cLottable01 = Lottable01, 
   	@cEditWho = EditWho
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ToID = @cToID

   SELECT @nQTY = ISNULL( SUM(BeforeReceivedQTY), 0)
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ToID = @cToID

   -- Replace field with actual value
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cLottable01))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( SUBSTRING( @cToID , 1,1 )))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( CAST( @nQTY AS NVARCHAR(10))))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cToID)) -- SUBSTRING( @cToID, 1,10)
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cEditWho))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', RTRIM( GETDATE()))

   -- Output label to print
   SET @cPrintData = @cPrintTemplate      

GO