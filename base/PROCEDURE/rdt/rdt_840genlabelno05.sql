SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840GenLabelNo05                                 */  
/* Purpose: 1st carton label no get from cartontrack                    */  
/*          2nd carton onwards get dummy label no                       */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-11-17 1.0  James      WMS-18321. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840GenLabelNo05] (  
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
   
   DECLARE @bSuccess INT
   
   IF @nCartonNo = 1
   BEGIN
      SELECT TOP 1 @cLabelNo = CaseID
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      AND   Sku = @cSKU
      ORDER BY 1 
   END
   ELSE
      -- Get new LabelNo
      EXECUTE isp_GenUCCLabelNo
         @cStorerKey = @cStorerKey,
         @cLabelNo   = @cLabelNo     OUTPUT,
         @b_success  = @bSuccess     OUTPUT,
         @n_err      = @nErrNo       OUTPUT,
         @c_errmsg   = @cErrMsg      OUTPUT
   Quit:

GO