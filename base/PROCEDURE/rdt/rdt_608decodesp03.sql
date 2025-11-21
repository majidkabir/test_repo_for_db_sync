SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_608DecodeSP03                                        */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Decode SKU                                                        */  
/*                                                                            */  
/* Called from: rdtfnc_PieceReturn                                            */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 05-08-2017  YeeKung    1.0   WMS-14415 Created                             */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_608DecodeSP03] (  
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,  
   @nInputKey    INT,  
   @cStorerKey   NVARCHAR( 15),  
   @cReceiptKey  NVARCHAR( 10),  
   @cPOKey       NVARCHAR( 10),  
   @cLOC         NVARCHAR( 10),  
   @cBarcode     NVARCHAR( 60),  
   @cSKU         NVARCHAR( 20)  OUTPUT,  
   @nUCCQTY      INT            OUTPUT,
   @cUCCUOM      NVARCHAR( 6)   OUTPUT,  
   @cLottable01  NVARCHAR( 18)  OUTPUT,  
   @cLottable02  NVARCHAR( 18)  OUTPUT,  
   @cLottable03  NVARCHAR( 18)  OUTPUT,  
   @dLottable04  DATETIME       OUTPUT,  
   @dLottable05  DATETIME       OUTPUT,  
   @cLottable06  NVARCHAR( 30)  OUTPUT,  
   @cLottable07  NVARCHAR( 30)  OUTPUT,  
   @cLottable08  NVARCHAR( 30)  OUTPUT,  
   @cLottable09  NVARCHAR( 30)  OUTPUT,  
   @cLottable10  NVARCHAR( 30)  OUTPUT,  
   @cLottable11  NVARCHAR( 30)  OUTPUT,  
   @cLottable12  NVARCHAR( 30)  OUTPUT,  
   @dLottable13  DATETIME       OUTPUT,  
   @dLottable14  DATETIME       OUTPUT,  
   @dLottable15  DATETIME       OUTPUT,  
   @nErrNo       INT            OUTPUT,  
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
  
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF EXISTS (SELECT 1 FROM UPC (NOLOCK) WHERE UPC=@cBarcode)
         BEGIN
            SELECT   @cUCCUOM=UPC.UOM,
                     @nUCCQTY=CASE WHEN (UPC.UOM=Pack.PACKUOM1) THEN PACK.CASECNT
                                 WHEN (UPC.UOM=Pack.PACKUOM2) THEN PACK.INNERPACK
                                 WHEN (UPC.UOM=Pack.PACKUOM3) THEN PACK.QTY
                                 WHEN (UPC.UOM=Pack.PACKUOM4) THEN PACK.PALLET
                                 WHEN (UPC.UOM=Pack.PACKUOM5) THEN PACK.Cube
                                 WHEN (UPC.UOM=Pack.PACKUOM6) THEN PACK.GrossWgt
                                 WHEN (UPC.UOM=Pack.PACKUOM7) THEN PACK.NetWgt
                                 WHEN (UPC.UOM=Pack.PACKUOM8) THEN PACK.OTHERUNIT1
                                 WHEN (UPC.UOM=Pack.PACKUOM9) THEN PACK.OTHERUNIT2
                                 ELSE 0 END
            FROM UPC WITH (NOLOCK) 
            JOIN dbo.Pack Pack WITH (NOLOCK) ON (UPC.PackKey = Pack.PackKey)
            WHERE UPC.UPC=@cBarcode
               AND storerkey=@cStorerKey
         END
      END  
   END
     
Quit:  
  
END  

GO