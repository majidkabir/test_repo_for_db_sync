SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtUpd03                                    */
/* Purpose: Lose id after pallet scan to container                      */
/*                                                                      */
/* Called from: rdtfnc_Scan_To_Container                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-06-20 1.0  James      WMS5460 Created                           */  
/************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtUpd03] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 18), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT,
           @bSuccess       INT, 
           @cFacility      NVARCHAR( 5),
           @cMBOL4PltID    NVARCHAR( 10), 
           @cPickDetailKey NVARCHAR( 10), 
           @cSku           NVARCHAR( 20), 
           @cLot           NVARCHAR( 10), 
           @cFromLoc       NVARCHAR( 10), 
           @cMoveRefKey    NVARCHAR( 10), 
           @cOrderKey      NVARCHAR( 10), 
           @cLoadKey       NVARCHAR( 10),
           @nQty           INT

   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         IF ISNULL( @cPalletKey, '') = ''
         BEGIN
            SET @nErrNo = 125501   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PALLET ID REQ
            GOTO Quit
         END

         SELECT TOP 1 @cOrderKey = OrderKey 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ID = @cPalletKey
         AND  [Status] < '9'

         -- Get the mbolkey for this particular pallet id
         SELECT @cMBOL4PltID = MbolKey, @cLoadKey = LoadKey  
         FROM dbo.MBOLDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.ID = @cPalletKey
         AND   LLI.Qty > 0
         AND   LOC.Facility = @cFacility
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cStorerKey, @cSku, @cLot, @cFromLoc, @nQty
         WHILE @@FETCH_STATUS <> -1 
         BEGIN
            SET @cMoveRefKey = ''
            SET @bSuccess = 1    
            EXECUTE nspg_getkey    
               @KeyName       = 'MoveRefKey',
               @fieldlength   = 10,
               @keystring     = @cMoveRefKey       OUTPUT, 
               @b_Success     = @bSuccess          OUTPUT,
               @n_err         = @nErrNo            OUTPUT,
               @c_errmsg      = @cErrMsg           OUTPUT

            IF NOT @bSuccess = 1    
            BEGIN    
               SET @nErrNo = 125502   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get RFKey Fail 
               GOTO Quit
            END 

            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                MoveRefKey = @cMoveRefKey
               ,EditWho    = SUSER_NAME()
               ,EditDate   = GETDATE()
               ,Trafficcop = NULL
            WHERE ID = @cPalletKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSku
            AND Status < '9'
            AND ShipFlag <> 'Y'
            AND LOT = @cLot
            AND LOC = @cFromLoc

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 125503   
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
               , @cPalletKey              -- @c_FromID      
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
               SET @nErrNo = 125504   
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
                  SET @nErrNo = 125505   
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
                         AND   RefNo = @cPalletKey
                         AND  [Status] = '9')
         BEGIN
            INSERT INTO RDT.RDTScanToTruck
                   (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate, Door)
            VALUES (@cMBOLKey, @cLoadKey, 'SCNPLT2CTN', @cPalletKey, @cContainerKey, '9', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '') 

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 125506
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsScn2TrkFail
               GOTO Quit
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cPalletKey AND Status = 'HOLD')
         BEGIN
            UPDATE dbo.ID WITH (ROWLOCK) SET 
               [Status] = 'OK'
            WHERE ID = @cPalletKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 125507
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unhold id fail
               GOTO Quit
            END
         END

         GOTO Quit
      END         
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_1637ExtUpd03  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

GO