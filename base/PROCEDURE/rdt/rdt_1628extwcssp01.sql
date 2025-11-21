SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1628ExtWCSSP01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-01-2022 1.0  yeekung     WMS18619. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtWCSSP01] (
   @nMobile                   INT,            
   @nFunc                     INT,            
   @cLangCode                 NVARCHAR( 3),   
   @nStep                     INT,            
   @nInputKey                 INT,            
   @cFacility                 NVARCHAR( 5),   
   @cStorerkey                NVARCHAR( 15),  
   @cWaveKey                  NVARCHAR( 10),  
   @cLoadKey                  NVARCHAR( 10),  
   @cOrderKey                 NVARCHAR( 10),  
   @cPutAwayZone              NVARCHAR( 10),  
   @cPickZone                 NVARCHAR( 10),  
   @cSKU                      NVARCHAR( 20),  
   @cPickSlipNo               NVARCHAR( 10),  
   @cLOT                      NVARCHAR( 10),  
   @cLOC                      NVARCHAR( 10),  
   @cDropID                   NVARCHAR( 20),  
   @cStatus                   NVARCHAR( 1),   
   @cCartonType               NVARCHAR( 10),  
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success  INT,
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cPickDetailKey     NVARCHAR( 10),
   @nDropIDCnt         INT,
   @nPickQty           INT,
   @nQTY_PD            INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nRPLCount          INT,
   @nPackQty           INT,
   @nCartonNo          INT,
   @cLabelNo           NVARCHAR( 20),
   @cLabelLine         NVARCHAR( 5),
   @cConsigneeKey      NVARCHAR( 15),
   @cExternOrderKey    NVARCHAR( 30),
   @cUOM               NVARCHAR( 10), 
   @cLoadDefaultPickMethod NVARCHAR( 1),  
   @nTotalPickedQty    INT,   
   @nTotalPackedQty    INT,   
   @nPickPackQty       INT,   
   @nMultiStorer       INT, 
   @cRoute             NVARCHAR( 20),  
   @cOrderRefNo        NVARCHAR( 18), 
   @cUserName          NVARCHAR( 20), 
   @cPrevDropID        NVARCHAR( 20),
   @cOption            NVARCHAR( 1),
   @nShortPick         INT

   DECLARE @cClusterPickUpdLabelNoToCaseID   NVARCHAR( 1)
   DECLARE @cstation NVARCHAR(20),
           @bSuccess INT

   SET @cPrevDropID = ''

   SELECT @cUserName = UserName,
          @cOption = I_Field01
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @cClusterPickUpdLabelNoToCaseID = rdt.RDTGetConfig( @nFunc, 'ClusterPickUpdLabelNoToCaseID', @cStorerKey) 
      
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
   BEGIN
      SELECT @cStorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   END

   SELECT @cLoadKey = LoadKey FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey

   SELECT @cLoadDefaultPickMethod = LoadPickMethod FROM dbo.LoadPlan WITH (NOLOCK)
   WHERE LoadKey = @cLoadKey

   SELECT TOP 1     
     @cLOC   = PD.Loc    
   FROM RDT.RDTPickLock RPL WITH (NOLOCK)    
   JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)    
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
   JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)    
   WHERE RPL.StorerKey = @cStorerkey    
      AND RPL.Status < '5'    
      AND RPL.AddWho = @cUserName    
      AND PD.Status = '0'    
      AND L.PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @cPutAwayZone END    
      AND L.PickZone = CASE WHEN ISNULL(@cPickZone, '') = '' THEN L.PickZone ELSE @cPickZone END    
      AND L.Facility = @cFacility    
      AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)   
                      WHERE SKIP_RPL.OrderKey = PD.OrderKey  
                      AND SKIP_RPL.SKU = PD.SKU  
                      AND SKIP_RPL.AddWho = @cUserName  
                      AND SKIP_RPL.Status = 'X')  
   ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey  
  
   IF @@ROWCOUNT = 0  
   BEGIN  
      SELECT TOP 1     
         @cLOC   = PD.Loc  
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)    
      WHERE PD.StorerKey = @cStorerKey    
         AND PD.Status = '0'    
         AND L.PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @cPutAwayZone END    
         AND L.PickZone = CASE WHEN ISNULL(@cPickZone, '') = '' THEN L.PickZone ELSE @cPickZone END    
         AND L.Facility = @cFacility    
         AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))  
         AND (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))  
         -- Cater for short pick or user change tote/dropid then sku not exists in rdtpicklock   
         --AND (( ISNULL( @cCurrSKU, '') = '') OR ( PD.SKU = @cCurrSKU))    
         -- Not to get the same loc within the same orders  
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)  
                           WHERE SKIP_RPL.OrderKey = PD.OrderKey  
                           AND SKIP_RPL.StorerKey = PD.StorerKey    
                           AND SKIP_RPL.SKU = PD.SKU  
                           AND SKIP_RPL.AddWho = @cUserName  
                           AND SKIP_RPL.Status = 'X')  
      ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey  
   END  
  
   IF @@ROWCOUNT = 0  
   BEGIN  
      SELECT TOP 1     
         @cLOC   = PD.Loc  
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)    
      WHERE PD.StorerKey = @cStorerKey    
         AND PD.Status = '0'    
         AND L.PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @cPutAwayZone END    
         AND L.PickZone = CASE WHEN ISNULL(@cPickZone, '') = '' THEN L.PickZone ELSE @cPickZone END    
         AND L.Facility = @cFacility    
         AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))  
         AND (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))  
         -- Not to get the same loc within the same orders  
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)  
                           WHERE SKIP_RPL.OrderKey = PD.OrderKey  
                           AND SKIP_RPL.StorerKey = PD.StorerKey    
                           AND SKIP_RPL.SKU = PD.SKU  
                           AND SKIP_RPL.AddWho = @cUserName  
                           AND SKIP_RPL.Status = 'X')  
      ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey  
   END

	IF ISNULL(@cLOC,'')=''
	BEGIN
		SELECT @cstation=short 
		FROM Codelkup (NOLOCK)
		WHERE listname='WCSSTATION' 
			AND code='GRS'
			AND storerkey =@cStorerkey

		SET @nErrNo = 0
		EXEC [dbo].[ispWCSRO03]    
				@c_StorerKey     =  @cStorerKey    
			, @c_Facility      =  @cFacility    
			, @c_ToteNo        =  @cDropID    
			, @c_TaskType      =  'PTS'    
			, @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
			, @c_TaskDetailKey =  ''     
			, @c_Username      =  @cUserName    
			, @c_RefNo01       =  @cstation   
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


		SET @nErrNo = 0
		EXEC [dbo].[ispWCSRO03]    
				@c_StorerKey     =  @cStorerKey    
			, @c_Facility      =  @cFacility    
			, @c_ToteNo        =  @cDropID    
			, @c_TaskType      =  'PTS'    
			, @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
			, @c_TaskDetailKey =  ''     
			, @c_Username      =  @cUserName    
			, @c_RefNo01       =  @cstation   
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
	END

	IF @nStep='15' and @cOption = '1'
	BEGIN
		SELECT @cstation=short 
		FROM Codelkup (NOLOCK)
		WHERE listname='WCSSTATION' 
			AND code='GRS'
			AND storerkey =@cStorerkey

		SET @nErrNo = 0
		EXEC [dbo].[ispWCSRO03]    
				@c_StorerKey     =  @cStorerKey    
			, @c_Facility      =  @cFacility    
			, @c_ToteNo        =  @cDropID    
			, @c_TaskType      =  'PTS'    
			, @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
			, @c_TaskDetailKey =  ''     
			, @c_Username      =  @cUserName    
			, @c_RefNo01       =  @cstation   
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


		SET @nErrNo = 0
		EXEC [dbo].[ispWCSRO03]    
				@c_StorerKey     =  @cStorerKey    
			, @c_Facility      =  @cFacility    
			, @c_ToteNo        =  @cDropID    
			, @c_TaskType      =  'PTS'    
			, @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
			, @c_TaskDetailKey =  ''     
			, @c_Username      =  @cUserName    
			, @c_RefNo01       =  @cstation   
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
	END
END

GO