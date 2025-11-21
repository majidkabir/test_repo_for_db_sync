SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840GenLabelNo06                                 */  
/* Purpose: Exec ispAsgnTNo2 to generate new tracking no                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-03-18 1.0  James      WMS-19123. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840GenLabelNo06] (  
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
   
   DECLARE @bSuccess       INT = 0
   DECLARE @cNewTrackingNo NVARCHAR( 20)
   
   -- 1st carton take orders' tracking no
   IF @nCartonNo = 1
      SET @cNewTrackingNo = @cTrackNo
   ELSE
   BEGIN
      SET @cLabelNo = ''
   
      EXEC ispAsgnTNo2  
        @c_OrderKey    = @cOrderKey     
      , @c_LoadKey     = ''  
      , @b_Success     = @bSuccess        OUTPUT        
      , @n_Err         = @nErrNo          OUTPUT        
      , @c_ErrMsg      = @cErrMsg         OUTPUT           
      , @b_ChildFlag   = 1  
      , @c_TrackingNo  = @cNewTrackingNo  OUTPUT   
   END
   
   SET @cLabelNo = @cNewTrackingNo

   Quit:

GO