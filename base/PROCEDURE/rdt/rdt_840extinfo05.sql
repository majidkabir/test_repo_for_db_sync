SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo05                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-07-05 1.0  James      WMS-13913. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInfo05] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nAfterStep    INT, 
   @nInputKey     INT, 
   @cStorerkey    NVARCHAR( 15), 
   @cOrderKey     NVARCHAR( 10), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nCartonNo     INT,
   @cExtendedInfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cCtnType        NVARCHAR( 10)

   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nAfterStep IN ( 3, 4) -- Carton type/weight
      BEGIN
         SELECT @cCtnType = CartonType
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         
         IF ISNULL( @cCtnType, '') <> ''
            SET @cExtendedInfo = 'SUGGEST CTN: ' + @cCtnType
      END
   END

   QUIT:

GO