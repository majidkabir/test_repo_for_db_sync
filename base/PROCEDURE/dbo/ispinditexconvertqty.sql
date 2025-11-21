SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispInditexConvertQTY                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Convert system QTY to and from display QTY                  */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-11-2012  1.0  Ung         SOS261921. Created                      */
/* 28-11-2012  1.1  James       SOS262231 - Error out if convert to base*/
/*                              qty result in decimal (james01)         */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispInditexConvertQTY] (
   @cType         NVARCHAR( 10), 
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Get SKU info
   DECLARE @cBUSR10 NVARCHAR(30), @nBUSR10 INT 
   SET @cBUSR10 = ''
   SELECT @cBUSR10 = BUSR10
   FROM dbo.SKU WITH (NOLOCK)
   WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = @cSKU -- Might be blank
   
   IF ISNULL(@cBUSR10, '') = '' OR @cBUSR10 = '0'
      RETURN

   SET @nBUSR10 = CAST(@cBUSR10 AS INT)
   
   IF @cType = 'ToDispQTY'
      SET @nQTY = @nQTY / @nBUSR10

   IF @cType = 'ToBaseQTY'
   BEGIN
      IF ((@nQTY * @nBUSR10) % @nBUSR10) <> 0
         SET @nQTY = -1 -- Error convert to base qty (james01)
      ELSE
         SET @nQTY = @nQTY * @nBUSR10
   END
   
QUIT:
END -- End Procedure


GO