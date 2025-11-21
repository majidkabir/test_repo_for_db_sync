SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_762ExtWCSSP01                                   */
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
/* 26-01-2022  1.0  yeekung     WMS18620. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_762ExtWCSSP01] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR(3),   
   @nStep          INT,                   
   @cUserName      NVARCHAR( 18), 
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15), 
   @cDropID        NVARCHAR( 20), 
   @cSKU           NVARCHAR( 20), 
   @nQty           INT,           
   @cToLabelNo     NVARCHAR( 20), 
   @cPTSLogKey     NVARCHAR( 20),  
   @nErrNo				INT OUTPUT,   
   @cErrMsg				NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cNewTaskDetailKey NVARCHAR(20),
           @cFromloc NVARCHAR(20),
           @cLot   NVARCHAR(20),
           @cUom   NVARCHAR(20),
           @cPutawayZone NVARCHAR(20),
           @bSuccess INT

   DECLARE @cToLOC            NVARCHAR( 10)  
   DECLARE @cToLOCPAZone      NVARCHAR( 10)  
   DECLARE @cToLOCAreaKey     NVARCHAR( 10)  
	DECLARE @cPickStatus       nvarchar(1)
	DECLARE @cOutField01    NVARCHAR( 20)  
 DECLARE @cOutField02    NVARCHAR( 20)  
   DECLARE @cOutField03    NVARCHAR( 20)  
   DECLARE @cOutField04    NVARCHAR( 20)  
   DECLARE @cOutField05    NVARCHAR( 20)  
   DECLARE @cOutField06    NVARCHAR( 20)  
   DECLARE @cOutField07    NVARCHAR( 20)  
   DECLARE @cOutField08    NVARCHAR( 20)  
   DECLARE @cOutField09    NVARCHAR( 20)  
   DECLARE @cOutField10    NVARCHAR( 20)  
	DECLARE @cOutField11    NVARCHAR( 20)  
	DECLARE @cOutField12    NVARCHAR( 20)  
   DECLARE @cOutField13    NVARCHAR( 20)  
   DECLARE @cOutField14    NVARCHAR( 20)  
   DECLARE @cOutField15    NVARCHAR( 20)  
	DECLARE @nPABookingKey  INT = 0  

	SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)
   IF @cPickStatus NOT IN ('3', '5')
      SET @cPickStatus = '5'


	SELECT @cFromloc = ptsposition,
				@cLot = lot,
				@cUom = uom
	FROM rdt.rdtPTSLog 
	WHERE PTSLogKey = @cPTSLogKey

	SELECT @cPutawayZone = PutawayZone  
	FROM dbo.LOC WITH (NOLOCK)  
	WHERE Facility = @cFacility  
	AND   Loc = @cFromLoc 


	SELECT @cNewTaskDetailKey=TaskDetailKey
	from taskdetail (nolock)
	where tasktype='ASTRPT'
	and Status=0
	and sku=@cSKU
	and caseid=@cToLabelNo
    
	SET @nErrNo = 0
	EXEC [dbo].[ispWCSRO03]    
			@c_StorerKey     =  @cStorerKey    
		, @c_Facility      =  @cFacility    
		, @c_ToteNo        =  @cToLabelNo    
		, @c_TaskType      =  'PA'    
		, @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
		, @c_TaskDetailKey =  @cNewTaskDetailKey     
		, @c_Username      =  @cUserName    
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


	GOTO QUIT
END

QUIT:

GO