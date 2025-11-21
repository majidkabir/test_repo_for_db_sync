SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1768DecodeSP04                                        */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose:                   return SKU + Qty                                */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2022-07-13  James     1.0   FCR-549  . Created                             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1768DecodeSP04] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60), 
   @cTaskDetailKey NVARCHAR( 10), 
   @cLOC           NVARCHAR( 10),                
   @cID            NVARCHAR( 18),                
   @cUPC           NVARCHAR( 20)  OUTPUT, 
   @nQTY           INT            OUTPUT, 
   @cLottable01    NVARCHAR( 18)  OUTPUT, 
   @cLottable02    NVARCHAR( 18)  OUTPUT, 
   @cLottable03    NVARCHAR( 18)  OUTPUT, 
   @dLottable04    DATETIME       OUTPUT, 
   @dLottable05    DATETIME       OUTPUT, 
   @cLottable06    NVARCHAR( 30)  OUTPUT, 
   @cLottable07    NVARCHAR( 30)  OUTPUT, 
   @cLottable08    NVARCHAR( 30)  OUTPUT, 
   @cLottable09    NVARCHAR( 30)  OUTPUT, 
   @cLottable10    NVARCHAR( 30)  OUTPUT, 
   @cLottable11    NVARCHAR( 30)  OUTPUT, 
   @cLottable12    NVARCHAR( 30)  OUTPUT, 
   @dLottable13    DATETIME       OUTPUT, 
   @dLottable14    DATETIME       OUTPUT, 
   @dLottable15    DATETIME       OUTPUT, 
   @cUserDefine01  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine02  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine03  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine04  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine05  NVARCHAR( 60)  OUTPUT, 
   @nErrNo         INT            OUTPUT, 
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT = 1
   DECLARE @nCaseCnt    INT = 0

   SET @cUPC = @cBarcode
   print 123123
   IF @nFunc = 1768 -- TMCC SKU
   BEGIN
      IF @nStep = 2 -- SKU
      BEGIN
			
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cPickStatus NVARCHAR( 20),
            @nSumPick INT
            SELECT @cUPC = O_Field01
            FROM RDT.RDTMOBREC with (NOLOCK)
            WHERE Mobile = @nMobile
   
			PRINT CONCAT(@cUPC,'66662323')
         	SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'CCExcludePICK', @cStorerkey)
            IF @cPickStatus <> '0'
            BEGIN
               SELECT @nSumPick = SUM(Qty)
               FROM PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey AND ID = ISNULL(@cID,'')
               AND Loc = @cLOC AND Sku = @cUPC AND Status = @cPickStatus
               GROUP BY Loc,Storerkey
               
               IF @nQTY > @nSumPick
               BEGIN
                  SET @nQTY = @nQTY - @nSumPick
               END
            END
         END   -- ENTER
      END
      
   END
   GOTO Quit
Quit:

END

GO