SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_522ExtPA01                                      */
/* Purpose: Pallet putaway extended putaway sp                          */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-08-14 1.0  James      Created SOS#348695                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_522ExtPA01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nInputKey       INT,
   @nStep           INT, 
   @nScn            INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT,  
   @cCaseID         NVARCHAR( 20),
   @nAfterStep      INT           OUTPUT, 
   @nAfterScn       INT           OUTPUT, 
   @cFinalLoc       NVARCHAR( 10) OUTPUT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

/*
For each sku, get Primary Piece Pick Location (PPPL)
If Found:
	If available quantity = 0 THEN
	   If total # cases on pallet for sku >= N
	      Create PA task(s) for N cases to go to PPPL
	      Create WCS Routing for Case(s)
	   ELSE
ELSE
   Continue with Putaway 
*/

   DECLARE @cLOT           NVARCHAR( 10), 
           @cPANoOfCase    NVARCHAR( 5), 
           @cPickLoc       NVARCHAR( 10), 
           @cCaseCnt       NVARCHAR( 5), 
           @cPieceLoc      NVARCHAR( 10), 
           @cPackKey       NVARCHAR( 10), 
           @cTargetDBName  NVARCHAR( 20),
           @nSKUxLocQTY    INT, 
           @nCaseCnt       INT, 
           @nPANoOfCase    INT, 
           @nTranCount     INT, 
           @nCaseInTransit INT, 
           @nTtl_Qty       INT, 
           @nLocationLimit INT, 
           @nRecordCnt     INT 

   DECLARE @cExecStatements    NVARCHAR(4000),  
           @cExecArguments     NVARCHAR(4000)
            
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         SELECT @cStorerkey = Storerkey,
                @cSKU = SKU,
                @cLot = LOT, 
                @nTtl_Qty = SUM( QTY - QTYALLOCATED - QTYPICKED)
         From dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE ID = @cFromID
         AND   LOC = @cFromLOC
         GROUP BY Storerkey, SKU, LOT

         IF @nTtl_Qty = 0
         BEGIN
            SET @nErrNo = 56301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet is empty
            GOTO Fail
         END

         SET @cPANoOfCase = rdt.RDTGetConfig( @nFunc, 'PANoOfCase', @cStorerKey)

         IF CAST( @cPANoOfCase AS INT) = 0
         BEGIN
            SET @nErrNo = 56302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Config not set
            GOTO Fail
         END

         SELECT @cCaseCnt = Lottable06
         FROM dbo.LotAttribute WITH (NOLOCK) 
         WHERE LOT = @cLOT

         -- If total no of cases on pallet < no of cases setup to putaway then ignore
         IF ( @nTtl_Qty/ CAST( @cCaseCnt AS INT)) < CAST( @cPANoOfCase AS INT)
            GOTO Fail

         -- Get piece pick loc
         SELECT @cPickLoc = Loc, @nLocationLimit = ISNULL( QtyLocationLimit, 0)
         FROM dbo.SKUxLOC WITH (NOLOCK) 
         WHERE SKU = @cSKU 
         AND   Storerkey = @cStorerkey 
         AND   Locationtype = 'PICK'

         -- No piece pick loc then no need putaway
         IF ISNULL( @cPickLoc, '') = ''
            GOTO Fail

         -- If already a pending PA task for the sku then no need putaway
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail (NOLOCK)
                     WHERE SKU = @cSKU
                     AND   [STATUS] <> '9'
                     AND   TaskType = 'PA'
                     AND   Storerkey = @cStorerkey)
            GOTO Fail

         SELECT @nSKUxLocQTY = ISNULL( SUM(QTY), 0)
         FROM dbo.SKUxLoc WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND Storerkey = @cStorerkey
         AND LOC = @cPickLoc
         AND LocationType = 'PICK'

         -- If qty in PPA < loc max
         IF @nSKUxLocQTY < @nLocationLimit
         BEGIN
            -- Go to next screen
            SET @nAfterScn = @nScn + 3
            SET @nAfterStep = @nStep + 3
               
            GOTO Quit
         END
         ELSE
            GOTO Fail
      END

      IF @nStep = 6
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail (NOLOCK)
                     WHERE SKU = @cSKU
                     AND   [STATUS] <> '9'
                     AND   TaskType = 'PA'
                     AND   Storerkey = @cStorerkey)
         BEGIN
            SET @nErrNo = 56303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Task Exists
            GOTO Fail
         END
                  
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail (NOLOCK) WHERE CASEID = @cCaseID AND Status <> '9')
         BEGIN
            SET @nErrNo = 56304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID In Used
            GOTO Fail
         END

         IF EXISTS ( SELECT 1 FROM rdt.rdtPutawayLog (NOLOCK) WHERE CASEID = @cCaseID AND Status = '0')
         BEGIN
            SET @nErrNo = 56305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID In Used
            GOTO Fail
         END

         SELECT @cPieceLoc = Loc
         FROM dbo.SKUxLOC WITH (NOLOCK) 
         WHERE SKU = @cSKU 
         AND   Storerkey = @cStorerkey 
         AND   Locationtype = 'PICK'

         IF ISNULL(RTRIM(@cPieceLoc),'') = ''
         BEGIN
            SET @nErrNo = 56306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO PPA LOC'
            GOTO Fail
         END

         SELECT @cTargetDBName = UPPER(SValue)  
         FROM dbo.StorerConfig WITH (NOLOCK)  
         WHERE CONFIGKEY = 'REPWCSDB'   
         AND   Storerkey = @cStorerkey  

         SET @cExecStatements = N'SELECT @nRecordCnt = COUNT(*) '  
                                 + 'FROM ' + RTRIM(@cTargetDBName) + '.dbo.ORDER_HEADER WITH (NOLOCK) '  
                                 + 'WHERE STATE_HCOM = ''10'' '  
                                 + 'AND  ACTION  = ''INSERT'' '  
                                 + 'AND  BOXNUMBER = CAST( @cCaseID AS INT) '  
        
         SET @cExecArguments = N'@cTargetDBName NVARCHAR( 20), ' +  
                                '@cCaseID       NVARCHAR( 20), ' +   
                                '@nrecordCnt    INT OUTPUT '    
        
         EXEC sp_ExecuteSql @cExecStatements   
                          , @cExecArguments    
                          , @cTargetDBName  
                          , @cCaseID     
                          , @nRecordCnt OUTPUT  

         IF @nRecordCnt > 0   
         BEGIN  
            SET @nErrNo = 56311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Case in used'
            GOTO Fail
         END

         SELECT TOP 1 @cLOT = LLI.Lot
         FROM dbo.LotxLocxID LLI WITH ( NOLOCK)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
         WHERE LLI.ID = @cFromID
         AND   LLI.Storerkey = @cStorerkey
         AND   LLI.Loc = @cFromLOC
         AND   LLI.SKU = @cSKU
         and   1 = CASE WHEN LA.Lottable06 IN ('', '0') THEN 2 ELSE 1 END
         GROUP BY LLI.LOT, LA.Lottable06
         ORDER BY SUM( LLI.QTY)/CAST( LA.Lottable06 AS INT) DESC   -- Get the case qty with the largest no of case

         IF ISNULL(RTRIM(@cLOT),'') = ''
         BEGIN
            SET @nErrNo = 56307
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LotNotFound'
            GOTO Fail
         END
         
         SELECT @nCaseCnt = CAST( Lottable06 AS INT)
         FROM dbo.LotAttribute WITH (NOLOCK) 
         WHERE Lot = @cLOT

         SELECT @cPackKey = PackKey FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cPANoOfCase = rdt.RDTGetConfig( @nFunc, 'PANoOfCase', @cStorerKey)
         
         IF RDT.rdtIsValidQTY( @cPANoOfCase, 1) = 0
         BEGIN
            SET @nErrNo = 56308
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid case qty'
            GOTO Fail
         END         
         
         SET @nPANoOfCase = CAST( @cPANoOfCase AS INT)

         SELECT @nCaseInTransit = COUNT( 1)
         FROM rdt.rdtPutawayLog WITH (NOLOCK)
         WHERE ID = @cFromID
         AND   [Status] = '0'
         AND   SKU = @cSKU
         
         IF @nCaseInTransit + 1 <= @nPANoOfCase
         BEGIN
            -- Insert into Putaway Table for Retrieval in ToLOC Screen --
            INSERT INTO rdt.rdtPutawayLog (mobile ,status ,Storerkey ,SKU ,Lot ,UOM ,Sourcekey ,caseID ,Qty ,ID , FromLoc , Packkey)
            VALUES (@nMobile ,'0' , @cStorerkey , @cSKU , @cLOT, '6', '' , @cCaseID , @nCaseCnt ,@cFromID , @cPieceLoc , @cPackKey )

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 56309
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PA Task Fail'
               GOTO Fail
            END
            ELSE
            BEGIN
               DECLARE @nPA_Qty INT, @nLLI_Qty INT

               SELECT @nPA_Qty = ISNULL( SUM( Qty), 0)
               FROM rdt.rdtPutawayLog WITH (NOLOCK)
               WHERE ID = @cFromID
               AND   [Status] = '0'
               AND   SKU = @cSKU
               
               SELECT @nLLI_Qty = ISNULL( SUM( Qty), 0)
               FROM dbo.LotxLocxID WITH ( NOLOCK)
               WHERE ID = @cFromID
               AND   Storerkey = @cStorerkey
               AND   Loc = @cFromLOC
               AND   SKU = @cSKU
                        
               IF (@nCaseInTransit + 1 = @nPANoOfCase) OR ( @nPA_Qty >= @nLLI_Qty)
               BEGIN
                  SET @nAfterStep = @nStep - 3
                  SET @nAfterScn = @nScn - 3
               END
               ELSE
               BEGIN
                  -- Set back to same screen and proceed with another case
                  SET @nAfterStep = @nStep
                  SET @nAfterScn = @nScn
               END               
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 56310
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Exceed # case'
            GOTO Fail
         END       
      END

   END

   FAIL:
   BEGIN
      -- Set back to same screen and proceed with putaway to bulk
      SET @nAfterStep = @nStep
      SET @nAfterScn = @nScn
   END
      
   QUIT:

GO