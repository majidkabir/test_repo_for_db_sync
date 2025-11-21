SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_IDXGetCtnType_01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get Carton Type                                             */
/*                                                                      */
/* Called from: rdtfnc_SortAndPack                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-03-2013  1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_IDXGetCtnType_01] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @cPackByType               NVARCHAR( 10),
   @cType                     NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cStorerKey                NVARCHAR( 15),
   @cSKU                      NVARCHAR( 20),
   @cConsigneeKey             NVARCHAR( 15)      OUTPUT,
   @cOrderKey                 NVARCHAR( 10)      OUTPUT,
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @bSuccess                  INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cFacility      NVARCHAR( 5), 
        @cSuggestedLoc  NVARCHAR( 10), 
        @c_BUSR5        NVARCHAR( 30),
        @c_BUSR9        NVARCHAR( 30),
        @nLoop          INT, 
        @nQty           INT 

   --If sku.busr5 = 'Unable', prompt the screen with default value '00'
   --If sku.busr9 = 'True', prompt the screen with default value '01'
   --Other values, still prompt the screen base on the svalue of storerconfig 'DefaultCartonType'
   --If no default carton tye specified then return blank

   SELECT @c_BUSR5 = BUSR5, 
          @c_BUSR9 = BUSR9
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU
   
   IF ISNULL(@c_BUSR9, '') = 'True' 
      SET @c_oFieled01 = '01'

   IF ISNULL(@c_BUSR5, '') = 'Unable' 
      SET @c_oFieled01 = '00'

   IF ISNULL(@c_BUSR5, '') <> 'Unable' AND ISNULL(@c_BUSR9, '') <> 'True'
      SET @c_oFieled01 = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerkey)
      
   -- If still no value then set to blank
   IF ISNULL(@c_oFieled01, '') = ''
      SET @c_oFieled01 = ''

Quit:
END

GO