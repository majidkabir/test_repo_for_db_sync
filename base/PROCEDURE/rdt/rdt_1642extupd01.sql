SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1642ExtUpd01                                    */  
/* Purpose: If all DropID for MBOL has been Scanned to Door.            */  
/*          Set LoadPlanLandDetail.Status = 9                           */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-04-21 1.0  James      SOS316783. Created                        */  
/* 2015-05-08 1.0  James      Add Drop Id rec rdtscantotruck (james01)  */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1642ExtUpd01] (  
   @nMobile          INT,   
   @nFunc            INT,   
   @nStep            INT,   
   @nInputKey        INT,   
   @cLangCode        NVARCHAR( 3),    
   @cDropID          NVARCHAR( 20),   
   @cMbolKey         NVARCHAR( 10),   
   @cDoor            NVARCHAR( 20),   
   @cOption          NVARCHAR( 1),    
   @cRSNCode         NVARCHAR( 10),   
   @nAfterStep       INT,   
   @nErrNo           INT           OUTPUT,   
   @cErrMsg          NVARCHAR( 20) OUTPUT    
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
   DECLARE @nStartTCnt        INT,   
           @cLoadkey          NVARCHAR( 10),  
           @cExternOrderKey   NVARCHAR( 20),   
           @cConsigneeKey     NVARCHAR( 15),    
           @cLP_LaneNumber    NVARCHAR( 5),   
           @cOrderkey         NVARCHAR( 10),   
           @cFacility         NVARCHAR( 5),   
           @cStorerKey        NVARCHAR( 15),   
           @cSku              NVARCHAR( 20),   
           @cLot              NVARCHAR( 10),   
           @cFromLoc          NVARCHAR( 10),   
           @cMoveRefKey       NVARCHAR( 10),   
           @cID               NVARCHAR( 18),   
           @cMBOL4DropID      NVARCHAR( 10),   
           @nQty              INT,   
           @bSuccess          INT   
  
  
   SELECT @cFacility = Facility, @cStorerKey = StorerKey FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile  
  
   SET @nStartTCnt = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_1642ExtUpd01    
     
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 2   
      BEGIN  
         IF ISNULL( @cDropID, '') = ''  
         BEGIN  
            SET @nErrNo = 53801     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROPID REQ  
            GOTO Quit  
         END  
  
         SELECT TOP 1 @cOrderKey = OrderKey   
         FROM dbo.PickDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND   DropID = @cDropID  
         AND   [Status] < '9'  
  
         -- Get the mbolkey for this particular dropid  
         SELECT @cMBOL4DropID = MbolKey, @cLoadKey = LoadKey    
         FROM dbo.MBOLDetail WITH (NOLOCK)   
         WHERE OrderKey = @cOrderKey  
  
         SET @cID = ''  
         DECLARE CUR_INSDD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT DISTINCT ID FROM dbo.PickDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND   DropID = @cDropID  
         AND   [Status] < '9'  
         ORDER BY 1  
         OPEN CUR_INSDD  
         FETCH NEXT FROM CUR_INSDD INTO @cID   
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF NOT EXISTS ( SELECT 1   
                              FROM dbo.DropIDDetail WITH (NOLOCK)   
                              WHERE DropID = @cDropID   
                              AND   ChildId = @cID)  
            BEGIN  
               INSERT INTO DropIDDetail   
               ( DropID, ChildId, UserDefine01) VALUES   
               ( @cDropID, @cID, @cMBOL4DropID)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 53806     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Lane Err  
                  CLOSE CUR_INSDD  
                  DEALLOCATE CUR_INSDD  
                  GOTO Quit  
               END  
            END  
  
            FETCH NEXT FROM CUR_INSDD INTO @cID   
         END  
         CLOSE CUR_INSDD  
         DEALLOCATE CUR_INSDD  
  
         SET @cID = ''  
         SELECT @cID = ID FROM dbo.PICKDETAIL WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey   
         AND   DropID = @cDropID   
         AND   [Status] = '5'  
  
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty  
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
         WHERE LLI.ID = @cID  
         AND   LLI.Qty > 0  
         AND   LOC.Facility = @cFacility  
  
         OPEN CUR_LOOP  
         FETCH NEXT FROM CUR_LOOP INTO @cStorerKey, @cSku, @cLot, @cFromLoc, @nQty  
         WHILE @@FETCH_STATUS <> -1   
         BEGIN  
            SET @cMoveRefKey = ''  
            SET @bSuccess = 1      
            EXECUTE   nspg_getkey      
                     'MoveRefKey'      
                     , 10      
                     , @cMoveRefKey       OUTPUT      
                     , @bSuccess          OUTPUT      
                     , @nErrNo            OUTPUT      
                     , @cErrMsg           OUTPUT   
  
            IF NOT @bSuccess = 1      
            BEGIN      
               SET @nErrNo = 53802     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get RFKey Fail   
               GOTO Quit  
            END   
  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                MoveRefKey = @cMoveRefKey  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE ID = @cID  
            AND StorerKey = @cStorerKey  
            AND SKU = @cSku  
            AND Status < '9'  
            AND ShipFlag <> 'Y'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 53803     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCK PDTL FAIL   
               GOTO Quit  
            END  
  
            --Update all SKU on pallet to new ASRS LOC  
            EXEC nspItrnAddMove  
                  NULL                                          
               , @cStorerKey              -- @c_StorerKey     
               , @cSku                    -- @c_Sku           
               , @cLot                    -- @c_Lot           
               , @cFromLoc                -- @c_FromLoc       
               , @cID                     -- @c_FromID        
               , @cFromLoc                -- @c_ToLoc         
               , 'CLEAR'                  -- @c_ToID ( Set 'CLEAR' to lose id)  
               , '0'                      -- @c_Status        
               , ''                       -- @c_lottable01    
               , ''                       -- @c_lottable02    
               , ''                       -- @c_lottable03    
               , NULL                     -- @d_lottable04    
               , NULL                     -- @d_lottable05    
               , ''                       -- @c_lottable06    
               , ''                       -- @c_lottable07    
               , ''                       -- @c_lottable08    
               , ''                       -- @c_lottable09    
               , ''                       -- @c_lottable10    
               , ''                       -- @c_lottable11    
               , ''                       -- @c_lottable12    
               , NULL                     -- @d_lottable13    
               , NULL                     -- @d_lottable14    
               , NULL                     -- @d_lottable15    
               , 0                        -- @n_casecnt       
               , 0                        -- @n_innerpack     
               , @nQty                    -- @n_qty           
               , 0                        -- @n_pallet        
               , 0                        -- @f_cube          
               , 0                        -- @f_grosswgt      
               , 0                        -- @f_netwgt        
               , 0                        -- @f_otherunit1    
               , 0                        -- @f_otherunit2    
               , ''                       -- @c_SourceKey     
               , ''                       -- @c_SourceType    
               , ''                       -- @c_PackKey       
               , ''                       -- @c_UOM           
               , 0                        -- @b_UOMCalc       
               , NULL                     -- @d_EffectiveD    
               , ''                       -- @c_itrnkey       
               , @bSuccess   OUTPUT       -- @b_Success     
               , @nErrNo     OUTPUT       -- @n_err         
               , @cErrMsg    OUTPUT       -- @c_errmsg      
               , @cMoveRefKey             -- @c_MoveRefKey       
                                                                    
            IF @@ERROR <> 0 OR RTRIM(@cErrMsg) <> ''  
            BEGIN  
               SET @nErrNo = 53804     
               SET @cErrMsg = @cErrMsg--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lose ID Fail   
               GOTO Quit  
            END  
  
            UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET   
                MoveRefKey = ''  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE MoveRefKey = @cMoveRefKey  
  
            IF @@ERROR <> 0   
            BEGIN  
               SET @nErrNo = 53805     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --REL PDTL FAIL   
               GOTO Quit  
            END  
  
            FETCH NEXT FROM CUR_LOOP INTO @cStorerKey, @cSku, @cLot, @cFromLoc, @nQty  
         END  
         CLOSE CUR_LOOP  
         DEALLOCATE CUR_LOOP  
  
         -- Add record into RDTScanToTruck (james01)  
         IF NOT EXISTS ( SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)   
                         WHERE MBOLKey = @cMBOL4DropID  
                         AND   RefNo = @cDropID  
                         AND  [Status] = '9')  
         BEGIN  
            INSERT INTO RDT.RDTScanToTruck  
                   (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate)  
            VALUES (@cMBOLKey, @cLoadKey, '', @cDropID, '', '9', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())   
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 53808  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsScn2TrkFail  
               GOTO Quit  
            END  
         END  
  
         GOTO Quit  
      END  
  
      IF @nStep = 5   
      BEGIN  
         IF ISNULL( @cMbolKey, '') <> ''  
         BEGIN  
            IF OBJECT_ID('tempdb..#TMP_DropID') IS NOT NULL     
               DROP TABLE #TMP_DropID  
  
            CREATE TABLE #TMP_DropID ( DROPID NVARCHAR(20) NULL DEFAULT (''))    
  
            INSERT INTO #TMP_DropID ( DROPID)  
            SELECT DISTINCT PD.DropID   
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
            WHERE OD.MbolKey = @cMbolKey  
  
            IF NOT EXISTS ( SELECT 1 FROM #TMP_DropID tmp WITH (NOLOCK)   
                            JOIN dbo.DropID D WITH (NOLOCK) ON ( tmp.DropID = D.DropID)  
                            WHERE [Status] < '9')  
            BEGIN  
               DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
               SELECT DISTINCT LoadKey  
               FROM dbo.MbolDetail MD WITH (NOLOCK)   
               JOIN dbo.Mbol M WITH (NOLOCK) ON MD.MbolKey = M.MbolKey  
               WHERE M.MbolKey = @cMbolKey  
               AND   M.Status < '9'  
               OPEN CUR_LOOP  
               FETCH NEXT FROM CUR_LOOP INTO @cLoadkey  
               WHILE @@FETCH_STATUS <> -1   
               BEGIN  
                  UPDATE dbo.LoadPlanLaneDetail WITH (ROWLOCK) SET   
                     [Status] = '9'  
                  WHERE Loadkey = @cLoadkey   
                  AND  [Status] < '9'  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 53807     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Lane Err  
                     CLOSE CUR_LOOP  
                     DEALLOCATE CUR_LOOP  
                     GOTO Quit  
                  END  
  
                  FETCH NEXT FROM CUR_LOOP INTO @cLoadkey  
               END  
               CLOSE CUR_LOOP  
               DEALLOCATE CUR_LOOP  
            END  
         END  
      END  
   END  
   GOTO Quit  
  
   Quit:  
   IF ISNULL( @nErrNo, 0) <> 0  -- Error Occured - Process And Return    
      ROLLBACK TRAN rdt_1642ExtUpd01    
    
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started    
      COMMIT TRAN rdt_1642ExtUpd01  


GO