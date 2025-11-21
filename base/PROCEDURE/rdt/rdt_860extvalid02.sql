SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_860ExtValid02                                   */
/* Purpose: Validate whether serial no scanned can be swapped or not    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-04-30   James     1.0   WMS3621 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_860ExtValid02]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cDropID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@nTaskQTY        INT
   ,@nPQTY           INT
   ,@cUCC            NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)

   DECLARE     
      @cNewLottable01   NVARCHAR( 18),    @cNewLottable02   NVARCHAR( 18),    
      @cNewLottable03   NVARCHAR( 18),    @dNewLottable04   DATETIME,         
      @dNewLottable05   DATETIME,         @cNewLottable06   NVARCHAR( 30),    
      @cNewLottable07   NVARCHAR( 30),    @cNewLottable08   NVARCHAR( 30),    
      @cNewLottable09   NVARCHAR( 30),    @cNewLottable10   NVARCHAR( 30),    
      @cNewLottable11   NVARCHAR( 30),    @cNewLottable12   NVARCHAR( 30),    
      @dNewLottable13   DATETIME,         @dNewLottable14   DATETIME,         
      @dNewLottable15   DATETIME,         @cNewID           NVARCHAR( 18)

   DECLARE     
      @cCurLottable01   NVARCHAR( 18),    @cCurLottable02   NVARCHAR( 18),    
      @cCurLottable03   NVARCHAR( 18),    @dCurLottable04   DATETIME,         
      @dCurLottable05   DATETIME,         @cCurLottable06   NVARCHAR( 30),    
      @cCurLottable07   NVARCHAR( 30),    @cCurLottable08   NVARCHAR( 30),    
      @cCurLottable09   NVARCHAR( 30),    @cCurLottable10   NVARCHAR( 30),    
      @cCurLottable11   NVARCHAR( 30),    @cCurLottable12   NVARCHAR( 30),    
      @dCurLottable13   DATETIME,         @dCurLottable14   DATETIME,         
      @dCurLottable15   DATETIME,         @cCurID           NVARCHAR( 18)

   SELECT @cCurLottable02 = O_Field06, 
          @cNewLottable02 = I_Field09
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 860
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Lot02 is serial no and suppose to be unique
            SELECT @cCurLottable01 = Lottable01,
                   @dCurLottable05 = Lottable05,
                   @cCurLottable06 = Lottable06,
                   @cCurLottable07 = Lottable07,
                   @cCurLottable08 = Lottable08,
                   @cCurLottable12 = Lottable12,
                   @cCurID = LLI.ID
            FROM dbo.LOTAttribute LA WITH (NOLOCK)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON LA.LOT = LLI.LOT
            WHERE LA.StorerKey = @cStorerkey
            AND   LA.Lottable02 = @cCurLottable02  -- Existing lot02
            AND   LA.SKU = @cSKU
            AND   LLI.Qty > 0

            SELECT @cNewLottable01 = Lottable01,
                   @dNewLottable05 = Lottable05,
                   @cNewLottable06 = Lottable06,
                   @cNewLottable07 = Lottable07,
                   @cNewLottable08 = Lottable08,
                   @cNewLottable12 = Lottable12,
                   @cNewID = LLI.ID
            FROM dbo.LOTAttribute LA WITH (NOLOCK)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON LA.LOT = LLI.LOT
            WHERE LA.StorerKey = @cStorerkey
            AND   LA.Lottable02 = @cNewLottable02  -- New lot02
            AND   LA.SKU = @cSKU
            AND   LLI.Qty > 0

            IF ISNULL( @cCurID, '') <> ISNULL( @cNewID, '')
            BEGIN
               SET @nErrNo = 122051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff Pallet'
               GOTO Quit
            END

            IF @cNewLottable01 <> @cCurLottable01 OR @cNewLottable01 IS NULL OR @cCurLottable01 IS NULL
            BEGIN
               SET @nErrNo = 122052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L01 Not Match
               GOTO Quit
            END

            IF DATEDIFF( DD, @dCurLottable05, @dNewLottable05) > 90 OR @dNewLottable05 IS NULL OR @dCurLottable05 IS NULL
            BEGIN
               SET @nErrNo = 122053
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L05 Not Match
               GOTO Quit
            END

            IF @cNewLottable06 <> @cCurLottable06 OR @cNewLottable06 IS NULL OR @cCurLottable06 IS NULL
            BEGIN
               SET @nErrNo = 122054
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L06 Not Match
               GOTO Quit
            END

            IF @cNewLottable07 <> @cCurLottable07 OR @cNewLottable07 IS NULL OR @cCurLottable07 IS NULL
            BEGIN
               SET @nErrNo = 122055
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L07 Not Match
               GOTO Quit
            END

            IF @cNewLottable08 <> @cCurLottable08 OR @cNewLottable08 IS NULL OR @cCurLottable08 IS NULL
            BEGIN
               SET @nErrNo = 122056
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L08 Not Match
               GOTO Quit
            END

            IF @cNewLottable12 <> @cCurLottable12 OR @cNewLottable12 IS NULL OR @cCurLottable12 IS NULL
            BEGIN
               SET @nErrNo = 122057
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L12 Not Match
               GOTO Quit
            END
         END
      END
   END
END

Quit:

GO