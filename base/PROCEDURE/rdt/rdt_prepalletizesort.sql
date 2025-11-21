SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PrePalletizeSort                                */
/*                                                                      */
/* Purpose: Get UCC stat                                                */
/*                                                                      */
/* Called from: rdtfnc_PrePalletizeSort                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-01-29  1.0  James      WMS11430. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PrePalletizeSort] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 20), 
   @cLane            NVARCHAR( 10), 
   @cUCC             NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20), 
   @cType            NVARCHAR( 10), 
   @cCreateUCC       NVARCHAR( 1),       
   @cLottable01      NVARCHAR( 18),      
   @cLottable02      NVARCHAR( 18),      
   @cLottable03      NVARCHAR( 18),      
   @dLottable04      DATETIME,           
   @dLottable05      DATETIME,           
   @cLottable06      NVARCHAR( 30),      
   @cLottable07      NVARCHAR( 30),      
   @cLottable08      NVARCHAR( 30),      
   @cLottable09      NVARCHAR( 30),      
   @cLottable10      NVARCHAR( 30),      
   @cLottable11      NVARCHAR( 30),      
   @cLottable12      NVARCHAR( 30),      
   @dLottable13      DATETIME,           
   @dLottable14      DATETIME,           
   @dLottable15      DATETIME,
   @cPosition        NVARCHAR( 20)  OUTPUT,   
   @cToID            NVARCHAR( 18)  OUTPUT,  
   @cClosePallet     NVARCHAR( 1)   OUTPUT,  
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 125) OUTPUT 
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
      @cUCCCounted  NVARCHAR( 5),
      @cPOKey       NVARCHAR( 10), 
      @nPosInUsed       INT,
      @nMaxAllowedPos   INT,
      @nTranCount       INT,
      @nUCCQty          INT,
      @nNonImmediateNeedsPos  INT,
      @cBUSR7       NVARCHAR( 30),
      @cPrePltGetPosSP     NVARCHAR( 20),
      @cSQL                NVARCHAR( MAX), 
      @cSQLParam           NVARCHAR( MAX)      

   SET @nErrNo = 0

   SET @cPrePltGetPosSP = rdt.RDTGetConfig( @nFunc, 'PrePltGetPosSP', @cStorerkey)
   IF @cPrePltGetPosSP IN ('0', '')
      SET @cPrePltGetPosSP = ''

   IF @cPrePltGetPosSP <> '' AND 
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPrePltGetPosSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cPrePltGetPosSP) +     
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, @cType, ' + 
         ' @cCreateUCC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, ' +
         ' @cLottable08, @cLottable09, @cLottable10, @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
         ' @cPosition OUTPUT, @cToID OUTPUT, @cClosePallet OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

      SET @cSQLParam =    
         '@nMobile         INT,           ' +
         '@nFunc           INT,           ' +
         '@cLangCode       NVARCHAR( 3),  ' +
         '@nStep           INT,           ' +
         '@nInputKey       INT,           ' +
         '@cStorerkey      NVARCHAR( 15), ' +
         '@cFacility       NVARCHAR( 5),  ' +
         '@cReceiptKey     NVARCHAR( 20), ' +
         '@cLane           NVARCHAR( 10), ' +
         '@cUCC            NVARCHAR( 20), ' + 
         '@cSKU            NVARCHAR( 20), ' + 
         '@cType           NVARCHAR( 10), ' +
         '@cCreateUCC      NVARCHAR( 1),  ' +
         '@cLottable01     NVARCHAR( 18), ' +      
         '@cLottable02     NVARCHAR( 18), ' +      
         '@cLottable03     NVARCHAR( 18), ' +     
         '@dLottable04     DATETIME,      ' +     
         '@dLottable05     DATETIME,      ' +      
         '@cLottable06     NVARCHAR( 30), ' +      
         '@cLottable07     NVARCHAR( 30), ' +      
         '@cLottable08     NVARCHAR( 30), ' +      
         '@cLottable09     NVARCHAR( 30), ' +      
         '@cLottable10     NVARCHAR( 30), ' +      
         '@cLottable11     NVARCHAR( 30), ' +      
         '@cLottable12     NVARCHAR( 30), ' +      
         '@dLottable13     DATETIME,      ' +       
         '@dLottable14     DATETIME,      ' +       
         '@dLottable15     DATETIME,      ' +     
         '@cPosition       NVARCHAR( 20)  OUTPUT, ' +  
         '@cToID           NVARCHAR( 18)  OUTPUT, ' +  
         '@cClosePallet    NVARCHAR( 1)   OUTPUT, ' +  
         '@nErrNo          INT            OUTPUT, ' +
         '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, @cType, 
            @cCreateUCC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, 
            @cLottable08, @cLottable09, @cLottable10, @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @cPosition OUTPUT, @cToID OUTPUT, @cClosePallet OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      RETURN
   END
   
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PrePalletizeSort

   SET @cPosition = ''
   SET @cCode = ''
   SET @cUdf10 = ''

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
      SET @cCode = ''

   SELECT @cPosition = ISNULL( Description, '')
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'PreRcvLane'
   AND   StorerKey = @cStorerKey
   AND   Code = @cCode

   IF ISNULL( @cPosition, '') <> ''
      GOTO GETCOUNT

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

   INSERT INTO #PositionInUsed (Position)
   SELECT DISTINCT Position
   FROM rdt.rdtPreReceiveSort P WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   LOC = @cLane
   AND   Func = @nFunc
   AND   ISNULL( Position, '') <> ''   -- Position that has some pallet assigned
   AND   NOT EXISTS ( SELECT 1 FROM dbo.CodeLkUp C WITH (NOLOCK) 
                        WHERE C.ListName = 'PreRcvLane'
                        AND   C.Code = P.Position 
                        AND   C.Short = 'R'
                        AND   C.StorerKey = @cStorerKey)

   -- First 5 position reserved as at above
   SET @nMaxAllowedPos = 0
   SELECT @nMaxAllowedPos = MaxPallet - 5
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @cLane
   AND   Facility = @cFacility

   SET @nNonImmediateNeedsPos = 6

   WHILE @nMaxAllowedPos > 0
   BEGIN
      INSERT INTO #AllowedPosition (Position) VALUES 
      (RIGHT( '000' + CAST( @nNonImmediateNeedsPos AS NVARCHAR( 3)), 3))

      SET @nMaxAllowedPos = @nMaxAllowedPos - 1
      SET @nNonImmediateNeedsPos = @nNonImmediateNeedsPos + 1
   END

   -- If ucc udf06-10 does not contain value 1 THEN is single sku pallet
   -- look position in rdttempucc table for the pallet with the same sku
   SELECT @cCode = Position
   FROM rdt.rdtPreReceiveSort P WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU
   AND   LOC = @cLane
   AND   Func = @nFunc
   AND   ISNULL( Position, '') <> ''   -- Position that has some pallet assigned
   AND   NOT EXISTS ( SELECT 1 FROM dbo.CodeLkUp C WITH (NOLOCK) 
                      WHERE C.ListName = 'PreRcvLane'
                      AND   C.Code = P.Position 
                      AND   C.Short = 'R'
                      AND   C.StorerKey = @cStorerKey)

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

   GETCOUNT:
   BEGIN
      -- (james01)
      --	Sub-position:  
      -- Retrieve sku.busr7 as sub-position, one UCC always have same Busr7 (PE: 10/20/30)
      SET @cBUSR7 = ''
      SELECT TOP 1 
         @cBUSR7 = ISNULL( BUSR7, ''),
         @nUCCQty = UCC.qty
      FROM dbo.UCC UCC WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON 
         (UCC.SKU = SKU.SKU AND UCC.StorerKey = SKU.StorerKey)
      WHERE UCC.StorerKey = @cStorerKey
      AND   UCC.UCCNo = @cUCC

      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
                      WHERE UCCNo = @cUCC
                      AND   StorerKey = @cStorerKey
                      AND   Func = @nFunc)
      BEGIN
         INSERT INTO rdt.rdtPreReceiveSort
         (Mobile, Func, Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, Position, SourceType, UDF01, [Status]) VALUES 
         (@nMobile, @nFunc, @cFacility, @cStorerKey, @cReceiptKey, @cUCC, @cSKU, @nUCCQty, @cLane, @cCode, 'rdt_PrePalletizeSort', @cBUSR7, '1')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 106051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE rdt.rdtPreReceiveSort WITH (ROWLOCK) SET 
            Position = @cCode
         WHERE UCCNo = @cUCC
         AND   StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Loc = @cLane
         AND   [Status] = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 106052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
            GOTO RollBackTran
         END
      END

      SET @cPOKey = ''
      SELECT @cPOKey = ISNULL( POKey, '')
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cUCC

      -- Get count information
      SELECT @cUCCCounted = COUNT( DISTINCT UCCNo)
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Func = @nFunc
      AND   Position = @cCode  -- Position
      AND   Loc = @cLane -- Loc
      AND   ReceiptKey = @cReceiptKey
      AND   ( ( @cCode <> '003') OR
              ( @cCode = '003' AND @cBUSR7 <> '' AND UDF01 = @cBUSR7))

      -- If ucc contain pre set userdefined value (need immediate action)
      IF '1' IN ( @cUdf06, @cUdf07, @cUdf08, @cUdf09, @cUdf10)
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
            IF @cBUSR7 <> ''
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
                              AND   SKU.BUSR7 = @cBUSR7)
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

            IF @cBUSR7 <> ''
            BEGIN
               SET @cPosition = RTRIM( @cPosition) + '-' + @cBUSR7
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
                        AND   RD.ReceiptKey = @cReceiptKey
                        AND   RD.FinalizeFlag <> 'Y') 
            GROUP BY UCCNo
            HAVING 1 = CASE WHEN MAX(UCC.Userdefined06) IN ('', '0') THEN 1 ELSE '0' END AND
                   1 = CASE WHEN MAX(UCC.Userdefined07) IN ('', '0') THEN 1 ELSE '0' END AND
                   1 = CASE WHEN MAX(UCC.Userdefined08) IN ('', '0') THEN 1 ELSE '0' END AND
                   1 = CASE WHEN MAX(UCC.Userdefined09) IN ('', '0') THEN 1 ELSE '0' END AND
                   1 = CASE WHEN MAX(UCC.Userdefined10) IN ('', '0') THEN 1 ELSE '0' END
            ) AS T

      --SELECT @cRecordCount = @cUCCCounted + '/' + @cUCCCount
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PrePalletizeSort
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO