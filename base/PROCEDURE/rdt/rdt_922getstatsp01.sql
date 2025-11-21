SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922GetStatSP01                                  */
/* Purpose: Get statistic                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-04-12 1.0  Ung        WMS-4476 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_922GetStatSP01] (
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 1),
   @cMBOLKey     NVARCHAR( 10),
   @cLoadKey     NVARCHAR( 10),
   @cOrderKey    NVARCHAR( 10), 
   @cDoor        NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 40), 
   @cCheckPackDetailDropID INT, 
   @cCheckPickDetailDropID INT, 
   @nTotalCarton INT OUTPUT, 
   @nScanCarton  INT OUTPUT, 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)  
   FROM dbo.PackHeader PH WITH (NOLOCK)
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PH.LoadKey = @cLoadKey
      AND PD.RefNo = @cRefNo

   SELECT @nScanCarton = COUNT( 1) 
   FROM rdt.rdtScanToTruck WITH (NOLOCK) 
   WHERE LoadKey = @cLoadKey 
      AND RefNo = @cRefNo
END

GO