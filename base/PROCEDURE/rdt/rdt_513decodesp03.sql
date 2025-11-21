SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513DecodeSP03                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-04-10  James     1.0   WMS-22175 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_513DecodeSP03] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 2000), 
   @cFromLOC     NVARCHAR( 10)  OUTPUT, 
   @cFromID      NVARCHAR( 18)  OUTPUT, 
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cToLOC       NVARCHAR( 10)  OUTPUT, 
   @cToID        NVARCHAR( 18)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Delim        CHAR( 1) = ','
   DECLARE @nRowCount      INT = 0
   
   IF @nFunc = 513 -- Move by SKU
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
     
               DECLARE @t_DPCRec TABLE (  
                  Seqno    INT,   
                  ColValue VARCHAR(215)  
               )  
     
               INSERT INTO @t_DPCRec  
               SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @cBarcode)  
               SET @nRowCount = @@ROWCOUNT
            
               --SELECT * FROM @t_DPCRec
               --SELECT @nRowCount '@nRowCount'
            
               IF @nRowCount = 8  -- Bag QR
                  SELECT @cSKU = ColValue FROM @t_DPCRec WHERE Seqno = 5
               ELSE  -- Pallet QR
                  SELECT @cSKU = ColValue FROM @t_DPCRec WHERE Seqno = 8
            END
         END   -- ENTER
      END   -- @nStep = 3
   END

Quit:

END

GO