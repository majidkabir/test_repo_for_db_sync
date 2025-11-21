SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_UCC_Swap_GetStat                                */
/* Copyright: IDS                                                       */
/* Purpose: Swap UCC, assign LOC                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-09-07 1.0  Ung      SOS255352. Created                          */
/* 2014-04-07 1.1  Ung      SOS308790. Add CrossDock ASN                */
/* 2014-06-02 1.2  Ung      SOS313440. Add Random check                 */
/* 2015-10-20 1.3  Ung      Performance turning for Nov 11              */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_UCC_Swap_GetStat]
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR(3),
   @cReceiptKey NVARCHAR(10),
   @cStorerKey  NVARCHAR(15), 
   @cNewUCC     NVARCHAR(20),
   @cTotal      NVARCHAR(5)   OUTPUT,
   @cSwapped    NVARCHAR(5)   OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @nQTY           INT
   DECLARE @nTotal         INT
   DECLARE @nSwapped       INT
   DECLARE @cExternKey     NVARCHAR(20)
   DECLARE @cDocType       NVARCHAR(10)
   DECLARE @cLOC           NVARCHAR(10)
   DECLARE @cUserDefined07 NVARCHAR(30)
   
   DECLARE @tExternReceiptKey TABLE
   (
      ExternReceiptKey NVARCHAR( 20) NOT NULL PRIMARY KEY
   )
   
   -- Get UCC info
   SELECT 
      @cSKU = SKU, 
      @nQTY = QTY, 
      @cExternKey = ExternKey, 
      @cLOC = UserDefined06, 
      @cUserDefined07 = UserDefined07
   FROM UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cNewUCC
   
   -- Get Receipt info
   SELECT TOP 1 
      @cReceiptKey = ReceiptKey
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ExternReceiptKey = @cExternKey
   
   -- Get ExternReceiptKey 
   INSERT INTO @tExternReceiptKey (ExternReceiptKey)
   SELECT DISTINCT ExternReceiptKey 
   FROM ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
   
   -- Get Receipt info
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
   
   -- CrossDock
   IF @cDocType = 'X'
   BEGIN
      -- Full check UCC
      IF @cLOC = '1'
      BEGIN
         -- Get total UCC
         SELECT @nTotal = COUNT( DISTINCT UCCNo)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined07 = 'CIQ'
            AND NOT EXISTS( SELECT TOP 1 1 FROM UCC U2 WITH (NOLOCK) WHERE UCC.UCCNo = U2.UCCNo AND StorerKey = @cStorerKey AND UserDefined07 <> 'CIQ') -- Partial check UCC
         
         -- Get swapped UCC
         SELECT @nSwapped = COUNT( DISTINCT UCCNo)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined06 = '1'

        GOTO Quit
      END

      -- Partial check UCC
      IF @cLOC = '2'
      BEGIN
         -- Get total UCC
         SELECT @nTotal = COUNT( DISTINCT UCCNo)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined07 = 'CIQ'
            AND EXISTS( SELECT TOP 1 1 FROM UCC U2 WITH (NOLOCK) WHERE UCC.UCCNo = U2.UCCNo AND StorerKey = @cStorerKey AND UserDefined07 <> 'CIQ') -- Partial check UCC
         
         -- Get swapped UCC
         SELECT @nSwapped = COUNT( DISTINCT UCCNo)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined06 = '2'
        
        GOTO Quit
      END
            
      -- The rest of UCC
      -- Get total UCC
      SELECT @nTotal = COUNT( DISTINCT UCCNo)
      FROM UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND ExternKey = @cExternKey
         AND NOT EXISTS( SELECT TOP 1 1 FROM UCC U2 WITH (NOLOCK) WHERE UCC.UCCNo = U2.UCCNo AND StorerKey = @cStorerKey AND UserDefined07 = 'CIQ') -- Partial check UCC
      
      -- Get swapped UCC
      SELECT @nSwapped = COUNT( DISTINCT UCCNo)
      FROM UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND ExternKey = @cExternKey
         AND UserDefined06 = @cLOC
   END
   
   -- Non crossDock
   IF @cDocType <> 'X' 
   BEGIN
       -- Multi SKU UCC
      IF (SELECT COUNT( 1) FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cNewUCC) > 1
      BEGIN
         -- Get total UCC
         SELECT @nTotal = COUNT(1)
         FROM 
         (
            SELECT UCCNo
            FROM UCC WITH (NOLOCK) 
               JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
            WHERE StorerKey = @cStorerKey 
               -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            GROUP BY UCCNo
            HAVING COUNT( DISTINCT SKU) > 1
         ) A
         
         -- Get swapped UCC
         SELECT @nSwapped = COUNT( DISTINCT UCCNo)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined06 = '1' -- LOC

         GOTO Quit
      END

      -- Random check
      IF @cUserDefined07 = 'RDM'
      BEGIN
         -- Get total UCC
         SELECT @nTotal = COUNT(1)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            -- AND SKU = @cSKU
            -- AND QTY = @nQTY
            AND UserDefined07 = 'RDM'
            AND NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC U2 WITH (NOLOCK) WHERE U2.UCCNo = UCC.UCCNo AND StorerKey = @cStorerKey HAVING COUNT(1) > 1) -- not Multi SKU UCC
                  
         -- Get swapped UCC
         SELECT @nSwapped = COUNT(1)
         FROM UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined06 = '2' -- LOC

         GOTO Quit
      END
   
      -- Minority UCC
      DECLARE @nMinority INT
      SET @nMinority = rdt.RDTGetConfig( @nFunc, 'UCCSwapMinorityLevel', @cStorerKey)
      IF @nMinority > 0 AND @cLOC = '3'
      BEGIN
         -- Get total UCC
         SELECT @nTotal = ISNULL( SUM( UCCCnt), 0) 
         FROM 
         (
            SELECT COUNT( DISTINCT UCCNo) UCCCnt
            FROM dbo.UCC WITH (NOLOCK) 
               JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
            WHERE StorerKey = @cStorerKey 
               -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
               AND UserDefined07 <> 'RDM'
               AND NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC U2 WITH (NOLOCK) WHERE U2.UCCNo = UCC.UCCNo AND StorerKey = @cStorerKey HAVING COUNT(1) > 1) -- not Multi SKU UCC
            GROUP BY SKU, QTY
            HAVING COUNT( DISTINCT UCCNo) <= @nMinority
         ) A

         -- Get swapped UCC
         SELECT @nSwapped = COUNT( 1)
         FROM dbo.UCC WITH (NOLOCK) 
            JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
         WHERE StorerKey = @cStorerKey 
            -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            AND UserDefined06 = '3' -- LOC

         GOTO Quit
      END
      
      -- The rest of UCC
      -- Get total UCC
      SELECT @nTotal = COUNT(1)
      FROM UCC WITH (NOLOCK) 
         JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
      WHERE StorerKey = @cStorerKey 
         -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
         AND SKU = @cSKU
         AND QTY = @nQTY
         AND UserDefined07 <> 'RDM'
         AND NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC U2 WITH (NOLOCK) WHERE U2.UCCNo = UCC.UCCNo AND StorerKey = @cStorerKey HAVING COUNT(1) > 1) -- not Multi SKU UCC
               
      -- Get swapped UCC
      SELECT @nSwapped = COUNT(1)
      FROM UCC WITH (NOLOCK) 
         JOIN @tExternReceiptKey t ON (t.ExternReceiptKey = UCC.ExternKey)
      WHERE StorerKey = @cStorerKey 
         -- AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
         AND SKU = @cSKU
         AND QTY = @nQTY
         AND UserDefined06 = @cLOC
   END
   
Quit:
   SET @cTotal = CAST( ISNULL( @nTotal, 0) AS NVARCHAR( 5))
   SET @cSwapped = CAST( ISNULL( @nSwapped, 0) AS NVARCHAR( 5))
   
END

GO