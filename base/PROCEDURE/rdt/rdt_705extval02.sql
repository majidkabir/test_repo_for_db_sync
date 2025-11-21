SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_705ExtVal02                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 13-Dec-2022 1.0  Ung         WMS-21400 Created                       */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_705ExtVal02] (  
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @tVar       VariableTable READONLY,
   @nErrNo     INT            OUTPUT,  
   @cErrMsg    NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF     

   IF @nFunc = 705 -- Job capture
   BEGIN
      IF @nStep = 1 -- User ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cUserID NVARCHAR( 30)
            DECLARE @cStatus NVARCHAR( 1) = ''
            
            -- Variable mapping
            SELECT @cUserID = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID'
            
            -- Get group job info
            SELECT TOP 1 
               @cStatus = WL.Status
            FROM rdt.rdtWATLog WL WITH (NOLOCK)
               JOIN rdt.RDTWatTeamLog WRL WITH (NOLOCK) ON (WL.RowRef = WRL.UDF01)
            WHERE WRL.MemberUser = @cUserID 
               AND WRL.TeamUser <> @cUserID
            ORDER BY WL.EditDate DESC

            -- Check group job not yet closed
            IF @cStatus NOT IN ('9', '') 
            BEGIN
               SET @nErrNo = 195101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --707JobNotDone
               GOTO Quit
            END
         END
      END
   END

Quit:

END  

GO