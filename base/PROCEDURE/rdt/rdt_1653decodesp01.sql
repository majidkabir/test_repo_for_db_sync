SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653DecodeSP01                                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Insert TrackingID                                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-08-01  1.0  James    WMS-14248. Created                         */  
/* 2021-07-09  1.1  James    WMS-17425-Reset orderkey variable (james01)*/
/* 2021-08-25  1.2  James    WMS-17773 Extend TrackNo to 40 chars       */
/*                           Output Label No                            */
/* 2022-04-28  1.3  James    WMS-18616 Extend barcode length (james02)  */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653DecodeSP01] (    
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
   
   DECLARE @cInTrackNo     NVARCHAR( 40) = ''
   DECLARE @cBuyerPO       NVARCHAR( 20)
   DECLARE @nCaseCnt       INT
   DECLARE @nRowCount      INT
   DECLARE @curClosePlt    CURSOR

   SET @cInTrackNo = RIGHT( RTRIM( @cBarcode), 18)
   
   -- (james01)
   SET @cOrderKey = ''
   SELECT TOP 1 @cOrderKey = OrderKey
   FROM dbo.PICKDETAIL WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   CaseID = @cInTrackNo
   AND  ([Status] < '9' OR ShipFlag <> 'P') 
   ORDER BY 1

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SELECT @cBuyerPO = LabelNo
      FROM dbo.CartonTrack WITH (NOLOCK)
      WHERE KeyName = @cStorerKey
      AND   UDF03 = SUBSTRING( @cBarcode, 1, CASE WHEN LEN( @cBarcode) > 18 THEN LEN( @cBarcode) - 18 ELSE LEN( @cBarcode) END)   
      AND   Trackingno = Right( @cBarcode, 18) 
      AND   CarrierRef2 = 'GET'
      
      SELECT @cOrderKey = OrderKey
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   BuyerPO = @cBuyerPO
   END

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SELECT TOP 1 @cOrderKey = PH.OrderKey
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
      WHERE PH.StorerKey = @cStorerKey
      AND   PD.LabelNo = @cInTrackNo
   END 

   SET @cTrackNo = @cInTrackNo
   SET @cLabelNo = @cInTrackNo
Fail:    
END    

GO