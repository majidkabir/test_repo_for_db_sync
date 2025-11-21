SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PrePalletizeSort_Reversal                       */
/*                                                                      */
/* Purpose: Remove record from rdt.rdtPreReceiveSort                    */
/*                                                                      */
/* Called from: rdtfnc_PrePalletizeSort_Reversal                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2023-10-13   1.0  James    WMS-23812. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PrePalletizeSort_Reversal] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cReceiptKey      NVARCHAR( 20),
   @cToID            NVARCHAR( 18),
   @cLane            NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 125) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @curDelUCC      CURSOR
   DECLARE @nRowRef        INT

   SET @nErrNo = 0

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PrePalletizeSort_Reversal

	SET @curDelUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
	SELECT RowRef   
	FROM rdt.rdtPreReceiveSort WITH (NOLOCK)  
	WHERE StorerKey = @cStorerKey
	AND   Facility = @cFacility
	AND   ReceiptKey = @cReceiptKey
	AND   ID = @cToID  
	AND   LOC = @cLane  
	AND   UCCNo = @cUCC
	ORDER BY 1
	OPEN @curDelUCC 
	FETCH NEXT FROM @curDelUCC INTO @nRowRef  
	WHILE @@FETCH_STATUS = 0  
	BEGIN    
	   DELETE FROM RDT.rdtPreReceiveSort WHERE Rowref = @nRowRef  
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 106051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Reversal Fail
         GOTO RollBackTran
      END
                  
	   FETCH NEXT FROM @curDelUCC INTO @nRowRef   
	END  
		   


   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PrePalletizeSort_Reversal
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO