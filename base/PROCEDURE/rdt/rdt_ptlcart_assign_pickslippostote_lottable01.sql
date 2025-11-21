SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_PickslipPosTote_Lottable01             */
/* Copyright      : LFLogistics                                               */
/*                 PickslipPosTote_Lottable->PickslipPosTote_Lottable01       */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 21-05-2021 1.0  yeekung  WMS-17002 Created                                 */
/* 28-12-2021 1.1  YeeKung  WMS-18463 Group by lot (yeekung01)						*/
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLCart_Assign_PickslipPosTote_Lottable01] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cCartID          NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cMethod          NVARCHAR( 1),
   @cPickSeq         NVARCHAR( 1),
   @cDPLKey          NVARCHAR( 10),
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

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nTranCount  INT
   DECLARE @nTotalTote  INT

   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)

   DECLARE @cPSType     NVARCHAR(10)
   DECLARE @cZone       NVARCHAR(18)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cLoadKey    NVARCHAR(10)

   DECLARE @cLottableCode NVARCHAR( 30)
   DECLARE @cLottable01   NVARCHAR( 18)
   DECLARE @cLottable02   NVARCHAR( 18)
   DECLARE @cLottable03   NVARCHAR( 18)
   DECLARE @dLottable04   DATETIME
   DECLARE @dLottable05   DATETIME
   DECLARE @cLottable06   NVARCHAR( 30)
   DECLARE @cLottable07   NVARCHAR( 30)
   DECLARE @cLottable08   NVARCHAR( 30)
   DECLARE @cLottable09   NVARCHAR( 30)
   DECLARE @cLottable10   NVARCHAR( 30)
   DECLARE @cLottable11   NVARCHAR( 30)
   DECLARE @cLottable12   NVARCHAR( 30)
   DECLARE @dLottable13   DATETIME
   DECLARE @dLottable14   DATETIME
   DECLARE @dLottable15   DATETIME
   DECLARE @cLOT          NVARCHAR(20)
   
   DECLARE @cSelect  NVARCHAR( MAX)
   DECLARE @cFrom    NVARCHAR( MAX)
   DECLARE @cWhere1  NVARCHAR( MAX)
   DECLARE @cWhere2  NVARCHAR( MAX)
   DECLARE @cGroupBy NVARCHAR( MAX)
   DECLARE @cOrderBy NVARCHAR( MAX)
   DECLARE @cPickConfirmStatus NVARCHAR(1)  
   DECLARE @cAutoScanIn NVARCHAR( 1)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @nReplenExists        INT
   DECLARE @cCheckPendingReplen  NVARCHAR( 1)
   DECLARE @cCheckReplenGroup    NVARCHAR( 10)
   DECLARE @cFilterLocType       NVARCHAR( 10)
   DECLARE @cSQLFilterLocType    NVARCHAR( MAX)
   DECLARE @cTemp_PickSlipNo     NVARCHAR( 10)
   DECLARE @cPickSlipNo2ScanIn   NVARCHAR( 10)
   DECLARE @cTemp_OrderKey       NVARCHAR( 10) = ''
   DECLARE @cTemp_LoadKey        NVARCHAR( 10) = ''
   DECLARE @cM_PickSlipNo        NVARCHAR( 10) = ''
   
   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = '' -- PickSlipNo
		SET @cOutField04 = '' -- Position
		SET @cOutField05 = '' -- ToteID
		SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote

	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo

		-- Go to pickslipno, pos, tote screen
		SET @nScn = 4185
   END      

   /*   
   IF @cType = 'POPULATE-OUT'
   BEGIN
		-- Go to cart screen
   END
   */

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField03
      SET @cPosition = @cInField04
      SET @cToteID = @cInField05


      -- Get total
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Check finish assign
      IF @nTotalTote > 0 AND @cPickSlipNo = '' AND @cPosition = '' AND @cToteID = ''
      BEGIN
         GOTO Quit
      END
      
      -- Check blank
		IF @cPickSlipNo = '' 
      BEGIN
         SET @nErrNo = 168201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedPickSlipNo
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo
         GOTO Quit
      END
      
      -- Check pickslip assigned
      IF @cPickZone = ''
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
      ELSE
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND (PickZone = @cPickZone OR PickZone = '')
      IF ISNULL(@nErrNo,'') NOT IN('',0)
      BEGIN
         SET @nErrNo = 168202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo
         SET @cOutField03 = ''
         GOTO Quit
      END

      SET @cPSType = ''

      -- Get PickHeader info
      SELECT 
         @cZone = Zone, 
         @cOrderKey = ISNULL( OrderKey, ''), 
         @cLoadKey = ExternOrderKey
      FROM PickHeader WITH (NOLOCK) 
      WHERE PickHeaderKey = @cPickSlipNo

      -- Check PickSlipNo valid
      IF @@ROWCOUNT = 0
      BEGIN
         -- Check if custom pickslip
         IF NOT EXISTS ( SELECT 1 
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   PickSlipNo = @cPickSlipNo
            AND   Status < '4')
         BEGIN
            SET @nErrNo = 168203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PickSlipNo
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo
            GOTO Quit
         END
         ELSE
         BEGIN
            -- Not in PickHeader, is a custom pickslip
            SET @cPSType = 'CUSTOM'

            -- Check if this custom pickslip is a sub pickslip ( not exists in pickheader)
            SELECT TOP 1 @cTemp_OrderKey = OrderKey
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND   PickSlipNo = @cPickSlipNo
               AND   Status < '4'
            ORDER BY 1

            -- Look for discrete pickslipno
            SELECT @cM_PickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cTemp_OrderKey

            -- Look for conso pickslipno
            IF @@ROWCOUNT = 0
            BEGIN
               SELECT @cTemp_LoadKey = LoadKey
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cTemp_OrderKey

               SELECT @cM_PickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE ExternOrderKey = @cTemp_LoadKey
            END
         END
      END

      -- (james01)
      -- If setup custom pick status then check pd.status based on setup.
      -- If not setup then follow original checking
      SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = ''

      IF @cPSType = ''
      BEGIN
         -- Get PickSlip type
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
            SET @cPSType = 'XD'
         ELSE IF @cOrderKey = ''
            SET @cPSType = 'CONSO'
         ELSE 
            SET @cPSType = 'DISCRETE'
      END

      -- Check PickSlip in Zone
      SET @nErrNo = 1
      IF @cPSType = 'DISCRETE'
      BEGIN
         DECLARE @cPickinProcess NVARCHAR(20)

         Select @cPickinProcess = Max(CL.UDF03)
         FROM Orders O(Nolock) LEFT Join CODELKUP CL(Nolock)On O.Stop = CL.Code
         JOIN PickHeader PH(Nolock) On PH.Orderkey = O.Orderkey
         WHERE CL.Listname = 'LORBRD' 
            AND PH.PickHeaderKey = @cPickSlipNo
    
         If @cPickinProcess = 'PickInProcess' 
         Begin
            Set @cPickConfirmStatus = '3' 
         End
         Else 
         Begin
            Set @cPickConfirmStatus = '5'
         End

         SET @cSQL =   
         ' SELECT TOP 1 @nErrNo = 0, @cTemp_PickSlipNo = @cPickSlipNo ' +   
         ' FROM dbo.Orders O WITH (NOLOCK) ' +
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
         CASE WHEN @cPickZone <> '' THEN ' JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' ELSE '' END + 
         ' WHERE O.OrderKey = @cOrderKey ' +
         ' AND ( PD.Status < @cPickConfirmStatus) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone <> '' THEN ' AND LOC.PickZone = @cPickZone' ELSE '' END +
         ' ORDER BY 1'
      END

      IF @cPSType = 'CONSO'
         SET @cSQL =   
         ' SELECT TOP 1 @nErrNo = 0, @cTemp_PickSlipNo = MAX(IIF(PD.PickSlipNo <> @cPickSlipNo, PD.PickSlipNo, '''')) ' +   
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +    
         ' JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' +
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
         CASE WHEN @cPickZone <> '' THEN ' JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' ELSE '' END + 
         ' WHERE LPD.Loadkey = @cLoadKey ' +
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone <> '' THEN ' AND LOC.PickZone = @cPickZone' ELSE '' END +
         ' ORDER BY 1'

      IF @cPSType = 'XD'
         SET @cSQL =   
         ' SELECT TOP 1 @nErrNo = 0, @cTemp_PickSlipNo = MAX(IIF(PD.PickSlipNo <> @cPickSlipNo, PD.PickSlipNo, '''')) ' +   
         ' FROM dbo.Orders O WITH (NOLOCK) ' +    
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
         ' JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' +
         CASE WHEN @cPickZone <> '' THEN ' JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' ELSE '' END + 
         ' WHERE RKL.PickslipNo = @cPickSlipNo ' +
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone <> '' THEN ' AND LOC.PickZone = @cPickZone' ELSE '' END +
         ' ORDER BY 1'

      IF @cPSType = 'CUSTOM'
         SET @cSQL = 
         ' SELECT TOP 1 @nErrNo = 0, @cTemp_PickSlipNo = MAX(IIF(PD.PickSlipNo <> @cPickSlipNo, PD.PickSlipNo, '''')) ' +   
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' +
         CASE WHEN @cPickZone <> '' THEN ' JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' ELSE '' END + 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone <> '' THEN ' AND LOC.PickZone = @cPickZone' ELSE '' END +
         ' ORDER BY 1'

      SET @cSQLParam = 
         '@cLoadKey    NVARCHAR( 10), ' +  
         '@cOrderKey   NVARCHAR( 10), ' +  
         '@cPickSlipNo NVARCHAR( 10), ' +  
         '@cPickZone   NVARCHAR( 10), ' + 
         '@cPickConfirmStatus NVARCHAR( 1), ' +
         '@cTemp_PickSlipNo  NVARCHAR( 10) OUTPUT, ' + 
         '@nErrNo      INT OUTPUT'

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @cLoadKey, @cOrderKey, @cPickSlipNo, @cPickZone, @cPickConfirmStatus, @cTemp_PickSlipNo OUTPUT, @nErrNo OUTPUT
      
      IF  ISNULL(@cTemp_PickSlipNo,'')=''
      BEGIN
         SET @nErrNo = 168204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS NoPickTask
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo
         SET @cOutField03 = ''
         GOTO Quit
      END
      
      -- If not custom pickslip, pickdetail.pickslipno shouldn't have value
      -- Else both type pickslip can be scanned
      -- For show pick, wms will stamp pickslipno into pickdetail
      -- Reject user to scan P* pickslip if there are T* pickslip in pickdetail.
      IF @cPSType <> 'CUSTOM' AND ISNULL( @cTemp_PickSlipNo, '') <> '' AND 
         ISNULL(@cTemp_PickSlipNo,'') <> ISNULL(@cPickSlipNo,'')
      BEGIN
         SET @nErrNo = 168205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateTask
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- (james03)
      SET @cCheckPendingReplen = rdt.rdtGetConfig( @nFunc, 'CheckPendingReplen', @cStorerKey)  
      IF @cCheckPendingReplen = '1'
      BEGIN
         SET @cCheckReplenGroup = rdt.rdtGetConfig( @nFunc, 'CheckReplenGroup', @cStorerKey) 
         IF @cCheckReplenGroup = '0'
            SET @cCheckReplenGroup = ''
             
         SET @nReplenExists = 0

         -- Check Pending Replen
         IF @cPSType = 'DISCRETE' 
         BEGIN
            SELECT TOP 1 @nReplenExists = (1)
            FROM dbo.PICKHEADER PH WITH (NOLOCK)
               JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( WD.Orderkey=PH.Orderkey)
               JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( PD.Orderkey=WD.Orderkey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LOC.Loc=PD.Loc)
               JOIN dbo.REPLENISHMENT RP WITH (NOLOCK) ON  ( RP.Wavekey = WD.Wavekey AND RP.Lot = PD.Lot AND RP.FromLoc = PD.Loc AND RP.ID = PD.ID)
            WHERE PH.PickHeaderKey = @cPickSlipNo 
               AND   PD.Status < '4' 
               AND   PD.Qty > 0 
               AND   RP.Confirmed = 'N'
               AND  ( @cPickZone = '' OR LOC.PickZone = @cPickZone)
               AND  ( @cCheckReplenGroup = '' OR RP.ReplenishmentGroup = @cCheckReplenGroup)
         END
         
         IF @cPSType = 'CONSO' 
         BEGIN
            SELECT TOP 1 @nReplenExists = (1)
            FROM dbo.PICKHEADER PH WITH (NOLOCK)
               JOIN dbo.LOADPLANDETAIL LD WITH (NOLOCK) ON ( LD.Loadkey = PH.ExternOrderkey)
               JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( PD.Orderkey = LD.Orderkey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LOC.Loc = PD.Loc)
               JOIN dbo.REPLENISHMENT RP WITH (NOLOCK) ON ( RP.Loadkey = LD.Loadkey AND RP.Lot = PD.Lot AND RP.FromLoc = PD.Loc AND RP.ID = PD.ID)
            WHERE PH.PickHeaderKey = @cPickSlipNo 
               AND   PD.Status < '4' 
               AND   PD.Qty > 0 
               AND   RP.Confirmed = 'N'
               AND  ( @cPickZone ='' OR LOC.PickZone = @cPickZone)
               AND  ( @cCheckReplenGroup = '' OR RP.ReplenishmentGroup = @cCheckReplenGroup)
         END
         
         IF @cPSType = 'XD' 
         BEGIN
            SELECT TOP 1 @nReplenExists = (1)
            FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
               JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) 
               JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.LoadKey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LOC.Loc = PD.Loc)
               JOIN dbo.REPLENISHMENT RP WITH (NOLOCK) ON ( RP.Loadkey = O.Loadkey AND RP.Lot = PD.Lot AND RP.FromLoc = PD.Loc AND RP.ID = PD.ID)
            WHERE RKL.Pickslipno = @cPickSlipNo 
               AND   PD.Status < '4' 
               AND   PD.Qty > 0 
               AND   RP.Confirmed = 'N'
               AND  ( @cPickZone ='' OR LOC.PickZone = @cPickZone)
               AND  ( @cCheckReplenGroup = '' OR RP.ReplenishmentGroup = @cCheckReplenGroup)
         END

         IF @cPSType = 'CUSTOM'
         BEGIN
            SELECT TOP 1 @nReplenExists = (1)
            FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
               JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.LoadKey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LOC.Loc = PD.Loc)
               JOIN dbo.REPLENISHMENT RP WITH (NOLOCK) ON ( RP.Loadkey = O.Loadkey AND RP.Lot = PD.Lot AND RP.FromLoc = PD.Loc AND RP.ID = PD.ID)
            WHERE PD.Pickslipno = @cPickSlipNo 
               AND   PD.Status < '4' 
               AND   PD.Qty > 0 
               AND   RP.Confirmed = 'N'
               AND  ( @cPickZone ='' OR LOC.PickZone = @cPickZone)
               AND  ( @cCheckReplenGroup = '' OR RP.ReplenishmentGroup = @cCheckReplenGroup)
         END

         IF @nReplenExists > 0
         BEGIN
            SET @nErrNo = 168206
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Replen
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Position
            SET @cOutField03 = ''
            GOTO Quit
         END
      END

      SET @cOutField03 = @cPickSlipNo
      
      -- Check position blank
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 168207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Position
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Check position valid
      IF NOT EXISTS( SELECT 1
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'CART'
            AND DeviceID = @cCartID
            AND DevicePosition = @cPosition)
      BEGIN
         SET @nErrNo = 168208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Position
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position
         SET @cOutField04 = ''
         GOTO Quit
      END

      If EXISTS ( Select 1 From rdt.rdtPTLCartLog WITH (NOLOCK) Where CartID = @cCartID  )
      BEGIN
         Declare @cOrderGroup nvarchar(10) , @cPTLOrderGroup nvarchar(10)

         Select  @cOrderGroup=CD.UDF02 
         FROM Orders O (Nolock) Left Join CODELKUP CD (Nolock) On (O.Stop = CD.Code)
         Where CD.Listname = 'LORBRD'
         AND O.Orderkey = @cOrderKey

         Select TOP 1 @cPTLOrderGroup = Max(CD.UDF02) 
         FROM Orders  O(Nolock)   Left Join CODELKUP CD(Nolock)  On (O.Stop = CD.Code) 
         JOIN PickHeader PH(Nolock) ON (PH.Orderkey = O.Orderkey)
         Join rdt.rdtPTLCartLog CL(Nolock) On (CL.PickSlipNo = PH.PickHeaderkey)
         Where CD.Listname = 'LORBRD' 
            AND CL.Cartid = @cCartID

         If @cPTLOrderGroup <> @cOrderGroup
         Begin
            SET @nErrNo = 168209
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffOrderGroup
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position
            SET @cOutField04 = ''
            GOTO Quit
         End
      End     


      -- Check position assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND Position = @cPosition)
      BEGIN
         SET @nErrNo = 168210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pos assigned
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cPosition

      -- Check blank tote
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 168211
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check tote assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = @cToteID)
      BEGIN
         SET @nErrNo = 168212
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      SET @cOutField05 = @cToteID
      
      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT
      
      -- Get position info
      SELECT @cIPAddress = IPAddress
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceType = 'CART'
         AND DeviceID = @cCartID
         AND DevicePosition = @cPosition

      BEGIN TRAN
      SAVE TRAN rdt_PTLCart_Assign
      
      -- Save assign
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, PickSlipNo, StorerKey)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cPickSlipNo, @cStorerKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 168213
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollBackTran
      END

      -- (james04)
      SET @cFilterLocType = rdt.rdtGetConfig( @nFunc, 'FilterLocType', @cStorerKey)
      IF @cFilterLocType = '0'
         SET @cFilterLocType = ''

      IF @cFilterLocType <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = @cFilterLocType
               AND   Storerkey = @cStorerKey
               AND  (code2 = @nFunc OR code2 = 0))
            SET @cFilterLocType = ''
      END

      DECLARE @curPD CURSOR

      IF @cPSType = 'DISCRETE'
         SET @cSQL =   
         ' SELECT PD.LOC, PD.SKU, SUM( PD.QTY),Lottable02,lottable04,PD.LOT ' +   
         ' FROM Orders O WITH (NOLOCK) ' +
         ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
         ' JOIN LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
         CASE WHEN @cFilterLocType <> '' THEN ' JOIN @tLocationType t ON (LOC.LocationType = t.LocationType) ' 
              ELSE '' END +
         ' WHERE O.OrderKey = @cOrderKey ' +
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +   
         ' GROUP BY PD.LOC, PD.SKU,PD.LOT,Lottable02,lottable04 ' --(yeekung01)
         
      IF @cPSType = 'CONSO'
         SET @cSQL =   
         ' SELECT PD.LOC, PD.SKU, SUM( PD.QTY),Lottable02,lottable04,PD.LOT   ' +   
         ' FROM LoadPlanDetail LPD WITH (NOLOCK) ' +    
         ' JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' +
         ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
         ' JOIN LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
         CASE WHEN @cFilterLocType <> '' THEN ' JOIN @tLocationType t ON (LOC.LocationType = t.LocationType) ' 
              ELSE '' END +
         ' WHERE LPD.Loadkey = @cLoadKey ' +
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +   
         ' GROUP BY PD.LOC, PD.SKU,PD.LOT,Lottable02,lottable04  ' 

      IF @cPSType = 'XD'
         SET @cSQL =   
         ' SELECT PD.LOC, PD.SKU, SUM( PD.QTY),Lottable02,lottable04,PD.LOT   ' +   
         ' FROM Orders O WITH (NOLOCK) ' +    
         ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
         ' JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' +
         ' JOIN LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
         CASE WHEN @cFilterLocType <> '' THEN ' JOIN @tLocationType t ON (LOC.LocationType = t.LocationType) ' 
              ELSE '' END +
         ' WHERE RKL.PickslipNo = @cPickSlipNo ' +
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +   
         ' GROUP BY PD.LOC, PD.SKU,PD.LOT,Lottable02,lottable04  ' 

      IF @cPSType = 'CUSTOM'
         SET @cSQL =   
         ' SELECT PD.LOC, PD.SKU, SUM( PD.QTY),Lottable02,lottable04,PD.LOT    ' +   
         ' FROM Orders O WITH (NOLOCK) ' +    
         ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
         ' JOIN LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
         CASE WHEN @cFilterLocType <> '' THEN ' JOIN @tLocationType t ON (LOC.LocationType = t.LocationType) ' 
              ELSE '' END +
         ' WHERE PD.PickslipNo = @cPickSlipNo ' +
         ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < @cPickConfirmStatus) OR ' +
         '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
         ' AND   PD.QTY > 0 ' +
         ' AND   O.Status <> ''CANC'' ' +
         ' AND   O.SOStatus <> ''CANC''' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +   
         ' GROUP BY PD.LOC, PD.SKU,PD.LOT,Lottable02,lottable04  ' 

      -- Set loc type filter
      SET @cSQLFilterLocType =   
      ' IF @cFilterLocType <> ''''
         BEGIN
            DECLARE @tLocationType TABLE 
               ( [LocationType] NVARCHAR ( 10) NOT NULL PRIMARY KEY)

            INSERT INTO @tLocationType ( LocationType)
            SELECT Code FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = @cFilterLocType
            AND   Storerkey = @cStorerKey
            AND  (code2 = @nFunc OR code2 = '''')
            ORDER BY code2 DESC 
         END ' 
      -- Open cursor  
      SET @cSQL =   
         ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +   
            @cSQL +   
         ' OPEN @curPD '   

      SET @cSQL = @cSQLFilterLocType + @cSQL

      SET @cSQLParam = 
         '@curPD       CURSOR OUTPUT, ' + 
         '@nFunc       INT, '           + 
         '@cStorerKey  NVARCHAR( 15), ' +  
         '@cPickSlipNo NVARCHAR( 10), ' +  
         '@cOrderKey   NVARCHAR( 10), ' +  
         '@cLoadKey    NVARCHAR( 10), ' +  
         '@cPickZone   NVARCHAR( 10), ' + 
         '@cFilterLocType     NVARCHAR( 10), ' + 
         '@cPickConfirmStatus NVARCHAR( 1),' +
         '@cLOT        NVARCHAR(20)'

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @curPD OUTPUT, @nFunc, @cStorerKey, @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickZone, @cFilterLocType, @cPickConfirmStatus,@cLOT

      FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY,@cLottable02,@dLottable04,@cLOT
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get SKU info
         SELECT @cLottableCode = LottableCode FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
         
         SET @cSelect = ''
         
         -- Dynamic lottable
         IF @cLottableCode <> ''
            EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 4, @cLottableCode, 'LA', 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cSelect  OUTPUT,
               @cWhere1  OUTPUT,
               @cWhere2  OUTPUT,
               @cGroupBy OUTPUT,
               @cOrderBy OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT
            
         -- By lottables
         IF @cSelect <> ''
         BEGIN

            SET @cSQL = 
                ' INSERT INTO PTL.PTLTran ( ' + 
                  ' IPAddress, DeviceID, DevicePosition, Status, PTLType, ' + 
                  ' DeviceProfileLogKey, DropID, SourceKey, Storerkey, SKU, LOC, ExpectedQTY, QTY,LOT, ' + @cGroupBy + ') ' + 
              ' SELECT ' + 
                  ' @cIPAddress, @cCartID, @cPosition, ''0'', ''CART'', ' + 
                  ' @cDPLKey, '''', @cPickSlipNo, @cStorerKey, @cSKU, @cLOC, ISNULL( SUM( PD.QTY), 0), 0,@cLOT, ' + @cGroupBy + 
               CASE 
                  WHEN @cPSType = 'DISCRETE' THEN 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE O.OrderKey = @cOrderKey '
                  WHEN @cPSType = 'CONSO' THEN 
                     ' FROM LoadPlanDetail LPD WITH (NOLOCK) ' + 
                        ' JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE LPD.Loadkey = @cLoadKey '
                  WHEN @cPSType = 'XD' THEN 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                        ' JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE RKL.PickslipNo = @cPickSlipNo '
                  ELSE 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE PD.PickslipNo = @cPickSlipNo '
               END + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < ''4''' + 
                  ' AND ( ( @cPickConfirmStatus <> '''' AND PD.Status < ''5'') OR ' + 
                  '       ( @cPickConfirmStatus = '''' AND PD.Status < ''4'')) ' +
                  ' AND PD.QTY > 0' + 
                  ' AND PD.Lot = @cLot ' +
                  --CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +   
                  --CASE WHEN @cWhere2 = '' THEN '' ELSE ' = '   + @cWhere2 END +  
                  ' AND O.Status <> ''CANC''' + 
                  ' AND O.SOStatus <> ''CANC''' + 
               ' GROUP BY PD.LOT, ' + @cGroupBy + 
               ' ORDER BY ' + @cOrderBy 

            SET @cSQLParam = 
               '@cIPAddress  NVARCHAR( 40), ' + 
               '@cCartID     NVARCHAR( 10), ' + 
               '@cPosition   NVARCHAR( 10), ' + 
               '@cDPLKey     NVARCHAR( 10), ' + 
               '@cPickSlipNo NVARCHAR( 10), ' +  
               '@cOrderKey   NVARCHAR( 10), ' +  
               '@cLoadKey    NVARCHAR( 10), ' +  
               '@cLOC        NVARCHAR( 10), ' +  
               '@cStorerKey  NVARCHAR( 15), ' +  
               '@cSKU        NVARCHAR( 20), ' +
               '@cGroupBy    NVARCHAR( MAX), ' +
               '@cLottable01   NVARCHAR( 18),'+
               '@cLottable02   NVARCHAR( 18),'+
               '@cLottable03   NVARCHAR( 18),'+
               '@dLottable04   DATETIME     ,'+
               '@dLottable05   DATETIME     ,'+
               '@cLottable06   NVARCHAR( 30),'+
               '@cLottable07   NVARCHAR( 30),'+
               '@cLottable08   NVARCHAR( 30),'+
               '@cLottable09   NVARCHAR( 30),'+
               '@cLottable10   NVARCHAR( 30),'+
               '@cLottable11   NVARCHAR( 30),'+
               '@cLottable12   NVARCHAR( 30),'+
               '@dLottable13   DATETIME     ,'+
               '@dLottable14   DATETIME     ,'+
               '@dLottable15   DATETIME     ,'+
               '@cPickConfirmStatus NVARCHAR( 1), '+
               '@cLot          NVARCHAR( 20) '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @cIPAddress, @cCartID, @cPosition, @cDPLKey, @cPickSlipNo, @cOrderKey, @cLoadKey, @cLOC, @cStorerKey, @cSKU, @cGroupBy, @cPickConfirmStatus,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @dLottable05,
               @cLottable06,
               @cLottable07,
               @cLottable08,
               @cLottable09,
               @cLottable10,
               @cLottable11,
               @cLottable12,
               @dLottable13,
               @dLottable14,
               @dLottable15,
               @cLOT

         END
         ELSE
         BEGIN
            INSERT INTO PTL.PTLTran (
               IPAddress, DeviceID, DevicePosition, Status, PTLType, 
               DeviceProfileLogKey, DropID, SourceKey, Storerkey, SKU, LOC, ExpectedQTY, QTY)
            VALUES (
               @cIPAddress, @cCartID, @cPosition, '0', 'CART',
               @cDPLKey, '', @cPickSlipNo, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)
         END
      
         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 168214
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY,@cLottable02,@dLottable04,@cLOT
      END

      -- (james02)
      SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorerKey)  
      IF @cAutoScanIn = '1'
      BEGIN
         SET @cPickSlipNo2ScanIn = @cPickslipNo

         IF @cPSType = 'CUSTOM'
         BEGIN
            IF ISNULL( @cM_PickSlipNo, '') <> ''
               SET @cPickSlipNo2ScanIn = @cM_PickSlipNo
         END
            
         -- Insert PickingInfo
         IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo2ScanIn)
         BEGIN
            SELECT @cUserName = UserName
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            -- Scan in pickslip
            EXEC dbo.isp_ScanInPickslip
               @c_PickSlipNo  = @cPickSlipNo2ScanIn,
               @c_PickerID    = @cUserName,
               @n_err         = @nErrNo      OUTPUT,
               @c_errmsg      = @cErrMsg     OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 168215
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Fail scan-in
               GOTO RollBackTran
            END
         END
      END

      COMMIT TRAN rdt_PTLCart_Assign

      SET @nTotalTote = @nTotalTote + 1

      -- Prepare current screen var
      SET @cOutField03 = '' -- PickSlipNo
      SET @cOutField04 = '' -- Position
      SET @cOutField05 = '' -- ToteID
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote
      
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO