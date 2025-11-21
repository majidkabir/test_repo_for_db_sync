SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_625ExtVal01                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-Dec-2018 1.0  James       WMS7168. Created                        */  
/* 28-Mar-2019 1.1  James       Add extra SKU/UPC validation (james01)  */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_625ExtVal01] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nAfterStep       INT,
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15),  
   @tVar             VariableTable READONLY,
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cSKU     NVARCHAR( 20)
   DECLARE @cAltSKU  NVARCHAR( 20)
   DECLARE @cQty     NVARCHAR( 5)

   -- Variable mapping
   SELECT @cSKU = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cSKU'
   SELECT @cQty = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cQty'

   -- This is actual value key in. @cSKU is after rdt_GETSKU 
   SELECT @cAltSKU = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cInField04'

   --SELECT @cAltSKU = I_Field04   -- This is actual value key in. @cSKU is after rdt_GETSKU 
   --FROM RDT.RDTMOBREC WITH (NOLOCK)
   --WHERE Mobile = @nMobile

   IF @nFunc = 625 -- Data capture 9
   BEGIN
      IF @nStep = 2 -- SKU/Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SET @nErrNo = 0

            IF @cSKU = ''
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 4 
               SET @nErrNo = -1
               GOTO Quit
            END

            IF @cSKU <> ''
            BEGIN
               IF LEN( RTRIM( @cAltSKU)) < 12
               BEGIN
                  SET @nErrNo = 132854
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- InvalidSKU/UPC
                  EXEC rdt.rdtSetFocusField @nMobile, 4
                  GOTO Quit
               END

               IF LEN( RTRIM( @cAltSKU)) > 12
               BEGIN
                  IF NOT EXISTS (SELECT 1 
                     FROM dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
                     WHERE StorerKey = @cStorerKey 
                     AND Sku = @cAltSKU)  -- Altsku is actual value user key in from screen
                  BEGIN
                     SET @nErrNo = 132855
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- InvalidSKU/UPC
                     EXEC rdt.rdtSetFocusField @nMobile, 4
                     GOTO Quit
                  END
               END

               IF LEN( RTRIM( @cAltSKU)) = 12
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku))   
                                  WHERE AltSku = @cAltSKU)
                  BEGIN
                     SET @nErrNo = 132851
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- Invalid UPC
                     EXEC rdt.rdtSetFocusField @nMobile, 4
                     GOTO Quit
                  END
               END
            END

            IF @cQty = ''
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 5 
               SET @nErrNo = -1
               GOTO Quit
            END

            IF @cQty <> '' AND 
               RDT.rdtIsValidQTY( @cQty, 1) = 0
            BEGIN
               SET @nErrNo = 132852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- Invalid Qty
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Quit
            END

            IF @cQty <> '' AND 
               CAST( @cQty AS INT) > 9999
            BEGIN
               SET @nErrNo = 132853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- Qty Exceed
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Quit
            END
         END   -- InputKey
      END   -- Step
   END   -- Func

   Quit:
END  

GO