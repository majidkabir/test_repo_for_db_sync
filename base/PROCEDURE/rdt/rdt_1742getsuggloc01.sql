SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1742GetSuggLOC01                                */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Suggest a LOC for the Drop ID                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2023-10-17  1.0  Ung      WMS-23390 Created                          */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1742GetSuggLOC01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cDropID          NVARCHAR( 20),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT, 
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cUserDefine10  NVARCHAR( 10)
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''

   SELECT TOP 1 
      @cOrderKey = OrderKey
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND DropID = @cDropID
      AND Status = '5'
   ORDER BY EditDate DESC
   
   -- Get wave info
   SELECT @cWaveKey = ISNULL( UserDefine09, '') FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   SELECT @cUserDefine10 = ISNULL( UserDefine10, '') FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey
   
   -- Output wave staging LOC
   IF @cUserDefine10 <> ''
      SET @cSuggLOC = @cUserDefine10
END

GO