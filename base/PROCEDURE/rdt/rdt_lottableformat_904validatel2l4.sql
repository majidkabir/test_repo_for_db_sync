SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: rdt_LottableFormat_904ValidateL2L4                   */
/* Copyright      : LF                                                   */
/*                                                                       */
/* Purpose: Validate L2 & L4 against the PPA type keyed in               */
/*                                                                       */
/*                                                                       */
/* Date        Rev  Author      Purposes                                 */
/* 07-09-2016  1.0  James       SOS374911. Created                       */
/*************************************************************************/
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_904ValidateL2L4]  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT,  
   @cStorerKey       NVARCHAR( 15),  
   @cSKU             NVARCHAR( 20),  
   @cLottableCode    NVARCHAR( 30),   
   @nLottableNo      INT,  
   @cFormatSP        NVARCHAR( 50),   
   @cLottableValue   NVARCHAR( 60),   
   @cLottable        NVARCHAR( 60) OUTPUT,  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  

   DECLARE  @nStart        INT,
            @nLength2Take  INT, 
            @cCode         NVARCHAR( 10),
            @cShort        NVARCHAR( 10),
            @cLong         NVARCHAR( 250),
            @cUDF01        NVARCHAR( 60),
            @cSSCC         NVARCHAR( 60),
            @cPPAType      NVARCHAR( 1),
            @cRefNo        NVARCHAR( 20),
            @cOrderkey     NVARCHAR( 10),
            @cLoadkey      NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),
            @cDropID       NVARCHAR( 20),
            @cEditable     NVARCHAR( 2),
            @cLottable01   NVARCHAR( 18),
            @cLottable02   NVARCHAR( 18),
            @cLottable03   NVARCHAR( 18),
            @dLottable04   DATETIME,
            @dLottable05   DATETIME,
            @cLottable06   NVARCHAR( 30),
            @cLottable07   NVARCHAR( 30),
            @cLottable08   NVARCHAR( 30),
            @cLottable09   NVARCHAR( 30),
            @cLottable10   NVARCHAR( 30),
            @cLottable11   NVARCHAR( 30),
            @cLottable12   NVARCHAR( 30),
            @dLottable13   DATETIME,
            @dLottable14   DATETIME,
            @dLottable15   DATETIME

   IF EXISTS ( SELECT 1 FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE Lottablecode = @cLottableCode
               AND   LottableNo = @nLottableNo
               AND   Function_ID = @nFunc
               AND   StorerKey = @cStorerKey
               AND   Editable = '1')
   BEGIN
      SET @cLottable = @cLottableValue
      SET @cEditable = '1'

      SELECT @cPPAType     = V_String18, 
             @cOrderKey    = V_String1,
             @cDropID      = V_String2,
             @cRefNo       = V_String19,
             @cLoadkey     = V_Loadkey,
             @cPickSlipNo  = V_PickSlipNo,
             @cSKU         = V_SKU,
             @cStorerKey   = StorerKey
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SET @cLottable01 = CASE WHEN @nLottableNo = 1 THEN @cLottableValue ELSE '' END
      SET @cLottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottableValue ELSE '' END
      SET @cLottable03 = CASE WHEN @nLottableNo = 3 THEN @cLottableValue ELSE '' END
      SET @dLottable04 = CASE WHEN @nLottableNo = 4 THEN @cLottableValue ELSE '' END
      SET @dLottable05 = CASE WHEN @nLottableNo = 5 THEN @cLottableValue ELSE '' END
      SET @cLottable06 = CASE WHEN @nLottableNo = 6 THEN @cLottableValue ELSE '' END
      SET @cLottable07 = CASE WHEN @nLottableNo = 7 THEN @cLottableValue ELSE '' END
      SET @cLottable08 = CASE WHEN @nLottableNo = 8 THEN @cLottableValue ELSE '' END
      SET @cLottable09 = CASE WHEN @nLottableNo = 9 THEN @cLottableValue ELSE '' END
      SET @cLottable10 = CASE WHEN @nLottableNo = 10 THEN @cLottableValue ELSE '' END
      SET @cLottable11 = CASE WHEN @nLottableNo = 11 THEN @cLottableValue ELSE '' END
      SET @cLottable12 = CASE WHEN @nLottableNo = 12 THEN @cLottableValue ELSE '' END
      SET @dLottable13 = CASE WHEN @nLottableNo = 13 THEN @cLottableValue ELSE '' END
      SET @dLottable14 = CASE WHEN @nLottableNo = 14 THEN @cLottableValue ELSE '' END
      SET @dLottable15 = CASE WHEN @nLottableNo = 15 THEN @cLottableValue ELSE '' END
   END
   ELSE
   BEGIN
      SELECT @cPPAType     = V_String18, 
             @cOrderKey    = V_String1,
             @cDropID      = V_String2,
             @cRefNo       = V_String19,
             @cLoadkey     = V_Loadkey,
             @cPickSlipNo  = V_PickSlipNo,
             @cSKU         = V_SKU,
             @cStorerKey   = StorerKey,
             @cLottable01 = V_Lottable01,
             @cLottable02 = V_Lottable02,
             @cLottable03 = V_Lottable03,
             @dLottable04 = V_Lottable04,
             @dLottable05 = V_Lottable05,
             @cLottable06 = V_Lottable06,
             @cLottable07 = V_Lottable07,
             @cLottable08 = V_Lottable08,
             @cLottable09 = V_Lottable09,
             @cLottable10 = V_Lottable10,
             @cLottable11 = V_Lottable11,
             @cLottable12 = V_Lottable12,
             @dLottable13 = V_Lottable13,
             @dLottable14 = V_Lottable14,
             @dLottable15 = V_Lottable15
      FROM RDT.RDTMOBREC WITH (NOLOCK)
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
   END

   IF @cPPAType = '1'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey )
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE LPD.Loadkey = @cLoadkey
         AND   PD.SKU = @cSKU
         AND   O.Storerkey = @cStorerKey
         AND   Lottable01 = CASE WHEN @nLottableNo = 1 THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN @nLottableNo = 3 THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN @nLottableNo = 4 AND ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN @nLottableNo = 5 AND ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN @nLottableNo = 6 THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN @nLottableNo = 7 THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN @nLottableNo = 8 THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN @nLottableNo = 9 THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN @nLottableNo = 10 THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN @nLottableNo = 11 THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN @nLottableNo = 12 THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( LA.Lottable13, 0) = CASE WHEN @nLottableNo = 13 AND ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( LA.Lottable13, 0) END
         AND   ISNULL( LA.Lottable14, 0) = CASE WHEN @nLottableNo = 14 AND ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( LA.Lottable14, 0) END
         AND   ISNULL( LA.Lottable15, 0) = CASE WHEN @nLottableNo = 15 AND ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( LA.Lottable15, 0) END)
      BEGIN
         GOTO Fail
      END
   END

   IF @cPPAType = '2'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE PD.Storerkey = @cStorerKey
         AND   PD.SKU = @cSKU
         AND   PD.PickSlipNo = @cPickSlipNo
         AND   Lottable01 = CASE WHEN @nLottableNo = 1 THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN @nLottableNo = 3 THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN @nLottableNo = 4 AND ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN @nLottableNo = 5 AND ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN @nLottableNo = 6 THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN @nLottableNo = 7 THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN @nLottableNo = 8 THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN @nLottableNo = 9 THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN @nLottableNo = 10 THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN @nLottableNo = 11 THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN @nLottableNo = 12 THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( LA.Lottable13, 0) = CASE WHEN @nLottableNo = 13 AND ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( LA.Lottable13, 0) END
         AND   ISNULL( LA.Lottable14, 0) = CASE WHEN @nLottableNo = 14 AND ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( LA.Lottable14, 0) END
         AND   ISNULL( LA.Lottable15, 0) = CASE WHEN @nLottableNo = 15 AND ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( LA.Lottable15, 0) END)
      BEGIN
         GOTO Fail
      END
   END

   IF @cPPAType = '3'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE PD.Storerkey = @cStorerKey
         AND   PD.Orderkey = @cOrderkey
         AND   PD.SKU = @cSKU
         AND   Lottable01 = CASE WHEN @nLottableNo = 1 THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN @nLottableNo = 3 THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN @nLottableNo = 4 AND ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN @nLottableNo = 5 AND ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN @nLottableNo = 6 THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN @nLottableNo = 7 THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN @nLottableNo = 8 THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN @nLottableNo = 9 THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN @nLottableNo = 10 THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN @nLottableNo = 11 THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN @nLottableNo = 12 THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( LA.Lottable13, 0) = CASE WHEN @nLottableNo = 13 AND ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( LA.Lottable13, 0) END
         AND   ISNULL( LA.Lottable14, 0) = CASE WHEN @nLottableNo = 14 AND ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( LA.Lottable14, 0) END
         AND   ISNULL( LA.Lottable15, 0) = CASE WHEN @nLottableNo = 15 AND ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( LA.Lottable15, 0) END)
      BEGIN
         GOTO Fail
      END
   END

   IF @cPPAType = '4'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE PD.Storerkey = @cStorerKey
         AND   PD.SKU = @cSKU
         AND   PD.DropID = @cDropID
         AND   Lottable01 = CASE WHEN @nLottableNo = 1 THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN @nLottableNo = 3 THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN @nLottableNo = 4 AND ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN @nLottableNo = 5 AND ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN @nLottableNo = 6 THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN @nLottableNo = 7 THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN @nLottableNo = 8 THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN @nLottableNo = 9 THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN @nLottableNo = 10 THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN @nLottableNo = 11 THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN @nLottableNo = 12 THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( LA.Lottable13, 0) = CASE WHEN @nLottableNo = 13 AND ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( LA.Lottable13, 0) END
         AND   ISNULL( LA.Lottable14, 0) = CASE WHEN @nLottableNo = 14 AND ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( LA.Lottable14, 0) END
         AND   ISNULL( LA.Lottable15, 0) = CASE WHEN @nLottableNo = 15 AND ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( LA.Lottable15, 0) END)
      BEGIN
         GOTO Fail
      END
   END

   IF @cPPAType = '5'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.OrderDetail AS OD WITH (NOLOCK)
         JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
         JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE LP.UserDefine10 = @cRefNo
         AND   OD.StorerKey = @cStorerKey
         AND   OD.SKU = @cSKU
         AND   LA.Lottable01 = CASE WHEN @nLottableNo = 1 THEN @cLottable01 ELSE LA.Lottable01 END
         AND   LA.Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottable02 ELSE LA.Lottable02 END
         AND   LA.Lottable03 = CASE WHEN @nLottableNo = 3 THEN @cLottable03 ELSE LA.Lottable03 END
         AND   ISNULL( LA.Lottable04, 0) = CASE WHEN @nLottableNo = 4 AND ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( LA.Lottable04, 0) END
         AND   ISNULL( LA.Lottable05, 0) = CASE WHEN @nLottableNo = 5 AND ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( LA.Lottable05, 0) END
         AND   LA.Lottable06 = CASE WHEN @nLottableNo = 6 THEN @cLottable06 ELSE LA.Lottable06 END
         AND   LA.Lottable07 = CASE WHEN @nLottableNo = 7 THEN @cLottable07 ELSE LA.Lottable07 END
         AND   LA.Lottable08 = CASE WHEN @nLottableNo = 8 THEN @cLottable08 ELSE LA.Lottable08 END
         AND   LA.Lottable09 = CASE WHEN @nLottableNo = 9 THEN @cLottable09 ELSE LA.Lottable09 END
         AND   LA.Lottable10 = CASE WHEN @nLottableNo = 10 THEN @cLottable10 ELSE LA.Lottable10 END
         AND   LA.Lottable11 = CASE WHEN @nLottableNo = 11 THEN @cLottable11 ELSE LA.Lottable11 END
         AND   LA.Lottable12 = CASE WHEN @nLottableNo = 12 THEN @cLottable12 ELSE LA.Lottable12 END
         AND   ISNULL( LA.Lottable13, 0) = CASE WHEN @nLottableNo = 13 AND ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( LA.Lottable13, 0) END
         AND   ISNULL( LA.Lottable14, 0) = CASE WHEN @nLottableNo = 14 AND ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( LA.Lottable14, 0) END
         AND   ISNULL( LA.Lottable15, 0) = CASE WHEN @nLottableNo = 15 AND ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( LA.Lottable15, 0) END)
      BEGIN
         GOTO Fail
      END
   END

   GOTO Quit

Fail:  
   IF @cEditable = '1'
      SET @cLottable = ''

   IF @nLottableNo = 1  SET @nErrNo = 103751 --Invalid LOT01
   IF @nLottableNo = 2  SET @nErrNo = 103752 --Invalid LOT02
   IF @nLottableNo = 3  SET @nErrNo = 103753 --Invalid LOT03
   IF @nLottableNo = 4  SET @nErrNo = 103754 --Invalid LOT04
   IF @nLottableNo = 5  SET @nErrNo = 103755 --Invalid LOT05
   IF @nLottableNo = 6  SET @nErrNo = 103756 --Invalid LOT06
   IF @nLottableNo = 7  SET @nErrNo = 103757 --Invalid LOT07
   IF @nLottableNo = 8  SET @nErrNo = 103758 --Invalid LOT08
   IF @nLottableNo = 9  SET @nErrNo = 103759 --Invalid LOT09
   IF @nLottableNo = 10  SET @nErrNo = 103760 --Invalid LOT10
   IF @nLottableNo = 11  SET @nErrNo = 103761 --Invalid LOT11
   IF @nLottableNo = 12  SET @nErrNo = 103762 --Invalid LOT12
   IF @nLottableNo = 13  SET @nErrNo = 103763 --Invalid LOT13
   IF @nLottableNo = 14  SET @nErrNo = 103764 --Invalid LOT14
   IF @nLottableNo = 15  SET @nErrNo = 103765 --Invalid LOT15

   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix
Quit:  

END -- End Procedure  

GO