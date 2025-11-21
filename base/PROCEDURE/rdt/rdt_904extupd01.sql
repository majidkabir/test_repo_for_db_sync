SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_904ExtUpd01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Upd qty if system qty <> qty (based on count no)            */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 18-08-2016  1.0  James       SOS370878. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_904ExtUpd01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cRefNo       NVARCHAR( 10)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cLoadkey     NVARCHAR( 10)
   ,@cOrderkey    NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cPPAType     NVARCHAR( 1)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@dLottable05  DATETIME
   ,@cLottable06  NVARCHAR( 30)
   ,@cLottable07  NVARCHAR( 30)
   ,@cLottable08  NVARCHAR( 30)
   ,@cLottable09  NVARCHAR( 30)
   ,@cLottable10  NVARCHAR( 30)
   ,@cLottable11  NVARCHAR( 30)
   ,@cLottable12  NVARCHAR( 30)
   ,@dLottable13  DATETIME
   ,@dLottable14  DATETIME
   ,@dLottable15  DATETIME
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @nPQTY             INT,
           @nInsertNewPPA     INT, 
           @nPUOM_Div         INT, 
           @cSKUDescr         NVARCHAR( 60), 
           @cUserName         NVARCHAR( 18) 

   SET @nInsertNewPPA = 0

   SELECT @nPUOM_Div = V_String15, 
          @cSKUDescr = V_SKUDescr,
          @cUserName = UserName--, 
          --@cLottable01 = V_Lottable01,
          --@cLottable02 = V_Lottable02,
          --@cLottable03 = V_Lottable03,
          --@dLottable04 = V_Lottable04,
          --@dLottable05 = V_Lottable05,
          --@cLottable06 = V_Lottable06,
          --@cLottable07 = V_Lottable07,
          --@cLottable08 = V_Lottable08,
          --@cLottable09 = V_Lottable09,
          --@cLottable10 = V_Lottable10,
          --@cLottable11 = V_Lottable11,
          --@cLottable12 = V_Lottable12,
          --@dLottable13 = V_Lottable13,
          --@dLottable14 = V_Lottable14,
          --@dLottable15 = V_Lottable15
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cLottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE '' END
   SET @cLottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE '' END
   SET @cLottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE '' END
   SET @dLottable04 = CASE WHEN ISNULL( @dLottable04, '') <> '' THEN @dLottable04 ELSE NULL END
   SET @dLottable05 = CASE WHEN ISNULL( @dLottable05, '') <> '' THEN @dLottable05 ELSE NULL END
   SET @cLottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE '' END
   SET @cLottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE '' END
   SET @cLottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE '' END
   SET @cLottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE '' END
   SET @cLottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE '' END
   SET @cLottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE '' END
   SET @cLottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE '' END
   SET @dLottable13 = CASE WHEN ISNULL( @dLottable13, '') <> '' THEN @dLottable13 ELSE NULL END
   SET @dLottable14 = CASE WHEN ISNULL( @dLottable14, '') <> '' THEN @dLottable14 ELSE NULL END
   SET @dLottable15 = CASE WHEN ISNULL( @dLottable15, '') <> '' THEN @dLottable15 ELSE NULL END

   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN rdt_904ExtUpd01  

   IF @nStep = 7 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cPPAType = '1'
         BEGIN
            SELECT @nPQTY = ISNULL( SUM( PD.QTY), 0) 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey )
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
            WHERE LPD.Loadkey = @cLoadkey
            AND   PD.SKU = @cSKU
            AND   O.Storerkey = @cStorerKey
            AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END

            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPPA WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey
               AND   LoadKey = @cLoadKey
               AND   SKU = @cSKU
               AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
               AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
               AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
               AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
               AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
               AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
               AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
               AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
               AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
               AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
               AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
               AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
               AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
               AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
               AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END)
            BEGIN
               INSERT INTO rdt.rdtPPA (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               VALUES ('', '', @cLoadKey, '', @cStorerKey, @cSKU, @cSKUDescr, @nPQTY, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, '', '', 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 103201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Reset PPA Fail'
                  GOTO RollBackTran
               END
            END
         END

         IF @cPPAType = '2'
         BEGIN
            SELECT @nPQTY = ISNULL( SUM( QTY), 0) 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
            WHERE PD.Storerkey = @cStorerKey
            AND   PD.SKU = @cSKU
            AND   PD.PickSlipNo = @cPickSlipNo
            AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END

            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPPA WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey
               AND   PickSlipNo = @cPickSlipNo
               AND   SKU = @cSKU
               AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
               AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
               AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
               AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
               AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
               AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
               AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
               AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
               AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
               AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
               AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
               AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
               AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
               AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
               AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END)
            BEGIN
               INSERT INTO rdt.rdtPPA (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               VALUES ('', @cPickSlipNo, '', '', @cStorerKey, @cSKU, @cSKUDescr, @nPQTY, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, @cOrderKey, '', 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 103202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Reset PPA Fail'
                  GOTO RollBackTran
               END
            END
         END

         IF @cPPAType = '3'
         BEGIN
            SELECT @nPQTY = ISNULL( SUM( PD.QTY), 0) 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
            WHERE PD.Storerkey = @cStorerKey
            AND   PD.Orderkey = @cOrderkey
            AND   PD.SKU = @cSKU
            AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END

            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPPA WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey
               AND   Orderkey = @cOrderkey
               AND   SKU = @cSKU
               AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
               AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
               AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
               AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
               AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
               AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
               AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
               AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
               AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
               AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
               AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
               AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
               AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
               AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
               AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END)
            BEGIN
               INSERT INTO rdt.rdtPPA (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               VALUES ('', '', '', '', @cStorerKey, @cSKU, @cSKUDescr, @nPQTY, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, @cOrderKey, '', 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 103203
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Reset PPA Fail'
                  GOTO RollBackTran
               END
            END
         END

         IF @cPPAType = '4'
         BEGIN
            SELECT @nPQTY = ISNULL( SUM( QTY), 0) 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
            WHERE PD.Storerkey = @cStorerKey
            AND   PD.SKU = @cSKU
            AND   PD.DropID = @cDropID
            AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END

            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPPA WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey
               AND   DropID = @cDropID
               AND   SKU = @cSKU
               AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
               AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
               AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
               AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
               AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
               AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
               AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
               AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
               AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
               AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
               AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
               AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
               AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
               AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
               AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END)
            BEGIN
               SELECT TOP 1 @cOrderKey = OrderKey 
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE SKU = @cSKU
               AND   Storerkey = @cStorerKey
               AND   DropID = @cDropID
               AND   [Status] < '9'

               SELECT TOP 1 @cLoadKey = LoadKey
               FROM dbo.Orders WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   OrderKey = @cOrderKey 

               SELECT TOP 1 @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE ExternOrderKey = @cLoadKey

               INSERT INTO rdt.rdtPPA (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               VALUES ('', @cPickSlipNo, @cLoadKey, '', @cStorerKey, @cSKU, @cSKUDescr, @nPQTY, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, @cOrderKey, @cDropID, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 103204
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Reset PPA Fail'
                  GOTO RollBackTran
               END
            END
         END

         IF @cPPAType = '5'
         BEGIN
            SELECT @nPQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.OrderDetail AS OD WITH (NOLOCK)
            JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
            WHERE LP.UserDefine10 = @cRefNo
            AND   OD.StorerKey = @cStorerKey
            AND   OD.SKU = @cSKU
            AND   LA.Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE LA.Lottable01 END
            AND   LA.Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE LA.Lottable02 END
            AND   LA.Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE LA.Lottable03 END
            AND   ISNULL( LA.Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( LA.Lottable04, 0) END
            AND   ISNULL( LA.Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( LA.Lottable05, 0) END
            AND   LA.Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE LA.Lottable06 END
            AND   LA.Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE LA.Lottable07 END
            AND   LA.Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE LA.Lottable08 END
            AND   LA.Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE LA.Lottable09 END
            AND   LA.Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE LA.Lottable10 END
            AND   LA.Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE LA.Lottable11 END
            AND   LA.Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE LA.Lottable12 END
            AND   ISNULL( LA.Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( LA.Lottable13, 0) END
            AND   ISNULL( LA.Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( LA.Lottable14, 0) END
            AND   ISNULL( LA.Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( LA.Lottable15, 0) END

            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPPA WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey
               AND   RefKey = @cRefNo
               AND   SKU = @cSKU
               AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END
               AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END
               AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END
               AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
               AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
               AND   Lottable06 = CASE WHEN @cLottable06 <> '' THEN @cLottable06 ELSE Lottable06 END
               AND   Lottable07 = CASE WHEN @cLottable07 <> '' THEN @cLottable07 ELSE Lottable07 END
               AND   Lottable08 = CASE WHEN @cLottable08 <> '' THEN @cLottable08 ELSE Lottable08 END
               AND   Lottable09 = CASE WHEN @cLottable09 <> '' THEN @cLottable09 ELSE Lottable09 END
               AND   Lottable10 = CASE WHEN @cLottable10 <> '' THEN @cLottable10 ELSE Lottable10 END
               AND   Lottable11 = CASE WHEN @cLottable11 <> '' THEN @cLottable11 ELSE Lottable11 END
               AND   Lottable12 = CASE WHEN @cLottable12 <> '' THEN @cLottable12 ELSE Lottable12 END
               AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
               AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
               AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END)
            BEGIN
               INSERT INTO rdt.rdtPPA (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               VALUES (@cRefNo, '', '', '', @cStorerKey, @cSKU, @cSKUDescr, @nPQTY, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, @cOrderKey, '', 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 103205
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Reset PPA Fail'
                  GOTO RollBackTran
               END
            END
         END
      END   -- @nInputKey = 1
   END   -- @nStep = 1

   GOTO QUIT  

   RollBackTran:  
      ROLLBACK TRAN rdt_904ExtUpd01  
  
   Quit:  
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
          COMMIT TRAN rdt_904ExtUpd01  
END

GO