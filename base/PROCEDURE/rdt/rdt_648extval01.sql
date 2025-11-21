SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_648ExtVal01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate Qty to move must be equal to Qty available         */
/*          in same loc, id + lottables (regardless sku)                */
/*                                                                      */
/* Called from: rdtfnc_Move_SKU_Lottable_V7                             */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 12-Aug-2021  1.0  yeekung     WMS-17527. Created                    */
/************************************************************************/
CREATE PROC [RDT].[rdt_648ExtVal01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cFromLOC       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @nQTY           INT,          
   @cToID          NVARCHAR( 18),
   @cToLOC         NVARCHAR( 10),
   @cLottableCode  NVARCHAR( 30),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,     
   @dLottable05    DATETIME,     
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,     
   @dLottable14    DATETIME,     
   @dLottable15    DATETIME,     
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 
   DECLARE 
      @nQTY_Bal      INT,
      @nQTY_LLI      INT,
      @nQTY_Avail    INT,
      @cSKU2Move     NVARCHAR( 20),
      @cMUOM_Desc    NVARCHAR( 5),
      @cUserName     NVARCHAR( 18),
      @cLOT          NVARCHAR( 10),
      @cWhere        NVARCHAR( MAX),
      @curLLI        CURSOR,
      @cGroupBy      NVARCHAR( MAX),
      @cOrderBy      NVARCHAR( MAX),
      @cSQL          NVARCHAR( MAX),
      @cSQLParam     NVARCHAR( MAX),
      @cUserid       NVARCHAR(20),
      @cOpsPosition  NVARCHAR(20)

      
      IF @nStep='2'
      BEGIN
         SELECT @cUserid=UserName
         FROM rdt.rdtmobrec (NOLOCK)
         WHERE mobile=@nMobile

         SELECT @cOpsPosition=opsPosition
         FROM rdt.rdtuser(NOLOCK)
         WHERE username=@cUserid

         IF @cOpsPosition='B2B'
         BEGIN
            IF EXISTS(SELECT 1 
                     FROM dbo.LOTxLOCxID LLI (NOLOCK) JOIN
                     dbo.LOTATTRIBUTE LA(NOLOCK) 
                     ON (LLi.Lot=LA.Lot AND lli.sku=la.Sku AND lli.StorerKey=la.StorerKey)
                     WHERE la.Lottable02 IN ('01000','02000')
                     AND lli.loc=@cFromLOC
                     HAVING SUM(lli.Qty) IN(0)
                     )
                     OR NOT EXISTS (SELECT 1 
                        FROM dbo.LOTxLOCxID LLI (NOLOCK) JOIN
                        dbo.LOTATTRIBUTE LA(NOLOCK) 
                        ON (LLi.Lot=LA.Lot AND lli.sku=la.Sku AND lli.StorerKey=la.StorerKey)
                        WHERE lli.loc=@cFromLOC
                        AND la.Lottable02 IN ('01000','02000')
                        AND LA.StorerKey=@cStorerKey)
            BEGIN
               SET @nErrNo = 173653 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DiffLotID'
               GOTO Quit
            END
         END
         ELSE IF @cOpsPosition='B2C'
         BEGIN
            IF EXISTS(SELECT 1 
                     FROM dbo.LOTxLOCxID LLI (NOLOCK) JOIN
                     dbo.LOTATTRIBUTE LA(NOLOCK) 
                     ON (LLi.Lot=LA.Lot AND lli.sku=la.Sku AND lli.StorerKey=la.StorerKey)
                     WHERE la.Lottable02 NOT IN ('01000','02000')
                     AND lli.loc=@cFromLOC
                     HAVING SUM(lli.Qty) IN(0)
                     )
                     OR NOT EXISTS (SELECT 1 
                        FROM dbo.LOTxLOCxID LLI (NOLOCK) JOIN
                        dbo.LOTATTRIBUTE LA(NOLOCK) 
                        ON (LLi.Lot=LA.Lot AND lli.sku=la.Sku AND lli.StorerKey=la.StorerKey)
                        WHERE lli.loc=@cFromLOC
                        AND la.Lottable02 NOT IN ('01000','02000')
                        AND LA.StorerKey=@cStorerKey)
            BEGIN
               SET @nErrNo = 173654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DiffLotID'
               GOTO Quit
            END
         END
      END

      IF @nStep='7'
      BEGIN
         SELECT @cUserid=UserName
         FROM rdt.rdtmobrec (NOLOCK)
         WHERE mobile=@nMobile

         SELECT @cOpsPosition=opsPosition
         FROM rdt.rdtuser(NOLOCK)
         WHERE username=@cUserid

         IF @cOpsPosition='B2B'
         BEGIN
            IF EXISTS(SELECT 1
                      FROM loc (NOLOCK)
                      WHERE loc=@ctoloc
                      AND LocationFlag='HOLD'
                      AND LocationCategory IN (SELECT code
                                               FROM codelkup (NOLOCK)
                                               WHERE listname='NonITFLoc'
                                               AND storerkey=@cStorerKey))
            BEGIN
               SET @nErrNo = 173651  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'QtyAvl<>Qty2Mv'
               GOTO Quit
            END
         END
         ELSE IF @cOpsPosition='B2C'
         BEGIN
            IF EXISTS(SELECT 1
                      FROM loc (NOLOCK)
                      WHERE loc=@ctoloc
                      AND LocationFlag='HOLD'
                      AND LocationCategory NOT IN (SELECT code
                                               FROM codelkup (NOLOCK)
                                               WHERE listname='NonITFLoc'
                                               AND storerkey=@cStorerKey))
                      
            BEGIN
               SET @nErrNo = 173652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'QtyAvl<>Qty2Mv'
               GOTO Quit
            END
         END
      END

   Quit:
END

GO