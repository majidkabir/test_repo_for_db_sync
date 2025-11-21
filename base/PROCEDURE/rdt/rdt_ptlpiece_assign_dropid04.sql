SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_PTLPiece_Assign_DropID04                              */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2021-02-16 1.0  yeekung  WMS-18729 Created                                 */  
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_PTLPiece_Assign_DropID04] (  
   @nMobile          INT,   
   @nFunc            INT,   
   @cLangCode        NVARCHAR( 3),   
   @nStep            INT,   
   @nInputKey        INT,   
   @cFacility        NVARCHAR( 5),   
   @cStorerKey       NVARCHAR( 15),    
   @cStation         NVARCHAR( 10),    
   @cMethod          NVARCHAR( 1),  
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK  
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,     
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,     
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,     
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,     
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,     
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,    
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,    
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,    
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,    
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,    
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,   
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,   
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,   
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,   
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,   
   @nScn             INT           OUTPUT,  
   @nErrNo           INT           OUTPUT,   
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cDropID      NVARCHAR(20)  
   DECLARE @nTotalDropID INT  
   DECLARE @cIPAddress   NVARCHAR(40)  
   DECLARE @cPosition    NVARCHAR(10)  
   DECLARE @cOrderKey    NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 20)
	DECLARE @cLoadkey     NVARCHAR(20)
   DECLARE @cSKU         NVARCHAR( 20)
   DECLARE @cChkStation  NVARCHAR( 10)
   DECLARE @cWaveKey     NVARCHAR( 10)
   DECLARE @cWaveKey2cHK NVARCHAR( 10)
   DECLARE @nCnt         INT
   DECLARE @nTranCount   INT
   DECLARE @curOrder     CURSOR 
   DECLARE @curPickslipNo CURSOR
   DECLARE @cLight       NVARCHAR( 1)
   DECLARE @nCountOrder  INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PTLPiece_Assign_DropID04
  
   /***********************************************************************************************  
                                                POPULATE  
   ***********************************************************************************************/  
   IF @cType = 'POPULATE-IN'  
   BEGIN  
      -- Get stat  
      SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''  
        
		-- Prepare next screen var  
		SET @cOutField01 = ''  
		SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))  
  
		-- Go to batch screen  
		SET @nScn = 4602  
   END  

   IF @cType = 'POPULATE-OUT'  
   BEGIN  
      IF @nStep='4'
      BEGIN
         SELECT TOP 1 @cLoadkey=loadkey
         FROM rdt.rdtPTLPieceLog (NOLOCK) 
	      WHERE StorerKey = @cStorerKey  
	      AND station=@cStation

         -- Loop orders  
		   SET @curPickslipNo = CURSOR FOR  
		   SELECT PD.pickdetailkey  
		   FROM dbo.PICKDETAIL PD WITH (NOLOCK)   
		   JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
		   WHERE PD.Storerkey = @cStorerKey 
		   AND   O.loadkey=@cLoadkey
		   AND   PD.Status < '5'
		   AND   PD.QTY > 0
         AND   PD.caseid=''
		   AND   PD.Status <> '4'
		   AND   O.Status <> 'CANC' 
		   AND   O.SOStatus <> 'CANC'
		   OPEN @curPickslipNo  
		   FETCH NEXT FROM @curPickslipNo INTO @cPickDetailKey  
		   WHILE @@FETCH_STATUS = 0  
		   BEGIN  
            UPDATE PICKDETAIL with (rowlock)
            SET status='4'
            WHERE  pickdetailkey=@cPickDetailKey

            -- Check blank  
            IF @@ERROR <>''  
            BEGIN  
               SET @nErrNo = 182851   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID  
               GOTO RollBackTran  
            END

            FETCH NEXT FROM @curPickslipNo INTO @cPickDetailKey  
         END
         CLOSE @curPickslipNo 
         Deallocate @curPickslipNo
      END
   END  
     
   /***********************************************************************************************  
                                                 CHECK  
   ***********************************************************************************************/  
   IF @cType = 'CHECK'  
   BEGIN  
      -- Screen mapping  
      SET @cDropID = @cInField01  
        
      -- Get total  
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND SourceKey <> ''  
        
      -- Check finish assign  
      IF @cDropID = '' AND @nTotalDropID > 0  
      BEGIN  
         GOTO RollBackTran  
      END  
        
      -- Check blank  
      IF @cDropID = ''   
      BEGIN  
         SET @nErrNo = 182851   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID  
         GOTO RollBackTran  
      END  
     
      -- Check DropID valid  
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                        AND DropID = @cDropID 
                        AND [Status] < '5')  
      BEGIN  
         SET @nErrNo = 182852  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad DropID  
         SET @cOutField01 = ''  
         GOTO RollBackTran  
      END  

      DECLARE @cUser NVARCHAR(20)

      select @cUser=username,
             @cLight = V_String24
      from rdt.rdtmobrec (nolock)
      where mobile=@nMobile
     
      -- Check DropID assigned  
      IF EXISTS( SELECT 1   
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND dropid = @cDropID
            AND addwho<>@cUser)  
      BEGIN  
         SET @nErrNo = 182853  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned  
         SET @cOutField01 = ''  
         GOTO RollBackTran  
      END  

		SELECT @cLoadkey=o.loadkey,
				@cWaveKey= o.userdefine09
		FROM PickDetail pd WITH (NOLOCK)
		JOIN orders o (nolock) ON pd.storerkey=o.storerkey and pd.orderkey=o.orderkey
		WHERE pd.StorerKey = @cStorerKey 
			AND pd.DropID = @cDropID 
         AND ISNULL(PD.CASEID,'') = ''
			AND pd.[Status] < '5'

      IF ISNULL(@cLoadkey,'')=''
      BEGIN  
         SET @nErrNo = 182857  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned  
         SET @cOutField01 = ''  
         GOTO RollBackTran  
      END  

      IF EXISTS( SELECT 1 from rdt.rdtPTLPieceLog (NOLOCK) 
						WHERE StorerKey = @cStorerKey  
						AND station=@cStation)
      BEGIN  

         IF EXISTS( SELECT 1 from rdt.rdtPTLPieceLog (NOLOCK) 
						WHERE StorerKey = @cStorerKey  
						AND station=@cStation
                  AND loadkey<>@cLoadkey)
         BEGIN
            SET @nErrNo = 182853  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned  
            SET @cOutField01 = ''  
            GOTO RollBackTran  
         END
      END  


      IF EXISTS( SELECT 1 from rdt.rdtPTLPieceLog (NOLOCK) 
					WHERE StorerKey = @cStorerKey  
					AND station<>@cStation
               AND loadkey=@cLoadkey)
      BEGIN
         SET @nErrNo = 182853  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned  
         SET @cOutField01 = ''  
         GOTO RollBackTran  
      END

      SELECT @nCountOrder= COUNT(*)
      FROM (SELECT PD.Orderkey
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)   
		      JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey and pd.storerkey=o.storerkey)
		      WHERE PD.Storerkey = @cStorerKey
		      AND   O.loadkey=@cLoadkey
            GROUP BY PD.Orderkey) as records

      IF EXISTS (SELECT 1 
				      FROM dbo.DeviceProfile DP WITH (NOLOCK)  
				      WHERE DP.DeviceType = 'STATION'  
					      AND DP.DeviceID = @cStation 
					      AND DP.logicalname NOT IN('BATCH','PACK')
                     AND DP.storerkey=@cStorerKey
                 HAVING COUNT(*)<@nCountOrder)
      BEGIN
         SET @nErrNo = 182856  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned  
         SET @cOutField01 = ''  
         GOTO RollBackTran  
      END


		IF NOT EXISTS (SELECT 1 from rdt.rdtPTLPieceLog (NOLOCK) 
						WHERE StorerKey = @cStorerKey  
						AND station=@cStation
                  AND loadkey=@cLoadkey
						)
		BEGIN
			-- Loop orders  
			DECLARE @cPreassignPos NVARCHAR(10)  
			SET @curOrder = CURSOR FOR  
			SELECT PD.OrderKey   
			FROM dbo.PICKDETAIL PD WITH (NOLOCK)   
			JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
			WHERE PD.Storerkey = @cStorerKey 
			AND   O.loadkey=@cLoadkey
			AND   PD.Status <= '5'
			AND   PD.QTY > 0
			AND   PD.Status <> '4'
			AND   O.Status <> 'CANC' 
			AND   O.SOStatus <> 'CANC'
			GROUP BY PD.OrderKey
			ORDER BY PD.OrderKey  
			OPEN @curOrder  
			FETCH NEXT FROM @curOrder INTO @cOrderKey  
			WHILE @@FETCH_STATUS = 0  
			BEGIN  
				-- Get position not yet assign  
				SET @cIPAddress = ''  
				SET @cPosition = ''  

				SELECT TOP 1  
					@cIPAddress = DP.IPAddress,   
					@cPosition = DP.DevicePosition  
				FROM dbo.DeviceProfile DP WITH (NOLOCK)  
				WHERE DP.DeviceType = 'STATION'  
					AND DP.DeviceID = @cStation 
					AND DP.logicalname NOT IN('BATCH','PACK')
					AND NOT EXISTS( SELECT 1  
						FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)  
						WHERE Log.Station = @cStation  
							AND Log.Position = DP.DevicePosition)  
				ORDER BY DP.LogicalPos, DP.DevicePosition  

				-- Save assign  
				INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Position, Method, dropid, OrderKey, SKU, loadkey,storerkey) 
				VALUES  
				(@cStation, @cIPAddress, @cPosition, @cMethod, @cDropID, @cOrderKey, '', @cLoadkey,@cStorerKey)
				IF @@ERROR <> 0  
				BEGIN  
					SET @nErrNo = 182854  
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail  
					GOTO RollBackTran  
				END  

				FETCH NEXT FROM @curOrder INTO @cOrderKey
			END
		END
      ELSE
      BEGIN
			SET @curOrder = CURSOR FOR  
			SELECT PD.OrderKey   
			FROM dbo.PICKDETAIL PD WITH (NOLOCK)   
			JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
			WHERE PD.Storerkey = @cStorerKey 
			AND   O.loadkey=@cLoadkey
			AND   PD.Status <= '5'
         AND   PD.Dropid =@cDropID
			AND   PD.QTY > 0
			AND   PD.Status <> '4'
			AND   O.Status <> 'CANC' 
			AND   O.SOStatus <> 'CANC'
			GROUP BY PD.OrderKey
			ORDER BY PD.OrderKey  

         OPEN @curOrder  
			FETCH NEXT FROM @curOrder INTO @cOrderKey  
			WHILE @@FETCH_STATUS = 0  
			BEGIN  

			   UPDATE RDT.rdtptlpiecelog
            set dropid=@cDropID,
                editdate=getdate(),
                editwho= @cUser
            where orderkey=@cOrderKey
            AND station=@cStation

				IF @@ERROR <> 0  
				BEGIN  
					SET @nErrNo = 182854  
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail  
					GOTO RollBackTran  
				END  

				FETCH NEXT FROM @curOrder INTO @cOrderKey
			END
         CLOSE @curOrder 
         Deallocate @curOrder

      END
      
      IF @cLight ='1'
      BEGIN
		   DECLARE	@cLightModeBatch NVARCHAR(20),
					   @bSuccess INT,
					   @cDisplay NVARCHAR(20) =''

		   SET @cLightModeBatch = rdt.RDTGetConfig( @nFunc, 'LightModeBatch', @cStorerKey)

		   SELECT 
			   @cPosition=deviceposition,
			   @cIPAddress=ipaddress
		   FROM deviceprofile WITH (NOLOCK) 
		   WHERE deviceid = @cStation
		   and storerkey=@cStorerKey
		   and logicalname='batch'

		   -- Off all lights
		   EXEC  PTL.isp_PTL_TerminateModuleSingle
				   @cStorerKey
               ,@nFunc
               ,@cStation
				   ,@cPosition
				   ,@bSuccess    OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = 0
           ,@c_DisplayValue   = 'STarT' 
           ,@b_Success        = @bSuccess    OUTPUT    
           ,@n_Err            = @nErrNo      OUTPUT  
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos      = @cPosition
           ,@c_DeviceIP       = @cIPAddress  
           ,@c_LModMode       = @cLightModeBatch
           ,@c_DeviceModel    = 'BATCH'
         IF @nErrNo <> 0
            GOTO Quit
      END
   END  

   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_PTLPiece_Assign_DropID04
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
  
END  

GO