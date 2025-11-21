SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_805ExtUpd02                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: If the ucc no more residual in the carton prompt EMPTY BOX msg    */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-04-21   1.0  James      WMS-15658. Created                            */
/******************************************************************************/
CREATE PROC [RDT].[rdt_805ExtUpd02](
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cFacility  NVARCHAR( 5),
   @cStorerKey NVARCHAR( 15),
   @cStation1  NVARCHAR( 10),
   @cStation2  NVARCHAR( 10),
   @cStation3  NVARCHAR( 10),
   @cStation4  NVARCHAR( 10),
   @cStation5  NVARCHAR( 10),
   @cMethod    NVARCHAR( 10),
   @cScanID    NVARCHAR( 20),
   @cSKU       NVARCHAR( 20),
   @nQTY       INT,
   @cCartonID    NVARCHAR( 20),
   @nActQTY    INT,
   @cNewCartonID NVARCHAR( 20),
   @cLight     NVARCHAR( 1), 
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nCurStep       INT
   DECLARE @nUCCQty        INT
   DECLARE @nPackQTY       INT
   DECLARE @nResidualQty   INT
   DECLARE @cUCC           NVARCHAR( 20)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   
   SELECT @nCurStep = Step, 
          @cUCC = V_String7
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nErrNo = 0
                  
   -- From step 4 going to step 3 (matrix screen press ENTER)
   IF @nStep = 3 AND @nCurStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cUCC <> ''
         BEGIN
            -- Only UCC need prompt msg
            IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                        WHERE Storerkey = @cStorerKey
                        AND   UCCNo = @cUCC)
               GOTO Quit

      
            IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                            WHERE Storerkey = @cStorerKey
                            AND   DropID = @cUCC)
            BEGIN
               -- the original ucc no more in pickdetail
               -- meaning no more residual, prompt empty box
               --SET @nUCCQty = 0
               --SELECT @nUCCQty = Qty
               --FROM dbo.UCC WITH (NOLOCK)
               --WHERE Storerkey = @cStorerKey
               --AND   UCCNo = @cUCC
      
               --SET @nPackQTY = 0
               --SELECT @nPackQTY = ISNULL( SUM( Qty), 0)
               --FROM dbo.PackDetail WITH (NOLOCK)
               --WHERE StorerKey = @cStorerKey
               --AND   DropID = @cUCC
      
               ---- Check if ucc has residual
               --SET @nResidualQty = @nUCCQty - @nPackQTY

               --IF @nResidualQty > 0
               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE TaskType = 'ASTRPT'
                           AND   Caseid = @cUCC
                           AND   Storerkey = @cStorerKey
                           AND   SourceType = 'isp_805PTL_Confirm11'
                           AND   [Status] = '0')
               BEGIN
                  SET @cErrMsg1 = rdt.rdtgetmessage( 166701, @cLangCode, 'DSP')  -- RESIDUAL PUTAWAY
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               END
               ELSE
               BEGIN
                  SET @cErrMsg1 = rdt.rdtgetmessage( 166702, @cLangCode, 'DSP')  -- EMPTY BOX
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               END
               
               SET @nErrNo = 0
            END
         END
      END
   END
Quit:

END

GO