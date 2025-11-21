SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: isp_RtnLabel02_RP                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2021-03-07 1.0  James    WMS-19095 Created                              */
/* 2022-04-04 1.1  SYChua   JSM-60666 - Temp Fix for HMCOS Return Label    */
/*                          mapping (SY01)                                 */
/***************************************************************************/

CREATE PROC [dbo].[isp_RtnLabel02_RP] (
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
          ,@cBuyerPO    NVARCHAR( 20)

   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cPrintTemplate = ''


   SET @cLabelNo     = @cByRef1
   SET @cOrderKey    = @cByRef2

   SELECT @cBuyerPO = BuyerPO
   FROM dbo.orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SELECT @cPrintTemplate = C1.PrintData
   FROM dbo.CartonTrack C1 WITH (NOLOCK)
   WHERE C1.CarrierRef2 IN (
      SELECT C2.CarrierRef2
      FROM dbo.CartonTrack C2 WITH (NOLOCK)
      WHERE C2.TrackingNo = @cLabelNo
      AND   C2.LabelNo = @cBuyerPO)
   AND C1.TrackingNo <> @cLabelNo
   AND C1.LabelNo = @cBuyerPO       --SY01


   SET @cPrintData = @cPrintTemplate

   SET @cCodePage = '850'

   GOTO Quit

Quit:

GO