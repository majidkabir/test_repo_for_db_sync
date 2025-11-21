SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1816ExtUpd03                                    */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/* Purpose: For Grape Galina                                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.   Purposes                               */  
/* 2025-02-14   JCH507    1.0.0  FCR-2597 Created                       */  
/************************************************************************/  
  
CREATE   PROCEDURE rdt.rdt_1816ExtUpd03  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@nInputKey       INT  
   ,@cTaskdetailKey  NVARCHAR( 10)  
   ,@cFinalLOC       NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cToLOC      NVARCHAR( 10)  
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cSourceKey  NVARCHAR( 30)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cStorerkey  NVARCHAR( 15) 
  
   DECLARE @bDebugFlag  BINARY = 0  

   --Get facility
   SELECT
      @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get task info  
   SELECT
      @cStorerkey = StorerKey,   
      @cToLOC = ToLOC,   
      @cFromID = FromID,
      @cSourceKey = SourceKey  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
  
   -- TM assist NMV  
   IF @nFunc = 1816  
   BEGIN  
      IF @nStep = 1 -- FinalLOC  
      BEGIN
         IF @nInputKey = 1 -- ENTER  
         BEGIN
            IF @bDebugFlag = 1
               SELECT @cSourceKey AS SourceKey
            UPDATE KD SET
               KD.Loc = @cToLOC
            FROM KIT WITH (NOLOCK)
            JOIN KITDETAIL KD WITH (NOLOCK) 
               ON KIT.KITKey = KD.KITKey
            WHERE KIT.Facility = @cFacility
               AND   KIT.StorerKey = @cStorerKey
               AND   KIT.[Status] <> '9'
               AND   KD.Id = @cFromID
               AND   KD.[Type] = 'F'
            
            GOTO Quit  
         END --INPUTKEY = 1 
      END --STEP = 1
   END  
   GOTO Quit  
  
Quit:  

END  

GO