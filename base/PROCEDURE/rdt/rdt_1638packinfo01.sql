SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1638PackInfo01                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: After all case id in orders scanned, show capture Refno     */  
/*                                                                      */  
/* Called from: rdtfnc_PickAndPack                                      */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2022-05-26  1.0  James    WM-19694. Created                          */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1638PackInfo01] (  
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @nStep              INT,
   @nInputKey          INT,
   @cFacility          NVARCHAR( 5),
   @cStorerKey         NVARCHAR( 15),
   @cPalletKey         NVARCHAR( 30),
   @cCaseID            NVARCHAR( 20),
   @cLOC               NVARCHAR( 10),
   @cSKU               NVARCHAR( 20),
   @nQTY               INT,
   @cCapturePackInfo   NVARCHAR( 3)  OUTPUT,
   @cCartonType        NVARCHAR( 10) OUTPUT,
   @cWeight            NVARCHAR( 10) OUTPUT,
   @cCube              NVARCHAR( 10) OUTPUT,
   @cRefNo             NVARCHAR( 20) OUTPUT,
   @nErrNo             INT           OUTPUT,
   @cErrMsg            NVARCHAR( 20) OUTPUT
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nActTtLCaseId  INT = 0
   DECLARE @nScannedCaseId INT = 0
   
   SET @cCapturePackInfo = ''
   SET @cCartonType = ''
   SET @cWeight = ''
   SET @cCube = ''
   SET @cRefNo = ''

   -- Retrieve current pickslipno
   SELECT TOP 1 @cPickSlipNo = PickSlipNo
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   LabelNo = @cCaseID
   ORDER BY 1

   -- Retrieve how many case need to scan
   SELECT @nActTtLCaseId = COUNT( DISTINCT LABELNO)
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo

   -- Retrieve scanned how many case (for this orders) so far
   SELECT @nScannedCaseId = COUNT( DISTINCT PLD.CASEID)
   FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
   WHERE PLD.StorerKey = @cStorerKey
   AND   PLD.PalletKey = @cPalletKey
   AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                  AND   PLD.CaseId = PD.LabelNo
                  AND   PLD.StorerKey = PD.StorerKey)

   -- Check if scanned + current to be scanned equal to actual case needed
   IF ( @nScannedCaseId + 1) = @nActTtLCaseId 
      SET @cCapturePackInfo = '2R'  -- Show Refno screen and insert packinfo
   ELSE
   	SET @cCapturePackInfo = '2'   -- Insert packinfo record only
      
   Quit:
END

GO