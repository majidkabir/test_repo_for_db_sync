SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo10                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-03-29 1.0  James      WMS-22039. Created                        */
/* 2023-04-07 1.1  James      Enhance extendedinfo display (james01)    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtInfo10] (
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

   DECLARE @cM_Company NVARCHAR( 100)
   
   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nAfterStep = 4 -- Packinfo
      BEGIN
         -- Get Order Info
         SELECT @cM_Company = M_Company
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         SET @cExtendedInfo = RIGHT( @cM_Company, 20)
      END
   END

GO