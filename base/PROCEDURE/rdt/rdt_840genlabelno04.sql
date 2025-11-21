SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840GenLabelNo04                                 */  
/* Purpose: Set Label No = Drop ID                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-04-20 1.0  James      WMS-16841. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840GenLabelNo04] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR( 3),   
   @nStep       INT,   
   @nInputKey   INT,   
   @cStorerkey  NVARCHAR( 15),   
   @cOrderKey   NVARCHAR( 10),   
   @cPickSlipNo NVARCHAR( 10),   
   @cTrackNo    NVARCHAR( 20),   
   @cSKU        NVARCHAR( 20),   
   @cLabelNo    NVARCHAR( 20) OUTPUT,
   @nCartonNo   INT           OUTPUT,  
   @nErrNo      INT           OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @cDropID     NVARCHAR( 20)
   
   SET @cLabelNo = ''
   
   SELECT @cDropID = V_CaseID
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF ISNULL( @cDropID, '') <> ''
      SET @cLabelNo = @cDropID

   Quit:

GO