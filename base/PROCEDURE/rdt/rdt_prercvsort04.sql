SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Store procedure: rdt_PreRcvSort04                                                   */
/*                                                                                     */
/* Purpose: Show carton position                                                       */
/*                                                                                     */
/* Called from: rdtfnc_PreReceiveSort2                                                 */
/*                                                                                     */
/* Modifications log:                                                                  */
/*                                                                                     */
/* Date        Rev  Author     Purposes                                                */
/* 26-Feb-2019 1.2  James      WMS-8010. Created                                       */
/***************************************************************************************/

CREATE PROC [RDT].[rdt_PreRcvSort04] (
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



   DECLARE @cPositionPreFix      NVARCHAR( 10)
   DECLARE @cSKU                 NVARCHAR( 20)
   DECLARE @cPrePosition         NVARCHAR( 10)

   SET @cReceiptKey = @cParam1

   SET @cSKU = @cUCCNo
   SET @cPosition = ''
   SET @cUserName = sUSER_sNAME()

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PreRcvSort04

   SELECT @cPositionPreFix = Short
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'PreRcvSort'
   AND   Code = 'PosPreFix'
   AND   StorerKey = @cStorerKey
   AND   code2 = @nFunc

   IF ISNULL( @cPositionPreFix, '') = ''
   BEGIN
      SET @nErrNo = 134801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Prefix
      SET @cPosition01 = ''
      GOTO RollBackTran
   END

   SELECT TOP 1 @cLoc = Loc
   FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   ReceiptKey = @cReceiptKey
   AND   [Status] < '9'
   AND   SKU = @cSKU

   IF @@ROWCOUNT = 0
   BEGIN
      SELECT TOP 1 @cLoc = Loc
      FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   [Status] < '9'
      ORDER BY 1 DESC
         
      IF @@ROWCOUNT = 0
         SET @cPosition = @cPositionPreFix + '0001'
      ELSE
      BEGIN
         SET @cPrePosition = SUBSTRING( @cLoc, LEN( @cPositionPreFix) + 1, LEN( @cLoc) - LEN( @cPositionPreFix))
         SET @cPosition = @cPositionPreFix + RIGHT( '0000' + CAST( CAST( IsNULL( MAX( @cPrePosition), 0) AS INT) + 1 AS NVARCHAR( 4)), 4)
      END

      -- Insert sorting record here
      INSERT INTO [RDT].[rdtPreReceiveSort2Log]
      (Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, Status, AddWho, AddDate, EditWho, EditDate) 
      VALUES
      (@cFacility, @cStorerKey, @cReceiptKey, '', @cSKU, 0, @cPosition, '1', @cUserName, GETDATE(), @cUserName, GETDATE())

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 134802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PreRcv Err
         SET @cPosition01 = ''
         GOTO RollBackTran
      END
   END
   ELSE
      SET @cPosition = @cLoc

   SET @cPosition01 = 'ASN:'
   SET @cPosition02 = @cReceiptKey
   SET @cPosition03 = 'POSITION: '
   SET @cPosition04 = @cPosition
      
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PreRcvSort04
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

SET QUOTED_IDENTIFIER OFF

GO