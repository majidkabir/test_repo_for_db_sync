SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_ShipLabel03_RP                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2021-08-05 1.0  James    WMS-17661 Created                              */
/* 2022-07-18 1.1  SYCHUA   JSM-82342 Prevent printing labels from other   */
/*                          storerkey (SY01)                               */
/***************************************************************************/

CREATE PROC [dbo].[isp_ShipLabel03_RP] (
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
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cCodePage        NVARCHAR( 50)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
          ,@cLabelNo    NVARCHAR( 20)


   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cPrintTemplate = ''

   SET @cLabelNo     = @cByRef1

   SELECT @cPrintTemplate = PrintData
   FROM dbo.CartonTrack WITH (NOLOCK)
   WHERE LabelNo = @cLabelNo
   AND KeyName = @cStorerKey     --SY01

   SET @cPrintData = @cPrintTemplate

   SET @cCodePage = '850'

   GOTO Quit

Quit:

GO