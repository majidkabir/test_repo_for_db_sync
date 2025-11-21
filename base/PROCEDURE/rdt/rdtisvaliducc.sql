SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtIsValidUCC                                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate common UCC data error                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-07-12 1.0  UngDH    Created                                     */
/* 2014-02-06 1.1  Ung      SOS296465 Move QTYAlloc with UCC.Status=3   */
/* 2023-06-01 1.2  Ung      WMS-22561 Add UCCWithMultiSKU               */
/* 2023-10-04 1.3  Michael  Fix wrong LOC get from MultiUCC (ML01)      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtIsValidUCC] (
   @cLangCode  NVARCHAR( 3),
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cUCC       NVARCHAR( 20),   -- Compulsory
   @cStorerKey NVARCHAR( 15),   -- Compulsory
   @cStatus    NVARCHAR( 10),   -- Compulsory
   @cChkSKU    NVARCHAR( 20)    = NULL,
   @nChkQTY    INT          = NULL,
   @cChkLOT    NVARCHAR( 10)    = NULL,
   @cChkLOC    NVARCHAR( 10)    = NULL,
   @cChkID     NVARCHAR( 18)    = NULL
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount   INT
   DECLARE @cUCCStorer  NVARCHAR( 15)
   DECLARE @cUCCSKU     NVARCHAR( 20)
   DECLARE @cUCCStatus  NVARCHAR( 1)
   DECLARE @cUCCLOT     NVARCHAR( 10)
   DECLARE @cUCCLOC     NVARCHAR( 10)
   DECLARE @cUCCID      NVARCHAR( 18)
   DECLARE @nUCCQTY     INT
   DECLARE @nCaseCnt    INT

   SET @nErrNo = 0

   -- Check parameter
   IF @cUCC = '' OR @cUCC IS NULL
   BEGIN
      SET @nErrNo = 60661
      SET @cErrMsg = rdt.rdtgetmessage( 60661, @cLangCode, 'DSP') --'UCC needed'
      GOTO Fail
   END
   IF @cStorerKey = '' OR @cStorerKey IS NULL
   BEGIN
      SET @nErrNo = 60662
      SET @cErrMsg = rdt.rdtgetmessage( 60662, @cLangCode, 'DSP') --'Storer needed'
      GOTO Fail
   END
   IF @cStatus IS NULL
   BEGIN
      SET @nErrNo = 60663
      SET @cErrMsg = rdt.rdtgetmessage( 60663, @cLangCode, 'DSP') --'Status needed'
      GOTO Fail
   END

   -- Get UCC
   SELECT
      @cUCCStorer = StorerKey,
      @cUCCSKU = SKU,
      @cUCCStatus = Status,
      @cUCCLOT = LOT,
      @cUCCLOC = LOC,
      @cUCCID = [ID],
      @nUCCQTY = QTY
   FROM dbo.UCC (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCC
      AND CHARINDEX( Status, @cStatus) > 0
   ORDER BY CASE WHEN @cChkLOC IS NOT NULL AND LOC<>@cChkLOC THEN 1 ELSE 2 END    --(ML01)

   SET @nRowCount = @@ROWCOUNT

   -- Validate UCC exist
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 60664
      SET @cErrMsg = rdt.rdtgetmessage( 60664, @cLangCode, 'DSP') --'UCC not exist'
      GOTO Fail
   END

   IF @nRowCount > 1
   BEGIN
      IF rdt.rdtGetConfig( 0, 'UCCWithMultiSKU', @cStorerKey) <> '1' -- 1=Multi SKU UCC
      BEGIN
         SET @nErrNo = 60665
         SET @cErrMsg = rdt.rdtgetmessage( 60665, @cLangCode, 'DSP') --'Multi UCC rec'
         GOTO Fail
      END
   END

   -- Validate SKU
   IF (@cChkSKU IS NOT NULL) AND
      (@cUCCSKU <> @cChkSKU)
   BEGIN
      SET @nErrNo = 60666
      SET @cErrMsg = rdt.rdtgetmessage( 60666, @cLangCode, 'DSP') --'UCC SKU Diff'
      GOTO Fail
   END

   -- Validate LOT
   IF (@cChkLOT IS NOT NULL) AND
      (@cUCCLOT <> @cChkLOT)
   BEGIN
      SET @nErrNo = 60667
      SET @cErrMsg = rdt.rdtgetmessage( 60667, @cLangCode, 'DSP') --'UCC LOT Diff'
      GOTO Fail
   END

   -- Validate LOC
   IF (@cChkLOC IS NOT NULL) AND
      (@cUCCLOC <> @cChkLOC)
   BEGIN
      SET @nErrNo = 60668
      SET @cErrMsg = rdt.rdtgetmessage( 60668, @cLangCode, 'DSP') --'UCC LOC Diff'
      GOTO Fail
   END

   -- Validate ID
   IF (@cChkID IS NOT NULL) AND
      (@cUCCID <> @cChkID)
   BEGIN
      SET @nErrNo = 60669
      SET @cErrMsg = rdt.rdtgetmessage( 60669, @cLangCode, 'DSP') --'UCC ID Diff'
      GOTO Fail
   END

   -- Validate case count
   IF @nChkQTY IS NOT NULL
   BEGIN
      -- Validate QTY
      IF RDT.rdtIsValidQTY( @nUCCQTY, 1) = 0
      BEGIN
         SET @nErrNo = 60671
         SET @cErrMsg = rdt.rdtgetmessage( 60671, @cLangCode, 'DSP') --'Invalid UCCQTY'
         GOTO Fail
      END

      -- If UCC's case count is fixed (i.e. NOT dynamic), check the case count
      IF rdt.rdtGetConfig( 0, 'UCCWithDynamicCaseCNT', @cStorerKey) <> '1' -- 1=Dynamic CaseCNT
      BEGIN
         -- Get CaseCnt
         SELECT @nCaseCnt = CaseCnt
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cUCCSKU

         -- Validate case count
         IF @nCaseCnt = 0 OR @nCaseCnt IS NULL
         BEGIN
            SET @nErrNo = 60670
            SET @cErrMsg = rdt.rdtgetmessage( 60670, @cLangCode, 'DSP') --'Setup CaseCnt'
            GOTO Fail
         END

         IF @nUCCQTY <> @nCaseCnt
         BEGIN
            SET @nErrNo = 60672
            SET @cErrMsg = rdt.rdtgetmessage( 60672, @cLangCode, 'DSP') --'QTY <> CaseCnt'
            GOTO Fail
         END
      END
   END
Fail:


GO