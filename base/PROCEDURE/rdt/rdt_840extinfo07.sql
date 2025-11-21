SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo07                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-11-18 1.0  James      WMS-15678. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInfo07] (
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

   DECLARE @cOrdType       NVARCHAR( 10)
   DECLARE @cHMOrdType     NVARCHAR( 10)

   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nAfterStep = 3 -- Sku
      BEGIN
         SELECT @cOrdType = [Type]
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         SELECT @cHMOrdType = [Description]
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'HMORDTYPE'
         AND   Code = @cOrdType
         AND   Storerkey = @cStorerkey
         
         SET @cExtendedInfo = @cHMOrdType
      END
   END

   QUIT:

GO