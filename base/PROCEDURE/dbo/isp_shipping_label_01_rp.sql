SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_Shipping_Label_01_RP                               */
/* Purpose: Shipping label                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2016-05-31 1.0  Ung      SOS368192 Created                              */
/***************************************************************************/

CREATE PROC [dbo].[isp_Shipping_Label_01_RP] (
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
   @cErrMsg          NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Output label to print
   SELECT @cPrintData = PrintData
   FROM dbo.CartonTrack WITH (NOLOCK) 
   WHERE KeyName = @cStorerKey
   AND   LabelNo = @cByRef1


GO