SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtValidSP01                                 */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-05-04 1.0  ChewKP     WMS-4542 Created                          */  
/* 2019-05-17 1.1  Ung        WMS-9051 DropID need to release earlier   */
/* 2022-04-20 1.2  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtValidSP01] (  
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
   DECLARE @cOrderKey      NVARCHAR(10) 
          ,@cOrderType     NVARCHAR(1) 
          ,@cSUSR1         NVARCHAR(20) 
          ,@cPreFix        NVARCHAR(10) 
          ,@cDocType       NVARCHAR(1)
  
   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   SELECT @cOrderKey = OrderKey 
   FROM dbo.PickHeader WITH (NOLOCK) 
   WHERE PickHeaderKey = @cPickSlipNo
   
   SELECT @cDocType = DocType 
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND OrderKey = @cOrderKey     

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
         
         IF @cDocType = 'N'
         BEGIN
            IF LEN(@cDropID) <> 20 
            BEGIN
               
               SET @nErrNo = 123954
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLength'
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- Drop ID  
               GOTO QUIT
            END
            
            SELECT @cSUSR1 = SUSR1 
            FROm dbo.Storer WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            
            SET @cPrefix = '000' + ISNULL(@cSUSR1,'') 
                        
            IF LEFT(@cDropID,10) <> RTRIM(@cPrefix)
            BEGIN
               SET @nErrNo = 123955
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'
               GOTO QUIT
            END
         END
         
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
            SET @nErrNo = 123951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDInUse'
            GOTO QUIT
         END
      END
   END
   
   IF @nStep = 3 
   BEGIN
     IF @nInputKey = 1 
     BEGIN
        IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey 
                    AND OrderKey = @cOrderkey
                    AND B_Fax1 = '1 SKU/Carton' ) 
        BEGIN
           IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                       WHERE StorerKey = @cStorerKey
                       AND OrderKey = @cOrderKey
                       AND DropID = @cDropID)
           BEGIN
              SET @nErrNo = 123953
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotAllowMixSKUInDropID'
              GOTO QUIT 
           END
        END        
     END
   END
END  
  
QUIT:  


GO