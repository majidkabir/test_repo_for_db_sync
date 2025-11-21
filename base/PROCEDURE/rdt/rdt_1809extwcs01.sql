SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1809ExtWCS01                                    */  
/* Purpose: Lululemon routing insertion                                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-03-08 1.0  James      WMS-15657. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1809ExtWCS01] (  
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR(3),   
   @nStep            INT,   
   @nInputKey        INT,
   @cType            NVARCHAR( 10),
   @cStorerKey       NVARCHAR(15),   
   @cReasonCode      NVARCHAR(10),   
   @cTaskDetailKey   NVARCHAR(10),
   @cDropID          NVARCHAR(20), -- (ChewKP01)
   @nErrNo           INT       OUTPUT,   
   @cErrMsg          CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
   DECLARE @cToteNo        NVARCHAR( 20)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cTTMTasktype   NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cAreaKey       NVARCHAR( 10)
   DECLARE @cCloseTote     NVARCHAR( 1) = '1'
   DECLARE @bsuccess       INT
   
   IF @nFunc = 1809  
   BEGIN  

      SELECT @cToteNo = V_String1, 
             @cFacility = Facility, 
             @cUserName = UserName, 
             @cOrderKey = V_String26, 
             @cAreaKey = V_String32
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
   
      SELECT @cStorerKey = Storerkey, 
             @cTTMTasktype = TaskType,
             @cWaveKey = WaveKey,
             @cLoadKey = LoadKey,
             @cPickMethod = PickMethod 
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
   
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            --IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)  
            --            WHERE ToteNo = @cToteNo  
            --            AND ActionFlag = 'I'  )   
            --BEGIN  
            --    IF EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)  
            --               WHERE ToteNo = @cToteNo  
            --               AND Status = '0')  
            --    BEGIN                       
            --      GOTO QUIT  
            --    END  
            --END    
         
            IF ISNULL( @cTaskDetailKey, '') = ''
            BEGIN
               SELECT TOP 1 @cTaskDetailKey = TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE UserKey = @cUserName
               AND   [Status] = '3'
               ORDER BY 1

               SELECT @cStorerKey = Storerkey, 
                      @cTTMTasktype = TaskType,
                      @cWaveKey = WaveKey,
                      @cLoadKey = LoadKey,
                      @cPickMethod = PickMethod 
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
            END

            EXEC [dbo].[ispWCSRO03]
                  @c_StorerKey     = @cStorerKey
               , @c_Facility      = @cFacility
               , @c_ToteNo        = @cToteNo
               , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
               , @c_ActionFlag    = 'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
               , @c_TaskDetailKey = ''
               , @c_Username      = @cUserName
               , @c_RefNo01       = @cLoadKey
               , @c_RefNo02       = @cPickMethod -- (ChewKP02)
               , @c_RefNo03       = @cOrderKey -- (ChewKP02)
               , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
               , @c_RefNo05       = ''
               , @b_debug         = '0'
               , @c_LangCode      = 'ENG'
               , @n_Func          = 0
               , @b_success       = @bsuccess OUTPUT
               , @n_ErrNo         = @nErrNo    OUTPUT
               , @c_ErrMsg        = @cErrMSG   OUTPUT

            IF @cPickMethod IN ('DOUBLES','MULTIS','PIECE','PP','STOTE')
            BEGIN
               SELECT @cOrderKey = OrderKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
               
               IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey
                           AND   [Status] > '3'
                           AND   [Status] < '9')
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                              WHERE OrderKey = @cOrderKey
                              AND   [Status] = '4')
                  BEGIN
                     EXEC [dbo].[ispWCSRO03]
                          @c_StorerKey     = @cStorerKey
                        , @c_Facility      = @cFacility
                        , @c_ToteNo        = @cToteNo
                        , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
                        , @c_ActionFlag    = 'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                        , @c_TaskDetailKey = '' -- @cTaskdetailkey
                        , @c_Username      = @cUserName
                        , @c_RefNo01       = @cLoadKey
                        , @c_RefNo02       = @cPickMethod -- (ChewKP02)
                        , @c_RefNo03       = @cOrderKey -- (ChewKP02)
                        , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
                        , @c_RefNo05       = @cCloseTote -- (ChewKP02)
                        , @b_debug         = '0'
                        , @c_LangCode      = 'ENG'
                        , @n_Func          = 0
                        , @b_success       = @bsuccess  OUTPUT
                        , @n_ErrNo         = @nErrNo    OUTPUT
                        , @c_ErrMsg        = @cErrMSG   OUTPUT       
            
                     EXEC [dbo].[ispWCSRO03]
                        @c_StorerKey     = @cStorerKey
                     , @c_Facility      = @cFacility
                     , @c_ToteNo        = @cToteNo
                     , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
                     , @c_ActionFlag    = 'S' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                     , @c_TaskDetailKey = '' -- @cTaskdetailkey
                     , @c_Username      = @cUserName
                     , @c_RefNo01       = @cLoadKey
                     , @c_RefNo02       = @cPickMethod -- (ChewKP02)
                     , @c_RefNo03       = @cOrderKey -- (ChewKP02)
                     , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
                     , @c_RefNo05       = @cCloseTote -- (ChewKP02)
                     , @b_debug         = '0'
                     , @c_LangCode      = 'ENG'
                     , @n_Func          = 0
                     , @b_success       = @bsuccess OUTPUT
                     , @n_ErrNo         = @nErrNo    OUTPUT
                     , @c_ErrMsg        = @cErrMSG   OUTPUT
                     
                     GOTO QUIT
                  END
               END
            END
            
            EXEC [dbo].[ispWCSRO03]
                 @c_StorerKey     = @cStorerKey
               , @c_Facility      = @cFacility
               , @c_ToteNo        = @cToteNo
               , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
               , @c_ActionFlag    = 'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
               , @c_TaskDetailKey = '' -- @cTaskdetailkey
               , @c_Username      = @cUserName
               , @c_RefNo01       = @cLoadKey
               , @c_RefNo02       = @cPickMethod -- (ChewKP02)
               , @c_RefNo03       = @cOrderKey -- (ChewKP02)
               , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
               , @c_RefNo05       = @cCloseTote -- (ChewKP02)
               , @b_debug         = '0'
               , @c_LangCode      = 'ENG'
               , @n_Func          = 0
               , @b_success       = @bsuccess  OUTPUT
               , @n_ErrNo         = @nErrNo    OUTPUT
               , @c_ErrMsg        = @cErrMSG   OUTPUT       
         END
      END

      IF @nStep = 4
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cType = 'C'
            BEGIN
               EXEC [dbo].[ispWCSRO03]
                    @c_StorerKey     = @cStorerKey
                  , @c_Facility      = @cFacility
                  , @c_ToteNo        = @cToteNo
                  , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
                  , @c_ActionFlag    = 'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                  , @c_TaskDetailKey = ''
                  , @c_Username      = @cUserName
                  , @c_RefNo01       = @cLoadKey
                  , @c_RefNo02       = @cPickMethod -- (ChewKP02)
                  , @c_RefNo03       = @cOrderKey -- (ChewKP02)
                  , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
                  , @c_RefNo05       = ''
                  , @b_debug         = '0'
                  , @c_LangCode      = 'ENG'
                  , @n_Func          = 0
                  , @b_success       = @bsuccess OUTPUT
                  , @n_ErrNo         = @nErrNo    OUTPUT
                  , @c_ErrMsg        = @cErrMSG   OUTPUT


            
               --IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
               --            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
               --            WHERE O.LoadKey = @cLoadKey
               --            AND PD.Status <> '5'
               --            AND PD.StorerKey = @cStorerKey
               --            AND PD.DropID = @cToteNo )
               --BEGIN
               --      EXEC [dbo].[ispWCSRO03]
               --        @c_StorerKey     = @cStorerKey
               --      , @c_Facility      = @cFacility
               --      , @c_ToteNo        = @cToteNo
               --      , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
               --      , @c_ActionFlag    = 'S' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
               --      , @c_TaskDetailKey = '' -- @cTaskdetailkey
               --      , @c_Username      = @cUserName
               --      , @c_RefNo01       = @cLoadKey
               --      , @c_RefNo02       = @cPickMethod -- (ChewKP02)
               --      , @c_RefNo03       = @cOrderKey -- (ChewKP02)
               --      , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
               --      , @c_RefNo05       = @cCloseTote -- (ChewKP02)
               --      , @b_debug         = '0'
               --      , @c_LangCode      = 'ENG'
               --      , @n_Func          = 0
               --      , @b_success       = @bsuccess OUTPUT
               --      , @n_ErrNo         = @nErrNo    OUTPUT
               --      , @c_ErrMsg        = @cErrMSG   OUTPUT
               --END

               EXEC [dbo].[ispWCSRO03]
                       @c_StorerKey     = @cStorerKey
                     , @c_Facility      = @cFacility
                     , @c_ToteNo        = @cToteNo
                     , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
                     , @c_ActionFlag    = 'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                     , @c_TaskDetailKey = '' -- @cTaskdetailkey
                     , @c_Username      = @cUserName
                     , @c_RefNo01       = @cLoadKey
                     , @c_RefNo02       = @cPickMethod -- (ChewKP02)
                     , @c_RefNo03       = @cOrderKey -- (ChewKP02)
                     , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
                     , @c_RefNo05       = @cCloseTote -- (ChewKP02)
                     , @b_debug         = '0'
                     , @c_LangCode      = 'ENG'
                     , @n_Func          = 0
                     , @b_success       = @bsuccess OUTPUT
                     , @n_ErrNo         = @nErrNo    OUTPUT
                     , @c_ErrMsg        = @cErrMSG   OUTPUT
            END
         END
      END
   
      IF @nStep = 9
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ISNULL( @cTaskDetailKey, '') = ''
            BEGIN
               SELECT TOP 1 @cTaskDetailKey = TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE UserKey = @cUserName
               AND   [Status] = '3'
               ORDER BY 1

               SELECT @cStorerKey = Storerkey, 
                      @cTTMTasktype = TaskType,
                      @cWaveKey = WaveKey,
                      @cLoadKey = LoadKey,
                      @cPickMethod = PickMethod 
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
            END

            EXEC [dbo].[ispWCSRO03]
                  @c_StorerKey     = @cStorerKey
               , @c_Facility      = @cFacility
               , @c_ToteNo        = @cToteNo
               , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
               , @c_ActionFlag    = 'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
               , @c_TaskDetailKey = ''
               , @c_Username      = @cUserName
               , @c_RefNo01       = @cLoadKey
               , @c_RefNo02       = @cPickMethod -- (ChewKP02)
               , @c_RefNo03       = @cOrderKey -- (ChewKP02)
               , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
               , @c_RefNo05       = ''
               , @b_debug         = '0'
               , @c_LangCode      = 'ENG'
               , @n_Func          = 0
               , @b_success       = @bsuccess OUTPUT
               , @n_ErrNo         = @nErrNo    OUTPUT
               , @c_ErrMsg        = @cErrMSG   OUTPUT

            EXEC [dbo].[ispWCSRO03]
                 @c_StorerKey     = @cStorerKey
               , @c_Facility      = @cFacility
               , @c_ToteNo        = @cToteNo
               , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
               , @c_ActionFlag    = 'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
               , @c_TaskDetailKey = '' -- @cTaskdetailkey
               , @c_Username      = @cUserName
               , @c_RefNo01       = @cLoadKey
               , @c_RefNo02       = @cPickMethod -- (ChewKP02)
               , @c_RefNo03       = @cOrderKey -- (ChewKP02)
               , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
               , @c_RefNo05       = @cCloseTote -- (ChewKP02)
               , @b_debug         = '0'
               , @c_LangCode      = 'ENG'
               , @n_Func          = 0
               , @b_success       = @bsuccess  OUTPUT
               , @n_ErrNo         = @nErrNo    OUTPUT
               , @c_ErrMsg        = @cErrMSG   OUTPUT       
         END
      END
   END  
  
QUIT:  

 
 

GO