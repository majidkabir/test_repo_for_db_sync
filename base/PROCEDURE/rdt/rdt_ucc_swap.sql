SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_UCC_Swap                                        */
/* Copyright: IDS                                                       */
/* Purpose: Swap UCC, assign LOC                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-09-07 1.0  Ung      SOS255352. Created                          */
/* 2014-04-07 1.1  Ung      SOS308790. Add CrossDock ASN                */
/* 2014-06-02 1.2  Ung      SOS313440. Add Random check                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_UCC_Swap]
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR(3),
   @cReceiptKey NVARCHAR(10),
   @cStorerKey  NVARCHAR(15), 
   @cOldUCC     NVARCHAR(20),
   @cNewUCC     NVARCHAR(20),
   @cLOC        NVARCHAR(10) OUTPUT,
   @nErrNo      INT      OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @cDocType    NVARCHAR(1)
   DECLARE @cExternKey  NVARCHAR(20)
   DECLARE @nTotalLOC   INT
   DECLARE @nTotalUCC   INT
   DECLARE @nMinority   INT

   SET @cSKU = ''
   SET @nQTY = 0
   SET @cLOC = ''
   SET @cExternKey = ''

   -- Get storer config
   SET @nTotalLOC = rdt.RDTGetConfig( @nFunc, 'UCCSwapTotalLOC', @cStorerKey)
   IF @nTotalLOC = 0
      SET @nTotalLOC = 50

   -- Get Receipt info
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
   
   -- Get UCC info
   SELECT 
      @cExternKey = Externkey, 
      @cSKU = SKU, 
      @nQTY = QTY 
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE UCCNo = @cOldUCC 
      AND StorerKey = @cStorerKey
   
   IF @cDocType = 'X' -- CrossDock
   BEGIN
      SET @cSKU = ''
      SET @nQTY = 0
      
      -- If CIQ check
      IF EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cOldUCC AND StorerKey = @cStorerKey AND UserDefined07 = 'CIQ')
      BEGIN
         IF EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cOldUCC AND StorerKey = @cStorerKey AND UserDefined07 = '')
            SET @cLOC = '2' -- Partial check
         ELSE
            SET @cLOC = '1' -- Full check

         GOTO UpdateUCC
      END
      
      -- Get LOC with same SKU and QTY
      SELECT @cLOC = LOC 
      FROM rdt.rdtUCCSwapLog WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey -- Same ASN
         AND Externkey = @cExternKey  -- Same Externkey
      
      IF @cLOC <> '' GOTO UpdateUCC
   END
   ELSE
   BEGIN
      -- If multi SKU UCC, LOC = 1
      IF (SELECT COUNT(1) FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cOldUCC AND StorerKey = @cStorerKey) > 1
      BEGIN
         SET @cSKU = ''
         SET @nQTY = 0
         SET @cLOC = '1'
         GOTO UpdateUCC
      END
      
      -- If random check UCC, LOC = 2
      IF EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cOldUCC AND StorerKey = @cStorerKey AND UserDefined07 = 'RDM')
      BEGIN
         SET @cSKU = ''
         SET @nQTY = 0
         SET @cLOC = '2'
         GOTO UpdateUCC
      END
      
      -- Minority UCC
      SET @nMinority = rdt.RDTGetConfig( @nFunc, 'UCCSwapMinorityLevel', @cStorerKey)
      IF @nMinority > 0
      BEGIN
         -- Get UCC with same SKU QTY, exclude multi SKU UCC and random check UCC
         SELECT @nTotalUCC = COUNT(1) 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND ExternKey = @cExternKey
            AND SKU = @cSKU
            AND QTY = @nQTY
            AND UserDefined07 <> 'RDM'
            AND NOT EXISTS( SELECT COUNT(1) FROM dbo.UCC U2 WITH (NOLOCK) WHERE U2.UCCNo = UCC.UCCNo AND StorerKey = @cStorerKey HAVING COUNT(1) > 1) -- not Multi SKU UCC
         
         -- If no of UCC less then defined, LOC = 3
         IF @nTotalUCC <= @nMinority
         BEGIN
            SET @cSKU = ''
            SET @nQTY = 0
            SET @cLOC = '3'
            GOTO UpdateUCC
         END
      END
            
      -- Get LOC with same SKU and QTY
      SELECT @cLOC = LOC 
      FROM rdt.rdtUCCSwapLog WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey -- Same ASN
         AND SKU = @cSKU              -- Same SKU
         AND QTY = @nQTY              -- Same QTY
      
      IF @cLOC <> '' GOTO UpdateUCC
   END
   
   -- List LOC 2... to total locations
   IF EXISTS( SELECT 1 FROM tempdb.dbo.sysobjects WHERE ID = OBJECT_ID(N'tempdb..#LOC'))
      DROP TABLE #LOC
   CREATE TABLE #LOC (LOC NVARCHAR(10))
   DECLARE @i INT
   SET @i = CASE WHEN @cDocType = 'X' THEN 3 ELSE 4 END -- Starting loc
   WHILE @i <= @nTotalLOC
   BEGIN
      INSERT INTO #LOC (LOC) VALUES (@i) -- (RIGHT( '0' + CAST( @i AS NVARCHAR(2)),2))
      SET @i = @i + 1
   END
   
   -- Get an empty LOC
   SELECT TOP 1 @cLOC = LOC 
   FROM #LOC
   WHERE NOT EXISTS (SELECT 1 FROM rdt.rdtUCCSwapLog WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND #LOC.LOC = rdtUCCSwapLog.LOC)
   ORDER BY CAST( LOC AS INT)
   
   -- Check empty LOC available
   IF @cLOC = ''
   BEGIN
      SET @nErrNo = 76901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No empty LOC
      GOTO Quit
   END

   -- Lock the LOC
   DECLARE @iRowCount INT
   INSERT INTO rdt.rdtUCCSwapLog (ReceiptKey, LOC, SKU, QTY, ExternKey)
   SELECT @cReceiptKey, @cLOC, @cSKU, @nQTY, @cExternKey
   WHERE NOT EXISTS (SELECT 1 FROM rdt.rdtUCCSwapLog WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND @cLOC = rdtUCCSwapLog.LOC)
   
   SELECT @nErrNo = @@ERROR, @iRowCount = @@ROWCOUNT
   IF @nErrNo <> 0
   BEGIN
      SET @nErrNo = 76902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
      GOTO Quit
   END
   
   -- Check if LOC taken by other (concurrent users)
   IF @iRowCount <> 1
   BEGIN
      SET @nErrNo = 76903
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCLock. Retry
      GOTO Quit
   END   

UpdateUCC:
   UPDATE UCC SET 
      UCCNo = @cNewUCC, 
      UserDefined04 = @cOldUCC, 
      UserDefined05 = @cReceiptKey, 
      UserDefined06 = @cLOC, 
      EditDate = GETDATE(), 
      EditWho = 'rdt.' + SUSER_NAME()
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cOldUCC
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 76904
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
   END

Quit:
END

GO