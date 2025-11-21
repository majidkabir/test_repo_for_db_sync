SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_LottableProcess_DefaultLottable02                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*          get pickdetail.lottable02 (storer:Loreal)                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-11-2022   yeekung    1.0  WMS-21214 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_DefaultLottable02]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptKey NVARCHAR(10),
           @cRefNo NVARCHAR(20),
           @cOrderkey NVARCHAR(20)

   SELECT @cReceiptKey = V_ReceiptKey,
          @cRefNo = V_String1
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF LEN(@cRefNo)=19 and SUBSTRING(@cRefNo,1,1)='R'
      SET @cRefNo=Right(@cRefNo,15) --yeekung02

   SELECT @cOrderkey=orderkey
   FROM orders (NOLOCK)
   WHERE trackingno=@cRefNo

   IF ISNULL(@cOrderkey,'')=''
   BEGIN
      SELECT @cOrderkey=orderkey
      FROM cnarchive.dbo.orders (NOLOCK)
      WHERE trackingno=@cRefNo

      SELECT TOP 1 @cLottable02=LOT.lottable02
      FROM cnarchive.dbo.pickdetail PD (nolock) 
      JOIN cnarchive.dbo.LOTattribute LOT (NOLOCK) ON PD.Lot=LOT.LOT
      WHERE orderkey=@corderkey
      and PD.storerkey=@cStorerKey
      AND PD.SKU=@cSKU

   END
   ELSE
   BEGIN
      SELECT TOP 1 @cLottable02=lottable02
      FROM pickdetail PD (nolock) 
      JOIN LOTattribute LOT (NOLOCK) ON PD.Lot=LOT.LOT
      WHERE orderkey=@corderkey
      and PD.storerkey=@cStorerKey
      AND PD.SKU=@cSKU
   END


Fail:

END

GO