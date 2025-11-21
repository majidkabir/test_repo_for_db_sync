SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal12                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Validate only same loadkey can scan to same pallet          */
/*          for retail orders                                           */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/*	2020-12-23  1.0  Chermaine WMS-15888. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal12] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF @nFunc = 1638 -- Scan to pallet  
   BEGIN  
      IF @nStep = 3 -- CaseID  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Get 1st case on pallet  
            DECLARE @cSuggCaseID NVARCHAR( 20)  
            SET @cSuggCaseID = ''  
            SELECT TOP 1   
               @cSuggCaseID = CaseID  
            FROM dbo.PalletDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey   
               AND PalletKey = @cPalletKey  
            ORDER BY PalletLineNumber  
  
            IF @cSuggCaseID <> ''  
            BEGIN  
               DECLARE @cSuggPickSlipNo   NVARCHAR( 10)  
               DECLARE @cSuggOrderKey     NVARCHAR( 10)  
               DECLARE @cSuggLoadKey      NVARCHAR( 10)  
               DECLARE @cPickSlipNo       NVARCHAR( 10)  
               DECLARE @cOrderKey         NVARCHAR( 10)  
               DECLARE @cLoadKey          NVARCHAR( 10)  
               DECLARE @cDoctype          NVARCHAR( 1)
                 
               SET @cSuggPickSlipNo = ''  
               SET @cSuggOrderKey = ''  
               SET @cSuggLoadKey = ''  
               SET @cPickSlipNo = ''  
               SET @cOrderKey = ''  
               SET @cLoadKey = ''  
                 
               -- Get suggested case info  
               SELECT @cSuggPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cSuggCaseID  
               SELECT @cSuggLoadKey = LoadKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cSuggPickSlipNo  
               --SELECT @cSuggLoadKey = LoadKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cSuggOrderKey  
                 
               -- Get case info  
               SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCaseID  
               SELECT @cLoadKey = LoadKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  
               SELECT TOP 1 @cDoctype = doctype  FROM Orders WITH (NOLOCK) WHERE LoadKey = @cLoadKey ORDER BY 1  
  
               IF @cDoctype <> 'N'
                  GOTO Quit

               IF @cSuggLoadKey <> @cLoadKey  
               BEGIN  
                  SET @nErrNo = 161601  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Load  
               END  
            END  
         END  
      END  
   END  
   
   Quit:
END  

GO