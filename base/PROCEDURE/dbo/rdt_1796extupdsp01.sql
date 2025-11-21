SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1796ExtUpdSP01                                        */
/* Purpose:                                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2017-05-11   ChewKP    1.0   WMS-1225 Created                              */
/******************************************************************************/

CREATE PROCEDURE [dbo].[rdt_1796ExtUpdSP01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT       OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@cParam01        NVARCHAR( 30) = ''
   ,@cParam02        NVARCHAR( 30) = ''
   ,@cParam03        NVARCHAR( 30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)

   DECLARE @cStorerKey   NVARCHAR( 15)
          ,@cTDTaskDetailKey NVARCHAR(10) 
          ,@cUserName    NVARCHAR(18) 
          ,@cFromID      NVARCHAR(18)
          ,@cFromLoc     NVARCHAR(10) 


   
   -- TM Putaway To
   IF @nFunc = 1796
   BEGIN
      IF @nStep = 0 -- Init
      BEGIN
         SET @cFromLoc = ''
         SET @cFromID  = ''

         SELECT @cUserName = UserName 
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile 
         
         SELECT @cFromLoc = FromLoc 
               ,@cFromID  = FromID
               ,@cStorerKey = StorerKey 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey 
         
         
         DECLARE C_1796TaskDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TaskDetailKey 
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND FromLoc = @cFromLoc
         AND FromID  = @cFromID 
         AND Status = '0' 
         ORDER BY TaskDetailKey 
         
         OPEN C_1796TaskDetail  
         FETCH NEXT FROM C_1796TaskDetail INTO  @cTDTaskDetailKey
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN  
            
            UPDATE dbo.TaskDetail WITH (ROWLOCK) 
            SET Status = '3'
               ,UserKey = @cUserName 
            WHERE TaskDetailKey = @cTaskDetailKey 
            
            IF @@ERROR <> 0 
            BEGIN
                SET @nErrNo = 109151
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFail'  
                GOTO Fail     
            END
            
            FETCH NEXT FROM C_1796TaskDetail INTO  @cTDTaskDetailKey
         END
         CLOSE C_1796TaskDetail  
         DEALLOCATE C_1796TaskDetail 
         
      END

      
   END

  

Fail:

END

GO