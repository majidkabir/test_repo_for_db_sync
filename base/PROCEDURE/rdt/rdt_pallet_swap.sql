SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdt_Pallet_Swap                                          */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#316871 - Transfer goods from old pallet to a new pallet      */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2015-04-16 1.0  James    Created                                          */
/*****************************************************************************/

CREATE PROC [RDT].[rdt_Pallet_Swap](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cFromID       NVARCHAR( 18),       
   @cToID         NVARCHAR( 18),   
   @cFromLOC      NVARCHAR( 10),   
   @cSKU          NVARCHAR( 20),   
   @nQty          INT, 
   @nErrNo        INT  OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @b_success           INT, 
            @n_err               INT, 
            @c_errmsg            NVARCHAR( 250), 
            @n_debug             INT,
            @c_MoveRefKey        NVARCHAR( 10) 

   DECLARE  @cLot                NVARCHAR( 10), 
            @cLLI_SKU            NVARCHAR( 20), 
            @nLLI_Qty            INT,
            @nTranCount          INT 

   SET @n_debug = 0

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_Pallet_Swap  
  
   IF EXISTS ( SELECT 1 
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               WHERE LLI.ID = @cFromID
               AND (LLI.QtyAllocated + LLI.QtyPicked) > 0
               AND LLI.LOC = @cFromLOC)
   BEGIN
      DECLARE C_CUR_UPDLLI2 CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      WHERE LLI.ID = @cFromID
      AND LLI.Qty > 0
      AND LLI.LOC = @cFromLOC

      OPEN C_CUR_UPDLLI2
      FETCH NEXT FROM C_CUR_UPDLLI2 INTO @cStorerKey, @cLLI_SKU, @cLot, @cFromLoc, @nLLI_Qty
      WHILE @@FETCH_STATUS <> -1 
      BEGIN
         SET @c_MoveRefKey = ''
         SET @b_success = 1    
         EXECUTE   nspg_getkey    
                  'MoveRefKey'    
                  , 10    
                  , @c_MoveRefKey       OUTPUT    
                  , @b_success          OUTPUT    
                  , @n_err              OUTPUT    
                  , @c_errmsg           OUTPUT 

         IF NOT @b_success = 1    
         BEGIN    
            SET @nErrNo = 53651   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get RfKey Fail
            CLOSE C_CUR_UPDLLI2
            DEALLOCATE C_CUR_UPDLLI2
            GOTO RollBackTran
         END 

         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
         SET MoveRefKey = @c_MoveRefKey
            ,EditWho    = SUSER_NAME()
            ,EditDate   = GETDATE()
            ,Trafficcop = NULL
         WHERE ID = @cFromID
         AND StorerKey = @cStorerKey
         AND SKU = @cLLI_SKU
         AND Status < '9'
         AND ShipFlag <> 'Y'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 53652   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RfKey Fail
            CLOSE C_CUR_UPDLLI2
            DEALLOCATE C_CUR_UPDLLI2
            GOTO RollBackTran
         END

         IF @n_debug = 1
         BEGIN
            select * from pickdetail (nolock) where MoveRefKey = @c_MoveRefKey
            SELECT '@c_MoveRefKey', @c_MoveRefKey, '@cToID', @cToID, '@cStorerKey', @cStorerKey
            SELECT '@cLLI_SKU', @cLLI_SKU, '@cFromLOC', @cFromLOC, '@cFromID', @cFromID
            SELECT '@cLot', @cLot, '@nLLI_Qty', @nLLI_Qty
         END

         --Update all SKU on pallet to new ASRS LOC
         EXEC dbo.nspItrnAddMove
              NULL                                        
            , @cStorerKey              -- @c_StorerKey   
            , @cLLI_SKU                -- @c_SKU         
            , @cLot                    -- @c_Lot         
            , @cFromLoc                -- @c_FromLoc     
            , @cFromID                 -- @c_FromID      
            , @cFromLoc                -- @c_ToLoc       
            , @cToID                   -- @c_ToID        
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
            , @nLLI_Qty                -- @n_qty         
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
            , @b_success  OUTPUT       -- @b_Success   
            , @n_err      OUTPUT       -- @n_err       
            , @c_errmsg   OUTPUT       -- @c_errmsg    
            , @c_MoveRefKey            -- @c_MoveRefKey     
                                                                  
         IF @@ERROR <> 0 OR RTRIM(@c_errmsg) <> ''
         BEGIN
            SET @nErrNo = 53653   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ItrnAddMV Fail
            CLOSE C_CUR_UPDLLI2
            DEALLOCATE C_CUR_UPDLLI2
            GOTO RollBackTran
         END

         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
         SET MoveRefKey = ''
            ,EditWho    = SUSER_NAME()
            ,EditDate   = GETDATE()
            ,Trafficcop = NULL
         WHERE MoveRefKey = @c_MoveRefKey

         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 53654   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RFKEY FAIL
            CLOSE C_CUR_UPDLLI2
            DEALLOCATE C_CUR_UPDLLI2
            GOTO RollBackTran
         END

         FETCH NEXT FROM C_CUR_UPDLLI2 INTO @cStorerKey, @cLLI_SKU, @cLot, @cFromLoc, @nLLI_Qty
      END
      CLOSE C_CUR_UPDLLI2
      DEALLOCATE C_CUR_UPDLLI2
   END
   ELSE
   BEGIN
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
         @cSourceType = 'rdt_Pallet_Swap', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cFromLOC, 
         @cToLOC      = @cFromLOC,
         @cFromID     = @cFromID,
         @cToID       = @cToID 

         IF @nErrNo <> 0
            GOTO RollBackTran
   END
   
     --Send message to WCS to swap the existing task for OLD pallet to NEW pallet
      --Start Call WCS message.  
      SET @nErrNo = 0

      EXEC isp_TCP_WCS_MsgProcess  
         @c_MessageName    = 'PLTSWAP'
       , @c_MessageType    = 'SEND'
       , @c_OrigMessageID  = ''
       , @c_PalletID       = @cFromID
       , @c_FromLoc        = ''
       , @c_ToLoc          = ''        
       , @c_Priority       = ''
       , @c_UD1            = @cToID 
       , @c_UD2            = '' 
       , @c_UD3            = ''
       , @c_TaskDetailKey  = ''  	
       , @n_SerialNo       = ''
       , @b_debug          = 0
       , @b_Success        = @b_Success   OUTPUT
       , @n_Err            = @nErrNo      OUTPUT
       , @c_ErrMsg         = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 53655   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SEND WCS FAIL
         GOTO RollBackTran
      END
      
   GOTO Quit

   RollBackTran:  
         ROLLBACK TRAN rdt_Pallet_Swap  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
END

GO