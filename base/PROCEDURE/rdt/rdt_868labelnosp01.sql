SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_868LabelNoSP01                                  */
/* Copyright: IDS                                                       */
/* Called From: rdt_PickAndPack_InsPack                                 */
/* Purpose: Generate label no                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2021-03-30  1.0  James       WMS-16695.Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_868LabelNoSP01](
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @cFacility                 NVARCHAR( 5),  
   @cStorerkey                NVARCHAR( 15), 
   @cLoadKey                  NVARCHAR( 10), 
   @cOrderKey                 NVARCHAR( 10), 
   @cPickSlipNo               NVARCHAR( 10), 
   @cDropID                   NVARCHAR( 20), 
   @cSKU                      NVARCHAR( 20), 
   @cLabelNo                  NVARCHAR( 20) OUTPUT,
   @nCartonNo                 INT           OUTPUT, 
   @nErrNo                    INT           OUTPUT, 
   @cErrMsg                   NVARCHAR( 20) OUTPUT   

)AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPrefix     NVARCHAR( 10)
   DECLARE @cShipperKey NVARCHAR( 15)
   DECLARE @cExternOrderKey   NVARCHAR( 20)
   DECLARE @cCartonNo   NVARCHAR( 3)
   
   SELECT @cShipperKey = ShipperKey,
          @cExternOrderKey = ExternOrderKey 
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   AND   OrderGroup = 'ECOM'
   
   IF @@ROWCOUNT <> 0
   BEGIN
      SELECT @cPrefix = Code
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE Listname = 'UACOMPREFI'
      AND   Long = @cShipperKey
      AND   Storerkey = @cStorerkey
      
      IF @@ROWCOUNT <> 0
      BEGIN
         SELECT @nCartonNo = ISNULL( MAX( CartonNo), 0) + 1 
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE Pickslipno = @cPickSlipNo
         
         SET @cCartonNo = RIGHT( '000' + CAST( @nCartonNo AS NVARCHAR( 3)), 3)

         SET @cLabelNo = RTRIM( @cPrefix) + RTRIM( @cExternOrderKey) + @cCartonNo
         
         GOTO Quit
      END
      
   END

   SET @cLabelNo = @cDropID
   Quit:


GO