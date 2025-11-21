SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1804ExtInfo03                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 16-05-2019 1.0 YeeKung     WMS-9029 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1804ExtInfo03] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1804 -- Move to UCC
   BEGIN
      
      IF @nAfterStep in (5, 6)
      BEGIN
         
         -- Variable mapping
         DECLARE @cSKU NVARCHAR(18)
         SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'

         IF @cSKU <> ''
         BEGIN

            DECLARE @BUSR6 NVARCHAR(60) 

            SELECT @BUSR6=BUSR6 
            FROM dbo.SKU WITH (NOLOCK)
            WHERE SKU = @cSKU AND STORERKEY=@cStorerKey;

            IF (@BUSR6 <> '')
            BEGIN
               SET @cExtendedInfo ='BUSR6: ' + @BUSR6
            END

         END
      END  
   END

Quit:

END

GO