SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1650ExtUpd01                                    */
/* Purpose: If all Pallet ID for MBOL has been Scanned to Door.         */
/*	         Set LoadPlanLandDetail.Status = 9                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-04-21 1.0  James      SOS316783. Created                        */
/* 2015-05-08 1.1  James      Add Pallet Id rec rdtscantotruck (james01)*/
/* 2015-12-04 1.2  James      SOS316783 - Unhold pallet (james02)       */
/* 2015-12-18 1.3  James      Deadlock tuning (james03)                 */
/* 2017-04-07 1.4  James      Deadlock tuning (james04)                 */
/* 2024-05-09 1.5  NLT013     FCR-117 Auto ship on RDT                  */
/* 2024-10-22 1.6  JHU151     UWP-24991 WHen Cls Truck then             */
/*                                      Trigger LogiReport              */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1650ExtUpd01] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cPalletID        NVARCHAR( 20), 
   @cMbolKey         NVARCHAR( 10), 
   @cDoor            NVARCHAR( 20), 
   @cOption          NVARCHAR( 1),  
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
           @cSku              NVARCHAR( 20), 
           @cLot              NVARCHAR( 10), 
           @cFromLoc          NVARCHAR( 10), 
           @cMoveRefKey       NVARCHAR( 10), 
           @cID               NVARCHAR( 18), 
           @cMBOL4PltID       NVARCHAR( 10), 
           @nQty              INT, 
           @bSuccess          INT, 
           @cPickDetailKey    NVARCHAR( 10),     -- (james02),
           @cAutoShipMBOL     NVARCHAR( 10),
           @nKeyCount         INT = 0,
           @nWarningNo        INT = 0,
           @cUserName         NVARCHAR( 128)


   SELECT @cFacility = Facility,
      @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @cAutoShipMBOL = rdt.rdtGetConfig(@nFunc, 'AUTOSHIPMBOL', @cStorerKey)
   IF @cAutoShipMBOL = '0'
      SET @cAutoShipMBOL = ''

   SET @nStartTCnt = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1650ExtUpd01  
   

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2 
      BEGIN
         IF ISNULL( @cPalletID, '') = ''
         BEGIN
            SET @nErrNo = 53801   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PALLET ID REQ
            GOTO Quit
         END

         SELECT TOP 1 @cOrderKey = OrderKey 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ID = @cPalletID
         AND  [Status] < '9'

         -- Get the mbolkey for this particular pallet id
         SELECT @cMBOL4PltID = MbolKey, @cLoadKey = LoadKey  
         FROM dbo.MBOLDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.ID = @cPalletID
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

            -- (james04)
            DECLARE CUR_UPDMOVREF CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT DISTINCT PickDetailKey 
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE  ID = @cPalletID
            AND    StorerKey = @cStorerKey
            AND    SKU = @cSku
            AND    Status < '9'
            AND    ShipFlag <> 'Y'
            AND    LOT = @cLot
            AND    LOC = @cFromLoc
            OPEN CUR_UPDMOVREF 
            FETCH NEXT FROM CUR_UPDMOVREF INTO @cPickDetailKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                MoveRefKey = @cMoveRefKey
               ,EditWho    = SUSER_NAME()
               ,EditDate   = GETDATE()
               ,Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 53803   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCK PDTL FAIL 
                  CLOSE CUR_UPDMOVREF
                  DEALLOCATE CUR_UPDMOVREF
                  GOTO Quit
               END

               FETCH NEXT FROM CUR_UPDMOVREF INTO @cPickDetailKey
            END
            CLOSE CUR_UPDMOVREF
            DEALLOCATE CUR_UPDMOVREF

            --Update all SKU on pallet to new ASRS LOC
            EXEC nspItrnAddMove
                  NULL                                        
               , @cStorerKey              -- @c_StorerKey   
               , @cSku                    -- @c_Sku         
               , @cLot                    -- @c_Lot         
               , @cFromLoc                -- @c_FromLoc     
               , @cPalletID               -- @c_FromID      
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

            -- (james02)
            DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT PickDetailKey
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE MoveRefKey = @cMoveRefKey
            OPEN CUR_UPD
            FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
                   MoveRefKey = ''
                  ,EditWho    = SUSER_NAME()
                  ,EditDate   = GETDATE()
                  ,Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 53805   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --REL PDTL FAIL 
                  GOTO Quit
               END

               FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD

            FETCH NEXT FROM CUR_LOOP INTO @cStorerKey, @cSku, @cLot, @cFromLoc, @nQty
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP

         -- Add record into RDTScanToTruck (james01)
         IF NOT EXISTS ( SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK) 
                         WHERE MBOLKey = @cMBOL4PltID
                         AND   RefNo = @cPalletID
                         AND  [Status] = '9')
         BEGIN
            INSERT INTO RDT.RDTScanToTruck
                   (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate, Door)
            VALUES (@cMBOLKey, @cLoadKey, 'SCNPT2DOOR', @cPalletID, '', '9', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cDoor) 

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 53806
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsScn2TrkFail
               GOTO Quit
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cPalletID AND Status = 'HOLD')
         BEGIN
            UPDATE dbo.ID WITH (ROWLOCK) SET 
               [Status] = 'OK'
            WHERE ID = @cPalletID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 53808
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unhold id fail
               GOTO Quit
            END
         END

         GOTO Quit
      END

      IF @nStep = 3 
      BEGIN         
         IF @cOption = '1'
         BEGIN
            IF ISNULL( @cMbolKey, '') <> ''
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM MBOLDETAIL MD WITH (NOLOCK) 
                              JOIN rdt.rdtScanToTruck ST WITH (NOLOCK) ON ( MD.MBOLKey = ST.MBOLKey AND CartonType = 'SCNPT2DOOR')
                              WHERE MD.MBOLKey = @cMbolKey
                              AND   ST.Status < '9')
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

               IF @cAutoShipMBOL = '1'
               BEGIN
                  SET @nKeyCount        = 0
                  SET @nWarningNo       = 0

                  BEGIN TRY
                     EXEC [WM].[lsp_WaveShip] 
                        @c_WaveKey              = '',
                        @c_MBOLkey              = @cMbolKey,
                        @c_ShipMode             = 'MBOL',
                        @n_TotalSelectedKeys    = 1,
                        @c_ProceedWithWarning   = 'N',
                        @c_UserName             = @cUserName,
                        @n_KeyCount             = @nKeyCount            OUTPUT,
                        @b_Success              = @bSuccess             OUTPUT,
                        @n_err                  = @nErrNo               OUTPUT,
                        @c_ErrMsg               = @cErrMsg              OUTPUT,
                        @n_WarningNo            = @nWarningNo           OUTPUT
                  END TRY
                  BEGIN CATCH
                     SET @nErrNo = 53809
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AUTO SHIP FAIL
                     GOTO Quit
                  END CATCH
               END

               DECLARE
                  @cTriggerRptAPI NVARCHAR(10)
               SET @cTriggerRptAPI = rdt.rdtGetConfig(@nFunc, 'TriggerRptAPI', @cStorerKey)
               IF @cTriggerRptAPI = '0'
                  SET @cTriggerRptAPI = ''

               IF @cTriggerRptAPI = '1'
               BEGIN
                  DECLARE 
                        @c_ResponseString NVARCHAR(MAX), 
                        @c_vbHttpStatusCode NVARCHAR(10), 
                        @c_vbHttpStatusDesc NVARCHAR(100);
                  DECLARE 
                        @c_doc1 NVARCHAR(MAX),
                        @c_vbErrMsg  NVARCHAR(MAX),
                        @c_PDFFileName_Courier NVARCHAR(MAX),
                        @b_Debug int = 1
                  DECLARE
                        @ctriggerName     NVARCHAR(30),
                        @cReportName      NVARCHAR(30),
                        @cFileFolder	   NVARCHAR(200),
                        @cWebRequestURL   NVARCHAR(4000)

                  SELECT
                     @ctriggerName = parm1_label,
                     @cReportName = JReportFileName,
                     @cFileFolder = FileFolder,
                     @cWebRequestURL = PrintSettings
                  FROM RDT.rdtReportDetail WITH(NOLOCK)
                  WHERE storerkey = @cStorerkey
                  AND ReportType = 'CLSTRUCK'

                  SET @c_doc1 = '{    "triggerName":"' + @ctriggerName + '",'
                  SET @c_doc1 = @c_doc1 + '    "storerKey":"' + @cStorerKey + '",'
                  SET @c_doc1 = @c_doc1 + '    "reportName":"' + @cReportName + '",'
                  SET @c_doc1 = @c_doc1 + '    "parameters":{        "PARAM_WMS_c_ReceiptKey":"'+ @cMbolKey + '"    }'
                  SET @c_doc1 = @c_doc1 + '}'
                  

                  --SET @cFileFolder = N'E:\COMObject\GenericWebServiceClient\WSconfig.ini'
                  --SET @cWebRequestURL = N'https://172.16.64.7:443/logi_trigger.jsp'
                  EXEC master.dbo.isp_GenericWebServiceClientV5 
                        @c_IniFilePath = @cFileFolder,
                        @c_WebRequestURL = @cWebRequestURL,
                        @c_WebRequestMethod = N'POST', -- nvarchar(10)
                        @c_ContentType = N'application/json', -- nvarchar(100)
                        @c_WebRequestEncoding = N'UTF-8', -- nvarchar(30)
                        @c_RequestString = @c_doc1,
                        @c_ResponseString = @c_ResponseString OUTPUT, -- nvarchar(max)
                        @c_vbErrMsg = @c_vbErrMsg OUTPUT, -- nvarchar(max)
                        @n_WebRequestTimeout = 0, -- int
                        @c_NetworkCredentialUserName = N'', -- nvarchar(100)
                        @c_NetworkCredentialPassword = N'', -- nvarchar(100)
                        @b_IsSoapRequest = 0, -- bit
                        @c_RequestHeaderSoapAction = N'', -- nvarchar(100)
                        @c_HeaderAuthorization = N'', -- nvarchar(4000)
                        @c_ProxyByPass = N'1', -- nvarchar(1)
                        @c_WebRequestHeaders = 'ClientSystem:RDT', -- Folder:Z:\GBR\DTSToExceed\nikecn01-chn-cdt|FileName:WMS_TESTING.pdf
                        @c_vbHttpStatusCode = @c_vbHttpStatusCode OUTPUT, -- nvarchar(10)
                        @c_vbHttpStatusDesc = @c_vbHttpStatusDesc OUTPUT -- nvarchar(100)            
               END  
            END
         END         
      END
   END
   GOTO Quit

   Quit:
   IF ISNULL( @nErrNo, 0) <> 0  -- Error Occured - Process And Return  
      ROLLBACK TRAN rdt_1650ExtUpd01  
  
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started  
      COMMIT TRAN rdt_1650ExtUpd01


GO