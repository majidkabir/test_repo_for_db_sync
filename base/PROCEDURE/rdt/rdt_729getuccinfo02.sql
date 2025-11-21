SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_729GetUCCInfo02                                 */
/*                                                                      */
/* Purpose: Display workorder id                                        */
/*                                                                      */
/* Called from: rdtfnc_UCCInquire                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2023-09-13  1.0  James      WMS-23534. Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_729GetUCCInfo02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cUCC             NVARCHAR( 20),
   @cExtInfo01       NVARCHAR( 20)  OUTPUT,
   @cExtInfo02       NVARCHAR( 20)  OUTPUT,
   @cExtInfo03       NVARCHAR( 20)  OUTPUT,
   @cExtInfo04       NVARCHAR( 20)  OUTPUT,
   @cExtInfo05       NVARCHAR( 20)  OUTPUT,
   @cExtInfo06       NVARCHAR( 20)  OUTPUT,
   @cExtInfo07       NVARCHAR( 20)  OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cToID    NVARCHAR( 18)

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         SELECT TOP 1 @cToID = WKORDUDEF3 
         FROM DBO.WorkOrder WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
         AND TYPE = 'TASK'
         AND WKORDUDEF2 = @cUCC
         ORDER BY EditDate DESC

         IF @cToID <> ''
         BEGIN
         	SET @cExtInfo01 = ''
         	SET @cExtInfo02 = ''
         	SET @cExtInfo03 = 'TO ID:'
         	SET @cExtInfo04 = @cToID
         END
      END
   END

   Quit:



GO