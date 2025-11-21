SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1620DropIDSP02                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Adidas decode label return SKU + Qty                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 08-03-2023  James     1.0   WMS-21711. Created                             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1620DropIDSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60),
   @cWaveKey       NVARCHAR( 10), 
   @cLoadKey       NVARCHAR( 10), 
   @cOrderKey      NVARCHAR( 10), 
   @cPutawayZone   NVARCHAR( 10), 
   @cPickZone      NVARCHAR( 10), 
   @cDropID        NVARCHAR( 20)  OUTPUT, 
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

   DECLARE @cLoc        NVARCHAR( 10)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cOutField08 NVARCHAR( 20)
   DECLARE @cId         NVARCHAR( 18)
   
   IF @nFunc IN ( 1620, 1621, 1628) -- Cluster Pick 
   BEGIN
      IF @nStep = 7 -- Drop Id
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
         	SELECT 
         	   @cLoc = V_LOC,
         	   @cFacility = Facility,
         	   @cOutField08 = O_Field08
         	FROM rdt.RDTMOBREC WITH (NOLOCK)
         	WHERE Mobile = @nMobile
         	
         	IF NOT EXISTS ( SELECT 1 
         	                FROM dbo.LOC WITH (NOLOCK)
         	                WHERE Loc = @cLoc
         	                AND   Facility = @cFacility
         	                AND   LoseId = '0') 
               GOTO Quit

            IF @cBarcode <> ''
            BEGIN
            	SET @cId = SUBSTRING( @cOutField08, 4, 16)
            	
            	SELECT 
            	   @cUPC = Sku,
            	   @nQTY = ISNULL( SUM( Qty), 0)
            	FROM dbo.PICKDETAIL WITH (NOLOCK)
            	WHERE OrderKey = @cOrderKey
            	AND   Loc = @cLoc
            	AND   ID = @cId
            	AND   [Status] = '0'
            	GROUP BY Sku
            END   -- @cBarcode
         END   -- ENTER
      END   -- @nStep = 3
   END

Quit:

END

GO