SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtValidSP03                                 */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-02-28 1.0  James      WMS-12197. Created                        */
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtValidSP03] (  
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 1),  
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT, 
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30),                
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 839  
BEGIN  
   DECLARE @cOrderKey      NVARCHAR( 10) = ''
          ,@cLoadKey       NVARCHAR( 10) = '' 
          ,@cZone          NVARCHAR( 10) = ''
          ,@cPSType        NVARCHAR( 10) = ''
          ,@cSUSR1         NVARCHAR( 20) = ''
          ,@cPreFix        NVARCHAR( 10) = ''
          ,@cDocType       NVARCHAR( 1) = ''
  
   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   SELECT @cZone = Zone, 
          @cLoadKey = ExternOrderKey,
          @cOrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo

   -- Get PickSlip type      
   IF @@ROWCOUNT = 0
      SET @cPSType = 'CUSTOM'
   ELSE
   BEGIN
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         SET @cPSType = 'XD'
      ELSE IF @cOrderKey = ''
         SET @cPSType = 'CONSO'
      ELSE 
         SET @cPSType = 'DISCRETE'
   END  

   IF @nStep = 2 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check blank   
         -- (not use rdtIsValidFormat in parent due to user don't want RDT prompt "Invalid Format" when drop ID is blank, just need cursor position on drop ID field)  
         IF @cDropID = ''  
         BEGIN  
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Drop ID  
            SET @nErrNo = -1  
            SET @cErrMsg = ''  
            GOTO QUIT  
         END  
         
         IF @cPSType <> 'CUSTOM'
         BEGIN
            IF LEFT( @cDropID, 3) <> 'CNA'
            BEGIN
               SET @nErrNo = 148851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'
               GOTO QUIT
            END
            
            -- Check drop ID in use
            IF @cPSType = 'CONSO'
            BEGIN
               IF EXISTS ( SELECT 1 
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey) 
                  WHERE StorerKey = @cStorerKey
                     AND LPD.LoadKey <> @cLoadKey
                     AND PD.Status < '5'
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND PD.CaseID = ''
                     AND PD.DropID = @cDropID)
               BEGIN
                  SET @nErrNo = 148852
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDInUse'
                  GOTO QUIT
               END
            END
            ELSE
            BEGIN
               IF EXISTS ( SELECT 1 
                  FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey <> @cOrderKey
                     AND Status < '5'
                     AND Status <> '4'
                     AND QTY > 0
                     AND CaseID = ''
                     AND DropID = @cDropID)
               BEGIN
                  SET @nErrNo = 148853
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDInUse'
                  GOTO QUIT
               END
            END
         END
         ELSE  -- @cPSType = 'CUSTOM'
         BEGIN
            -- Check drop ID in use
            IF EXISTS ( SELECT 1 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo <> @cPickSlipNo
                  AND Status < '5'
                  AND Status <> '4'
                  AND QTY > 0
                  AND CaseID = ''
                  AND DropID = @cDropID)
            BEGIN
               SET @nErrNo = 148854
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDInUse'
               GOTO QUIT
            END
         END
      END
   END
END  
  
QUIT:  


GO