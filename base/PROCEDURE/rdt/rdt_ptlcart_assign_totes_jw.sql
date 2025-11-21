SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_Totes_JW                               */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2016-08-09 1.0  James    SOS370883 Created                                 */
/* 2017-11-17 1.1  James    Orders with tm task released only can assign to   */
/*                          cart for picking (james01)                        */
/* 2018-01-26 1.2  Ung      Change to PTL.Schema                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_Totes_JW] (
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

   DECLARE @nTranCount  INT
   DECLARE @nTotalTote  INT
   DECLARE @bSuccess    INT

   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cLoadKey    NVARCHAR(10)
   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)

   DECLARE @cChkFacility  NVARCHAR(5)
   DECLARE @cChkStorerKey NVARCHAR(15)
   DECLARE @cChkStatus    NVARCHAR(10)
   DECLARE @cChkSOStatus  NVARCHAR(10)
   DECLARE @cCartCapacity NVARCHAR(5) 
   DECLARE @cOrders4Tote  NVARCHAR(10) 
   DECLARE @cDropIDType   NVARCHAR(10)
   DECLARE @nReleaseTote  INT 

   DECLARE @cErrMsg1      NVARCHAR( 20), 
           @cErrMsg2      NVARCHAR( 20), 
           @cErrMsg3      NVARCHAR( 20), 
           @cErrMsg4      NVARCHAR( 20), 
           @cErrMsg5      NVARCHAR( 20),
           @cErrMsg6      NVARCHAR( 20), 
           @cErrMsg7      NVARCHAR( 20) 

   DECLARE @cExtendedValidateSP NVARCHAR( 20),    
           @cCustomSQL          NVARCHAR( MAX),
           @cStartSQL           NVARCHAR( MAX),
           @cExcludeSQL         NVARCHAR( MAX),
           @cEndSQL             NVARCHAR( MAX),
           @cExecStatements     NVARCHAR( MAX),
           @cExecArguments      NVARCHAR( MAX)
           

   DECLARE @cInit_Final_Zone  NVARCHAR( 10)
   DECLARE @cFinalWCSZone     NVARCHAR( 10)
   DECLARE @cWCSKey           NVARCHAR( 10)
   DECLARE @cCurrPutawayzone  NVARCHAR( 10)
   DECLARE @cPPAZone          NVARCHAR( 10)
   DECLARE @cUserName         NVARCHAR( 18)
   DECLARE @cPicked_OrderKey  NVARCHAR( 10)
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
           
   SET @nTranCount = @@TRANCOUNT

   SET @nReleaseTote = 0
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total tote
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = @cMethod
		SET @cOutField04 = @cPickSeq
		SET @cOutField05 = '' -- ToteID
		SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))

	   EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID

		-- Go to totes screen
		SET @nScn = 4188
   END
      
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cToteID = @cInField05

      -- Get total tote
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Check finish assign
      IF @nTotalTote > 0 AND @cToteID = ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCartID   -- CartID
         SET @cOutField02 = @cPickZone -- PickZone
         SET @cOutField03 = @cMethod   -- Method
         SET @cOutField04 = @cPickSeq  -- Pick Seq
         SET @cOutField05 = CAST( @nTotalTote AS NVARCHAR(5))

         -- Exit
         SET @nErrNo = 0  

         GOTO Quit
      END

      -- Check blank tote
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 103001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cToteID) = 0
      BEGIN
         SET @nErrNo = 103002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
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
         SET @nErrNo = 103003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      
      -- Get position not yet assign
      SET @cPosition = ''
      SELECT TOP 1
         @cPosition = DP.DevicePosition
      FROM dbo.DeviceProfile DP WITH (NOLOCK)
      WHERE DP.DeviceType = 'CART'
         AND DP.DeviceID = @cCartID
         AND NOT EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND PCLog.Position = DP.DevicePosition)
      ORDER BY DP.DevicePosition
      
      -- Check position blank
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 103004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check if it is a PA tote/case  
      IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK)  
                 WHERE StorerKey = @cStorerKey  
                 AND   TaskType = 'PA'  
                 AND   Status IN ('0', '3', 'W')  
                 AND   CaseID = @cToteID)  
      BEGIN  
         SET @nErrNo = 103005  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PutAway Tote  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END  

      -- Check if tote is still in use by DPK/PTS
      IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   CASEID = @cToteID
                  AND   [Status] IN ('0', '3', '4'))
      BEGIN  
         SET @nErrNo = 103006  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DPK/PTS Tote  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END  

      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                  WHERE DropID = @cToteID 
                  And   Status < '9' 
                  AND   UDF02 <> 'CARTPICK')     -- Exclude cart picking tote. will check after this
      BEGIN  
         -- Check if every orders inside tote is canc. If exists 1 orders is open/in progress/picked then not allow   
         IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)  
                    JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey  
                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
                    WHERE TD.DropID = @cToteID  
                    AND   O.STATUS NOT IN ('9', 'CANC')  
                    AND   O.StorerKey = @cStorerKey)  
         BEGIN  
            SET @nErrNo = 103007  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
            SET @cOutField05 = ''
            GOTO Quit
         END  
         ELSE  
         BEGIN  
            -- If every orders in tote is shipped/canc then update them to '9' and release it 
            SET @nReleaseTote = 1
         END  
      END  

      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                  WHERE DropID = @cToteID 
                  And   Status NOT IN ('9','X','3') )  
      BEGIN  
         SET @nErrNo = 103008  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END  

      SET @cPicked_OrderKey = ''
      SET @cOrderKey = ''

      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                  WHERE DropID = @cToteID 
                  AND   UDF02 = 'CARTPICK')
      BEGIN  
         -- Check if every orders inside tote is canc. If exists 1 orders is open/in progress/picked then not allow   
         IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)  
                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
                    WHERE PD.DropID = @cToteID  
                    AND   O.STATUS NOT IN ('9', 'CANC')  
                    AND   O.StorerKey = @cStorerKey)  
         BEGIN  
            -- Get orderkey for the tote
            SELECT @cPicked_OrderKey = PD.OrderKey
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
            WHERE PD.DropID = @cToteID 
            AND   O.STATUS NOT IN ('9', 'CANC')  
            AND   O.StorerKey = @cStorerKey

            -- No other open task for the same orders then cannot reuse the tote until orders is shipped
            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   OrderKey = @cPicked_OrderKey
                            AND   Status = '0'
                            AND   ISNULL( DropID, '') = '')
            BEGIN  
               SET @nErrNo = 103016   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used
               EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
               SET @cOutField05 = ''
               GOTO Quit
            END  
            ELSE
               -- If tote still have pick task for the same orders
               SET @cOrderKey = @cPicked_OrderKey
         END  
      END

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

      /*
      CODE = æ1Æ, DESCRIPTION = æEcomm MultisÆ, SHORT = æ1Æ
    	CODE = æ2Æ, DESCRIPTION = æEcomm SinglesÆ, SHORT = æ2Æ
    	CODE = æ3Æ, DESCRIPTION = æAll EcommÆ, SHORT = æ3Æ
    	CODE = æ4Æ, DESCRIPTION = æStore SinglesÆ, SHORT = æ4Æ
    	CODE = æ5Æ, DESCRIPTION = æStore Singles and Ecomm MultisÆ, SHORT = 		æ5Æ
    	CODE = æ6Æ, DESCRIPTION = æAll SinglesÆ, SHORT = æ6Æ
    	CODE = æ7Æ, DESCRIPTION = æAll Singles and Ecomm MultisÆ, SHORT = æ7Æ
    	
    	Only select orders that 
    	1. can be fully picked in 1 trolley zone
    	2. not partially picked before
    	3. cancel task for orders if not start yet
      */

      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         IF OBJECT_ID('tempdb..#t_orderkey') IS NOT NULL
            DROP TABLE #t_orderkey

         CREATE TABLE #t_orderkey (OrderKey NVARCHAR( 10), TZone NVARCHAR( 10))

         -- Get Orderkey
         SET @cStartSQL = 
         ' INSERT INTO #t_orderkey (OrderKey, TZone)' + 
         ' SELECT O.OrderKey, ISNULL( CLK.Long, '''') ' + 
         ' FROM dbo.Orders O WITH (NOLOCK) ' + 
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey) ' + 
         ' JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC) ' + 
         ' JOIN dbo.CodeLkUp CLK WITH (NOLOCK) ON ( LOC.PickZone = CLK.Code AND O.StorerKey = CLK.StorerKey) ' + 
         ' WHERE O.StorerKey = @cStorerKey ' + 
         ' AND   O.Status IN (''1'', ''2'') ' + -- Only select orders that not yet start picking, either partial or fully alloc
         ' AND   PD.Status = ''0'' ' + 
         ' AND   PD.TaskDetailKey <> '''' ' +          -- orders must allocated & tm task released (james01)
         ' AND   CLK.ListName = ''WCSSTATION'' ' +
         ' AND   ISNULL( CLK.Long, '''') <> '''' ' +
--         ' AND   LOC.LocationCategory = ''PPA'' ' +
         ' AND   LOC.LocationType = ''PICK'' ' +
         ' AND   LOC.Facility = @cFacility ' 

         -- Must exclude those assign orders
         SET @cExcludeSQL = 
         ' AND   NOT EXISTS ( SELECT 1 FROM rdt.rdtPTLCartLog PTL WITH (NOLOCK) ' +
         '                    WHERE O.OrderKey = PTL.OrderKey ' +
         '                    AND   O.StorerKey = PTL.StorerKey) ' 
         
         -- Exclude those orders which already has task and pick in progress
         SET @cExcludeSQL = @cExcludeSQL + 
         ' AND   NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK) ' +
         '                    WHERE PD.TaskDetailKey = TD.TaskDetailKey ' +
         '                    AND   TD.Status > ''0'') '           

         IF @cPickSeq IN ( '1', '2', '3')
         BEGIN
            IF @cPickSeq = '1'
               SET @cCustomSQL = ' AND   USERDEFINE01 LIKE ''MULTI%'' '

            IF @cPickSeq = '2'
               SET @cCustomSQL = ' AND   USERDEFINE01 LIKE ''SINGLE%'' '

            IF @cPickSeq = '3'
               SET @cCustomSQL = ' AND   USERDEFINE01 <> '''' '

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, '''') '
         END

         IF @cPickSeq = '4'   -- STORE SINGLES
         BEGIN
            SET @cCustomSQL = ' AND   O.Type LIKE ''STORE%'' '

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, '''') ' +
            ' HAVING ISNULL( SUM( PD.QTY), 0) = 1 '
         END

         IF @cPickSeq = '5'   -- STORE SINGLES & ECOMM MULTIS
         BEGIN
            SET @cCustomSQL = ' ' 

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, ''''), O.Type, USERDEFINE01 ' +
            ' HAVING ( O.Type LIKE ''STORE%'' AND ISNULL( SUM( PD.QTY), 0) = 1) OR ' + 
            '        USERDEFINE01 LIKE ''MULTI%'' '
         END

         IF @cPickSeq = '6'   -- ALL SINGLES
         BEGIN
            SET @cCustomSQL = ' ' 

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, '''') ' +
            ' HAVING ISNULL( SUM( PD.QTY), 0) = 1 '
         END

         IF @cPickSeq = '7'   -- ALL SINGLES & ECOMM MULTIS
         BEGIN
            SET @cCustomSQL = ' ' 

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, ''''), USERDEFINE01 ' +
            ' HAVING ISNULL( SUM( PD.QTY), 0) = 1 OR ' +
            '        USERDEFINE01 LIKE ''MULTI%'' '
         END
      END

      SET @cExecStatements = @cStartSQL + @cCustomSQL + @cExcludeSQL + @cEndSQL

      SET @cExecArguments =  N'@cStorerKey            NVARCHAR(15), ' +
                              '@cFacility             NVARCHAR(5)   '                               

      EXEC sp_ExecuteSql @cExecStatements
                        ,@cExecArguments
                        ,@cStorerKey
                        ,@cFacility

      IF OBJECT_ID('tempdb..#t_orderkey1') IS NOT NULL
         DROP TABLE #t_orderkey1

      CREATE TABLE #t_orderkey1 (OrderKey NVARCHAR( 10))

      INSERT INTO #t_orderkey1 (OrderKey)
      SELECT T.OrderKey   
      FROM #t_orderkey T
      JOIN dbo.Pickdetail PD WITH (NOLOCK) ON T.OrderKey = PD.OrderKey
      JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      GROUP BY T.OrderKey
      -- Only select orders that can be fulfilled by 1 trolley zone only
      HAVING COUNT( DISTINCT T.TZone) = 1


      SELECT TOP 1 @cOrderKey = T1.OrderKey
      FROM #t_orderkey1 T1
      JOIN PICKDETAIL PD (NOLOCK) ON T1.ORDERKEY = PD.ORDERKEY
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.LOC
      JOIN CODELKUP CLK (NOLOCK) ON ( LOC.PICKZONE = CLK.CODE  AND O.StorerKey = CLK.StorerKey)
      WHERE ISNULL( CLK.LONG, '') = @cPickZone
      AND   CLK.LISTNAME = 'WCSSTATION'
      AND   O.StorerKey = @cStorerKey
      GROUP BY LOC.LogicalLocation, LOC.LOC, O.Priority, T1.OrderKey 
      ORDER BY LOC.LogicalLocation, LOC.LOC, O.Priority, T1.OrderKey 

      -- If no orderkey found
      IF ISNULL( @cOrderKey, '') = '' 
      BEGIN
         -- If cart already assigned tote, prompt no more orders to pick
         IF EXISTS ( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
                     WHERE CartID = @cCartID
                     AND   StorerKey = @cStorerKey)
         BEGIN
            /*
            -- Prepare next screen var
            SET @cOutField01 = @cCartID   -- CartID
            SET @cOutField02 = @cPickZone -- PickZone
            SET @cOutField03 = @cMethod   -- Method
            SET @cOutField04 = @cPickSeq  -- Pick Seq
            SET @cOutField05 = CAST( @nTotalTote AS NVARCHAR(5))
            
            -- Exit
            SET @nErrNo = 0       
            */
            SET @nErrNo = 103009
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No More Orders
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
            SET @cOutField05 = ''
            GOTO Quit
         END

         SET @nErrNo = 0
         SET @cErrMsg1 = 'CART ID: ' + @cCartID
         SET @cErrMsg2 = 'PICKZONE: ' + @cPickZone
         SET @cErrMsg3 = 'METHOD: ' + @cMethod
         SET @cErrMsg4 = 'PICK SEQ: ' + @cPickSeq
         SET @cErrMsg5 = ''
         SET @cErrMsg6 = 'NO OUTSTANDING PICKS'
         SET @cErrMsg7 = 'FOR THIS CART ZONE.'

         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, @cErrMsg6, @cErrMsg7

         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            SET @cErrMsg6 = ''
            SET @cErrMsg7 = ''
         END
         
         GOTO Quit
      END

      BEGIN TRAN
      SAVE TRAN rdt_PTLCart_Assign_Totes_JW

      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  AND   ISNULL( TaskDetailKey, '') <> '')
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT DISTINCT TaskDetailKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   ISNULL( TaskDetailKey, '') <> ''
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cTaskDetailKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE TaskDetail WITH (ROWLOCK) SET 
               Status = '9', 
               StatusMsg = 'Cancelled by cart picking', 
               TrafficCop = NULL
            WHERE TaskDetailKey = @cTaskDetailKey
            AND   Status = '0'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 103017
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cancel Task Fail
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_LOOP INTO @cTaskDetailKey
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END

      SELECT @cLoadKey = LoadKey, 
             @cDropIDType = CASE WHEN ISNULL( UserDefine01, '') = '' THEN 'PIECE' ELSE UserDefine01 END
      FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey

      SELECT @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE ExternOrderKey = @cLoadkey
      AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END
      
      -- Save assign
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, OrderKey, StorerKey)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cOrderKey, @cStorerKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 103010
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Fail
         GOTO RollBackTran
      END

      -- Insert required pickzone
      CREATE TABLE #t_pickzone(
         PickZone       NVARCHAR(10))

      INSERT INTO #t_pickzone (PickZone)
      SELECT CODE FROM dbo.CodelkUp WITH (NOLOCK)
      WHERE ListName = 'WCSSTATION'
      AND   Long = @cPickZone

      -- Insert PTLTran
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
      FROM Orders O WITH (NOLOCK) 
      JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      WHERE O.OrderKey = @cOrderKey
      AND   PD.Status < '4'
      AND   PD.QTY > 0
      AND   O.Status <> 'CANC' 
      AND   O.SOStatus <> 'CANC'
      GROUP BY LOC.LOC, PD.SKU
      
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         INSERT INTO PTL.PTLTran (
            IPAddress, DeviceID, DevicePosition, Status, PTLType, 
            DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY)
         VALUES (
            @cIPAddress, @cCartID, @cPosition, '0', 'CART',
            @cDPLKey, '', @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)
   
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 103011
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      END

      -- Check if tote is from cart picking and already unassign
      -- Then need release tote as well
      IF @nReleaseTote = 0
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cToteID
                     AND   UDF02 = 'CARTPICK') 
         BEGIN
            IF NOT EXISTS ( SELECT 1 
                            FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
                            WHERE @cCartID = 'CART2'
                            AND   DeviceProfileLogKey = @cDPLKey
                            AND   ToteID = @cToteID
                            AND   StorerKey = @cStorerKey)
            BEGIN
               -- 1 tote for 1 orders for cart picking
               SELECT TOP 1 @cOrders4Tote = OrderKey
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   DropID = @cToteID
               AND   Status < '9'
               AND   Qty > 0 

               -- Check if this orders has something not picked
               IF NOT EXISTS ( SELECT 1 FROM PickDetail WITH (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND   OrderKey = @cOrders4Tote
                               AND   Status < '9'
                               AND   Qty > 0
                               AND   ISNULL( DropID, '') = '')
               BEGIN
                  SET @nReleaseTote = 1
               END
            END
         END
      END

      -- Release used tote
      IF @nReleaseTote = 1
      BEGIN  
         UPDATE dbo.DropID WITH (ROWLOCK) SET  
            Status = '9'  
         WHERE DropID = @cToteID  
         AND   Status < '9'  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 103012  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetToteFail  
            GOTO RollBackTran  
         END  
      END

      IF EXISTS ( SELECT 1 From dbo.DropID WITH (NOLOCK) 
                  Where DropID = @cToteID 
                  And   Status = '9' )  
      BEGIN  
         DELETE FROM dbo.DROPIDDETAIL  
         WHERE DropID = @cToteID  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 103013
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetToteFail  
            GOTO RollBackTran  
         END  
  
         DELETE FROM dbo.DROPID  
         WHERE DropID = @cToteID  
         AND   Status = '9'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 103014
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetToteFail  
            GOTO RollBackTran  
         END  
      END  

      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteID )  
      BEGIN  
         INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo, UDF01, UDF02 )  
         VALUES (@cToteID , '' , @cDropIDType , '0' , @cLoadkey, @cPickSlipNo, @cOrderKey, 'CARTPICK')  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 103015
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
            GOTO RollBackTran  
         END  
      END

      --COMMIT TRAN rdt_PTLCart_Assign_Totes_JW

      SET @nTotalTote = @nTotalTote + 1

      -- Get cart capacity
      SELECT @cCartCapacity = Short
      FROM dbo.CodeLkUp WITH (NOLOCK) 
      WHERE ListName = 'CART'
      AND   Code = @cCartID
      AND   StorerKey = @cStorerKey

      -- Still can assign tote, go ahead
      IF @nTotalTote < CAST( @cCartCapacity AS INT)
      BEGIN
         -- Prepare current screen var
         SET @cOutField05 = '' -- ToteID
         SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))
         
         -- Stay in current page
         SET @nErrNo = -1 
      END
      ELSE  -- Reach cart capacity, start picking
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCartID   -- CartID
         SET @cOutField02 = @cPickZone -- PickZone
         SET @cOutField03 = @cMethod   -- Method
         SET @cOutField04 = @cPickSeq  -- Pick Seq
         SET @cOutField05 = CAST( @nTotalTote AS NVARCHAR(5))
         
         -- Exit
         SET @nErrNo = 0       
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_Totes_JW
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO