SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839DecodeSP02                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-04-19   1.0  yeekung    WMS-16839 Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_839DecodeSP02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 60), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cUPC         NVARCHAR( 30)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
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
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cUPC=''

   SELECT @cUPC=pd.SKU,@nqty=pd.qty
   FROM pickdetail pd JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON 
   (pd.loc=lli.loc AND pd.lot=lli.lot AND pd.sku=lli.sku)
   WHERE lli.qty>0
   AND pd.id=@cBarcode
   AND pd.loc=@cLOC
   AND pd.storerkey=@cStorerKey
   AND pd.status=0

   IF @@ROWCOUNT=0
   BEGIN
      SELECT @cUPC=lli.SKU,@nqty=lli.qty
      FROM  dbo.LOTxLOCxID LLI (NOLOCK) 
      WHERE lli.qty>0
      AND lli.id=@cBarcode
      AND lli.loc=@cLOC

      IF @@ROWCOUNT=0
      BEGIN
         SET @nQTY=0
      END
   END

   IF ISNULL(@cUPC,'')<>''
   BEGIN
      UPDATE rdt.RDTMOBREC WITH (ROWLOCK)
      SET V_string50=@cBarcode
      WHERE Mobile=@nMobile
   END
   ELSE
   BEGIN
      SET @cUPC=@cBarcode

      UPDATE rdt.RDTMOBREC WITH (ROWLOCK)
      SET V_string50=''
      WHERE Mobile=@nMobile
   END

END

GO