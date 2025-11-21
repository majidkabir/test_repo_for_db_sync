SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_848ExtValid01                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2022-04-05  1.0  yeekung    WMS-19378. Created                       */  
/* 2022-12-16  1.1  YeeKung    MS-21260 Add palletid/taskdetail         */
/*                            (yeekung02)                               */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_848ExtValid01] (  
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),
   @cID          NVARCHAR( 18), 
   @cTaskdetailKey NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount       INT,  
           @cLabelLine        NVARCHAR( 5),  
           @nCartonNo         INT,
           @cUsername         NVARCHAR(20),
           @cFacility         NVARCHAR(20)
  
   IF @nFunc = 848  
   BEGIN  
      IF @nStep = 1
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK) 
                        WHERE dropid=@cDropID
                        AND storerkey=@cStorerKey)
         BEGIN
            SET @nErrNo = 185501   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotExitst  
            GOTO QUIT  
         END
      END
  
   END  
  
   GOTO Quit  
  
Quit:  
END  

GO