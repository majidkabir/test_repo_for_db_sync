SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653DecodeSP04                                  */
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Insert TrackingID                                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2024-07-26  1.0  CYU027   FCR-539  . Created                         */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1653DecodeSP04] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 100),
   @cTrackNo       NVARCHAR( 40)  OUTPUT,
   @cOrderKey      NVARCHAR( 10)  OUTPUT,
   @cLabelNo       NVARCHAR( 20)  OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   -- 00000521775000000418 -> 000521775000000418
   IF LEN(@cBarcode) = 20 AND LEFT(@cBarcode,2) = '00'
      SET @cTrackNo = RIGHT(@cBarcode, 18)
   ELSE
      SET @cTrackNo = @cBarcode


   SELECT @cLabelNo = LabelNo
   FROM dbo.CartonTrack WITH (NOLOCK)
   WHERE KeyName = @cStorerKey
     AND   Trackingno = @cTrackNo

   IF @@ROWCOUNT = 0
      SET @cLabelNo = @cTrackNo

   SELECT TOP 1 @cOrderKey = PH.OrderKey
   FROM dbo.PackDetail PD WITH (NOLOCK)
           JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.StorerKey = @cStorerKey
     AND   ( PD.LabelNo = @cLabelNo OR PD.LabelNo = @cTrackNo)
   ORDER BY 1

   QUIT:
END    

GO