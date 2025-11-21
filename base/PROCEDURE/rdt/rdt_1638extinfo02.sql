SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtInfo02                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2022-05-26  1.0  James    WMS-19694. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtInfo02] (
   @nMobile       INT,           
   @nFunc         INT,           
   @nStep         INT,
   @nInputKey     INT,           
   @cLangCode     NVARCHAR( 3),  
   @cFacility     NVARCHAR( 5),  
   @cStorerkey    NVARCHAR( 15), 
   @cPalletKey    NVARCHAR( 30), 
   @cCartonType   NVARCHAR( 10), 
   @cCaseID       NVARCHAR( 20), 
   @cLOC          NVARCHAR( 10), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT,            
   @cLength       NVARCHAR(5),    
   @cWidth        NVARCHAR(5),    
   @cHeight       NVARCHAR(5),    
   @cGrossWeight  NVARCHAR(5),    
   @cExtendedInfo NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nActTtLCaseId  INT = 0
   DECLARE @nScannedCaseId INT = 0
   
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3    -- Case ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 
               @cPickSlipNo = PH.PickSlipNo, 
               @cOrderKey = PH.OrderKey
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.LabelNo = @cCaseID
            ORDER BY 1

            -- Retrieve how many case need to scan
            SELECT @nActTtLCaseId = COUNT( DISTINCT LABELNO)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            -- Retrieve scanned how many case so far
            SELECT @nScannedCaseId = COUNT( DISTINCT CASEID)
            FROM dbo.PALLETDETAIL PLTD WITH (NOLOCK)
            WHERE PLTD.StorerKey = @cStorerkey
            AND   PLTD.PalletKey = @cPalletKey
            AND   EXISTS ( SELECT 1
                           FROM dbo.PackDetail PACKD WITH (NOLOCK)
                           WHERE PACKD.PickSlipNo = @cPickSlipNo
                           AND   PACKD.LabelNo = PLTD.CaseID)
                           
            SELECT @cExtendedInfo = 'ORD:' + @cOrderKey + ' ' +
                  CAST( @nScannedCaseId AS NVARCHAR( 2)) + '/' + CAST( @nActTtLCaseId AS NVARCHAR( 2))
         END
      END
   END
END

GO