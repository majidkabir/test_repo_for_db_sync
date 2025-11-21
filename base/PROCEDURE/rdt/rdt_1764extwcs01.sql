SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtWCS01                                    */
/* Purpose: TM Replen From, Extended Update for HK Lulu                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-02-10   James     1.0   WMS-15656 Created                       */
/* 2022-01-21   yeekung   1.1   WMS-18718 add wavekey underfine01       */
/*                              (yeekung01)                             */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtWCS01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cListKey       NVARCHAR( 10)
   DECLARE @cTaskKey       NVARCHAR( 10)
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cYogaMatCaseID NVARCHAR( 20)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cUserKey       NVARCHAR( 18)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @bSuccess       INT
   DECLARE @cWaveKey       NVARCHAR( 20)
   
   SELECT @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cListKey = ListKey, 
          @cUserKey = UserKey, 
          @cStorerKey  = Storerkey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey
   
   DECLARE @cCurRouting CURSOR
   SET @cCurRouting = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT TaskDetailKey, CaseID,wavekey  
   FROM dbo.TaskDetail WITH (NOLOCK) 
   WHERE ListKey = @cListKey
   AND   TaskType = 'RPF' 
   ORDER BY 1
   OPEN @cCurRouting
   FETCH NEXT FROM @cCurRouting INTO @cTaskKey, @cCaseID,@cWaveKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cYogaMatCaseID = ''
      SELECT @cYogaMatCaseID = ToID
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
      WHERE TD.TaskDetailKey = @cTaskKey
      AND   TD.TaskType = 'RPF'
      AND   TD.[Status] = '9'
      AND   LOC.PutawayZone = 'LULUCP'
      AND   LOC.Facility = @cFacility
            
      IF @cYogaMatCaseID <> ''
         SET @cCaseID = @cYogaMatCaseID
                     
      IF EXISTS (SELECT 1 FROM WAVE (NOLOCK)
                 WHERE wavekey=@cWaveKey
                 AND ISNULL(UserDefine01,'')='')
      BEGIN
                     
         SET @nErrNo = 0
         EXEC [dbo].[ispWCSRO03]    
              @c_StorerKey     =  @cStorerKey    
            , @c_Facility      =  @cFacility    
            , @c_ToteNo        =  @cCaseID    
            , @c_TaskType      =  'RPF'    
            , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
            , @c_TaskDetailKey =  @cTaskKey     
            , @c_Username      =  @cUserKey    
            , @c_RefNo01       =  ''    
            , @c_RefNo02       =  ''    
            , @c_RefNo03       =  ''    
            , @c_RefNo04       =  ''    
            , @c_RefNo05       =  ''    
            , @b_debug         =  '0'    
            , @c_LangCode      =  'ENG'    
            , @n_Func          =  0    
            , @b_Success       = @bSuccess  OUTPUT    
            , @n_ErrNo         = @nErrNo    OUTPUT    
            , @c_ErrMsg        = @cErrMSG   OUTPUT    
            
         IF @nErrNo <> 0
            BREAK
      END

      FETCH NEXT FROM @cCurRouting INTO @cTaskKey, @cCaseID,@cWaveKey
   END
END

GO