SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtValidSP05                                 */  
/* Purpose: Validate Dropid                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-04-09 1.0  James      WMS-16773. Created                        */
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtValidSP05] (  
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
          ,@cOrderGroup    NVARCHAR( 20) = ''
          ,@nIsValidDropID INT = 0
          
   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   SELECT @cZone = Zone, 
          @cLoadKey = LoadKey,
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
         IF @cDropID = ''  
         BEGIN  
            SET @nErrNo = 165851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID Required'
            GOTO QUIT  
         END  

         IF @cPSType = 'CUSTOM'
         BEGIN
            SELECT TOP 1 @cOrderGroup = O.OrderGroup
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            JOIN dbo.ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE PD.PickSlipNo = @cPickSlipNo
            ORDER BY 1
         END
         
         IF @cPSType = 'XD' OR @cPSType = 'CONSO'
         BEGIN
            SELECT TOP 1 @cOrderGroup = OrderGroup
            FROM dbo.ORDERS WITH (NOLOCK) 
            WHERE LoadKey = @cLoadKey
            ORDER BY 1
         END
         
         IF @cPSType = 'DISCRETE'
         BEGIN
            SELECT TOP 1 @cOrderGroup = OrderGroup
            FROM dbo.ORDERS WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
            ORDER BY 1
         END
         
         IF @cOrderGroup IN ('SINGLE', 'MULTI')
         BEGIN
            IF LEN( @cDropID) <> 9  
            BEGIN  
               SET @nErrNo = 165852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID Len Err'
               GOTO QUIT  
            END  

            IF @cOrderGroup = 'MULTI'
            BEGIN
               IF SUBSTRING( @cDropID, 1, 4) = 'NDHR' AND 
               RDT.rdtIsValidQTY( SUBSTRING( @cDropID, 5, 5), 0) = 1
                  SET @nIsValidDropID = 1
            END
            ELSE
            BEGIN
               IF SUBSTRING( @cDropID, 1, 4) IN ('NDHB', 'NDHG') AND 
               RDT.rdtIsValidQTY( SUBSTRING( @cDropID, 5, 5), 0) = 1
                  SET @nIsValidDropID = 1
            END
         END
         ELSE   
            SET @nIsValidDropID = 1
         
         IF @nIsValidDropID <> 1
         BEGIN  
            SET @nErrNo = 165853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid DropID'
            GOTO QUIT  
         END  
      END
   END
END  
  
QUIT:  


GO