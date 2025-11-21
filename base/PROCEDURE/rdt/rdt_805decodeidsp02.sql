SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805DecodeIDSP02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 05-12-2017 1.0 Ung         WMS-3962 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_805DecodeIDSP02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cScanID      NVARCHAR( 20)  OUTPUT, 
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT,
   @nDefaultSKU  NVARCHAR(1)    = 0 OUTPUT,
   @nDefaultQty  NVARCHAR(1)    = 0 OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nLength INT 

   IF @nFunc = 805 -- PTLStation
   BEGIN
      IF @nStep = 3 
      BEGIN
         IF @nInputKey = 1 
         BEGIN
            SET @nLength = Len(@cScanID)
            
            IF @nLength > 15 
            BEGIN
               SELECT TOP 1 @cSKU = SKU 
                           ,@nQty = Qty 
               FROM dbo.UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cScanID
               
               IF ISNULL(@cSKU,'')  <> '' 
               BEGIN
                  SET @nDefaultSKU = 1 
                  SET @nDefaultQty = 1 
               END
            END
            ELSE 
            BEGIN
               SET @cSKU = '' 
               SET @nQty = 0 
               SET @nDefaultSKU = 0
               SET @nDefaultQty = 0 
            END
         END
      END
   END

Quit:

END

GO