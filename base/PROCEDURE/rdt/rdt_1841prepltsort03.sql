SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt.rdt_1841PrePltSort03                               */
/*                                                                         */
/* Purpose: Get UCC stat                                                   */
/*                                                                         */
/* Called from: rdt_PrePltSortGetPos                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author     Purposes                                    */
/* 2021-06-21  1.0  Chermaine  WMS-17254.Created (dup rdt_1841PrePltSort01)*/
/* 2022-02-15  1.1  yeekung    Performance Tune (yeekung01)                */
/* 2023-02-21  1.2  James      WMS-21735 Add new position logic (james01)  */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_1841PrePltSort03] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerkey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cReceiptKey     NVARCHAR( 20),
   @cLane           NVARCHAR( 10),
   @cUCC            NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @cType           NVARCHAR( 10), 
   @cCreateUCC      NVARCHAR( 1),       
   @cLottable01     NVARCHAR( 18),      
   @cLottable02     NVARCHAR( 18),      
   @cLottable03     NVARCHAR( 18),      
   @dLottable04     DATETIME,           
   @dLottable05     DATETIME,           
   @cLottable06     NVARCHAR( 30),      
   @cLottable07     NVARCHAR( 30),      
   @cLottable08     NVARCHAR( 30),      
   @cLottable09     NVARCHAR( 30),      
   @cLottable10     NVARCHAR( 30),      
   @cLottable11     NVARCHAR( 30),      
   @cLottable12     NVARCHAR( 30),      
   @dLottable13     DATETIME,           
   @dLottable14     DATETIME,           
   @dLottable15     DATETIME,           
   @cPosition       NVARCHAR( 20)  OUTPUT,
   @cToID           NVARCHAR( 18)  OUTPUT,
   @cClosePallet    NVARCHAR( 1)   OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cUdf06       NVARCHAR( 60),
      @cUdf07       NVARCHAR( 60),
      @cUdf08       NVARCHAR( 60),
      @cUdf09       NVARCHAR( 60),
      @cUdf10       NVARCHAR( 60),
      @cCode        NVARCHAR( 10),
      @cUCCCount    NVARCHAR( 5),
      @nUCCCounted  INT,
      @cPOKey       NVARCHAR( 10), 
      @nPosInUsed       INT,
      @nMaxAllowedPos   INT = 0,
      @nTranCount       INT,
      @nUCCQty          INT,
      @nNonImmediateNeedsPos  INT,
      @cBUSR7       NVARCHAR( 30),
      @cSUSR1       NVARCHAR( 18),
      @cItemClass   NVARCHAR( 10),
      @cPltAllowMixSKU  NVARCHAR( 2),
      @cTemp_SKU    NVARCHAR( 20),
      @cUCC_SKU     NVARCHAR( 20),
      @nMaxPallet   INT = 0,
      @nRowCount    INT,
      @nSKUCount    INT,
      @cMaxPalletCount  NVARCHAR( 5),
      @nPltAllowMixSKU  INT,
      @nRowRef       INT,
      @nNewSKU       INT,
      @cSKUStyle     NVARCHAR(20),
      @cSKUGroup     NVARCHAR(10),
      @cUpdRDMCol   NVARCHAR( 20),
      @cSQL          NVARCHAR( MAX),
      @cSQLParam     NVARCHAR( MAX)
      

   SET @cUpdRDMCol = rdt.rdtGetConfig( @nFunc, 'UpdRDMCol', @cStorerKey) 
   
   SET @cPltAllowMixSKU = rdt.RDTGetConfig( @nFunc, 'PltAllowMixSKU', @cStorerkey)
   IF @cPltAllowMixSKU = '1'
      SET @nPltAllowMixSKU = 99
   ELSE
      SET @nPltAllowMixSKU = CAST( @cPltAllowMixSKU AS INT)
         
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1841PrePltSort03

   IF @cType = 'GET.POS'
   BEGIN
      IF EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND   UCCNo = @cUCC)
                  --AND   [Status] = '1')
      BEGIN
         SET @nErrNo = 170701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
         GOTO RollBackTran
      END

      IF OBJECT_ID('tempdb..#PositionInUsed') IS NOT NULL  
         DROP TABLE #PositionInUsed

      IF OBJECT_ID('tempdb..#AllowedPosition') IS NOT NULL  
         DROP TABLE #AllowedPosition

      CREATE TABLE #PositionInUsed  (  
         RowRef        BIGINT IDENTITY(1,1)  Primary Key,  
         Position      NVARCHAR(3))  

      CREATE TABLE #AllowedPosition  (  
         RowRef        BIGINT IDENTITY(1,1)  Primary Key,  
         Position      NVARCHAR(3))  

      SET @cPosition = ''
      SET @cCode = ''
      SET @cUdf10 = ''
      SET @cSKUGroup = '' --@cBUSR7 = ''

      -- Retrieve sku.busr7 as sub-position, one UCC always have same Busr7 (PE: 10/20/30)
      SELECT @cSKUStyle = Style, --@cItemClass = ItemClass
             @cSUSR1 = SUSR1,
             @cSKUGroup = SKUGroup --@cBUSR7 = ISNULL( BUSR7, '')         
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU
      
      --get position logic
      IF EXISTS (SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE StorerKey = @cStorerkey AND UserDefine01 = @cUCC  and ISNULL(UserDefine01,'')<>'') --yeekung01
      BEGIN
      	SELECT TOP 1   
            @cUdf06 = Userdefined06,
            @cUdf07 = Userdefined07,
            @cUdf08 = Userdefined08,
            @cUdf09 = Userdefined09
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] = '0' -- not received
         ORDER BY ucc.Userdefined06 desc

         IF @cUdf08 IN ('', 'HV') AND @cUdf06 = '1' AND @cUdf07 = '1' AND @cUdf09 = '1'
            SET @cCode = '0014' --QC-FM
         ELSE IF @cUdf08 IN ('', 'HV') AND @cUdf07 = '1' AND @cUdf09 = '1'
            SET @cCode = '0013' --QC-M
         ELSE IF @cUdf08 IN ('', 'HV') AND @cUdf06 = '1' AND @cUdf07 = '1'
            SET @cCode = '0015' --F-M
         ELSE IF (@cUdf08 IN ('BL') AND @cUdf09 = '') AND @cUdf06 = '1' 
            SET @cCode = '006' --BL-F
         ELSE IF @cUdf06 = '1' AND @cUdf07 = '1' AND @cUdf09 = '1'   -- (james01)
            SET @cCode = '0014' --QC-FM
         ELSE IF (@cUdf08 IN ('HV') OR @cUdf09 = '1') AND @cUdf06 = '1' 
            SET @cCode = '004' --QC-F
         ELSE IF @cUdf07 = '1' AND @cUdf09 = '1'   -- (james01)
            SET @cCode = '0013' --QC-M
         ELSE IF @cUdf06 = '1' AND @cUdf07 = '1'   -- (james01)
            SET @cCode = '0015' --F-M
         ELSE IF (@cUdf08 IN ('HV') OR @cUdf09 = '1')
            SET @cCode = '001' --QC
         ELSE IF (@cUdf08 IN ('BL') AND @cUdf09 = '')
            SET @cCode = '005'--BL
         ELSE IF @cUdf06 = '1' AND @cUdf08 = '' AND @cUdf09 = ''
            SET @cCode = '002' --F
         ELSE IF @cUdf07 = '1' AND @cUdf06 = '' AND @cUdf08 = '' AND @cUdf09 = ''
            SET @cCode = '003' --M
         ELSE
         BEGIN
            SELECT @nUCCQty = ISNULL( SUM( Qty), 0)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   UCCNo = @cUCC
            AND   [Status] = '0' -- not received

            IF RDT.rdtIsValidQTY( @cSUSR1, 0) = 1
            BEGIN
               IF @nUCCQty < CAST( @cSUSR1 AS INT)
                  SET @cCode = '007'
            END
            ELSE
               SET @cCode = ''
         END
      END
      
      SELECT @cPosition = ISNULL( Description, '')  
      FROM dbo.CodeLkUp WITH (NOLOCK)  
      WHERE ListName = 'PreRcvLane'  
      AND   StorerKey = @cStorerKey  
      AND   Code = @cCode  
      
      IF ISNULL( @cPosition, '') <> ''
      BEGIN
         SET @cToID = ''
         SELECT TOP 1 @cToID = ID
         FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   Position = @cCode
         AND   [Status] = '1'
         AND   LOC = @cLane
         ORDER BY EditDate DESC
      END
      ELSE
      BEGIN
         INSERT INTO #PositionInUsed (Position)
         SELECT DISTINCT Position
         FROM rdt.rdtPreReceiveSort P WITH (NOLOCK)
         WHERE P.StorerKey = @cStorerKey
         AND   P.ReceiptKey = @cReceiptKey
         AND   P.LOC = @cLane
         AND   P.Func = @nFunc
         AND   P.[Status] = '1'
         AND   ISNULL( P.Position, '') <> ''   -- Position that has some pallet assigned
         AND   NOT EXISTS ( SELECT 1 FROM dbo.CodeLkUp C WITH (NOLOCK) 
                              WHERE C.ListName = 'PreRcvLane'
                              AND   C.Code = P.Position 
                              AND   C.Short = 'R'
                              AND   C.StorerKey = @cStorerKey)

         -- First 6 position reserved as at above
         SELECT @nMaxPallet = MaxPallet
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE LOC = @cLane
         AND   Facility = @cFacility

         IF @nMaxPallet > 0
            SELECT @nMaxAllowedPos = @nMaxPallet - 6
         ELSE
            SELECT @nMaxAllowedPos = COUNT( DISTINCT c.Code) - 6
            FROM dbo.CODELKUP AS c WITH (NOLOCK)
            WHERE c.LISTNAME = 'PreRcvLane'
            AND   c.Storerkey = @cStorerKey

         SET @nNonImmediateNeedsPos = 7

         WHILE @nMaxAllowedPos > 0
         BEGIN
            INSERT INTO #AllowedPosition (Position) VALUES 
            (RIGHT( '000' + CAST( @nNonImmediateNeedsPos AS NVARCHAR( 3)), 3))

            SET @nMaxAllowedPos = @nMaxAllowedPos - 1
            SET @nNonImmediateNeedsPos = @nNonImmediateNeedsPos + 1
         END

         -- If UCC not for reserved loc then look in non reserved loc
         -- Look for pallet that not yet full. Need check allowable pallet max sku count
         -- If no pallet still can accept new sku then look for new loc
         -- If no more loc, prompt FULL
         DECLARE @cur_Position CURSOR
         SET @cCode = ''
         SET @cur_Position = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT DISTINCT Position
         FROM rdt.rdtPreReceiveSort P WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   P.ReceiptKey = @cReceiptKey
         AND   P.LOC = @cLane
         AND   P.Func = @nFunc
         AND   P.UDF01 = @cSKUStyle--@cItemClass
         AND   ISNULL( P.Position, '') <> ''   -- Position that has some pallet assigned
         AND   NOT EXISTS ( SELECT 1 FROM dbo.CodeLkUp C WITH (NOLOCK) 
                            WHERE C.ListName = 'PreRcvLane'
                            AND   C.Code = P.Position 
                            AND   C.Short = 'R'
                            AND   C.StorerKey = @cStorerKey)
         ORDER BY 1
         OPEN @cur_Position
         FETCH NEXT FROM @cur_Position INTO @cCode
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @cToID = ''
            SELECT TOP 1 @cToID = ID
            FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   Position = @cCode
            AND   [Status] = '1'
            AND   LOC = @cLane
            ORDER BY EditDate DESC

            IF @nPltAllowMixSKU <> 99  -- 99 = can mix unlimited sku
            BEGIN
               SELECT @nSKUCount = COUNT( DISTINCT SKU)
               FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   LOC = @cLane
               AND   ID = @cToID
               AND   [Status] = '1'      

               IF NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
                               WHERE ReceiptKey = @cReceiptKey
                               AND   LOC = @cLane
                               AND   ID = @cToID
                               AND   SKU = @cSKU
                               AND   [Status] = '1')
                  SET @nNewSKU = 1
               ELSE
                  SET @nNewSKU = 0
                         
               -- This pallet not yet assign any ucc, no need further check
               IF @nSKUCount > 0
               BEGIN
                  -- If pallet already mix sku and user turn on not mix sku then prompt error
                  IF @nPltAllowMixSKU = 0
                     SET @cToID = ''

                  -- If pallet already mix sku and count > allowable pallet sku count then prompt error
                  IF @nSKUCount > 1 AND (( @nSKUCount + @nNewSKU) > @nPltAllowMixSKU) 
                     SET @cToID = ''

                  -- Try get new position since the current pallet already full
                  IF @cToID <> '' AND ISNULL( @cCode, '') <> ''
                  BEGIN
                     -- If can find the position to put the pallet
                     IF ISNULL( @cCode, '') <> ''
                        BREAK
                  END
               END
            END
            SET @cCode = ''
            FETCH NEXT FROM @cur_Position INTO @cCode
         END

         -- If the sku is never assigned to a pallet in the lane 
         -- THEN assign a new pallet
         -- Need check whether the lane is full or not
         IF ISNULL( @cCode, '') = ''
         BEGIN
            SELECT TOP 1 @cCode = Position 
            FROM #AllowedPosition AP
            WHERE NOT EXISTS ( SELECT 1 FROM #PositionInUsed PIU WHERE AP.Position = PIU.Position)
            ORDER BY Position

            -- If can find the position to put the pallet
            IF ISNULL( @cCode, '') <> ''
            BEGIN
               SELECT @cPosition = ISNULL( Description, '')
               FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE ListName = 'PreRcvLane'
               AND   StorerKey = @cStorerKey
               AND   Code = @cCode
            END
            ELSE
               -- Display FULL if no more empty position
               SET @cPosition = 'FULL'
         END
         ELSE
         BEGIN
            -- We can find the pallet position for the same sku
            SELECT @cPosition = ISNULL( Description, '')
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'PreRcvLane'
            AND   StorerKey = @cStorerKey
            AND   Code = @cCode
         END
      END
      
      -- Non reserved location, pallet can mix sku. No need check here
      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE ListName = 'PreRcvLane'
                        AND   StorerKey = @cStorerKey
                        AND   Code = @cCode
                        AND   Short = 'R')
      BEGIN
         IF @nPltAllowMixSKU <> 99  -- 99 = can mix unlimited sku
         BEGIN
            SELECT @nSKUCount = COUNT( DISTINCT SKU)
            FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   LOC = @cLane
            AND   ID = @cToID
            AND   [Status] = '1'      

            IF NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
                              WHERE ReceiptKey = @cReceiptKey
                              AND   LOC = @cLane
                              AND   ID = @cToID
                              AND   SKU = @cSKU
                              AND   [Status] = '1')
               SET @nNewSKU = 1
            ELSE
               SET @nNewSKU = 0
                         
            -- This pallet not yet assign any ucc, no need further check
            IF @nSKUCount > 0
            BEGIN
               -- If pallet already mix sku and user turn on not mix sku then prompt error
               IF @nPltAllowMixSKU = 0
                  SET @cToID = ''

               -- If pallet already mix sku and count > allowable pallet sku count then prompt error
               IF @nSKUCount > 1 AND (( @nSKUCount + @nNewSKU) > @nPltAllowMixSKU) 
                  SET @cToID = ''

               -- Try get new position since the current pallet already full
               IF @cToID = '' AND ISNULL( @cCode, '') <> ''
               BEGIN
                  SELECT TOP 1 @cCode = Position 
                  FROM #AllowedPosition AP
                  WHERE NOT EXISTS ( SELECT 1 FROM #PositionInUsed PIU WHERE AP.Position = PIU.Position)
                  ORDER BY Position

                  -- If can find the position to put the pallet
                  IF ISNULL( @cCode, '') <> ''
                  BEGIN
                     SELECT @cPosition = ISNULL( Description, '')
                     FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE ListName = 'PreRcvLane'
                     AND   StorerKey = @cStorerKey
                     AND   Code = @cCode
                  END
                  ELSE
                     -- Display FULL if no more empty position
                     SET @cPosition = 'FULL'
               END
            END
         END
      END
         
      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU, ISNULL( SUM( Qty), 0)
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC
      AND   [Status] = '0' -- not received
      GROUP BY SKU
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCC_SKU, @nUCCQty
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
                           WHERE UCCNo = @cUCC
                           AND   SKU = @cUCC_SKU
                           AND   StorerKey = @cStorerKey
                           AND   Func = @nFunc)
         BEGIN
            INSERT INTO rdt.rdtPreReceiveSort
            (Mobile, Func, Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, 
            LOC, ID, Position, SourceType, UDF01, UDF02, [Status],
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15 ) VALUES 
            (@nMobile, @nFunc, @cFacility, @cStorerKey, @cReceiptKey, @cUCC, @cUCC_SKU, @nUCCQty, 
            @cLane, '', @cCode, 'rdt_PrePltSortGetPos', @cSKUStyle, @cSKUGroup, '1',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 170702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Log Fail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE rdt.rdtPreReceiveSort WITH (ROWLOCK) SET 
               Position = @cCode
            WHERE UCCNo = @cUCC
            AND   SKU = @cUCC_SKU
            AND   StorerKey = @cStorerKey
            AND   ReceiptKey = @cReceiptKey
            AND   Loc = @cLane
            AND   [Status] = '1'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 170703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
               GOTO RollBackTran
            END
         END
            
         FETCH NEXT FROM @curUCC INTO @cUCC_SKU, @nUCCQty
      END
      
      SET @cPOKey = ''
      SELECT @cPOKey = ISNULL( POKey, '')
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cUCC

      -- Get count information
      SELECT @nUCCCounted = COUNT( DISTINCT UCCNo)
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Func = @nFunc
      AND   ReceiptKey = @cReceiptKey
      AND   UDF01 = @cSKUStyle--@cItemClass
      AND   Position = @cCode  -- Position
      AND   Loc = @cLane -- Loc
      AND   ( ( @cCode <> '003') OR
               --( @cCode = '003' AND @cBUSR7 <> '' AND UDF02 = @cBUSR7))
               ( @cCode = '003' AND @cSKUGroup <> '' AND UDF02 = @cSKUGroup))

      -- If ucc contain pre set userdefined value (need immediate action)
      IF '1' IN ( @cUdf06, @cUdf07, @cUdf09, @cUdf10)
      BEGIN
         IF @cCode = '001'
         BEGIN
         SELECT @cUCCCount = COUNT( 1) FROM (
            SELECT COUNT( DISTINCT UCCNo) AS A
            FROM dbo.UCC UCC WITH (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
            AND   UCC.Status = '0'
            -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
            -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
            AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     WHERE UCC.StorerKey = RD.StorerKey
                     AND   UCC.ReceiptKey = RD.POKey
                     AND   RD.ReceiptKey = @cReceiptKey
                     AND   RD.FinalizeFlag <> 'Y') 
            GROUP BY UCCNo
            HAVING 1 = CASE WHEN MAX(UCC.Userdefined10) = '1' THEN 1 ELSE '0' END) AS T
         END
         ELSE IF @cCode = '002'
         BEGIN
            SELECT @cUCCCount = COUNT( 1) FROM (
            SELECT COUNT( DISTINCT UCCNo) AS A
            FROM dbo.UCC UCC WITH (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
            AND   UCC.Status = '0'
            -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
            -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
            AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     WHERE UCC.StorerKey = RD.StorerKey
                     AND   UCC.ReceiptKey = RD.POKey
                     AND   RD.ReceiptKey = @cReceiptKey
                     AND   RD.FinalizeFlag <> 'Y') 
            GROUP BY UCCNo
            HAVING 1 = CASE WHEN MIN(UCC.Userdefined06) = '1' THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
            ) AS T
         END
         ELSE IF @cCode = '003'
         BEGIN
            -- (james01)
            IF @cSKUGroup <> '' --@cBUSR7 <> ''
            BEGIN
               SELECT @cUCCCount = COUNT( 1) FROM (
               SELECT COUNT( DISTINCT UCCNo) AS A
               FROM dbo.UCC UCC WITH (NOLOCK)
               WHERE UCC.StorerKey = @cStorerKey
               AND   UCC.Status = '0'
               -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
               -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
               AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                        WHERE UCC.StorerKey = RD.StorerKey
                        AND   UCC.ReceiptKey = RD.POKey
                        AND   RD.ReceiptKey = @cReceiptKey
                        AND   RD.FinalizeFlag <> 'Y') 
               AND   EXISTS ( SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK) 
                              WHERE SKU.SKU = UCC.SKU
                              AND   SKU.StorerKey = UCC.StorerKey
                              --AND   SKU.BUSR7 = @cBUSR7)
                              AND   SKU.SKUGroup = @cSKUGroup)
               GROUP BY UCCNo
               HAVING 1 = CASE WHEN MIN(UCC.Userdefined07) = '1' THEN 1 ELSE '0' END AND
                        1 = CASE WHEN MIN(UCC.Userdefined06) IN ('', '0') THEN 1 ELSE '0' END AND
                        1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
               ) AS T
            END
            ELSE
            BEGIN
               SELECT @cUCCCount = COUNT( 1) FROM (
               SELECT COUNT( DISTINCT UCCNo) AS A
               FROM dbo.UCC UCC WITH (NOLOCK)
               WHERE UCC.StorerKey = @cStorerKey
               AND   UCC.Status = '0'
               -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
               -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
               AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                        WHERE UCC.StorerKey = RD.StorerKey
                        AND   UCC.ReceiptKey = RD.POKey
                        AND   RD.ReceiptKey = @cReceiptKey
                        AND   RD.FinalizeFlag <> 'Y') 
               GROUP BY UCCNo
               HAVING 1 = CASE WHEN MIN(UCC.Userdefined07) = '1' THEN 1 ELSE '0' END AND
                        1 = CASE WHEN MIN(UCC.Userdefined06) IN ('', '0') THEN 1 ELSE '0' END AND
                        1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
               ) AS T

            END

            IF @cSKUGroup <> '' --@cBUSR7 <> ''
            BEGIN
               SET @cPosition = RTRIM( @cPosition) + '-' + @cSKUGroup --@cBUSR7
            END

         END
         ELSE IF @cCode = '004'
         BEGIN
            SELECT @cUCCCount = COUNT( 1) FROM (
            SELECT COUNT( DISTINCT UCCNo) AS A
            FROM dbo.UCC UCC WITH (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
            AND   UCC.Status = '0'
            -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
            -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
            AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     WHERE UCC.StorerKey = RD.StorerKey
                     AND   UCC.ReceiptKey = RD.POKey
                     AND   RD.ReceiptKey = @cReceiptKey
                     AND   RD.FinalizeFlag <> 'Y') 
            GROUP BY UCCNo
            HAVING 1 = CASE WHEN MIN(UCC.Userdefined08) = '1' THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MIN(UCC.Userdefined06) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MIN(UCC.Userdefined07) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
            ) AS T
         END
         ELSE 
         BEGIN
            SELECT @cUCCCount = COUNT( 1) FROM (
            SELECT COUNT( DISTINCT UCCNo) AS A
            FROM dbo.UCC UCC WITH (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
            AND   UCC.Status = '0'
            -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
            -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
            AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     WHERE UCC.StorerKey = RD.StorerKey
                     AND   UCC.ReceiptKey = RD.POKey
                     AND   RD.ReceiptKey = @cReceiptKey
                     AND   RD.FinalizeFlag <> 'Y') 
            GROUP BY UCCNo
            HAVING 1 = CASE WHEN MIN(UCC.Userdefined09) = '1' THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MIN(UCC.Userdefined06) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MIN(UCC.Userdefined07) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MIN(UCC.Userdefined08) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
            ) AS T
         END
      END
      ELSE
      BEGIN
         SELECT @cUCCCount = COUNT( 1) FROM (
         SELECT COUNT( DISTINCT UCCNo) AS A
         FROM dbo.UCC UCC WITH (NOLOCK)
         WHERE UCC.StorerKey = @cStorerKey
         AND   UCC.Status = '0'
         AND   UCC.SKU = @cSKU
         -- For multi po asn scenario. Need to check how many ucc under this asn need to be count
         -- Before receive ucc.receiptkey = rd.pokey. After receive ucc.receiptkey = rd.receiptkey
         AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                        WHERE UCC.StorerKey = RD.StorerKey
                        AND   UCC.ReceiptKey = RD.POKey
                        AND RD.ReceiptKey = @cReceiptKey
                        AND   RD.FinalizeFlag <> 'Y') 
            GROUP BY UCCNo
            HAVING 1 = CASE WHEN MAX(UCC.Userdefined06) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined07) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined08) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined09) IN ('', '0') THEN 1 ELSE '0' END AND
                     1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
            ) AS T

      --SELECT @cRecordCount = @cUCCCounted + '/' + @cUCCCount
      --SET @cRecordCount = ''
      END
   END
   
   IF @cType = 'UPD.ID'
   BEGIN
      -- sequence to display for nike sdc is 10, 6, 7, 8, 9
      SELECT   
         @cUdf10 = MAX( Userdefined10),
         @cUdf06 = CASE WHEN MAX( Userdefined10) = '1' THEN '' ELSE MIN( Userdefined06) END,
         @cUdf07 = CASE WHEN MAX( Userdefined10) = '1' OR MIN( Userdefined06) = '1' THEN '' ELSE MIN( Userdefined07) END,
         @cUdf08 = CASE WHEN MAX( Userdefined10) = '1' OR MIN( Userdefined07) = '1' THEN '' ELSE MIN( Userdefined08) END,
         @cUdf09 = CASE WHEN MAX( Userdefined10) = '1' OR MIN( Userdefined08) = '1' THEN '' ELSE MIN( Userdefined09) END
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC
      AND   [Status] = '0' -- not received

      -- Retrieve sku.busr7 as sub-position, one UCC always have same Busr7 (PE: 10/20/30)
      SELECT @cSKUStyle =Style, --@cItemClass = ItemClass,
             @cSUSR1 = SUSR1,
             @cSKUGROUP = SKUGroup --@cBUSR7 = ISNULL( BUSR7, '')             
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU
      
      IF ISNULL( @cUdf10, '') = '1'
         SET @cCode = '001'
      ELSE IF ISNULL( @cUdf06, '') = '1'
         SET @cCode = '002'
      ELSE IF ISNULL( @cUdf07, '') = '1'
         SET @cCode = '003'
      ELSE IF ISNULL( @cUdf08, '') = '1'
         SET @cCode = '004'
      ELSE IF ISNULL( @cUdf09, '') = '1'
         SET @cCode = '005'
      ELSE
      BEGIN
         SELECT @nUCCQty = ISNULL( SUM( Qty), 0)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] = '0' -- not received

         IF RDT.rdtIsValidQTY( @cSUSR1, 0) = 1
         BEGIN
            IF @nUCCQty < CAST( @cSUSR1 AS INT)
               SET @cCode = '006'
         END
         ELSE
            SET @cCode = ''
      END
      
      -- Non reserved location, pallet can mix sku. No need check here
      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                      WHERE ListName = 'PreRcvLane'
                      AND   StorerKey = @cStorerKey
                      AND   Code = @cCode
                      AND   Short = 'R')
      BEGIN
         IF @nPltAllowMixSKU <> 99  -- 99 = can mix unlimited sku
         BEGIN
            SELECT @nSKUCount = COUNT( DISTINCT SKU)
            FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   LOC = @cLane
            AND   ID = @cToID
            AND   [Status] = '1'      

            IF NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
                            WHERE ReceiptKey = @cReceiptKey
                            AND   LOC = @cLane
                            AND   ID = @cToID
                            AND   SKU = @cSKU
                            AND   [Status] = '1')
               SET @nNewSKU = 1
            ELSE
               SET @nNewSKU = 0
                         
            -- This pallet not yet assign any ucc, no need further check
            IF @nSKUCount > 0
            BEGIN
               -- If pallet already mix sku and user turn on not mix sku then prompt error
               IF @nPltAllowMixSKU = 0
               BEGIN
                  -- If only 1 SKU on the pallet
                  IF @nSKUCount = 1
                  BEGIN
                     SELECT TOP 1 @cTemp_SKU = SKU
                     FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND   LOC = @cLane
                     AND   ID = @cToID
                     AND   [Status] = '1'
                     ORDER BY 1

                     SET @cUCC_SKU = ''
                     SELECT TOP 1 @cUCC_SKU = SKU
                     FROM dbo.UCC WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey
                     AND   UCCNo = @cUCC
                     AND   [Status] = '1'
                     ORDER BY 1
                  END
                           
                  SET @nErrNo = 170704
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltNoMixSKU
                  GOTO RollBackTran
               END

               -- If pallet already mix sku and count > allowable pallet sku count then prompt error
               IF @nSKUCount > 1 AND (( @nSKUCount + @nNewSKU) > @nPltAllowMixSKU) 
               BEGIN
                  SET @nErrNo = 170705
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltMixSKU
                  GOTO RollBackTran
               END
            END
         END
      END
      
      UPDATE RDT.rdtPreReceiveSort WITH (ROWLOCK) SET
         ID = @cToID
      WHERE ReceiptKey = @cReceiptKey
      AND   LOC = @cLane
      AND   UCCNo = @cUCC
      AND   [Status] = '1'
      SET @nRowCount = @@ROWCOUNT
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 170706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
         GOTO RollBackTran
      END
      
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 170707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
         GOTO RollBackTran
      END

      SELECT TOP 1 @cTemp_SKU = SKU, @cCode = Position
      FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   LOC = @cLane
      AND   ID = @cToID
      AND   [Status] = '1'
      ORDER BY 1
                  
      SELECT @cSKUStyle = Style, --@cItemClass = ItemClass,
               @cSKUGroup = SKUGroup --@cBUSR7 = BUSR7 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cTemp_SKU
         
      -- Get count information
      SELECT @nUCCCounted = COUNT( DISTINCT UCCNo)
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Func = @nFunc
      AND   ReceiptKey = @cReceiptKey
      AND   UDF01 = @cSKUStyle--@cItemClass
      AND   Position = @cCode  -- Position
      AND   Loc = @cLane -- Loc
      AND   ID = @cToID -- ID
      --AND   ( ( @cCode <> '003') OR
      --         ( @cCode = '003' AND @cBUSR7 <> '' AND UDF02 = @cBUSR7))  

      SELECT TOP 1 @cMaxPalletCount = Short 
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'PltMaxCnt'
      AND   Code = @cSKUGroup --@cBUSR7
      AND   StorerKey = @cStorerkey
      AND   CODE2 = @cFacility
      ORDER BY 1
      
      -- Setup codelkup only need check max pallet count
      IF @@ROWCOUNT = 1
      BEGIN
         IF rdt.rdtIsValidQty( @cMaxPalletCount, 1) = 1
         BEGIN
            IF @nUCCCounted >= CAST( @cMaxPalletCount AS INT)
               SET @cClosePallet = '1'
         END
         ELSE
         BEGIN
            SET @nErrNo = 170708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPltCnt Err
            GOTO RollBackTran
         END
      END      

      IF EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
                  WHERE ReceiptKey = @cReceiptKey 
                  AND   ID = @cToID 
                  AND   [Status] = '9')
      BEGIN
         SET @nErrNo = 170709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Closed
         GOTO RollBackTran
      END
      
      --udate UCC.userDefine01 =RDM for UCC Pre Rev Audit(Fn845)
      IF @cUpdRDMCol <> '0'  
      BEGIN
      	--Pallet Position belong QC,QC-F,BL and BL-F.
      	IF EXISTS (SELECT 1
      	            FROM RDT.rdtPreReceiveSort PRS WITH (NOLOCK)
      	            JOIN codelkup C WITH (NOLOCK) ON (PRS.Position = C.Code AND PRS.StorerKey = C.Storerkey)
                     WHERE ReceiptKey = @cReceiptKey
                     AND   LOC = @cLane
                     AND   UCCNo = @cUCC
                     AND   [Status] = '1'
                     AND   ID = @cToID
                     AND   C.ListName = 'PreRcvLane'
                     AND   C.UDF05 = 'RDM')   
                     --AND   C.[Description] IN ('QC','QC-F','BL','BL-F') )
         BEGIN
         	SET @cSQL = N'Update UCC WITH (ROWLOCK) SET ' +    
         	            ' EditDate = GETDATE(), ' +
         	            ' EditWho = suser_sName(), ' +
         	            @cUpdRDMCol + ' = c.UDF05 ' +
         	            ' FROM UCC U WITH (ROWLOCK) ' +
         	            ' JOIN RDT.rdtPreReceiveSort PRS WITH (NOLOCK) ON (U.UccNo = PRS.UCCNo AND U.Storerkey = PRS.StorerKey) ' +
         	            ' JOIN codelkup C WITH (NOLOCK) ON (PRS.Position = C.Code AND PRS.StorerKey = C.Storerkey) ' +
         	            ' WHERE PRS.ReceiptKey = @cReceiptKey ' +
         	            ' AND PRS.LOC = @cLane ' +
                        ' AND U.UCCNo = @cUCC ' +
                        ' AND PRS.ID = @cToID ' +
                        ' AND PRS.StorerKey = @cStorerKey ' +     
                        ' AND   C.ListName = ''PreRcvLane'' ' +
                        ' SET @nErrNo = @@ERROR' 
                     
            SET @cSQLParam = ' @cReceiptKey  NVARCHAR(20), ' + 
                           ' @cLane          NVARCHAR(10), ' + 
                           ' @cUCC           NVARCHAR(20), ' +
                           ' @cToID          NVARCHAR(18), ' +  
                           ' @cStorerKey     NVARCHAR(15), ' + 
                           ' @nErrNo         INT = 0 OUTPUT' 
                           
            EXEC sp_ExecuteSql @cSQL    
                        , @cSQLParam    
                        , @cReceiptKey
                        , @cLane 
                        , @cUCC  
                        , @cToID    
                        , @cStorerKey 
                        , @nErrNo   OUTPUT 
                        
            IF @nErrNo <> 0  
               GOTO Quit     	
         END
      END         
   END
   
   IF @cType = 'DEL.UCC'
   BEGIN
      SELECT TOP 1 @nRowRef = RowRef
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   LOC = @cLane
      AND   [Status] = '1'      
      AND   UCCNo = @cUCC
      ORDER BY 1
      
      IF @@ROWCOUNT = 1
      BEGIN
		 --DELETE FROM RDT.rdtPreReceiveSort WHERE Rowref = @nRowRef  
        
		 --INC1213854 (START)
		 DECLARE curDelUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
		 SELECT RowRef   
		 FROM rdt.rdtPreReceiveSort WITH (NOLOCK)  
		 WHERE ReceiptKey = @cReceiptKey  
		 AND   LOC = @cLane  
		 AND   [Status] = '1'        
		 AND   UCCNo = @cUCC
		 ORDER BY 1
		 
		 OPEN curDelUCC 
		 FETCH NEXT FROM curDelUCC INTO @nRowRef  
		 WHILE @@FETCH_STATUS = 0  
		 BEGIN    
		   DELETE FROM RDT.rdtPreReceiveSort WHERE Rowref = @nRowRef  
		   
		   FETCH NEXT FROM curDelUCC INTO @nRowRef   
		 END  
		   
		 CLOSE curDelUCC
		 DEALLOCATE curDelUCC 
		 --INC1213854 (END)
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 170710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPltCnt Err
            GOTO RollBackTran
         END
      END
      
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1841PrePltSort03
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN



GO