SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal09                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Validate only same loadkey can scan to same pallet          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/*	2020-07-16  1.0  Ung       WMS-13218 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal09] (
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
               DECLARE @cSuggLoadKey NVARCHAR( 10)  
               DECLARE @cLoadKey     NVARCHAR( 10)  
                 
               SET @cSuggLoadKey = ''  
               SET @cLoadKey = ''  
                 
               -- Get suggested LoadKey
               SELECT TOP 1 
                  @cSuggLoadKey = LPD.LoadKey
               FROM PickDetail PD WITH (NOLOCK) 
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cSuggCaseID
                 
               -- Get LoadKey
               SELECT TOP 1 
                  @cLoadKey = LPD.LoadKey
               FROM PickDetail PD WITH (NOLOCK) 
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
  
               IF @cSuggLoadKey <> @cLoadKey  
               BEGIN  
                  SET @nErrNo = 157351  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Load  
               END  
            END  
         END  
      END  
   END  
   
   Quit:
END  

GO