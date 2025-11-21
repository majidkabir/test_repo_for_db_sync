SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_921ExtUpd01                                     */  
/* Purpose: Update cube                                                 */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-07-14 1.2  Ung        SOS368362 Change param                    */
/************************************************************************/  
CREATE PROC [RDT].[rdt_921ExtUpd01] (  
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cStorerKey     NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cDropID        NVARCHAR( 20), 
   @cLabelNo       NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cCartonNo      NVARCHAR( 5),  
   @cPickSlipNo    NVARCHAR( 10), 
   @cCartonType    NVARCHAR( 10), 
   @cCube          NVARCHAR( 20), 
   @cWeight        NVARCHAR( 20), 
   @cLength        NVARCHAR( 20), 
   @cWidth         NVARCHAR( 20), 
   @cHeight        NVARCHAR( 20), 
   @cRefNo         NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
IF @nFunc = 921 -- Capture PackInfo
BEGIN  
   IF @nStep = 2 -- Packinfo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Cube is blank and LWH is provided
         IF (@cCartonType = '') AND (@cLength <> '' AND @cWidth  <> '' AND @cHeight <> '')
         BEGIN
            UPDATE PackInfo SET
               Cube = CAST( @cLength AS FLOAT) * 
                      CAST( @cWidth AS FLOAT) * 
                      CAST( @cHeight AS FLOAT) / 1000000
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @cCartonNo
         END
      END
   END
END     

GO