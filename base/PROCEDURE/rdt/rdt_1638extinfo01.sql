SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtInfo01                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2021-01-18  1.0  James    WMS-15913. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtInfo01] (
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

   DECLARE @nCartonCnt     INT
   DECLARE @nCartonScanned INT
   DECLARE @cPickSlipNo    NVARCHAR( 10)
                  
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3    -- Case ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 @cPickSlipNo = PH.PickSlipNo 
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (O.ORDERKEY = PH.ORDERKEY) 
            JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PICKSLIPNO=PD.PICKSLIPNO)
            WHERE O.STORERKEY = @cStorerkey 
            AND   O.TYPE LIKE 'Z%'
            AND   PD.LabelNo = @cCaseID
            ORDER BY 1

            SELECT @nCartonCnt = COUNT( DISTINCT LabelNo)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @nCartonScanned = COUNT( DISTINCT LabelNo)
            FROM dbo.PackDetail PD WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL PLD WITH (NOLOCK) WHERE PD.LabelNo = PLD.CaseId AND PLD.PalletKey = @cPalletKey)
                        
            SELECT @cExtendedInfo = 'Scanned: ' + CAST( @nCartonScanned AS NVARCHAR ( 3)) + '/' + CAST( @nCartonCnt AS NVARCHAR( 3))
         END
      END
   END
END

GO