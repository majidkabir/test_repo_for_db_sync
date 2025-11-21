SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Store procedure: rdt_PreRcvSort03                                                   */
/*                                                                                     */
/* Purpose: Show carton position                                                       */
/*                                                                                     */
/* Called from: rdtfnc_PreReceiveSort2                                                 */
/*                                                                                     */
/* Modifications log:                                                                  */
/*                                                                                     */
/* Date        Rev  Author     Purposes                                                */
/* 2018-Feb-05 1.0  James      WMS3858 Created                                         */
/***************************************************************************************/

CREATE PROC [RDT].[rdt_PreRcvSort03] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cUCCNo           NVARCHAR( 20),  
   @cPosition01      NVARCHAR( 20)  OUTPUT,   
   @cPosition02      NVARCHAR( 20)  OUTPUT,   
   @cPosition03      NVARCHAR( 20)  OUTPUT,   
   @cPosition04      NVARCHAR( 20)  OUTPUT,   
   @cPosition05      NVARCHAR( 20)  OUTPUT,   
   @cPosition06      NVARCHAR( 20)  OUTPUT,   
   @cPosition07      NVARCHAR( 20)  OUTPUT,   
   @cPosition08      NVARCHAR( 20)  OUTPUT,   
   @cPosition09      NVARCHAR( 20)  OUTPUT,   
   @cPosition10      NVARCHAR( 20)  OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @cUCC_SKU         NVARCHAR( 20),
      @cReceiptKey      NVARCHAR( 10), 
      @cPosition        NVARCHAR( 20),
      @cUserName        NVARCHAR( 18),
      @cContainerKey    NVARCHAR( 18),
      @cLoc             NVARCHAR( 10),
      @cSortIntoDPPLoc  NVARCHAR( 1),
      @cSortFollowCaseCount   NVARCHAR( 1),
      @nTranCount       INT,
      @nUCCMultiSKU     INT,
      @nUCC_Qty         INT,
      @nCaseCnt         INT,
      @nUCC_Total       INT,
      @nUCC_Counted     INT

   DECLARE  @cErrMsg1    NVARCHAR( 20), 
            @cErrMsg2    NVARCHAR( 20),
            @cErrMsg3    NVARCHAR( 20), 
            @cErrMsg4    NVARCHAR( 20),
            @cErrMsg5    NVARCHAR( 20)


   SET @cReceiptKey = @cParam1
   SET @cContainerKey = @cParam2

   SET @nUCCMultiSKU = 0
   SET @cPosition = ''

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PreRcvSort03

   SELECT @cUserName = UserName FROM RDT.RDTMobRec WITH (NOLOCK) WHERE MOBILE = @nMobile

   SET @cSortIntoDPPLoc = rdt.RDTGetConfig( @nFunc, 'SortIntoDPPLoc', @cStorerKey)
   SET @cSortFollowCaseCount = rdt.RDTGetConfig( @nFunc, 'SortFollowCaseCount', @cStorerKey)

   -- If user key in containerkey then need retrieve receiptkey here
   IF ISNULL( @cReceiptKey, '') = ''
   BEGIN
      SELECT @cReceiptKey = SUBSTRING( UCC.SourceKey, 1, 10) 
      FROM dbo.UCC UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCCNo
      AND   [Status] = '0'
      AND   EXISTS ( SELECT 1 FROM dbo.Receipt R WITH (NOLOCK)
                     WHERE UCC.StorerKey = R.StorerKey
                     AND   UCC.ExternKey = R.ExternReceiptKey
                     AND   SUBSTRING( UCC.SourceKey, 1, 10) = R.ReceiptKey
                     AND   R.ContainerKey = @cContainerKey
                     AND   R.Status < '9'
                     AND   R.ASNStatus <> 'CANC')

      IF ISNULL( @cReceiptKey, '') = ''
      BEGIN
         SET @nErrNo = 119601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No ASN#
         SET @cPosition01 = ''
         GOTO RollBackTran
      END
   END

   -- Check if UCC mix sku
   IF EXISTS ( SELECT 1 
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cUCCNo
               AND   [Status] = '0'
               GROUP BY UCCNo 
               HAVING COUNT( DISTINCT SKU) > 1)
      SET @nUCCMultiSKU = 1

   -- Mix sku carton
   IF @nUCCMultiSKU = 1
   BEGIN
      SET @cUCC_SKU = ''
      SET @nUCC_Qty = 0

      SET @cPosition = '1'
      GOTO DISPLAY
   END
   ELSE  -- Single sku carton
   BEGIN
      SELECT @cUCC_SKU = SKU, 
             @nUCC_Qty = ISNULL( SUM( Qty), 0)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCCNo
      AND   [Status] = '0'
      GROUP BY SKU

      SELECT @nCaseCnt = Pack.CaseCnt
      FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.Pack Pack WITH (NOLOCK) ON ( SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cUCC_SKU

      -- Not a standard case count carton
      IF @nCaseCnt <> @nUCC_Qty
      BEGIN
         -- If config not turn on then show position 2
         -- If config turn off then show position 4 (or onwards)
         IF @cSortFollowCaseCount = '1'
         BEGIN
            SET @cPosition = '2'
            GOTO DISPLAY
         END
      END
      ELSE
      BEGIN
         -- If config turned on then allow sort into DPP location
         IF @cSortIntoDPPLoc = '1'
         BEGIN
            -- For standard packkey carton, check whether sku already exists in sorting table
            -- If not exists then can proceed further checking for position 3
            IF NOT EXISTS ( SELECT 1 FROM [RDT].[rdtPreReceiveSort2Log] R WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND   ReceiptKey = @cReceiptKey
                           AND   SKU = @cUCC_SKU
                           AND   LOC = '3'
                           AND   [Status] < '9')
            BEGIN
               -- Check sku no inventory in dpp location.
               IF NOT EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                           WHERE LLI.StorerKey = @cStorerKey
                           AND   LLI.SKU = @cUCC_SKU
                           AND   LOC.LocationType = 'DYNPPICK'
                           GROUP BY LLI.LOT
                           HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0)
               BEGIN
                  SET @cPosition = '3'
                  GOTO DISPLAY
               END
            END
         END
      END
   END

      -- All other exception
      -- Check if SKU already assigned a loc
      SELECT TOP 1 @cLoc = Loc
      FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   [Status] < '9'
      AND   LOC NOT IN ('1', '2', '3')
      AND   SKU = @cUCC_SKU

      IF ISNULL( @cLoc, '') <> ''
      BEGIN
         SET @cPosition = @cLoc
         GOTO DISPLAY
      END

         -- All other exception. Assign a new no for each new sku
      SELECT TOP 1 @cLoc = Loc
      FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   [Status] < '9'
      AND   LOC NOT IN ('1', '2', '3')
      ORDER BY 1 DESC

      IF ISNULL( @cLoc, '') = '' OR rdt.rdtIsValidQTY( @cLoc, 1) = 0
         SET @cPosition = '4'
      ELSE
         SET @cPosition = CAST( @cLoc AS INT) + 1

   Display:
   -- Check if UCC scanned before. If yes then skip insert
   SET @cLoc = ''
   SELECT @cLoc = LOC
   FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   ReceiptKey = @cReceiptKey
   AND   UCCNo = @cUCCNo
   AND   [Status] < '9'

   IF ISNULL( @cLoc, '') = ''
   BEGIN
      -- Insert sorting record here
      INSERT INTO [RDT].[rdtPreReceiveSort2Log]
      (Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, UDF01, Status, AddWho, AddDate, EditWho, EditDate) 
      VALUES
      (@cFacility, @cStorerKey, @cReceiptKey, @cUCCNo, @cUCC_SKU, @nUCC_Qty, @cPosition, @cContainerKey, '1', @cUserName, GETDATE(), @cUserName, GETDATE())

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 119602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PreRcv Err
         SET @cPosition01 = ''
         GOTO RollBackTran
      END
   END
   ELSE
      SET @cPosition = @cLoc

   -- Get total ucc counted (ASN level)
   SELECT @nUCC_Counted = COUNT( DISTINCT UCCNo)
   FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   ReceiptKey = @cReceiptKey
   AND   [Status] < '9'

   -- Get total ucc not counted (ASN level)
   SELECT @nUCC_Total = COUNT( DISTINCT UCCNo)
   FROM dbo.UCC UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SUBSTRING( UCC.SourceKey, 1, 10) = @cReceiptKey
   AND   [Status] < '9'

   SET @cPosition01 = 'ASN:'
   SET @cPosition02 = @cReceiptKey
   SET @cPosition03 = 'POSITION: '
   SET @cPosition04 = @cPosition
   SET @cPosition05 = 'UCC SCANNED:'
   SET @cPosition06 = CAST( @nUCC_Counted AS NVARCHAR( 5))+ '/' + CAST( @nUCC_Total AS NVARCHAR( 5))
      
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PreRcvSort03
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

SET QUOTED_IDENTIFIER OFF

GO